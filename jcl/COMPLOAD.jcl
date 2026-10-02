//COMPLOAD JOB 1,NOTIFY=&SYSUID
//*-------------------------------------------------------------------
//* Compile + link-edite CLMLOAD avec la proc IGYWCL
//* Source   : Z87663.CBL(CLMLOAD)
//* Copybook : Z87663.COPYLIB(CLMREC)
//* Module   : Z87663.LOAD(CLMLOAD)
//*-------------------------------------------------------------------
//COBRUN   EXEC IGYWCL
//COBOL.SYSIN  DD DSN=&SYSUID..CBL(CLMLOAD),DISP=SHR
//COBOL.SYSLIB DD DSN=&SYSUID..COPYLIB,DISP=SHR
//LKED.SYSLMOD DD DSN=&SYSUID..LOAD(CLMLOAD),DISP=SHR
