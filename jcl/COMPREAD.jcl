//COMPREAD JOB 1,NOTIFY=&SYSUID
//*-------------------------------------------------------------------
//* Compile + link-edite CLMREAD (sous-programme d'acces VSAM) avec
//* la proc IGYWCL.
//* Source   : Z87663.CBL(CLMREAD)
//* Copybook : Z87663.COPYLIB(CLMLINK), Z87663.COPYLIB(CLMREC)
//* Module   : Z87663.LOAD(CLMREAD)
//*
//* CLMREAD est appele dynamiquement par CLMRPT (CALL 'CLMREAD').
//* Les deux doivent se trouver dans la meme LOADLIB (Z87663.LOAD)
//* pour que l'appel soit resolu via le STEPLIB au moment du RUNRPT.
//*-------------------------------------------------------------------
//COBRUN   EXEC IGYWCL
//COBOL.SYSIN  DD DSN=&SYSUID..CBL(CLMREAD),DISP=SHR
//COBOL.SYSLIB DD DSN=&SYSUID..COPYLIB,DISP=SHR
//LKED.SYSLMOD DD DSN=&SYSUID..LOAD(CLMREAD),DISP=SHR
