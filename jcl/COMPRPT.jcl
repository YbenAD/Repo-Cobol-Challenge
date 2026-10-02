//COMPRPT  JOB 1,NOTIFY=&SYSUID
//*-------------------------------------------------------------------
//* Compile + link-edite CLMRPT (programme principal / rapport) avec
//* la proc IGYWCL.
//* Source   : Z87663.CBL(CLMRPT)
//* Copybook : Z87663.COPYLIB(CLMLINK), Z87663.COPYLIB(CLMREC)
//* Module   : Z87663.LOAD(CLMRPT)
//*
//* CLMRPT appelle dynamiquement CLMREAD : compile CLMREAD (voir
//* COMPREAD.jcl) avant d'executer RUNRPT.jcl.
//*-------------------------------------------------------------------
//COBRUN   EXEC IGYWCL
//COBOL.SYSIN  DD DSN=&SYSUID..CBL(CLMRPT),DISP=SHR
//COBOL.SYSLIB DD DSN=&SYSUID..COPYLIB,DISP=SHR
//LKED.SYSLMOD DD DSN=&SYSUID..LOAD(CLMRPT),DISP=SHR
