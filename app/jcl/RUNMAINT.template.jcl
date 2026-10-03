//RUNMAINT JOB 1,NOTIFY=&SYSUID
//*-----------------------------------------------------------------
//* Execute CLMMAINT (maintenance du VSAM : insert / update / delete)
//* SYSIN : une demande par ligne, separee par des virgules :
//*   I,RECORD-ID,DATE,SEX-INA,SEX-FEMALE,SEX-MALE  -> insertion
//*   U,RECORD-ID,DATE,SEX-INA,SEX-FEMALE,SEX-MALE  -> modification
//*   D,RECORD-ID                                   -> suppression
//*
//* Ce fichier est un TEMPLATE : le serveur Node.js remplace la
//* ligne SYSIN marquee ci-dessous par la demande de maintenance
//* construite a partir du formulaire (ex : I,08012012,08/01/2012,
//* 10,1500,2000) avant de soumettre une copie temporaire via le
//* Zowe CLI (voir server.js). Il n'utilise PAS le membre
//* Z87663.JCL(RUNMAINT) deja sur le mainframe : --wfo soumet un
//* fichier local directement a z/OSMF a chaque demande.
//*-----------------------------------------------------------------
//MAINTSTP EXEC PGM=CLMMAINT
//STEPLIB  DD DISP=SHR,DSN=Z87663.LOAD
//CLAIMIN  DD DISP=SHR,DSN=Z87663.CLAIMS.VSAM
//SYSOUT   DD SYSOUT=*
//CEEDUMP  DD SYSOUT=*
//SYSIN    DD *
{{REQUEST}}
/*
