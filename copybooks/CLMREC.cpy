      ******************************************************************
      * CLMREC.cpy  (v2 - bases sur les vrais en-tetes des CSV)
      *
      * Layout de l'enregistrement fusionne "Unemployment Claims".
      * Cle VSAM = CLM-RECORD-ID (unique, format MMJJAAAA, ex 08012011).
      * Longueur totale = 317 octets.
      *
      * Chaque dimension demographique est stockee comme une TABLE de
      * compteurs (CLM-xxx-VAL, OCCURS N). La position dans la table
      * correspond a une colonne precise du CSV source - voir la liste
      * ci-dessous pour chaque groupe. Ceci evite d'avoir un nom de
      * champ different pour chacune des 21 colonnes d'Industry, tout
      * en gardant un acces direct par indice (CLM-IND-VAL(2) = colonne
      * "Wholesale Trade", etc.)
      ******************************************************************
       01  CLM-RECORD.
           05  CLM-RECORD-ID           PIC X(08).
           05  CLM-DATE                PIC X(10).

      *    ---- AGE : 9 valeurs (source confirmee) --------------------
      *    1=INA 2=<22 3=22-24 4=25-34 5=35-44 6=45-54 7=55-59
      *    8=60-64 9=>=65
           05  CLM-AGE-VALUES.
               10  CLM-AGE-VAL         PIC 9(7) OCCURS 9 TIMES.

      *    ---- ETHNICITY : 3 valeurs (source confirmee) ---------------
      *    1=INA 2=Hispanic or Latino 3=Not Hispanic or Latino
           05  CLM-ETH-VALUES.
               10  CLM-ETH-VAL         PIC 9(7) OCCURS 3 TIMES.

      *    ---- INDUSTRY : 21 valeurs (source confirmee) ----------------
      *    1=INA
      *    2=Wholesale Trade
      *    3=Transportation & Warehouse
      *    4=Construction
      *    5=Finance & Insurance
      *    6=Manufacturing
      *    7=Agricult./Forestry/Fishing/Hunting
      *    8=Public Administration
      *    9=Utilities
      *    10=Accomodation & Food Services
      *    11=Information
      *    12=Professional/Scientific/Tech. Services
      *    13=Real Estate & Rental & Leasing
      *    14=Other Services (except Public Administration)
      *    15=Management of Companies & Enterprises
      *    16=Educational Services
      *    17=Mining
      *    18=Health Care & Social Assistance
      *    19=Arts, Entertainment & Recreation
      *    20=Admin. & Support/Waste Mgmt./Remedia. Serv.
      *    21=Retail Trade
           05  CLM-IND-VALUES.
               10  CLM-IND-VAL         PIC 9(7) OCCURS 21 TIMES.

      *    ---- RACE : 6 valeurs (source confirmee) ---------------------
      *    1=INA 2=White 3=Asian 4=Black or African American
      *    5=American Indian or Alaskan Native
      *    6=Native Hawaiian or Other Pacific Islander
           05  CLM-RACE-VALUES.
               10  CLM-RACE-VAL        PIC 9(7) OCCURS 6 TIMES.

      *    ---- SEX : 3 valeurs (source confirmee) -----------------------
      *    1=INA 2=FEMALE 3=MALE
           05  CLM-SEX-VALUES.
               10  CLM-SEX-VAL         PIC 9(7) OCCURS 3 TIMES.

      *    ---- Indicateurs de presence (Y si la source a fourni ------
      *         une ligne pour ce Record-ID, N sinon) -------------------
           05  CLM-FOUND-FLAGS.
               10  CLM-FOUND-AGE       PIC X(01).
               10  CLM-FOUND-ETH       PIC X(01).
               10  CLM-FOUND-IND       PIC X(01).
               10  CLM-FOUND-RACE      PIC X(01).
               10  CLM-FOUND-SEX       PIC X(01).
