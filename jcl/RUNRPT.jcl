//RUNRPT   JOB 1,NOTIFY=&SYSUID
//*-------------------------------------------------------------------
//* Execute CLMRPT (rapport) qui appelle CLMREAD (acces VSAM)
//* SYSIN : une demande par ligne, en colonnes 1-8
//*   un Record ID (ex 01012012) -> fiche detaillee
//*   ALL                        -> liste de tous les enregistrements
//*-------------------------------------------------------------------
//RPTSTEP  EXEC PGM=CLMRPT
//STEPLIB  DD DISP=SHR,DSN=Z87663.LOAD
//CLAIMIN  DD DISP=SHR,DSN=Z87663.CLAIMS.VSAM
//SYSOUT   DD SYSOUT=*
//CEEDUMP  DD SYSOUT=*
//SYSIN    DD *
01012012
99999999
ALL
/*
