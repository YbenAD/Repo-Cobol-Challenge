# Unemployment Claims - Application Web (point 5, optionnel)

Petite application Node.js / Express qui permet de rechercher un
enregistrement de chomage du Missouri (ou tous les enregistrements) sans
passer par l'ecran vert, en pilotant le mainframe z/OS a travers le
**Zowe CLI**.

Elle fait partie du challenge COBOL "9.3 - The Unemployment Claims" :
1. `CLMLOAD` charge les 5 CSV dans le VSAM `Z87663.CLAIMS.VSAM`.
2. `CLMREAD` est le sous-programme d'acces au VSAM (lecture par cle ou
   sequentielle).
3. `CLMRPT` est le programme de rapport qui appelle `CLMREAD`.
4. Cette application web est le point optionnel : au lieu de lancer le JCL
   `RUNRPT` a la main dans Zowe Explorer, on tape un Record-ID dans un
   formulaire, et le serveur soumet un job equivalent pour nous.

## Comment ca marche

```
Navigateur --POST /api/search--> server.js --Zowe CLI--> z/OSMF --> JES (job RUNRPT)
```

1. Le navigateur envoie `{ recordId: "08012012" }` (ou `"ALL"`) a
   `/api/search`.
2. `server.js` valide la valeur (8 chiffres ou `ALL` uniquement - elle est
   inseree telle quelle dans un JCL, donc on filtre strictement).
3. Il part du gabarit `jcl/RUNRPT.template.jcl`, remplace le marqueur
   `{{REQUEST}}` par la valeur demandee, et ecrit une copie temporaire.
4. Il soumet cette copie avec :
   `zowe zos-jobs submit local-file <fichier> --wait-for-output --rfj`
   (`--wait-for-output` bloque jusqu'a la fin du job ; `--rfj` renvoie du
   JSON exploitable).
5. Il liste les fichiers spool du job
   (`zowe zos-jobs list spool-files-by-jobid <jobid> --rfj`) pour trouver
   celui dont le `ddname` est `SYSOUT` (c'est la DD ou `CLMRPT` ecrit son
   rapport via `DISPLAY`).
6. Il recupere son contenu texte
   (`zowe zos-jobs view spool-file-by-id <jobid> <id>`) et le renvoie au
   navigateur avec le statut du job (`status`, `retcode` au format
   `CC nnnn`).

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
  - `Z87663.LOAD(CLMLOAD)`, `Z87663.LOAD(CLMREAD)`, `Z87663.LOAD(CLMRPT)`
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

1. Entrer un Record-ID au format `MMJJAAAA` (ex. `08012012` pour aout
   2012), ou taper `ALL` pour obtenir le tableau recapitulatif de tous les
   enregistrements charges.
2. Cliquer sur **Rechercher**. La soumission d'un job JCL reel sur le
   mainframe prend generalement quelques secondes.
3. Le rapport (identique a ce que `CLMRPT` afficherait en SYSOUT dans
   Zowe Explorer) s'affiche tel quel.

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
