       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLMLOAD.
      ******************************************************************
      * CLMLOAD (v2 - vrais en-tetes CSV confirmes)
      * Lit les 5 fichiers CSV (Age, Ethnicity, Industry, Race, Sex),
      * fusionne les lignes par Record-ID et ecrit un enregistrement
      * fusionne par cle dans le cluster VSAM KSDS CLAIMS.VSAM.
      *
      * Nombre de valeurs par fichier (hors Record ID / Date) :
      *   AGE      : 9   (INA + 8 tranches d'age)
      *   ETHNICITY: 3   (INA + Hispanic + Not Hispanic)
      *   INDUSTRY : 21  (INA + 20 secteurs)
      *   RACE     : 6   (INA + 5 categories)
      *   SEX      : 3   (INA + FEMALE + MALE)
      *
      * DDNAMEs attendus (voir JCL RUNLOAD) :
      *   AGEIN, ETHIN, INDIN, RACEIN, SEXIN  -> fichiers CSV en entree
      *   CLAIMOUT                            -> cluster VSAM en sortie
      *   SYSOUT                              -> messages / stats
      ******************************************************************
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT AGE-FILE  ASSIGN TO AGEIN
               FILE STATUS IS WS-AGE-FS.
           SELECT ETH-FILE  ASSIGN TO ETHIN
               FILE STATUS IS WS-ETH-FS.
           SELECT IND-FILE  ASSIGN TO INDIN
               FILE STATUS IS WS-IND-FS.
           SELECT RACE-FILE ASSIGN TO RACEIN
               FILE STATUS IS WS-RACE-FS.
           SELECT SEX-FILE  ASSIGN TO SEXIN
               FILE STATUS IS WS-SEX-FS.

           SELECT CLAIMS-VSAM ASSIGN TO CLAIMOUT
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS CLM-RECORD-ID
               FILE STATUS IS WS-VSAM-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  AGE-FILE
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 0 CHARACTERS.
       01  AGE-REC                    PIC X(300).

       FD  ETH-FILE
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 0 CHARACTERS.
       01  ETH-REC                    PIC X(300).

       FD  IND-FILE
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 0 CHARACTERS.
       01  IND-REC                    PIC X(600).

       FD  RACE-FILE
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 0 CHARACTERS.
       01  RACE-REC                    PIC X(300).

       FD  SEX-FILE
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 0 CHARACTERS.
       01  SEX-REC                    PIC X(300).

       FD  CLAIMS-VSAM.
           COPY CLMREC.

       WORKING-STORAGE SECTION.
       01  WS-AGE-FS                   PIC X(02).
       01  WS-ETH-FS                   PIC X(02).
       01  WS-IND-FS                   PIC X(02).
       01  WS-RACE-FS                  PIC X(02).
       01  WS-SEX-FS                   PIC X(02).
       01  WS-VSAM-FS                  PIC X(02).

       01  WS-EOF-SWITCHES.
           05  WS-AGE-EOF               PIC X(01) VALUE 'N'.
           05  WS-ETH-EOF               PIC X(01) VALUE 'N'.
           05  WS-IND-EOF               PIC X(01) VALUE 'N'.
           05  WS-RACE-EOF              PIC X(01) VALUE 'N'.
           05  WS-SEX-EOF               PIC X(01) VALUE 'N'.

       01  WS-FIRST-LINE                PIC X(01).
       01  WS-I                         PIC S9(4) COMP.

      *    ---- Analyseur CSV (gere guillemets + virgules de milliers) ---
       01  WS-LINE                      PIC X(600).
       01  WS-POS                       PIC S9(4) COMP.
       01  WS-FLD-NO                    PIC S9(4) COMP.
       01  WS-OUT-POS                   PIC S9(4) COMP.
       01  WS-CH                        PIC X(01).
       01  WS-IN-QUOTE                  PIC X(01).

      *    ---- Zone generique de decoupage CSV (25 colonnes max) -----
       01  WS-CSV-FIELDS.
           05  WS-CSV-FIELD OCCURS 25 TIMES PIC X(20).

      *    ---- Table intermediaire AGE (9 valeurs) --------------------
       01  WS-AGE-TABLE.
           05  WS-AGE-ENTRY OCCURS 500 TIMES INDEXED BY AGE-IX.
               10  WS-AGE-KEY           PIC X(08).
               10  WS-AGE-DATE          PIC X(10).
               10  WS-AGE-VALUES-GRP.
                   15  WS-AGE-VAL       PIC 9(7) OCCURS 9 TIMES.
       01  WS-AGE-COUNT                 PIC S9(4) COMP VALUE 0.

      *    ---- Table intermediaire ETHNICITY (3 valeurs) ----------------
       01  WS-ETH-TABLE.
           05  WS-ETH-ENTRY OCCURS 500 TIMES INDEXED BY ETH-IX.
               10  WS-ETH-KEY           PIC X(08).
               10  WS-ETH-DATE          PIC X(10).
               10  WS-ETH-VALUES-GRP.
                   15  WS-ETH-VAL       PIC 9(7) OCCURS 3 TIMES.
       01  WS-ETH-COUNT                 PIC S9(4) COMP VALUE 0.

      *    ---- Table intermediaire INDUSTRY (21 valeurs) -----------------
       01  WS-IND-TABLE.
           05  WS-IND-ENTRY OCCURS 500 TIMES INDEXED BY IND-IX.
               10  WS-IND-KEY           PIC X(08).
               10  WS-IND-DATE          PIC X(10).
               10  WS-IND-VALUES-GRP.
                   15  WS-IND-VAL       PIC 9(7) OCCURS 21 TIMES.
       01  WS-IND-COUNT                 PIC S9(4) COMP VALUE 0.

      *    ---- Table intermediaire RACE (6 valeurs) ------------------------
       01  WS-RACE-TABLE.
           05  WS-RACE-ENTRY OCCURS 500 TIMES INDEXED BY RACE-IX.
               10  WS-RACE-KEY          PIC X(08).
               10  WS-RACE-DATE         PIC X(10).
               10  WS-RACE-VALUES-GRP.
                   15  WS-RACE-VAL      PIC 9(7) OCCURS 6 TIMES.
       01  WS-RACE-COUNT                PIC S9(4) COMP VALUE 0.

      *    ---- Table intermediaire SEX (3 valeurs) ---------------------------
       01  WS-SEX-TABLE.
           05  WS-SEX-ENTRY OCCURS 500 TIMES INDEXED BY SEX-IX.
               10  WS-SEX-KEY           PIC X(08).
               10  WS-SEX-DATE          PIC X(10).
               10  WS-SEX-VALUES-GRP.
                   15  WS-SEX-VAL       PIC 9(7) OCCURS 3 TIMES.
       01  WS-SEX-COUNT                 PIC S9(4) COMP VALUE 0.

      *    ---- Liste des cles uniques (union de toutes les sources) ------
       01  WS-MASTER-TABLE.
           05  WS-MASTER-ENTRY OCCURS 500 TIMES INDEXED BY MST-IX.
               10  WS-MASTER-KEY        PIC X(08).
               10  WS-MASTER-DATE       PIC X(10).
       01  WS-MASTER-COUNT              PIC S9(4) COMP VALUE 0.

       01  WS-STATS.
           05  WS-REC-WRITTEN           PIC 9(5) VALUE 0.
           05  WS-DISPLAY-COUNT         PIC ZZZZ9.

       01  WS-KEY-FOUND                 PIC X(01).
       01  P-KEY                        PIC X(08).
       01  P-DATE                       PIC X(10).

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-LOAD-AGE
           PERFORM 2100-LOAD-ETH
           PERFORM 2200-LOAD-IND
           PERFORM 2300-LOAD-RACE
           PERFORM 2400-LOAD-SEX
           PERFORM 3000-BUILD-AND-WRITE
           PERFORM 9000-TERMINATE
           STOP RUN.

       1000-INIT.
           OPEN INPUT  AGE-FILE
                       ETH-FILE
                       IND-FILE
                       RACE-FILE
                       SEX-FILE
           OPEN OUTPUT CLAIMS-VSAM
           IF WS-VSAM-FS NOT = '00'
              DISPLAY 'ERREUR OUVERTURE VSAM : ' WS-VSAM-FS
              STOP RUN
           END-IF.

      *---------------------------------------------------------------*
      * AGE : Record ID,Date,INA,<22,22-24,25-34,35-44,45-54,55-59,   *
      *       60-64,>=65                            (11 colonnes)     *
      *---------------------------------------------------------------*
       2000-LOAD-AGE.
           MOVE 'Y' TO WS-FIRST-LINE
           PERFORM UNTIL WS-AGE-EOF = 'Y'
              MOVE SPACES TO AGE-REC
              READ AGE-FILE
                 AT END MOVE 'Y' TO WS-AGE-EOF
                 NOT AT END
                    IF WS-FIRST-LINE = 'Y'
                       MOVE 'N' TO WS-FIRST-LINE
                    ELSE
                       ADD 1 TO WS-AGE-COUNT
                       SET AGE-IX TO WS-AGE-COUNT
                       MOVE AGE-REC TO WS-LINE
                       PERFORM 6000-PARSE-LINE
                       MOVE WS-CSV-FIELD(1) TO WS-AGE-KEY(AGE-IX)
                       MOVE WS-CSV-FIELD(2) TO WS-AGE-DATE(AGE-IX)
                       PERFORM VARYING WS-I FROM 1 BY 1
                               UNTIL WS-I > 9
                          COMPUTE WS-AGE-VAL(AGE-IX, WS-I) =
                             FUNCTION NUMVAL(WS-CSV-FIELD(WS-I + 2))
                       END-PERFORM
                       MOVE WS-AGE-KEY(AGE-IX)  TO P-KEY
                       MOVE WS-AGE-DATE(AGE-IX) TO P-DATE
                       PERFORM 5000-ADD-MASTER-KEY
                    END-IF
              END-READ
           END-PERFORM.

      *---------------------------------------------------------------*
      * ETHNICITY : Record ID,Date,INA,Hispanic or Latino,             *
      *             Not Hispanic or Latino          (5 colonnes)       *
      *---------------------------------------------------------------*
       2100-LOAD-ETH.
           MOVE 'Y' TO WS-FIRST-LINE
           PERFORM UNTIL WS-ETH-EOF = 'Y'
              MOVE SPACES TO ETH-REC
              READ ETH-FILE
                 AT END MOVE 'Y' TO WS-ETH-EOF
                 NOT AT END
                    IF WS-FIRST-LINE = 'Y'
                       MOVE 'N' TO WS-FIRST-LINE
                    ELSE
                       ADD 1 TO WS-ETH-COUNT
                       SET ETH-IX TO WS-ETH-COUNT
                       MOVE ETH-REC TO WS-LINE
                       PERFORM 6000-PARSE-LINE
                       MOVE WS-CSV-FIELD(1) TO WS-ETH-KEY(ETH-IX)
                       MOVE WS-CSV-FIELD(2) TO WS-ETH-DATE(ETH-IX)
                       PERFORM VARYING WS-I FROM 1 BY 1
                               UNTIL WS-I > 3
                           COMPUTE WS-ETH-VAL(ETH-IX, WS-I) =
                             FUNCTION NUMVAL(WS-CSV-FIELD(WS-I + 2))
                       END-PERFORM
                       MOVE WS-ETH-KEY(ETH-IX)  TO P-KEY
                       MOVE WS-ETH-DATE(ETH-IX) TO P-DATE
                       PERFORM 5000-ADD-MASTER-KEY
                    END-IF
              END-READ
           END-PERFORM.

      *---------------------------------------------------------------*
      * INDUSTRY : Record ID,Date,INA + 20 secteurs   (23 colonnes)    *
      *---------------------------------------------------------------*
       2200-LOAD-IND.
           MOVE 'Y' TO WS-FIRST-LINE
           PERFORM UNTIL WS-IND-EOF = 'Y'
              MOVE SPACES TO IND-REC
              READ IND-FILE
                 AT END MOVE 'Y' TO WS-IND-EOF
                 NOT AT END
                    IF WS-FIRST-LINE = 'Y'
                       MOVE 'N' TO WS-FIRST-LINE
                    ELSE
                       ADD 1 TO WS-IND-COUNT
                       SET IND-IX TO WS-IND-COUNT
                       MOVE IND-REC TO WS-LINE
                       PERFORM 6000-PARSE-LINE
                       MOVE WS-CSV-FIELD(1) TO WS-IND-KEY(IND-IX)
                       MOVE WS-CSV-FIELD(2) TO WS-IND-DATE(IND-IX)
                       PERFORM VARYING WS-I FROM 1 BY 1
                               UNTIL WS-I > 21
                             COMPUTE WS-IND-VAL(IND-IX, WS-I) =
                               FUNCTION NUMVAL(WS-CSV-FIELD(WS-I + 2))
                       END-PERFORM
                       MOVE WS-IND-KEY(IND-IX)  TO P-KEY
                       MOVE WS-IND-DATE(IND-IX) TO P-DATE
                       PERFORM 5000-ADD-MASTER-KEY
                    END-IF
              END-READ
           END-PERFORM.

      *---------------------------------------------------------------*
      * RACE : Record ID,Date,INA,White,Asian,Black or African        *
      *        American,American Indian or Alaskan Native,Native      *
      *        Hawaiian or Other Pacific Islander    (8 colonnes)      *
      *---------------------------------------------------------------*
       2300-LOAD-RACE.
           MOVE 'Y' TO WS-FIRST-LINE
           PERFORM UNTIL WS-RACE-EOF = 'Y'
              MOVE SPACES TO RACE-REC
              READ RACE-FILE
                 AT END MOVE 'Y' TO WS-RACE-EOF
                 NOT AT END
                    IF WS-FIRST-LINE = 'Y'
                       MOVE 'N' TO WS-FIRST-LINE
                    ELSE
                       ADD 1 TO WS-RACE-COUNT
                       SET RACE-IX TO WS-RACE-COUNT
                       MOVE RACE-REC TO WS-LINE
                       PERFORM 6000-PARSE-LINE
                       MOVE WS-CSV-FIELD(1) TO WS-RACE-KEY(RACE-IX)
                       MOVE WS-CSV-FIELD(2) TO WS-RACE-DATE(RACE-IX)
                       PERFORM VARYING WS-I FROM 1 BY 1
                               UNTIL WS-I > 6
                             COMPUTE WS-RACE-VAL(RACE-IX, WS-I) =
                              FUNCTION NUMVAL(WS-CSV-FIELD(WS-I + 2))
                       END-PERFORM
                       MOVE WS-RACE-KEY(RACE-IX)  TO P-KEY
                       MOVE WS-RACE-DATE(RACE-IX) TO P-DATE
                       PERFORM 5000-ADD-MASTER-KEY
                    END-IF
              END-READ
           END-PERFORM.

      *---------------------------------------------------------------*
      * SEX : Record ID,Date,INA,FEMALE,MALE          (5 colonnes)     *
      *---------------------------------------------------------------*
       2400-LOAD-SEX.
           MOVE 'Y' TO WS-FIRST-LINE
           PERFORM UNTIL WS-SEX-EOF = 'Y'
              MOVE SPACES TO SEX-REC
              READ SEX-FILE
                 AT END MOVE 'Y' TO WS-SEX-EOF
                 NOT AT END
                    IF WS-FIRST-LINE = 'Y'
                       MOVE 'N' TO WS-FIRST-LINE
                    ELSE
                       ADD 1 TO WS-SEX-COUNT
                       SET SEX-IX TO WS-SEX-COUNT
                       MOVE SEX-REC TO WS-LINE
                       PERFORM 6000-PARSE-LINE
                       MOVE WS-CSV-FIELD(1) TO WS-SEX-KEY(SEX-IX)
                       MOVE WS-CSV-FIELD(2) TO WS-SEX-DATE(SEX-IX)
                       PERFORM VARYING WS-I FROM 1 BY 1
                               UNTIL WS-I > 3
                             COMPUTE WS-SEX-VAL(SEX-IX, WS-I) =
                               FUNCTION NUMVAL(WS-CSV-FIELD(WS-I + 2))
                       END-PERFORM
                       MOVE WS-SEX-KEY(SEX-IX)  TO P-KEY
                       MOVE WS-SEX-DATE(SEX-IX) TO P-DATE
                       PERFORM 5000-ADD-MASTER-KEY
                    END-IF
              END-READ
           END-PERFORM.

      *---------------------------------------------------------------*
      * Decoupe WS-LINE en WS-CSV-FIELD(1..n).                         *
      * - un guillemet ouvre/ferme une zone "protegee"                 *
      * - virgule HORS guillemets  = separateur de colonne             *
      * - virgule DANS guillemets  = separateur de milliers (ignoree)  *
      *   ex : "29,811" -> 29811                                       *
      * - les guillemets ne sont pas recopies                          *
      *---------------------------------------------------------------*
       6000-PARSE-LINE.
           MOVE SPACES TO WS-CSV-FIELDS
           MOVE 1   TO WS-FLD-NO
           MOVE 1   TO WS-OUT-POS
           MOVE 'N' TO WS-IN-QUOTE
           PERFORM VARYING WS-POS FROM 1 BY 1 UNTIL WS-POS > 600
              MOVE WS-LINE(WS-POS:1) TO WS-CH
              EVALUATE TRUE
                 WHEN WS-CH = '"'
                    IF WS-IN-QUOTE = 'Y'
                       MOVE 'N' TO WS-IN-QUOTE
                    ELSE
                       MOVE 'Y' TO WS-IN-QUOTE
                    END-IF
                 WHEN WS-CH = ',' AND WS-IN-QUOTE = 'N'
                    ADD 1 TO WS-FLD-NO
                    MOVE 1 TO WS-OUT-POS
                 WHEN WS-CH = ',' AND WS-IN-QUOTE = 'Y'
                    CONTINUE
                 WHEN OTHER
                    IF WS-FLD-NO <= 25 AND WS-OUT-POS <= 20
                       MOVE WS-CH
                          TO WS-CSV-FIELD(WS-FLD-NO)(WS-OUT-POS:1)
                       ADD 1 TO WS-OUT-POS
                    END-IF
              END-EVALUATE
           END-PERFORM.

      *---------------------------------------------------------------*
      * Ajoute une cle a la liste maitresse si elle n'y est pas deja   *
      *---------------------------------------------------------------*
       5000-ADD-MASTER-KEY.
           MOVE 'N' TO WS-KEY-FOUND
           PERFORM VARYING MST-IX FROM 1 BY 1
                   UNTIL MST-IX > WS-MASTER-COUNT
              IF WS-MASTER-KEY(MST-IX) = P-KEY
                 MOVE 'Y' TO WS-KEY-FOUND
              END-IF
           END-PERFORM
           IF WS-KEY-FOUND = 'N'
              ADD 1 TO WS-MASTER-COUNT
              SET MST-IX TO WS-MASTER-COUNT
              MOVE P-KEY  TO WS-MASTER-KEY(MST-IX)
              MOVE P-DATE TO WS-MASTER-DATE(MST-IX)
           END-IF.

      *---------------------------------------------------------------*
      * Construit chaque enregistrement fusionne et l'ecrit dans VSAM  *
      *---------------------------------------------------------------*
       3000-BUILD-AND-WRITE.
           PERFORM VARYING MST-IX FROM 1 BY 1
                   UNTIL MST-IX > WS-MASTER-COUNT
              MOVE SPACES TO CLM-RECORD-ID CLM-DATE
              MOVE ZEROS  TO CLM-AGE-VALUES CLM-ETH-VALUES
                             CLM-IND-VALUES CLM-RACE-VALUES
                             CLM-SEX-VALUES
              MOVE 'N' TO CLM-FOUND-AGE CLM-FOUND-ETH CLM-FOUND-IND
                          CLM-FOUND-RACE CLM-FOUND-SEX

              MOVE WS-MASTER-KEY(MST-IX)  TO CLM-RECORD-ID
              MOVE WS-MASTER-DATE(MST-IX) TO CLM-DATE

              PERFORM VARYING AGE-IX FROM 1 BY 1
                      UNTIL AGE-IX > WS-AGE-COUNT
                 IF WS-AGE-KEY(AGE-IX) = CLM-RECORD-ID
                    MOVE WS-AGE-VALUES-GRP(AGE-IX) TO CLM-AGE-VALUES
                    MOVE 'Y' TO CLM-FOUND-AGE
                 END-IF
              END-PERFORM

              PERFORM VARYING ETH-IX FROM 1 BY 1
                      UNTIL ETH-IX > WS-ETH-COUNT
                 IF WS-ETH-KEY(ETH-IX) = CLM-RECORD-ID
                    MOVE WS-ETH-VALUES-GRP(ETH-IX) TO CLM-ETH-VALUES
                    MOVE 'Y' TO CLM-FOUND-ETH
                 END-IF
              END-PERFORM

              PERFORM VARYING IND-IX FROM 1 BY 1
                      UNTIL IND-IX > WS-IND-COUNT
                 IF WS-IND-KEY(IND-IX) = CLM-RECORD-ID
                    MOVE WS-IND-VALUES-GRP(IND-IX) TO CLM-IND-VALUES
                    MOVE 'Y' TO CLM-FOUND-IND
                 END-IF
              END-PERFORM

              PERFORM VARYING RACE-IX FROM 1 BY 1
                      UNTIL RACE-IX > WS-RACE-COUNT
                 IF WS-RACE-KEY(RACE-IX) = CLM-RECORD-ID
                    MOVE WS-RACE-VALUES-GRP(RACE-IX) TO CLM-RACE-VALUES
                    MOVE 'Y' TO CLM-FOUND-RACE
                 END-IF
              END-PERFORM

              PERFORM VARYING SEX-IX FROM 1 BY 1
                      UNTIL SEX-IX > WS-SEX-COUNT
                 IF WS-SEX-KEY(SEX-IX) = CLM-RECORD-ID
                    MOVE WS-SEX-VALUES-GRP(SEX-IX) TO CLM-SEX-VALUES
                    MOVE 'Y' TO CLM-FOUND-SEX
                 END-IF
              END-PERFORM

              WRITE CLM-RECORD
                 INVALID KEY
                    DISPLAY 'ERREUR WRITE CLE=' CLM-RECORD-ID
                            ' STATUS=' WS-VSAM-FS
                 NOT INVALID KEY
                    ADD 1 TO WS-REC-WRITTEN
              END-WRITE
           END-PERFORM.

       9000-TERMINATE.
           CLOSE AGE-FILE ETH-FILE IND-FILE RACE-FILE SEX-FILE
                 CLAIMS-VSAM
           MOVE WS-REC-WRITTEN TO WS-DISPLAY-COUNT
           DISPLAY 'CLES UNIQUES TRAITEES : ' WS-MASTER-COUNT
           DISPLAY 'ENREGISTREMENTS ECRITS DANS LE VSAM : '
                   WS-DISPLAY-COUNT.
