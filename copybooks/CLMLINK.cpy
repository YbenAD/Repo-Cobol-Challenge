      ******************************************************************
      * CLMLINK.cpy
      * Zone de communication entre CLMRPT et le sous-programme CLMREAD.
      * CALL 'CLMREAD' USING CLM-REQUEST CLM-RECORD
      *
      * CLM-FUNCTION (en entree) :
      *    R = lire l'enregistrement de cle CLM-REQ-KEY
      *    F = lire le premier enregistrement du fichier
      *    N = lire l'enregistrement suivant
      *    C = fermer le fichier
      *
      * CLM-RETURN-CODE (en sortie) :
      *    00 = OK
      *    04 = cle non trouvee
      *    08 = fin de fichier (plus d'enregistrement)
      *    12 = erreur VSAM (detail dans CLM-VSAM-STATUS)
      *    16 = fonction invalide
      ******************************************************************
       01  CLM-REQUEST.
           05  CLM-FUNCTION            PIC X(01).
               88  CLM-FUNC-READ                      VALUE 'R'.
               88  CLM-FUNC-FIRST                     VALUE 'F'.
               88  CLM-FUNC-NEXT                      VALUE 'N'.
               88  CLM-FUNC-CLOSE                     VALUE 'C'.
           05  CLM-REQ-KEY             PIC X(08).
           05  CLM-RETURN-CODE         PIC X(02).
               88  CLM-RC-OK                          VALUE '00'.
               88  CLM-RC-NOTFOUND                    VALUE '04'.
               88  CLM-RC-EOF                         VALUE '08'.
               88  CLM-RC-ERROR                       VALUE '12'.
               88  CLM-RC-BADFUNC                     VALUE '16'.
           05  CLM-VSAM-STATUS         PIC X(02).
