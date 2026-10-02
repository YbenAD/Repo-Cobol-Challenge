//RUNRPT   JOB 1,NOTIFY=&SYSUID
//*-----------------------------------------------------------------
//* Execute CLMRPT (rapport) qui appelle CLMREAD (acces VSAM)
//* SYSIN : une demande par ligne, en colonnes 1-8
//*   un Record ID (ex 01012012) -> fiche detaillee
//*   ALL                        -> liste de tous les enregistrements
//*
//* Ce fichier est un TEMPLATE : le serveur Node.js remplace la
//* ligne SYSIN marquee ci-dessous par le Record-ID demande
//* (ex: 08012012) ou par le mot "ALL" avant de soumettre une
//* copie temporaire via le Zowe CLI (voir server.js). Il n'utilise
//* PAS le membre Z87663.JCL(RUNRPT) deja sur le mainframe : --wfo
//* soumet un fichier local directement a z/OSMF a chaque recherche.
//*-----------------------------------------------------------------
//RPTSTEP  EXEC PGM=CLMRPT
//STEPLIB  DD DISP=SHR,DSN=Z87663.LOAD
//CLAIMIN  DD DISP=SHR,DSN=Z87663.CLAIMS.VSAM
//SYSOUT   DD SYSOUT=*
//CEEDUMP  DD SYSOUT=*
//SYSIN    DD *
{{REQUEST}}
/*
