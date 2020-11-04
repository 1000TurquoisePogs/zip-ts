//ZWEKRING JOB
//*
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2020, 2020
//*
//*********************************************************************
//*
//* Zowe Open Source Project
//* This JCL can be used to define key ring and certificates for Zowe
//*
//*
//* CAUTION: This is neither a JCL procedure nor a complete job.
//* Before using this JCL, you will have to make the following
//* modifications:
//*
//* 1) Add job name and job parameters to the JOB statement, to
//*    meet your system requirements.
//*
//* 2) Update the SET PRODUCT= statement to match your security
//*    product.
//*
//* 3) Update the SET ZOWEUSER= statement to match the existing
//*    user ID for the Zowe started task.
//*
//* 4) Update the SET ZOWERING= statement to match the desired
//*    name of the keyring owned by the &ZOWEUSER user ID.
//*
//* 5) Update the SET LABEL= statement with the name of the Zowe
//*    certificate that will be added to the security database or
//*    that is already stored in the security database.
//*
//* 6) Update the SET DSNAME= statement if you plan to import the Zowe
//*    certificate from a data set in PKCS12 format.
//*
//* 7) Update the SET PKCSPASS= statement to match the password for
//*    the PKCS12 data set.
//*
//* 8) Specify the distinguished name of the Zowe's local CA by
//*    updating the SET statements CN=, OU=, O=, L=, SP=, C=, and
//*    LOCALCA=.
//*
//* 9) Update the SET HOSTNAME= variable to match the hostname where
//*    Zowe is to run.
//*
//* 10) Update the SET IPADDRES= variable to match the IP address
//*     where Zowe is to run.
//*
//* 11) Customize the commands in the DD statement that matches your
//*     security product so that they meet your system requirements.
//*
//* Note(s):
//*
//* 1. THE USER ID THAT RUNS THIS JOB MUST HAVE SUFFICIENT AUTHORITY
//*    TO ALTER SECURITY DEFINITIONS
//*
//* 2. Assumption: signing CA chain of the Zowe external certificate is
//*    added to the security database under the CERTAUTH userid.
//*
//* 3. If the Zowe certificate is imported from a data set then
//*    the certificate has to be in PKCS12 format and has to
//*    contain Zowe certificate's signing CA chain and private key.
//*
//* 4. This job WILL complete with return code 0.
//*    The results of each command must be verified after completion.
//*
//*********************************************************************
//         EXPORT SYMLIST=*
//*
//         SET  PRODUCT=RACF         * RACF, ACF2, or TSS
//*                     12345678
//         SET ZOWEUSER=ZWESVUSR     * userid for Zowe started task
//*                     12345678
//*
//*      * Hostname of the system where Zowe is to run
//         SET HOSTNAME=''
//*      * IP address of the system where Zowe is to run
//         SET IPADDRES=''
//*      * Keyring for the Zowe userid
//         SET ZOWERING='ZoweKeyring'
//*      * Zowe's certificate label
//         SET    LABEL='localhost'
//*      * Name of the data set containing Zowe's certificate (PKCS12)
//         SET   DSNAME=
//*      * Password for the PKCS12 data set
//         SET PKCSPASS=''
//*      * Name/Label of the intermediate CA of the Zowe certificate
//*      * Ignore if not applicable
//         SET ITRMZWCA=
//*      * Name/Label of the root CA of the Zowe certificate
//*      * Ignore if not applicable
//         SET ROOTZWCA=
//*      * Name/Label of the root CA of the z/OSMF certificate
//         SET ROOTZFCA=
//*      * Zowe's local CA common name
//         SET       CN='Zowe Development Instances'
//*      * Zowe's local CA organizational unit
//         SET       OU='API Mediation Layer'
//*      * Zowe's local CA organization
//         SET        O='Zowe Sample'
//*      * Zowe's local CA city/locality
//         SET        L='Prague'
//*      * Zowe's local CA state/province
//         SET       SP='Prague'
//*      * Zowe's local CA country
//         SET        C='CZ'
//*      * Zowe's local CA name
//         SET        LOCALCA='localca'
//*
//* ACF2 ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
//*                     12345678
//         SET   STCGRP=          * group for Zowe started tasks
//*                     12345678
//*
//* end ACF2 ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
//*
//*********************************************************************
//*
//* EXECUTE COMMANDS FOR SELECTED SECURITY PRODUCT
//*
//RUN      EXEC PGM=IKJEFT01,REGION=0M
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DDNAME=&PRODUCT
//*
//*********************************************************************
//*
//* RACF ONLY, customize to meet your system requirements
//*
//RACF     DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Create the keyring .............................................. */
  RACDCERT ADDRING(&ZOWERING.) ID(&ZOWEUSER.)
  SETROPTS RACLIST(DIGTRING) REFRESH

/* Create Zowe's local CA authority .................................*/
  RACDCERT GENCERT CERTAUTH +
           SUBJECTSDN( +
             CN('&CN. CA') +
             OU('&OU.') +
             O('&O.') +
             L('&L.') +
             SP('&SP.') +
             C('&C.')) +
           SIZE(2048) +
           NOTAFTER(DATE(2030-05-01)) +
           WITHLABEL('&LOCALCA') +
           KEYUSAGE(CERTSIGN)
  SETROPTS RACLIST(DIGTCERT) REFRESH

/* Connect Zowe's local CA authority to the keyring ................ */
  RACDCERT CONNECT(CERTAUTH LABEL('&LOCALCA') +
           RING(&ZOWERING.)) +
           ID(&ZOWEUSER.)

/* ***************************************************************** */
/* ATTENTION!                                                        */
/* Configure certificate for Zowe .................................. */
/* Select one of three options which is the most suitable for your   */
/* environment and follow the appropriate action                     */
/*                                                                   */
/* Options:                                                          */
/*  1. Zowe's certificate is already loaded in RACF database         */
/*     ACTION: a. Uncomment the "Option 1" block below and modify the*/
/*             following snippet below                               */
/*                CONNECT(SITE | ID(userid) +                        */
/*                LABEL('certlabel') +                               */
/*             to match the owner of the desired certificate.        */
/*             b. Comment out the "Option 3" block below             */
/*                                                                   */
/*  2. Import external Zowe's certificate from a data set in PKCS12  */
/*     format                                                        */
/*     ACTION: a. Uncomment the "Option 2" block below               */
/*             b. Comment out the "Option 3" block below             */
/*                                                                   */
/*  3. Generate Zowe's certificate that will be signed by the        */
/*     Zowe's local CA                                               */
/*     ACTION: This is the default behavior if you submit            */
/*             this file unmodified                                  */
/*                                                                   */
/* ***************************************************************** */
/*                                                                   */
/* Option 1 - BEGINNING ............................................ */
/* Connect a Zowe's certificate with the keyring                     */
/*  RACDCERT CONNECT(SITE | ID(userid) +
/*           LABEL('certlabel') +
/*           RING(&ZOWERING.) +
/*           USAGE(PERSONAL) DEFAULT) +
/*           ID(&ZOWEUSER.)

/* Option 1 - END .................................................. */
/* ................................................................. */
/* Option 2 - BEGINNING ............................................ */
/* Import external certificate from data set ....................... */
/* RACDCERT ADD('&DSNAME.') +
/*          ID(&ZOWEUSER.) +
/*          WITHLABEL('&LABEL.') +
/*          PASSWORD('&PKCSPASS.') +
/*          TRUST
/* SETROPTS RACLIST(DIGTCERT, DIGTRING) REFRESH

/* Connect a Zowe's certificate with the keyring                     */
/*  RACDCERT CONNECT(ID(&ZOWEUSER.) +
/*           LABEL('&LABEL.') +
/*           RING(&ZOWERING.) +
/*           USAGE(PERSONAL) DEFAULT) +
/*           ID(&ZOWEUSER.)

/* Option 2 - END .................................................. */
/* ................................................................. */
/* Option 3 - BEGINNING ............................................ */
/* Create a certificate signed by local zowe's CA .................. */
    RACDCERT GENCERT ID(&ZOWEUSER.) +
            SUBJECTSDN( +
                CN('&CN. certificate') +
                OU('&OU.') +
                O('&O.') +
                L('&L.') +
                SP('&SP.') +
                C('&C.')) +
            SIZE(2048) +
            NOTAFTER(DATE(2030-05-01)) +
            WITHLABEL('&LABEL.') +
            KEYUSAGE(HANDSHAKE) +
            ALTNAME(IP(&IPADDRES) +
                DOMAIN('&HOSTNAME')) +
            SIGNWITH(CERTAUTH LABEL('&LOCALCA'))
    SETROPTS RACLIST(DIGTCERT) REFRESH

/* Connect a Zowe's certificate with the keyring                     */
    RACDCERT CONNECT(ID(&ZOWEUSER.) +
             LABEL('&LABEL.') +
             RING(&ZOWERING.) +
             USAGE(PERSONAL) DEFAULT) +
             ID(&ZOWEUSER.)

/* Option 3 - END .................................................. */

/* A common part for all options starts here ....................... */

/* Connect all CAs of the Zowe certificate's signing chain with the  */
/* keyring ......................................................... */
/* Add or remove commands according to the Zowe certificate's        */
/* signing CA chain ................................................ */
   RACDCERT CONNECT(CERTAUTH +
            LABEL('&ITRMZWCA.') +
            RING(&ZOWERING.) USAGE(CERTAUTH)) +
            ID(&ZOWEUSER.)
   RACDCERT CONNECT(CERTAUTH +
            LABEL('&ROOTZWCA.') +
            RING(&ZOWERING.) USAGE(CERTAUTH)) +
            ID(&ZOWEUSER.)

/* Connect root CA that signed z/OSMF certificate with the keyring.  */
/* If z/OSMF is using self-signed certificate then specify directly  */
/* the z/OSMF certificate to be connected with the keyring.          */
   RACDCERT CONNECT(CERTAUTH +
            LABEL('&ROOTZFCA.') +
            RING(&ZOWERING.) USAGE(CERTAUTH)) +
            ID(&ZOWEUSER.)

/* Create jwtsecret .................................................*/
  RACDCERT GENCERT ID(&ZOWEUSER.) +
             SUBJECTSDN( +
               CN('&CN. JWT') +
               OU('&OU.') +
               O('&O.') +
               L('&L.') +
               SP('&SP.') +
               C('&C.')) +
             SIZE(2048) +
             NOTAFTER(DATE(2030-05-01)) +
             WITHLABEL('jwtsecret')
  SETROPTS RACLIST(DIGTCERT) REFRESH

/* Connect jwtsecret to the keyring ................................ */
  RACDCERT CONNECT(ID(&ZOWEUSER.) LABEL('jwtsecret') +
           RING(&ZOWERING.) USAGE(PERSONAL)) +
           ID(&ZOWEUSER.)

/* Allow ZOWEUSER to access keyring ................................ */
  PERMIT IRR.DIGTCERT.LISTRING CLASS(FACILITY) ID(&ZOWEUSER.) +
         ACCESS(READ)

/* Uncomment this command if SITE acid owns the Zowe certificate     */
/*  PERMIT IRR.DIGTCERT.GENCERT CLASS(FACILITY) ID(&ZOWEUSER.) +
/*         ACCESS(CONTROL)

  SETROPTS RACLIST(FACILITY) REFRESH

/* List the keyring ................................................ */
   RACDCERT LISTRING(&ZOWERING.) ID(&ZOWEUSER.)

/* ................................................................. */
/* only the last RC is returned, this command ensures it is a 0      */
PROFILE
$$
//*
//*********************************************************************
//*
//* ACF2 ONLY, customize to meet your system requirements
//*
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF
//
* Create the keyring
  SET PROFILE(USER) DIVISION(KEYRING)
  INSERT &ZOWEUSER..ZOWERING RINGNAME(&ZOWERING.)
  F ACF2,REBUILD(USR),CLASS(P),DIVISION(KEYRING)

* Create Zowe's local CA authority
  SET PROFILE(USER) DIVISION(CERTDATA)
  GENCERT CERTAUTH.ZOWECA LABEL(&LOCALCA) SIZE(2048) +
          SUBJSDN(CN='&CN. CA' +
                  OU='&OU.' +
                   O='&O.' +
                   L='&L.' +
                  SP='&SP.' +
                  C='&C.') +
  EXPIRE(05/01/30) +
  KEYUSAGE(CERTSIGN)
*
* Connect Zowe's local CA authority to the keyring ................ */
  SET PROFILE(USER) DIVISION(CERTDATA)
  CONNECT CERTDATA(CERTAUTH.ZOWECA) RINGNAME(&ZOWERING.) +
  KEYRING(&ZOWEUSER..ZOWERING) USAGE(CERTAUTH)
  CHKCERT CERTAUTH.ZOWECA

* ***************************************************************** */
* ATTENTION!                                                        */
* Configure certificate for Zowe .................................. */
* Select one of three options which is the most suitable for your   */
* environment and follow the appropriate action                     */
*                                                                   */
* Options:                                                          */
*  1. Zowe's certificate is already loaded in ACF2 database         */
*     ACTION: a. Uncomment the "Option 1" block below and modify the*/
*             following snippet in the uncommented block            */
*              CONNECT CERTDATA(SITECERT.digicert | userid.digicert)*/
*             to match the owner of the desired certificate.        */
*             b. Comment out the "Option 3" block below             */
*                                                                   */
*  2. Import external Zowe's certificate from a data set in PKCS12  */
*     format                                                        */
*     ACTION: a. Uncomment the "Option 2" block below               */
*             b. Comment out the "Option 3" block below             */
*                                                                   */
*  3. Generate Zowe's certificate that will be signed by the        */
*     Zowe's local CA                                               */
*     ACTION: This is the default behavior if you submit            */
*             this file unmodified                                  */
*                                                                   */
* ***************************************************************** */
*                                                                   */
* Option 1 - BEGINNING ............................................ */
* Connect a Zowe's certificate with the keyring                      */
*  SET PROFILE(USER) DIVISION(CERTDATA)
*  CONNECT CERTDATA(SITECERT.digicert | userid.digicert) +
*  KEYRING(&ZOWEUSER..ZOWERING) USAGE(PERSONAL) DEFAULT
*  CHKCERT &ZOWEUSER..ZOWECERT

* Option 1 - END .................................................. */
* ................................................................. */
* Option 2 - BEGINNING ............................................ */
* Import external certificate from data set ....................... */

*  SET PROFILE(USER) DIV(CERTDATA)
*  INSERT &ZOWEUSER..ZOWECERT +
*         DSNAME('&DSNAME.') +
*         LABEL(&LABEL.) +
*         PASSWORD('&PKCSPASS.') +
*         TRUST
*
* Connect a Zowe's certificate with the keyring                     */
*  SET PROFILE(USER) DIVISION(CERTDATA)
*  CONNECT CERTDATA(&ZOWEUSER..ZOWECERT) +
*  KEYRING(&ZOWEUSER..ZOWERING) USAGE(PERSONAL) DEFAULT
*  CHKCERT &ZOWEUSER..ZOWECERT

* Option 2 - END .................................................. */
* ................................................................. */
* Option 3 - BEGINNING ............................................ */
* Create a certificate signed by local zowe's CA .................. */
   SET PROFILE(USER) DIV(CERTDATA)
   GENCERT &ZOWEUSER..ZOWECERT +
            SUBJSDN(CN='&CN. certificate' +
                    OU='&OU.' +
                     O='&O.' +
                     L='&L.' +
                    SP='&SP.' +
                    C='&C.') +
           SIZE(2048) +
           EXPIRE(05/01/30) +
           LABEL(&LABEL.) +
           KEYUSAGE(HANDSHAKE) +
           ALTNAME(IP=&IPADDRES DOMAIN=&HOSTNAME) +
           SIGNWITH(CERTAUTH.ZOWECA)

* Connect a Zowe's certificate with the keyring                      */
   SET PROFILE(USER) DIVISION(CERTDATA)
   CONNECT CERTDATA(&ZOWEUSER..ZOWECERT) +
   KEYRING(&ZOWEUSER..ZOWERING) USAGE(PERSONAL) DEFAULT
   CHKCERT &ZOWEUSER..ZOWECERT

* Option 3 - END ................................................... */

* A common part for all options starts here ........................ */

* Connect all CAs of the Zowe certificate's signing chain with the   */
* keyring .......................................................... */
* Add or remove commands according to the Zowe certificate's         */
* signing CA chain ................................................. */
   SET PROFILE(USER) DIVISION(CERTDATA)
   CONNECT CERTDATA(CERTAUTH.&ITRMZWCA.) RINGNAME(&ZOWERING.) +
   KEYRING(&ZOWEUSER..ZOWERING) USAGE(CERTAUTH)

   CONNECT CERTDATA(CERTAUTH.&ROOTZWCA.) RINGNAME(&ZOWERING.) +
   KEYRING(&ZOWEUSER..ZOWERING) USAGE(CERTAUTH)

* Connect root CA that signed z/OSMF certificate with the keyring.   */
* If z/OSMF is using self-signed certificate then specify directly   */
* the z/OSMF certificate to be connected with the keyring.           */
   SET PROFILE(USER) DIVISION(CERTDATA)
   CONNECT CERTDATA(CERTAUTH.&ROOTZFCA.) RINGNAME(&ZOWERING.) +
   KEYRING(&ZOWEUSER..ZOWERING) USAGE(CERTAUTH)

* Create jwtsecret
   SET PROFILE(USER) DIVISION(CERTDATA)
   GENCERT &ZOWEUSER..ZOWEJWT +
           SUBJSDN(CN='&CN. JWT' +
                   OU='&OU.' +
                    O='&O.' +
                    L='&L.' +
                   SP='&SP.' +
                   C='&C.') +
           SIZE(2048) +
           LABEL(jwtsecret) +
           EXPIRE(05/01/30)

* Connect jwtsecret to the keyring ................................
  SET PROFILE(USER) DIVISION(CERTDATA)
  CONNECT CERTDATA(&ZOWEUSER..ZOWEJWT) RINGNAME(&ZOWERING.) +
  KEYRING(&ZOWEUSER..ZOWERING) USAGE(PERSONAL)
  CHKCERT &ZOWEUSER..ZOWEJWT

* Allow ZOWEUSER to access keyring ................................
  SET RESOURCE(FAC)
  RECKEY IRR ADD(DIGTCERT.LISTRING ROLE(&STCGRP) +
  SERVICE(READ) ALLOW)

* Uncomment this command if SITE acid owns the Zowe certificate
*  RECKEY IRR ADD(DIGTCERT.GENCERT ROLE(&STCGRP) +
*  SERVICE(CONTROL) ALLOW)

  F ACF2,REBUILD(FAC)

* List the keyring ................................................
  SET PROFILE(USER) DIVISION(KEYRING)
  LIST &ZOWEUSER..ZOWERING
$$
//*
//*********************************************************************
//*
//* Top Secret ONLY, customize to meet your system requirements
//*
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* Create the keyring .............................................. */
  TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.)

/* Create Zowe's local CA authority .................................*/
  TSS GENCERT(CERTAUTH) +
        DIGICERT(ZOWECA) +
        SUBJECTN( +
          'CN="&CN. CA" +
          OU="&OU." +
          O="&O." +
          L="&L." +
          SP="&SP." +
          C="&C." ') +
        KEYSIZE(2048) +
        NADATE(05/01/30) +
        LABLCERT(&LOCALCA) +
        KEYUSAGE('CERTSIGN')

/* Connect Zowe's local CA authority to the keyring ................ */
  TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.) +
      RINGDATA(CERTAUTH,ZOWECA)

/* ***************************************************************** */
/* ATTENTION!                                                        */
/* Configure certificate for Zowe .................................. */
/* Select one of three options which is the most suitable for your   */
/* environment and follow the appropriate action                     */
/*                                                                   */
/* Options:                                                          */
/*  1. Zowe's certificate is already loaded in TSS database         */
/*     ACTION: a. Uncomment the "Option 1" block below and modify the*/
/*             following snippet in the uncommented block            */
/*                RINGDATA(CERTSITE|userid,digicert)                 */
/*             to match the owner of the desired certificate.        */
/*             b. Comment out the "Option 3" block below             */
/*                                                                   */
/*  2. Import external Zowe's certificate from a data set in PKCS12  */
/*     format                                                        */
/*     ACTION: a. Uncomment the "Option 2" block below               */
/*             b. Comment out the "Option 3" block below             */
/*                                                                   */
/*  3. Generate Zowe's certificate that will be signed by the        */
/*     Zowe's local CA                                               */
/*     ACTION: This is the default behavior if you submit            */
/*             this file unmodified                                  */
/*                                                                   */
/* ***************************************************************** */
/*                                                                   */
/* Option 1 - BEGINNING ............................................ */
/* Connect a Zowe's certificate with the keyring                     */
/* TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) +
/*     RINGDATA(CERTSITE|userid,digicert) +
/*     USAGE(PERSONAL) DEFAULT

/* Option 1 - END .................................................. */
/* ................................................................. */
/* Option 2 - BEGINNING ............................................ */
/* Import external certificate from data set ....................... */
/* TSS ADD(&ZOWEUSER.) +
/*      DIGICERT(ZOWECERT) +
/*      DCDSN(&DSNAME.) +
/*      LABLCERT(&LABEL.) +
/*      PKCSPASS('&PKCSPASS.') +
/*      TRUST

/* Connect a Zowe's certificate with the keyring                     */
/* TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) +
/*     RINGDATA(&ZOWEUSER.,ZOWECERT) +
/*     USAGE(PERSONAL) DEFAULT

/* Option 2 - END .................................................. */
/* ................................................................. */
/* Option 3 - BEGINNING ............................................ */
/* Create a certificate signed by local zowe's CA .................. */
   TSS GENCERT(&ZOWEUSER.) +
       DIGICERT(ZOWECERT) +
       SUBJECTN( +
         'CN="&CN. certificate" +
         OU="&OU." +
         O="&O." +
         L="&L." +
         SP="&SP." +
         C="&C." ') +
       KEYSIZE(2048) +
       NADATE(05/01/30) +
       LABLCERT(&LABEL.) +
       KEYUSAGE('HANDSHAKE') +
       ALTNAME('DOMAIN=&HOSTNAME') +
       SIGNWITH(CERTAUTH,ZOWECA)

/* Connect a Zowe's certificate with the keyring                     */
   TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) +
       RINGDATA(&ZOWEUSER.,ZOWECERT) +
       USAGE(PERSONAL) DEFAULT

/* Option 3 - END .................................................. */

/* A common part for all options starts here ....................... */

/* Connect all CAs of the Zowe certificate's signing chain with the  */
/* keyring ......................................................... */
/* Add or remove commands according to the Zowe certificate's        */
/* signing CA chain ................................................ */
   TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.) +
       RINGDATA(CERTAUTH,&ITRMZWCA.) USAGE(CERTAUTH)

   TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.) +
       RINGDATA(CERTAUTH,&ROOTZWCA.) USAGE(CERTAUTH)

/* Connect root CA that signed z/OSMF certificate with the keyring.  */
/* If z/OSMF is using self-signed certificate then specify directly  */
/* the z/OSMF certificate to be connected with the keyring.          */
   TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.) +
       RINGDATA(CERTAUTH,&ROOTZFCA.) USAGE(CERTAUTH)

/* Create jwtsecret .................................................*/
   TSS GENCERT(&ZOWEUSER.) +
      DIGICERT(ZOWEJWT) +
      SUBJECTN( +
        'CN="&CN. JWT" +
        OU="&OU." +
        O="&O." +
        L="&L." +
        SP="&SP." +
        C="&C." ') +
      KEYSIZE(2048) +
      NADATE(05/01/30) +
      LABLCERT(jwtsecret)

/* Connect jwtsecret to the keyring ................................ */
  TSS ADD(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.) +
      RINGDATA(&ZOWEUSER.,ZOWEJWT) USAGE(PERSONAL)

/* Allow ZOWEUSER to access keyring ................................ */
  TSS PERMIT(&ZOWEUSER.) IBMFAC(IRR.DIGTCERT.LISTRING) ACCESS(READ)

/* Uncomment this command if SITE acid owns the Zowe certificate   */
/* TSS PERMIT(&ZOWEUSER.) IBMFAC(IRR.DIGTCERT.GENCERT) ACCESS(CONTROL)


/* List the keyring ................................................ */
  TSS LIST(&ZOWEUSER.) KEYRING(ZOWERING) LABLRING(&ZOWERING.)

/* ................................................................. */
/* only the last RC is returned, this command ensures it is a 0      */
PROFILE
$$
//*

