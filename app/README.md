# Unemployment Claims - Application Web (point 5, optionnel)

Petite application Node.js / Express avec deux onglets :
- **Recherche** : lire un enregistrement de chomage du Missouri (ou tous
  les enregistrements), sans passer par l'ecran vert.
- **Maintenance** (point 9.3.4, optionnel) : inserer, modifier ou
  supprimer un enregistrement.

Les deux pilotent le mainframe z/OS a travers le **Zowe CLI**.

Elle fait partie du challenge COBOL "9.3 - The Unemployment Claims" :
1. `CLMLOAD` charge les 5 CSV dans le VSAM `Z87663.CLAIMS.VSAM`.
2. `CLMREAD` est le sous-programme d'acces au VSAM (lecture par cle ou
   sequentielle, plus insertion/mise a jour/suppression - point 9.3.4).
3. `CLMRPT` est le programme de rapport qui appelle `CLMREAD`.
4. `CLMMAINT` est le programme de maintenance qui appelle lui aussi
   `CLMREAD` pour inserer/modifier/supprimer un enregistrement.
5. Cette application web est le point optionnel : au lieu de lancer les
   JCL `RUNRPT`/`RUNMAINT` a la main dans Zowe Explorer, on remplit un
   formulaire et le serveur soumet un job equivalent pour nous.

## Comment ca marche

```
Navigateur --POST /api/search----> server.js --Zowe CLI--> z/OSMF --> JES (CLMRPT)
Navigateur --POST /api/maintain--> server.js --Zowe CLI--> z/OSMF --> JES (CLMMAINT)
```

Les deux routes partagent la meme mecanique de soumission
(`submitJclTemplate` dans `server.js`), seuls le gabarit JCL et la ligne
SYSIN construite different :

1. Le navigateur poste sa demande :
   - `/api/search` : `{ recordId: "08012012" }` (ou `"ALL"`).
   - `/api/maintain` : `{ function: "I"|"U"|"D", recordId, date,
     sexIna, sexFemale, sexMale }` (`date` et les 3 valeurs `sex*` sont
     ignores/optionnels pour une suppression).
2. `server.js` valide strictement chaque champ (le Record-ID doit faire
   exactement 8 chiffres, la fonction doit etre I/U/D, les valeurs SEX
   doivent etre des entiers 0-9999999, etc.) - ces valeurs sont inserees
   telles quelles dans un JCL, donc la validation cote serveur est la
   premiere ligne de defense.
3. Il part du gabarit correspondant (`jcl/RUNRPT.template.jcl` ou
   `jcl/RUNMAINT.template.jcl`), remplace le marqueur `{{REQUEST}}` par
   la ligne construite (ex: `I,09152026,09/15/2026,10,1500,2000`), et
   ecrit une copie temporaire.
4. Il soumet cette copie avec :
   `zowe zos-jobs submit local-file <fichier> --wait-for-output --rfj`
   (`--wait-for-output` bloque jusqu'a la fin du job ; `--rfj` renvoie du
   JSON exploitable).
5. Il liste les fichiers spool du job
   (`zowe zos-jobs list spool-files-by-jobid <jobid> --rfj`) pour trouver
   celui dont le `ddname` est `SYSOUT` (c'est la DD ou `CLMRPT`/`CLMMAINT`
   ecrivent leur sortie via `DISPLAY`).
6. Il recupere son contenu texte
   (`zowe zos-jobs view spool-file-by-id <jobid> <id>`) et le renvoie au
   navigateur avec le statut du job (`status`, `retcode` au format
   `CC nnnn`).

Pour la maintenance, seule la dimension SEX est saisissable depuis le
formulaire (pour rester simple) : une insertion met les dimensions
AGE/ETHNICITY/INDUSTRY/RACE a 0, et une modification les laisse
inchangees (CLMMAINT relit d'abord l'enregistrement existant). Voir
`cobol/CLMMAINT.cbl` pour le detail du format SYSIN si tu veux piloter
davantage de champs.

Aucune donnee n'est stockee cote serveur : chaque recherche est un aller-
retour complet vers le mainframe.

## Pre-requis

- **Node.js 18+** (utilise `fs/promises`, `crypto.randomUUID`, etc.)
- **Zowe CLI** installe globalement et un profil `zosmf` par defaut deja
  configure - c'est le meme profil que celui utilise par Zowe Explorer
  dans VS Code :

  ```bash
  npm install -g @zowe/cli
  zowe config list          # verifie que ton profil (ex: LearnCOBOL) apparait
  zowe zos-jobs list jobs   # test rapide : doit lister tes jobs recents
  ```

- Sur le mainframe, les membres suivants doivent deja exister et avoir ete
  compiles avec succes :
  - `Z87663.LOAD(CLMLOAD)`, `Z87663.LOAD(CLMREAD)`, `Z87663.LOAD(CLMRPT)`,
    `Z87663.LOAD(CLMMAINT)` (uniquement necessaire pour l'onglet
    Maintenance)
  - Le cluster VSAM `Z87663.CLAIMS.VSAM` doit avoir ete charge (job
    `RUNLOAD`) au moins une fois.

## Installation et demarrage

```bash
cd app
npm install
npm start
```

Puis ouvrir `http://localhost:3000` dans un navigateur. Le port peut etre
change avec la variable d'environnement `PORT` :

```bash
# Windows (cmd)
set PORT=3001 && npm start

# Windows (PowerShell)
$env:PORT=3001; npm start

# Linux / macOS
PORT=3001 npm start
```

## Utilisation

### Onglet Recherche

1. Entrer un Record-ID au format `MMJJAAAA` (ex. `08012012` pour aout
   2012), ou taper `ALL` pour obtenir le tableau recapitulatif de tous les
   enregistrements charges.
2. Cliquer sur **Rechercher**. La soumission d'un job JCL reel sur le
   mainframe prend generalement quelques secondes.
3. Le rapport (identique a ce que `CLMRPT` afficherait en SYSOUT dans
   Zowe Explorer) s'affiche tel quel.

### Onglet Maintenance (point 9.3.4)

1. Choisir l'operation (**Insertion**, **Modification** ou
   **Suppression**) et entrer le Record-ID.
2. Pour une insertion ou une modification, remplir la Date et les 3
   valeurs SEX (Non renseigne / Femmes / Hommes).
3. Cliquer sur **Executer**. Le resultat (identique a ce que `CLMMAINT`
   afficherait en SYSOUT) s'affiche tel quel, avec le bilan
   "X OK / Y EN ERREUR".

La suppression est definitive : un avertissement s'affiche dans le
formulaire avant d'executer.

## Securite / limites volontaires

- `recordId` est strictement valide (regex `^[0-9]{8}$` ou `ALL`) avant
  d'etre insere dans le texte du JCL soumis : ca evite qu'une valeur
  inattendue ne modifie la structure du job.
- Le fichier JCL temporaire est ecrit dans le dossier temp du systeme et
  supprime juste apres la soumission (bloc `finally`), succes ou echec.
- Il n'y a pas d'authentification sur `/api/search` : cette application
  est pensee pour un usage local / pedagogique, pas pour etre exposee
  publiquement en l'etat. Pour un usage reel, ajouter au minimum une
  authentification devant le serveur Express et restreindre le profil
  Zowe utilise aux droits strictement necessaires (lecture du VSAM,
  soumission de ce job precis).

## Depannage

| Symptome | Cause probable | Solution |
|---|---|---|
| `EADDRINUSE: address already in use :::3000` | Un process ecoute deja sur ce port | Changer de port (`PORT=3001`) ou tuer l'ancien process |
| `spawn zowe ENOENT` / `spawn EINVAL` (Windows) | Node ne trouve pas / ne peut pas executer `zowe.cmd` directement | Deja corrige dans `server.js` via `shell: true` sous Windows - verifier que `zowe` est bien dans le PATH |
| `DD SYSOUT introuvable dans le spool du job` | Le job a echoue avant d'ecrire sur SYSOUT, ou noms de DD inattendus | Regarder `jobStatus` / `retcode` / `availableDDs` renvoyes dans l'erreur ; verifier `Z87663.LOAD` et `Z87663.CLAIMS.VSAM` |
| Le rapport affiche du texte bizarre a la place du Record-ID | Gabarit JCL corrompu / marqueur modifie a la main | Ne pas editer `jcl/RUNRPT.template.jcl` autrement qu'en gardant exactement un `{{REQUEST}}` sur sa propre ligne |
