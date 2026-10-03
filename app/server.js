'use strict';

/**
 * Serveur Node.js (point 5 - optionnel - du challenge COBOL).
 *
 * Deux usages, meme mecanique de soumission (voir submitJclTemplate) :
 *   - /api/search   pilote CLMRPT (lecture seule) via RUNRPT.template.jcl
 *   - /api/maintain pilote CLMMAINT (insert/update/delete, point 9.3.4)
 *                   via RUNMAINT.template.jcl
 *
 * Flux commun :
 *   1. Le navigateur poste une demande (recherche ou maintenance).
 *   2. On fabrique un JCL temporaire a partir du gabarit correspondant
 *      en remplacant {{REQUEST}} par la ligne SYSIN construite.
 *   3. On soumet ce JCL avec le Zowe CLI deja installe/configure sur
 *      cette machine (`zowe zos-jobs submit local-file ... --wfo --rfj`),
 *      ce qui attend la fin du job et renvoie son statut en JSON.
 *   4. On liste les fichiers spool du job (`zowe zos-jobs list
 *      spool-files-by-jobid`) pour trouver celui nomme SYSOUT (c'est la
 *      DD ou CLMRPT/CLMMAINT ecrivent leur sortie via DISPLAY).
 *   5. On recupere son contenu texte (`zowe zos-jobs view
 *      spool-file-by-id`) et on le renvoie au navigateur.
 *
 * Pre-requis sur cette machine :
 *   - Zowe CLI installe (npm install -g @zowe/cli) et un profil zosmf
 *     par defaut deja configure (celui que Zowe Explorer utilise,
 *     ex: "zowe config list" doit afficher ton profil LearnCOBOL).
 *   - Node.js 18+ (pour fetch/crypto.randomUUID, utilises ici).
 */

const express = require('express');
const path = require('path');
const fs = require('fs/promises');
const os = require('os');
const crypto = require('crypto');
const { execFile } = require('child_process');
const { promisify } = require('util');

const execFileAsync = promisify(execFile);

const PORT = process.env.PORT || 3000;
const TEMPLATE_PATH_RPT = path.join(__dirname, 'jcl', 'RUNRPT.template.jcl');
const TEMPLATE_PATH_MAINT = path.join(__dirname, 'jcl', 'RUNMAINT.template.jcl');
const ZOWE_TIMEOUT_MS = 2 * 60 * 1000; // le job + les 3 commandes zowe

const ZOWE_BIN = 'zowe';

// Sous Windows, le Zowe CLI s'installe comme "zowe.cmd" (un script, pas
// un .exe). Depuis Node 18.20/20.12/22 (correctif de securite CVE-2024-27980),
// execFile refuse d'executer un .cmd/.bat directement (erreur EINVAL) sauf
// si on passe par un shell. "shell: true" laisse cmd.exe resoudre "zowe"
// -> "zowe.cmd" via PATH/PATHEXT, comme le ferait une invite de commandes.
const EXEC_OPTS_EXTRA = process.platform === 'win32' ? { shell: true } : {};

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

/**
 * Valide la demande envoyee par le navigateur.
 * Accepte "ALL" ou exactement 8 chiffres (format Record-ID MMJJAAAA).
 * Rejette tout le reste (protection : cette valeur est inseree telle
 * quelle dans le texte du JCL soumis sur le mainframe).
 */
function validateRequest(raw) {
  const value = String(raw || '').trim().toUpperCase();
  if (value === 'ALL') {
    return 'ALL';
  }
  if (/^[0-9]{8}$/.test(value)) {
    return value;
  }
  return null;
}

/**
 * Construit et valide la ligne SYSIN d'une demande de maintenance
 * pour CLMMAINT (voir cobol/CLMMAINT.cbl et app/jcl/RUNMAINT.template.jcl)
 * a partir du corps JSON envoye par le formulaire. Renvoie soit
 * { line } soit { error } - jamais les deux.
 *
 * Format attendu par CLMMAINT, separe par des virgules :
 *   I,RECORD-ID,DATE,SEX-INA,SEX-FEMALE,SEX-MALE
 *   U,RECORD-ID,DATE,SEX-INA,SEX-FEMALE,SEX-MALE
 *   D,RECORD-ID
 *
 * Chaque champ est valide ici cote serveur avant d'etre insere dans
 * le texte du JCL soumis sur le mainframe (meme logique de defense
 * que validateRequest() pour /api/search).
 */
function buildMaintenanceLine(body) {
  const func = String((body && body.function) || '').trim().toUpperCase();
  if (!['I', 'U', 'D'].includes(func)) {
    return { error: 'Fonction invalide : attendu I (insertion), U (modification) ou D (suppression).' };
  }

  const recordId = String((body && body.recordId) || '').trim();
  if (!/^[0-9]{8}$/.test(recordId)) {
    return { error: 'Record-ID invalide : attendu exactement 8 chiffres (ex 08012012).' };
  }

  if (func === 'D') {
    return { line: `D,${recordId}` };
  }

  const date = String((body && body.date) || '').trim();
  if (!/^[0-9]{2}\/[0-9]{2}\/[0-9]{4}$/.test(date)) {
    return { error: 'Date invalide : attendu le format MM/JJ/AAAA (ex 08/01/2012).' };
  }

  const sexFields = ['sexIna', 'sexFemale', 'sexMale'];
  const sexValues = [];
  for (const field of sexFields) {
    const raw = String((body && body[field]) || '').trim();
    if (!/^[0-9]{1,7}$/.test(raw)) {
      return {
        error: 'Valeurs SEX invalides : attendu un nombre entier (0 a 9999999) ' +
          'pour chacun des 3 champs (Non renseigne / Femmes / Hommes).'
      };
    }
    sexValues.push(String(Number(raw)));
  }

  return { line: `${func},${recordId},${date},${sexValues.join(',')}` };
}

/** Execute une commande zowe et parse sa sortie JSON (--rfj). */
async function runZoweJson(args) {
  const { stdout } = await execFileAsync(ZOWE_BIN, args, {
    timeout: ZOWE_TIMEOUT_MS,
    maxBuffer: 10 * 1024 * 1024,
    ...EXEC_OPTS_EXTRA
  });
  return JSON.parse(stdout);
}

/** Execute une commande zowe et renvoie sa sortie texte brute. */
async function runZoweText(args) {
  const { stdout } = await execFileAsync(ZOWE_BIN, args, {
    timeout: ZOWE_TIMEOUT_MS,
    maxBuffer: 10 * 1024 * 1024,
    ...EXEC_OPTS_EXTRA
  });
  return stdout;
}

/**
 * Mecanique commune aux deux usages de l'appli : construit un JCL a
 * partir d'un gabarit + d'une ligne SYSIN, le soumet avec le Zowe CLI,
 * attend la fin du job et renvoie le contenu de sa DD SYSOUT.
 *
 * - templatePath : jcl/RUNRPT.template.jcl ou jcl/RUNMAINT.template.jcl
 * - requestLine  : la ou les lignes a inserer a la place de {{REQUEST}}
 * - tmpPrefix    : prefixe du fichier JCL temporaire (pour le distinguer
 *                  dans le dossier temp en cas de probleme)
 *
 * Renvoie { status, body } directement exploitable par res.status().json()
 * cote appelant, pour garder la meme forme de reponse qu'avant ce
 * refactoring (succes -> 200, divers echecs -> 400/500/502).
 */
async function submitJclTemplate(templatePath, requestLine, tmpPrefix) {
  const tmpFile = path.join(os.tmpdir(), `${tmpPrefix}-${crypto.randomUUID()}.jcl`);

  try {
    // 1. Construit le JCL a partir du gabarit
    const template = await fs.readFile(templatePath, 'utf8');
    if (!template.includes('{{REQUEST}}')) {
      return {
        status: 500,
        body: {
          error: `Le fichier ${path.basename(templatePath)} ne contient pas ` +
            'le marqueur {{REQUEST}} - re-telecharge le fichier fourni et ' +
            'remplace-le entierement (ne pas l\'editer a la main).',
          templatePath
        }
      };
    }
    const jcl = template.replaceAll('{{REQUEST}}', requestLine);
    console.log('----- JCL soumis -----\n' + jcl + '\n-----------------------');
    await fs.writeFile(tmpFile, jcl, 'utf8');

    // 2. Soumet et attend la fin du job
    const submitResult = await runZoweJson([
      'zos-jobs', 'submit', 'local-file', tmpFile,
      '--wait-for-output', '--rfj'
    ]);
    if (!submitResult.success) {
      return {
        status: 502,
        body: { error: 'Echec de soumission du job', detail: submitResult.message || submitResult }
      };
    }
    const job = submitResult.data;
    const jobid = job.jobid;
    console.log(`[${jobid}] job=${job.jobname} status=${job.status} retcode=${job.retcode}`);

    // 3. Liste les fichiers spool pour trouver la DD SYSOUT
    const spoolListResult = await runZoweJson([
      'zos-jobs', 'list', 'spool-files-by-jobid', jobid, '--rfj'
    ]);
    const spoolFiles = (spoolListResult.data || []);
    console.log(`[${jobid}] DDs spool: ` +
      spoolFiles.map((f) => `${f.ddname}(id=${f.id})`).join(', '));
    const sysoutFile = spoolFiles.find(
      (f) => String(f.ddname).toUpperCase() === 'SYSOUT'
    );
    if (!sysoutFile) {
      return {
        status: 502,
        body: {
          error: 'DD SYSOUT introuvable dans le spool du job',
          jobid,
          jobStatus: job.status,
          retcode: job.retcode,
          availableDDs: spoolFiles.map((f) => f.ddname)
        }
      };
    }

    // 4. Recupere le contenu du rapport
    const report = await runZoweText([
      'zos-jobs', 'view', 'spool-file-by-id', jobid, String(sysoutFile.id)
    ]);

    return {
      status: 200,
      body: { jobid, jobname: job.jobname, retcode: job.retcode, status: job.status, report }
    };
  } catch (err) {
    return {
      status: 500,
      body: { error: 'Erreur lors de l\'appel au Zowe CLI', detail: err.stderr ? err.stderr.toString() : err.message }
    };
  } finally {
    await fs.unlink(tmpFile).catch(() => {});
  }
}

app.post('/api/search', async (req, res) => {
  const request = validateRequest(req.body && req.body.recordId);
  if (!request) {
    return res.status(400).json({
      error: "Record-ID invalide : attendu 8 chiffres (ex 08012012) ou \"ALL\"."
    });
  }

  const { status, body } = await submitJclTemplate(TEMPLATE_PATH_RPT, request, 'runrpt');
  return res.status(status).json(body);
});

app.post('/api/maintain', async (req, res) => {
  const { line, error } = buildMaintenanceLine(req.body);
  if (error) {
    return res.status(400).json({ error });
  }

  const { status, body } = await submitJclTemplate(TEMPLATE_PATH_MAINT, line, 'runmaint');
  return res.status(status).json(body);
});

app.listen(PORT, () => {
  console.log(`Unemployment Claims app -> http://localhost:${PORT}`);
});
