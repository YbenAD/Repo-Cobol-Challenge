//DEFCLUS  JOB (ACCT),'DEFINE VSAM',CLASS=A,MSGCLASS=X,
//             NOTIFY=&SYSUID
//*-----------------------------------------------------------------
//* Definit le cluster VSAM KSDS pour les Unemployment Claims.
//* Cle = CLM-RECORD-ID, 8 octets, offset 0.
//* Longueur d'enregistrement fixe = 317 (voir copybook CLMREC :
//* 8 cle + 10 date + 9 age + 3 ethnicity + 21 industry + 6 race
//* + 3 sex + 5 flags = 317).
//* Pas de VOLUMES() : l'allocation est laissee au SMS.
//* Si ton site impose une classe, ajoute par exemple
//*   STORAGECLASS(xxx)  (demande le nom a ton admin / regarde
//*   celui de Z87663.TEST.VSAM avec LISTCAT ENTRIES(...) ALL).
//*-----------------------------------------------------------------
//STEP1    EXEC PGM=IDCAMS
//SYSPRINT DD   SYSOUT=*
//SYSIN    DD   *
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
