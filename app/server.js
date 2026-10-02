'use strict';

/**
 * Serveur Node.js (point 5 - optionnel - du challenge COBOL).
 *
 * Flux :
 *   1. Le navigateur poste un Record-ID (ou "ALL") sur /api/search.
 *   2. On fabrique un JCL temporaire a partir de jcl/RUNRPT.template.jcl
 *      en remplacant {{REQUEST}} par la demande.
 *   3. On soumet ce JCL avec le Zowe CLI deja installe/configure sur
 *      cette machine (`zowe zos-jobs submit local-file ... --wfo --rfj`),
 *      ce qui attend la fin du job et renvoie son statut en JSON.
 *   4. On liste les fichiers spool du job (`zowe zos-jobs list
 *      spool-files-by-jobid`) pour trouver celui nomme SYSOUT (c'est la
 *      DD ou CLMRPT ecrit son rapport via DISPLAY).
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
const TEMPLATE_PATH = path.join(__dirname, 'jcl', 'RUNRPT.template.jcl');
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

app.post('/api/search', async (req, res) => {
  const request = validateRequest(req.body && req.body.recordId);
  if (!request) {
    return res.status(400).json({
      error: "Record-ID invalide : attendu 8 chiffres (ex 08012012) ou \"ALL\"."
    });
  }

  const tmpFile = path.join(
    os.tmpdir(),
    `runrpt-${crypto.randomUUID()}.jcl`
  );

  try {
    // 1. Construit le JCL a partir du template
    const template = await fs.readFile(TEMPLATE_PATH, 'utf8');
    if (!template.includes('{{REQUEST}}')) {
      return res.status(500).json({
        error: 'Le fichier jcl/RUNRPT.template.jcl ne contient pas le ' +
          'marqueur {{REQUEST}} - re-telecharge le fichier fourni ' +
          'et remplace-le entierement (ne pas l\'editer a la main).',
        templatePath: TEMPLATE_PATH
      });
    }
    const jcl = template.replaceAll('{{REQUEST}}', request);
    console.log('----- JCL soumis -----\n' + jcl + '\n-----------------------');
    await fs.writeFile(tmpFile, jcl, 'utf8');

    // 2. Soumet et attend la fin du job
    const submitResult = await runZoweJson([
      'zos-jobs', 'submit', 'local-file', tmpFile,
      '--wait-for-output', '--rfj'
    ]);
    if (!submitResult.success) {
      return res.status(502).json({
        error: 'Echec de soumission du job',
        detail: submitResult.message || submitResult
      });
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
      return res.status(502).json({
        error: 'DD SYSOUT introuvable dans le spool du job',
        jobid,
        jobStatus: job.status,
        retcode: job.retcode,
        availableDDs: spoolFiles.map((f) => f.ddname)
      });
    }

    // 4. Recupere le contenu du rapport
    const report = await runZoweText([
      'zos-jobs', 'view', 'spool-file-by-id', jobid, String(sysoutFile.id)
    ]);

    return res.json({
      jobid,
      jobname: job.jobname,
      retcode: job.retcode,
      status: job.status,
      report
    });
  } catch (err) {
    return res.status(500).json({
      error: 'Erreur lors de l\'appel au Zowe CLI',
      detail: err.stderr ? err.stderr.toString() : err.message
    });
  } finally {
    await fs.unlink(tmpFile).catch(() => {});
  }
});

app.listen(PORT, () => {
  console.log(`Unemployment Claims app -> http://localhost:${PORT}`);
});
