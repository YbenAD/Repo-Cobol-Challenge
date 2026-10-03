//RUNMAINT JOB 1,NOTIFY=&SYSUID
//*-------------------------------------------------------------------
//* Execute CLMMAINT (maintenance du VSAM : insert / update / delete)
//* SYSIN : une demande par ligne, en colonnes 1-80, separee par des
//* virgules :
//*   I,RECORD-ID,DATE,SEX-INA,SEX-FEMALE,SEX-MALE   -> insertion
//*   U,RECORD-ID,DATE,SEX-INA,SEX-FEMALE,SEX-MALE   -> modification
//*   D,RECORD-ID                                    -> suppression
//* Une ligne vide ou commencant par * est ignoree (commentaire).
//*
//* ATTENTION : contrairement a RUNRPT (lecture seule), ce job
//* modifie reellement le contenu de Z87663.CLAIMS.VSAM. Verifier
//* les demandes avant de soumettre.
//*-------------------------------------------------------------------
//MAINTSTP EXEC PGM=CLMMAINT
//STEPLIB  DD DISP=SHR,DSN=Z87663.LOAD
//CLAIMIN  DD DISP=SHR,DSN=Z87663.CLAIMS.VSAM
//SYSOUT   DD SYSOUT=*
//CEEDUMP  DD SYSOUT=*
//SYSIN    DD *
I,09152026,09/15/2026,10,1500,2000
U,09152026,09/15/2026,10,1800,2500
D,09152026
/*
