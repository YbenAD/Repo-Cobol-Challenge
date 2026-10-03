       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLMMAINT.
      ******************************************************************
      * CLMMAINT - maintenance du VSAM CLAIMS (point 9.3.4 du challenge
      * : "Insert a new record / Update an existing record / Delete an
      * existing record").
      *
      * Lit des demandes de maintenance dans SYSIN, une par ligne,
      * texte separe par des virgules :
      *
      *   I,RECORD-ID,DATE,SEX-INA,SEX-FEMALE,SEX-MALE
      *        -> insere un nouvel enregistrement. Pour garder une
      *           interface simple a saisir a la main, seule la
      *           dimension SEX est renseignee ici ; les dimensions
      *           AGE/ETHNICITY/INDUSTRY/RACE sont initialisees a 0
      *           (CLM-FOUND-xxx = 'N' pour signaler l'absence de
      *           donnees sur ces dimensions).
      *   U,RECORD-ID,DATE,SEX-INA,SEX-FEMALE,SEX-MALE
      *        -> relit l'enregistrement existant (pour ne pas perdre
      *           les dimensions AGE/ETHNICITY/INDUSTRY/RACE deja
      *           chargees par CLMLOAD), puis remplace uniquement sa
      *           DATE et ses valeurs SEX.
      *   D,RECORD-ID
      *        -> supprime l'enregistrement de cle RECORD-ID.
      *
      *   Ligne vide ou commencant par '*' -> ignoree (commentaire).
      *
      * Exemple de SYSIN :
      *   * Cree un enregistrement de test, le corrige, puis l'efface
      *   I,09152026,09/15/2026,10,1500,2000
      *   U,09152026,09/15/2026,10,1800,2500
      *   D,09152026
      *
      * Acces aux donnees uniquement via CLMREAD (meme sous-programme
      * que CLMRPT, appel dynamique depuis la STEPLIB) : CLMMAINT ne
      * touche jamais le VSAM directement.
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
       01  REQ-REC                     PIC X(80).

       WORKING-STORAGE SECTION.
       01  WS-SUBPGM                   PIC X(08) VALUE 'CLMREAD'.
       01  WS-REQ-FS                   PIC X(02).
       01  WS-REQ-EOF                  PIC X(01) VALUE 'N'.
           88  REQ-EOF                           VALUE 'Y'.

      *    ---- Zone de communication + enregistrement VSAM -----------
           COPY CLMLINK.
           COPY CLMREC.

      *    ---- Champs issus du decoupage d'une ligne SYSIN ------------
       01  WS-MAINT-FUNCTION           PIC X(01).
           88  MAINT-FUNC-INSERT                 VALUE 'I'.
           88  MAINT-FUNC-UPDATE                 VALUE 'U'.
           88  MAINT-FUNC-DELETE                 VALUE 'D'.
       01  WS-F-KEY                    PIC X(20).
       01  WS-F-DATE                   PIC X(20).
       01  WS-F-SEX-INA                PIC X(20).
       01  WS-F-SEX-FEMALE             PIC X(20).
       01  WS-F-SEX-MALE               PIC X(20).

      *    ---- Conversion texte -> numerique (avec defaut 0) ----------
       01  WS-NUM-TEXT                 PIC X(20).
       01  WS-NUM-VALUE                PIC 9(7).

       01  WS-COUNT-OK                 PIC 9(5) VALUE 0.
       01  WS-COUNT-ERR                PIC 9(5) VALUE 0.
       01  WS-ED-OK                    PIC ZZ,ZZ9.
       01  WS-ED-ERR                   PIC ZZ,ZZ9.
       01  WS-SEP-EQ                   PIC X(63) VALUE ALL '='.

       PROCEDURE DIVISION.
       0000-MAIN.
           OPEN INPUT REQ-FILE
           IF WS-REQ-FS NOT = '00'
              DISPLAY 'CLMMAINT - SYSIN ILLISIBLE, STATUS=' WS-REQ-FS
              MOVE 16 TO RETURN-CODE
              STOP RUN
           END-IF
           DISPLAY WS-SEP-EQ
           DISPLAY 'CLMMAINT - MAINTENANCE UNEMPLOYMENT CLAIMS'
           DISPLAY WS-SEP-EQ
           PERFORM 1000-READ-REQUEST
           PERFORM UNTIL REQ-EOF
              PERFORM 2000-PARSE-LINE
              EVALUATE TRUE
                 WHEN MAINT-FUNC-INSERT
                    PERFORM 3000-DO-INSERT
                 WHEN MAINT-FUNC-UPDATE
                    PERFORM 4000-DO-UPDATE
                 WHEN MAINT-FUNC-DELETE
                    PERFORM 5000-DO-DELETE
                 WHEN OTHER
                    ADD 1 TO WS-COUNT-ERR
                    DISPLAY 'LIGNE IGNOREE (fonction invalide) : '
                            REQ-REC
              END-EVALUATE
              PERFORM 1000-READ-REQUEST
           END-PERFORM
           SET CLM-FUNC-CLOSE TO TRUE
           CALL WS-SUBPGM USING CLM-REQUEST CLM-RECORD
           CLOSE REQ-FILE
           MOVE WS-COUNT-OK  TO WS-ED-OK
           MOVE WS-COUNT-ERR TO WS-ED-ERR
           DISPLAY WS-SEP-EQ
           DISPLAY 'BILAN : ' WS-ED-OK ' OK / ' WS-ED-ERR ' EN ERREUR'
           DISPLAY WS-SEP-EQ
           IF WS-COUNT-ERR > 0
              MOVE 4 TO RETURN-CODE
           END-IF
           STOP RUN.

      *---------------------------------------------------------------*
      * Lit la prochaine ligne utile (ignore vides et commentaires)   *
      *---------------------------------------------------------------*
       1000-READ-REQUEST.
           PERFORM WITH TEST AFTER
                   UNTIL REQ-EOF
                      OR (REQ-REC NOT = SPACES
                          AND REQ-REC(1:1) NOT = '*')
              READ REQ-FILE
                 AT END SET REQ-EOF TO TRUE
              END-READ
           END-PERFORM.

      *---------------------------------------------------------------*
      * Decoupe la ligne SYSIN (separateur virgule)                   *
      *---------------------------------------------------------------*
       2000-PARSE-LINE.
           MOVE SPACES TO WS-MAINT-FUNCTION WS-F-KEY WS-F-DATE
                           WS-F-SEX-INA WS-F-SEX-FEMALE WS-F-SEX-MALE
           UNSTRING REQ-REC DELIMITED BY ','
              INTO WS-MAINT-FUNCTION WS-F-KEY WS-F-DATE
                   WS-F-SEX-INA WS-F-SEX-FEMALE WS-F-SEX-MALE
           END-UNSTRING.

      *---------------------------------------------------------------*
      * I : insertion                                                 *
      *---------------------------------------------------------------*
       3000-DO-INSERT.
           INITIALIZE CLM-RECORD
           MOVE WS-F-KEY(1:8)   TO CLM-RECORD-ID
           MOVE WS-F-DATE(1:10) TO CLM-DATE

           MOVE WS-F-SEX-INA    TO WS-NUM-TEXT
           PERFORM 2600-TEXT-TO-NUM
           MOVE WS-NUM-VALUE    TO CLM-SEX-VAL(1)
           MOVE WS-F-SEX-FEMALE TO WS-NUM-TEXT
           PERFORM 2600-TEXT-TO-NUM
           MOVE WS-NUM-VALUE    TO CLM-SEX-VAL(2)
           MOVE WS-F-SEX-MALE   TO WS-NUM-TEXT
           PERFORM 2600-TEXT-TO-NUM
           MOVE WS-NUM-VALUE    TO CLM-SEX-VAL(3)

           MOVE 'N' TO CLM-FOUND-AGE CLM-FOUND-ETH CLM-FOUND-IND
                       CLM-FOUND-RACE
           MOVE 'Y' TO CLM-FOUND-SEX

           SET CLM-FUNC-INSERT TO TRUE
           CALL WS-SUBPGM USING CLM-REQUEST CLM-RECORD
           EVALUATE TRUE
              WHEN CLM-RC-OK
                 ADD 1 TO WS-COUNT-OK
                 DISPLAY 'INSERE   : ' CLM-RECORD-ID
                         ' DATE=' CLM-DATE
                         ' SEX(INA/F/M)=' CLM-SEX-VAL(1)
                         '/' CLM-SEX-VAL(2) '/' CLM-SEX-VAL(3)
              WHEN CLM-RC-DUPLICATE
                 ADD 1 TO WS-COUNT-ERR
                 DISPLAY 'ERREUR   : ' WS-F-KEY(1:8)
                         ' existe deja (utilisez U pour modifier)'
              WHEN OTHER
                 ADD 1 TO WS-COUNT-ERR
                 PERFORM 8000-ERROR
           END-EVALUATE.

      *---------------------------------------------------------------*
      * U : mise a jour (DATE + SEX uniquement ; le reste de          *
      * l'enregistrement, deja charge par CLMLOAD, est conserve)      *
      *---------------------------------------------------------------*
       4000-DO-UPDATE.
           SET CLM-FUNC-READ TO TRUE
           MOVE WS-F-KEY(1:8) TO CLM-REQ-KEY
           CALL WS-SUBPGM USING CLM-REQUEST CLM-RECORD
           IF CLM-RC-OK
              MOVE WS-F-DATE(1:10) TO CLM-DATE

              MOVE WS-F-SEX-INA    TO WS-NUM-TEXT
              PERFORM 2600-TEXT-TO-NUM
              MOVE WS-NUM-VALUE    TO CLM-SEX-VAL(1)
              MOVE WS-F-SEX-FEMALE TO WS-NUM-TEXT
              PERFORM 2600-TEXT-TO-NUM
              MOVE WS-NUM-VALUE    TO CLM-SEX-VAL(2)
              MOVE WS-F-SEX-MALE   TO WS-NUM-TEXT
              PERFORM 2600-TEXT-TO-NUM
              MOVE WS-NUM-VALUE    TO CLM-SEX-VAL(3)
              MOVE 'Y' TO CLM-FOUND-SEX

              SET CLM-FUNC-UPDATE TO TRUE
              CALL WS-SUBPGM USING CLM-REQUEST CLM-RECORD
              IF CLM-RC-OK
                 ADD 1 TO WS-COUNT-OK
                 DISPLAY 'MODIFIE  : ' CLM-RECORD-ID
                         ' DATE=' CLM-DATE
                         ' SEX(INA/F/M)=' CLM-SEX-VAL(1)
                         '/' CLM-SEX-VAL(2) '/' CLM-SEX-VAL(3)
              ELSE
                 ADD 1 TO WS-COUNT-ERR
                 PERFORM 8000-ERROR
              END-IF
           ELSE
              ADD 1 TO WS-COUNT-ERR
              DISPLAY 'ERREUR   : ' WS-F-KEY(1:8)
                      ' introuvable (utilisez I pour creer)'
           END-IF.

      *---------------------------------------------------------------*
      * D : suppression                                                *
      *---------------------------------------------------------------*
       5000-DO-DELETE.
           SET CLM-FUNC-DELETE TO TRUE
           MOVE WS-F-KEY(1:8) TO CLM-REQ-KEY
           CALL WS-SUBPGM USING CLM-REQUEST CLM-RECORD
           EVALUATE TRUE
              WHEN CLM-RC-OK
                 ADD 1 TO WS-COUNT-OK
                 DISPLAY 'SUPPRIME : ' WS-F-KEY(1:8)
              WHEN CLM-RC-NOTFOUND
                 ADD 1 TO WS-COUNT-ERR
                 DISPLAY 'ERREUR   : ' WS-F-KEY(1:8) ' introuvable'
              WHEN OTHER
                 ADD 1 TO WS-COUNT-ERR
                 PERFORM 8000-ERROR
           END-EVALUATE.

      *---------------------------------------------------------------*
      * Convertit WS-NUM-TEXT en WS-NUM-VALUE (0 si le champ est      *
      * vide, pour accepter des lignes ou un montant est omis).       *
      *---------------------------------------------------------------*
       2600-TEXT-TO-NUM.
           IF WS-NUM-TEXT = SPACES
              MOVE 0 TO WS-NUM-VALUE
           ELSE
              COMPUTE WS-NUM-VALUE = FUNCTION NUMVAL(WS-NUM-TEXT)
           END-IF.

      *---------------------------------------------------------------*
      * Erreur remontee par CLMREAD                                   *
      *---------------------------------------------------------------*
       8000-ERROR.
           DISPLAY '*** ERREUR CLMREAD - FONCTION=' CLM-FUNCTION
                   ' RC=' CLM-RETURN-CODE
                   ' STATUS VSAM=' CLM-VSAM-STATUS.
