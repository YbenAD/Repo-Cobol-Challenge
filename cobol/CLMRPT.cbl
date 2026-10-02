       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLMRPT.
      ******************************************************************
      * CLMRPT - rapport sur le VSAM CLAIMS
      * Lit les demandes dans SYSIN (une par ligne, colonnes 1-8) :
      *   - un Record ID (ex : 01012012)  -> fiche detaillee
      *   - ALL                           -> liste de tous les records
      *   - ligne vide ou commencant par * -> ignoree
      * Acces aux donnees uniquement via le sous-programme CLMREAD
      * (appel dynamique : CLMREAD est charge depuis la STEPLIB).
      * Rapport ecrit dans SYSOUT (DISPLAY).
      ******************************************************************
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT REQ-FILE ASSIGN TO SYSIN
               FILE STATUS IS WS-REQ-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  REQ-FILE
           RECORDING MODE F.
       01  REQ-REC.
           05  REQ-KEY                 PIC X(08).
           05  FILLER                  PIC X(72).

       WORKING-STORAGE SECTION.
       01  WS-SUBPGM                   PIC X(08) VALUE 'CLMREAD'.
       01  WS-REQ-FS                   PIC X(02).
       01  WS-REQ-EOF                  PIC X(01) VALUE 'N'.
           88  REQ-EOF                           VALUE 'Y'.

      *    ---- Zone de communication + enregistrement retourne -------
           COPY CLMLINK.
           COPY CLMREC.

       01  WS-I                        PIC S9(4) COMP.
       01  WS-TOTAL                    PIC 9(9).
       01  WS-COUNT                    PIC 9(5)  VALUE 0.
       01  WS-GRAND-TOTAL              PIC 9(11) VALUE 0.
       01  WS-ED-COUNT                 PIC ZZ,ZZ9.
       01  WS-ED-GRAND                 PIC ZZ,ZZZ,ZZZ,ZZ9.

       01  WS-SEP-EQ                   PIC X(63) VALUE ALL '='.
       01  WS-SEP                      PIC X(63) VALUE ALL '-'.

      *    ---- Ligne de detail (fiche d'un Record ID) -----------------
       01  WS-DETAIL-LINE.
           05  FILLER                  PIC X(04) VALUE SPACES.
           05  DL-LABEL                PIC X(45).
           05  DL-VALUE                PIC ZZ,ZZZ,ZZ9.

      *    ---- Liste de tous les records ------------------------------
       01  WS-SUM-HEADER.
           05  FILLER                  PIC X(11) VALUE 'RECORD ID'.
           05  FILLER                  PIC X(12) VALUE 'DATE'.
           05  FILLER                  PIC X(12) VALUE '     TOTAL'.
           05  FILLER                  PIC X(11) VALUE '   FEMMES'.
           05  FILLER                  PIC X(12) VALUE '   HOMMES'.
           05  FILLER                  PIC X(05) VALUE 'SRC'.

       01  WS-SUM-LINE.
           05  SL-KEY                  PIC X(08).
           05  FILLER                  PIC X(03) VALUE SPACES.
           05  SL-DATE                 PIC X(10).
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  SL-TOTAL                PIC ZZ,ZZZ,ZZ9.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  SL-FEMALE               PIC Z,ZZZ,ZZ9.
           05  FILLER                  PIC X(02) VALUE SPACES.
           05  SL-MALE                 PIC Z,ZZZ,ZZ9.
           05  FILLER                  PIC X(03) VALUE SPACES.
           05  SL-FLAGS                PIC X(05).

      *    ---- Libelles AGE (meme ordre que CLM-AGE-VAL) --------------
       01  WS-AGE-LBL-DATA.
           05  FILLER PIC X(45) VALUE 'Non renseigne (INA)'.
           05  FILLER PIC X(45) VALUE 'Moins de 22 ans'.
           05  FILLER PIC X(45) VALUE '22 a 24 ans'.
           05  FILLER PIC X(45) VALUE '25 a 34 ans'.
           05  FILLER PIC X(45) VALUE '35 a 44 ans'.
           05  FILLER PIC X(45) VALUE '45 a 54 ans'.
           05  FILLER PIC X(45) VALUE '55 a 59 ans'.
           05  FILLER PIC X(45) VALUE '60 a 64 ans'.
           05  FILLER PIC X(45) VALUE '65 ans et plus'.
       01  WS-AGE-LBL-TAB REDEFINES WS-AGE-LBL-DATA.
           05  WS-AGE-LBL              PIC X(45) OCCURS 9 TIMES.

      *    ---- Libelles ETHNICITY -------------------------------------
       01  WS-ETH-LBL-DATA.
           05  FILLER PIC X(45) VALUE 'Non renseigne (INA)'.
           05  FILLER PIC X(45) VALUE 'Hispanique ou Latino'.
           05  FILLER PIC X(45) VALUE 'Non hispanique ou Latino'.
       01  WS-ETH-LBL-TAB REDEFINES WS-ETH-LBL-DATA.
           05  WS-ETH-LBL              PIC X(45) OCCURS 3 TIMES.

      *    ---- Libelles INDUSTRY (noms des colonnes du CSV) -----------
       01  WS-IND-LBL-DATA.
           05  FILLER PIC X(45) VALUE
               'Non renseigne (INA)'.
           05  FILLER PIC X(45) VALUE
               'Wholesale Trade'.
           05  FILLER PIC X(45) VALUE
               'Transportation & Warehouse'.
           05  FILLER PIC X(45) VALUE
               'Construction'.
           05  FILLER PIC X(45) VALUE
               'Finance & Insurance'.
           05  FILLER PIC X(45) VALUE
               'Manufacturing'.
           05  FILLER PIC X(45) VALUE
               'Agricult./Forestry/Fishing/Hunting'.
           05  FILLER PIC X(45) VALUE
               'Public Administration'.
           05  FILLER PIC X(45) VALUE
               'Utilities'.
           05  FILLER PIC X(45) VALUE
               'Accomodation & Food Services'.
           05  FILLER PIC X(45) VALUE
               'Information'.
           05  FILLER PIC X(45) VALUE
               'Professional/Scientific/Tech. Services'.
           05  FILLER PIC X(45) VALUE
               'Real Estate & Rental & Leasing'.
           05  FILLER PIC X(45) VALUE
               'Other Services (except Public Administration)'.
           05  FILLER PIC X(45) VALUE
               'Management of Companies & Enterprises'.
           05  FILLER PIC X(45) VALUE
               'Educational Services'.
           05  FILLER PIC X(45) VALUE
               'Mining'.
           05  FILLER PIC X(45) VALUE
               'Health Care & Social Assistance'.
           05  FILLER PIC X(45) VALUE
               'Arts, Entertainment & Recreation'.
           05  FILLER PIC X(45) VALUE
               'Admin. & Support/Waste Mgmt./Remedia. Serv.'.
           05  FILLER PIC X(45) VALUE
               'Retail Trade'.
       01  WS-IND-LBL-TAB REDEFINES WS-IND-LBL-DATA.
           05  WS-IND-LBL              PIC X(45) OCCURS 21 TIMES.

      *    ---- Libelles RACE ------------------------------------------
       01  WS-RACE-LBL-DATA.
           05  FILLER PIC X(45) VALUE 'Non renseigne (INA)'.
           05  FILLER PIC X(45) VALUE 'Blanc'.
           05  FILLER PIC X(45) VALUE 'Asiatique'.
           05  FILLER PIC X(45) VALUE 'Noir ou afro-americain'.
           05  FILLER PIC X(45) VALUE 'Amerindien / natif Alaska'.
           05  FILLER PIC X(45) VALUE 'Natif Hawaii / iles Pacifique'.
       01  WS-RACE-LBL-TAB REDEFINES WS-RACE-LBL-DATA.
           05  WS-RACE-LBL             PIC X(45) OCCURS 6 TIMES.

      *    ---- Libelles SEX -------------------------------------------
       01  WS-SEX-LBL-DATA.
           05  FILLER PIC X(45) VALUE 'Non renseigne (INA)'.
           05  FILLER PIC X(45) VALUE 'Femmes'.
           05  FILLER PIC X(45) VALUE 'Hommes'.
       01  WS-SEX-LBL-TAB REDEFINES WS-SEX-LBL-DATA.
           05  WS-SEX-LBL              PIC X(45) OCCURS 3 TIMES.

       PROCEDURE DIVISION.
       0000-MAIN.
           OPEN INPUT REQ-FILE
           IF WS-REQ-FS NOT = '00'
              DISPLAY 'CLMRPT - SYSIN ILLISIBLE, STATUS=' WS-REQ-FS
              MOVE 16 TO RETURN-CODE
              STOP RUN
           END-IF
           DISPLAY WS-SEP-EQ
           DISPLAY 'CLMRPT - RAPPORT UNEMPLOYMENT CLAIMS'
           DISPLAY WS-SEP-EQ
           PERFORM 1000-READ-REQUEST
           PERFORM UNTIL REQ-EOF
              IF REQ-KEY = 'ALL'
                 PERFORM 3000-REPORT-ALL
              ELSE
                 PERFORM 2000-REPORT-ONE
              END-IF
              PERFORM 1000-READ-REQUEST
           END-PERFORM
           SET CLM-FUNC-CLOSE TO TRUE
           CALL WS-SUBPGM USING CLM-REQUEST CLM-RECORD
           CLOSE REQ-FILE
           STOP RUN.

      *---------------------------------------------------------------*
      * Lit la prochaine demande utile (ignore vides et commentaires) *
      *---------------------------------------------------------------*
       1000-READ-REQUEST.
           PERFORM WITH TEST AFTER
                   UNTIL REQ-EOF
                      OR (REQ-KEY NOT = SPACES
                          AND REQ-KEY(1:1) NOT = '*')
              READ REQ-FILE
                 AT END SET REQ-EOF TO TRUE
              END-READ
           END-PERFORM.

      *---------------------------------------------------------------*
      * Demande d'un Record ID precis -> fiche detaillee              *
      *---------------------------------------------------------------*
       2000-REPORT-ONE.
           SET CLM-FUNC-READ TO TRUE
           MOVE REQ-KEY TO CLM-REQ-KEY
           CALL WS-SUBPGM USING CLM-REQUEST CLM-RECORD
           EVALUATE TRUE
              WHEN CLM-RC-OK
                 PERFORM 5000-PRINT-DETAIL
              WHEN CLM-RC-NOTFOUND
                 DISPLAY ' '
                 DISPLAY 'RECORD ID ' REQ-KEY ' : NON TROUVE'
                 IF RETURN-CODE < 4
                    MOVE 4 TO RETURN-CODE
                 END-IF
              WHEN OTHER
                 PERFORM 8000-ERROR
           END-EVALUATE.

      *---------------------------------------------------------------*
      * Demande ALL -> liste de tous les records + totaux             *
      *---------------------------------------------------------------*
       3000-REPORT-ALL.
           MOVE 0 TO WS-COUNT WS-GRAND-TOTAL
           DISPLAY ' '
           DISPLAY 'LISTE DE TOUS LES ENREGISTREMENTS'
           DISPLAY WS-SEP
           DISPLAY WS-SUM-HEADER
           DISPLAY WS-SEP
           SET CLM-FUNC-FIRST TO TRUE
           CALL WS-SUBPGM USING CLM-REQUEST CLM-RECORD
           PERFORM UNTIL NOT CLM-RC-OK
              PERFORM 6000-PRINT-SUMMARY-LINE
              SET CLM-FUNC-NEXT TO TRUE
              CALL WS-SUBPGM USING CLM-REQUEST CLM-RECORD
           END-PERFORM
           IF CLM-RC-EOF
              MOVE WS-COUNT       TO WS-ED-COUNT
              MOVE WS-GRAND-TOTAL TO WS-ED-GRAND
              DISPLAY WS-SEP
              DISPLAY 'ENREGISTREMENTS LUS  : ' WS-ED-COUNT
              DISPLAY 'TOTAL DES DEMANDES   : ' WS-ED-GRAND
           ELSE
              PERFORM 8000-ERROR
           END-IF.

      *---------------------------------------------------------------*
      * Fiche detaillee de l'enregistrement courant                   *
      *---------------------------------------------------------------*
       5000-PRINT-DETAIL.
           DISPLAY ' '
           DISPLAY WS-SEP-EQ
           DISPLAY 'RECORD ID : ' CLM-RECORD-ID
                   '    DATE : ' CLM-DATE
           DISPLAY WS-SEP-EQ
           COMPUTE WS-TOTAL = CLM-SEX-VAL(1) + CLM-SEX-VAL(2)
                            + CLM-SEX-VAL(3)
           MOVE 'TOTAL DES DEMANDES' TO DL-LABEL
           MOVE WS-TOTAL             TO DL-VALUE
           DISPLAY WS-DETAIL-LINE

           DISPLAY WS-SEP
           DISPLAY 'AGE'
           IF CLM-FOUND-AGE = 'N'
              DISPLAY '    (aucune donnee AGE pour cette date)'
           END-IF
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 9
              MOVE WS-AGE-LBL(WS-I)  TO DL-LABEL
              MOVE CLM-AGE-VAL(WS-I) TO DL-VALUE
              DISPLAY WS-DETAIL-LINE
           END-PERFORM

           DISPLAY WS-SEP
           DISPLAY 'ETHNICITY'
           IF CLM-FOUND-ETH = 'N'
              DISPLAY '    (aucune donnee ETHNICITY pour cette date)'
           END-IF
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 3
              MOVE WS-ETH-LBL(WS-I)  TO DL-LABEL
              MOVE CLM-ETH-VAL(WS-I) TO DL-VALUE
              DISPLAY WS-DETAIL-LINE
           END-PERFORM

           DISPLAY WS-SEP
           DISPLAY 'INDUSTRY'
           IF CLM-FOUND-IND = 'N'
              DISPLAY '    (aucune donnee INDUSTRY pour cette date)'
           END-IF
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 21
              MOVE WS-IND-LBL(WS-I)  TO DL-LABEL
              MOVE CLM-IND-VAL(WS-I) TO DL-VALUE
              DISPLAY WS-DETAIL-LINE
           END-PERFORM

           DISPLAY WS-SEP
           DISPLAY 'RACE'
           IF CLM-FOUND-RACE = 'N'
              DISPLAY '    (aucune donnee RACE pour cette date)'
           END-IF
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 6
              MOVE WS-RACE-LBL(WS-I)  TO DL-LABEL
              MOVE CLM-RACE-VAL(WS-I) TO DL-VALUE
              DISPLAY WS-DETAIL-LINE
           END-PERFORM

           DISPLAY WS-SEP
           DISPLAY 'SEX'
           IF CLM-FOUND-SEX = 'N'
              DISPLAY '    (aucune donnee SEX pour cette date)'
           END-IF
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 3
              MOVE WS-SEX-LBL(WS-I)  TO DL-LABEL
              MOVE CLM-SEX-VAL(WS-I) TO DL-VALUE
              DISPLAY WS-DETAIL-LINE
           END-PERFORM
           DISPLAY WS-SEP-EQ.

      *---------------------------------------------------------------*
      * Une ligne de la liste ALL                                     *
      *---------------------------------------------------------------*
       6000-PRINT-SUMMARY-LINE.
           COMPUTE WS-TOTAL = CLM-SEX-VAL(1) + CLM-SEX-VAL(2)
                            + CLM-SEX-VAL(3)
           ADD 1        TO WS-COUNT
           ADD WS-TOTAL TO WS-GRAND-TOTAL
           MOVE CLM-RECORD-ID   TO SL-KEY
           MOVE CLM-DATE        TO SL-DATE
           MOVE WS-TOTAL        TO SL-TOTAL
           MOVE CLM-SEX-VAL(2)  TO SL-FEMALE
           MOVE CLM-SEX-VAL(3)  TO SL-MALE
           MOVE CLM-FOUND-FLAGS TO SL-FLAGS
           DISPLAY WS-SUM-LINE.

      *---------------------------------------------------------------*
      * Erreur remontee par CLMREAD                                   *
      *---------------------------------------------------------------*
       8000-ERROR.
           DISPLAY ' '
           DISPLAY '*** ERREUR CLMREAD - FONCTION=' CLM-FUNCTION
                   ' RC=' CLM-RETURN-CODE
                   ' STATUS VSAM=' CLM-VSAM-STATUS
           MOVE 12 TO RETURN-CODE.
