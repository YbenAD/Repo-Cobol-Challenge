       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLMREAD.
      ******************************************************************
      * CLMREAD - sous-programme d'acces au VSAM CLAIMS
      * Appel   : CALL 'CLMREAD' USING CLM-REQUEST CLM-RECORD
      * DDNAME  : CLAIMIN (le cluster Z87663.CLAIMS.VSAM)
      * Le fichier est ouvert au premier appel et reste ouvert
      * entre les appels jusqu'a la fonction C (fermeture).
      ******************************************************************
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CLAIMS-VSAM ASSIGN TO CLAIMIN
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS VSAM-KEY
               FILE STATUS IS WS-VSAM-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  CLAIMS-VSAM.
       01  VSAM-REC.
           05  VSAM-KEY                PIC X(08).
           05  FILLER                  PIC X(309).

       WORKING-STORAGE SECTION.
       01  WS-VSAM-FS                  PIC X(02).
       01  WS-FILE-OPEN                PIC X(01) VALUE 'N'.
           88  FILE-IS-OPEN                      VALUE 'Y'.

       LINKAGE SECTION.
           COPY CLMLINK.
           COPY CLMREC.

       PROCEDURE DIVISION USING CLM-REQUEST CLM-RECORD.
       0000-MAIN.
           MOVE '00'   TO CLM-RETURN-CODE
           MOVE SPACES TO CLM-VSAM-STATUS
           IF NOT FILE-IS-OPEN AND NOT CLM-FUNC-CLOSE
              PERFORM 1000-OPEN
           END-IF
           IF CLM-RC-OK
              EVALUATE TRUE
                 WHEN CLM-FUNC-READ
                    PERFORM 2000-READ-KEY
                 WHEN CLM-FUNC-FIRST
                    PERFORM 3000-READ-FIRST
                 WHEN CLM-FUNC-NEXT
                    PERFORM 4000-READ-NEXT
                 WHEN CLM-FUNC-CLOSE
                    PERFORM 9000-CLOSE
                 WHEN OTHER
                    MOVE '16' TO CLM-RETURN-CODE
              END-EVALUATE
           END-IF
           GOBACK.

      *---------------------------------------------------------------*
      * Ouverture du VSAM (au premier appel seulement)                *
      *---------------------------------------------------------------*
       1000-OPEN.
           OPEN INPUT CLAIMS-VSAM
           MOVE WS-VSAM-FS TO CLM-VSAM-STATUS
           IF WS-VSAM-FS = '00'
              SET FILE-IS-OPEN TO TRUE
           ELSE
              MOVE '12' TO CLM-RETURN-CODE
           END-IF.

      *---------------------------------------------------------------*
      * R : lecture directe par cle                                   *
      *---------------------------------------------------------------*
       2000-READ-KEY.
           MOVE CLM-REQ-KEY TO VSAM-KEY
           READ CLAIMS-VSAM INTO CLM-RECORD
              KEY IS VSAM-KEY
           END-READ
           MOVE WS-VSAM-FS TO CLM-VSAM-STATUS
           EVALUATE WS-VSAM-FS
              WHEN '00'
                 CONTINUE
              WHEN '23'
                 MOVE '04' TO CLM-RETURN-CODE
              WHEN OTHER
                 MOVE '12' TO CLM-RETURN-CODE
           END-EVALUATE.

      *---------------------------------------------------------------*
      * F : positionnement au debut du fichier + 1ere lecture         *
      *---------------------------------------------------------------*
       3000-READ-FIRST.
           MOVE LOW-VALUES TO VSAM-KEY
           START CLAIMS-VSAM KEY IS NOT LESS THAN VSAM-KEY
           END-START
           MOVE WS-VSAM-FS TO CLM-VSAM-STATUS
           EVALUATE WS-VSAM-FS
              WHEN '00'
                 PERFORM 4000-READ-NEXT
              WHEN '23'
                 MOVE '08' TO CLM-RETURN-CODE
              WHEN OTHER
                 MOVE '12' TO CLM-RETURN-CODE
           END-EVALUATE.

      *---------------------------------------------------------------*
      * N : lecture sequentielle de l'enregistrement suivant          *
      *---------------------------------------------------------------*
       4000-READ-NEXT.
           READ CLAIMS-VSAM NEXT RECORD INTO CLM-RECORD
           END-READ
           MOVE WS-VSAM-FS TO CLM-VSAM-STATUS
           EVALUATE WS-VSAM-FS
              WHEN '00'
                 CONTINUE
              WHEN '10'
                 MOVE '08' TO CLM-RETURN-CODE
              WHEN OTHER
                 MOVE '12' TO CLM-RETURN-CODE
           END-EVALUATE.

      *---------------------------------------------------------------*
      * C : fermeture                                                 *
      *---------------------------------------------------------------*
       9000-CLOSE.
           IF FILE-IS-OPEN
              CLOSE CLAIMS-VSAM
              MOVE WS-VSAM-FS TO CLM-VSAM-STATUS
              MOVE 'N' TO WS-FILE-OPEN
           END-IF.
