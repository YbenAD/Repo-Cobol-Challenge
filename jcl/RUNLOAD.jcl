//RUNLOAD  JOB (1),NOTIFY=&SYSUID
//*-------------------------------------------------------------------
//* Etape 1 : (re)definit le cluster VSAM via IDCAMS (DELETE+DEFINE).
//* Etape 2 : execute CLMLOAD pour fusionner les 5 CSV et charger
//*           le VSAM, seulement si l'etape IDCAMS a reussi (COND).
//*-------------------------------------------------------------------
//DEFVSAM  EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DELETE Z87663.CLAIMS.VSAM CLUSTER PURGE
  SET MAXCC = 0
  DEFINE CLUSTER (NAME(Z87663.CLAIMS.VSAM)               -
         INDEXED                                        -
         KEYS(8 0)                                      -
         RECORDSIZE(317 317)                             -
         FREESPACE(10 10)                                -
         TRACKS(5 5)                                      -
         SHAREOPTIONS(2 3) )                               -
         DATA  (NAME(Z87663.CLAIMS.VSAM.DATA))              -
         INDEX (NAME(Z87663.CLAIMS.VSAM.INDEX))
/*
//RUNSTEP  EXEC PGM=CLMLOAD,COND=(0,NE,DEFVSAM)
//STEPLIB  DD DISP=SHR,DSN=Z87663.LOAD
//AGEIN    DD DISP=SHR,DSN=Z87663.UCAGE.CSV
//ETHIN    DD DISP=SHR,DSN=Z87663.UCAETHN.CSV
//INDIN    DD DISP=SHR,DSN=Z87663.UCAINDT.CSV
//RACEIN   DD DISP=SHR,DSN=Z87663.UCARACE.CSV
//SEXIN    DD DISP=SHR,DSN=Z87663.UCSEX.CSV
//CLAIMOUT DD DISP=SHR,DSN=Z87663.CLAIMS.VSAM
//SYSOUT   DD SYSOUT=*
//CEEDUMP  DD SYSOUT=*
