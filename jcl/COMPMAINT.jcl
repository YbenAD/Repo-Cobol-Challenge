//CMPMAINT JOB 1,NOTIFY=&SYSUID
//*-------------------------------------------------------------------
//* Compile + link-edite CLMMAINT (programme de maintenance : insert /
//* update / delete - point 9.3.4 du challenge) avec la proc IGYWCL.
//* Source   : Z87663.CBL(CLMMAINT)
//* Copybook : Z87663.COPYLIB(CLMLINK), Z87663.COPYLIB(CLMREC)
//* Module   : Z87663.LOAD(CLMMAINT)
//*
//* CLMMAINT appelle dynamiquement CLMREAD : compile CLMREAD (voir
//* COMPREAD.jcl) avant d'executer RUNMAINT.jcl.
//*-------------------------------------------------------------------
//COBRUN   EXEC IGYWCL
//COBOL.SYSIN  DD DSN=&SYSUID..CBL(CLMMAINT),DISP=SHR
//COBOL.SYSLIB DD DSN=&SYSUID..COPYLIB,DISP=SHR
//LKED.SYSLMOD DD DSN=&SYSUID..LOAD(CLMMAINT),DISP=SHR
