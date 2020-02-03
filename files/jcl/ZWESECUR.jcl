//ZWESECUR JOB
//*
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2018, 2020
//*
//*********************************************************************
//*
//* Zowe Open Source Project
//* This JCL can be used to define security permits for Zowe
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
//* 3) Update the SET ADMINGRP= statement to match the desired
//*    group name for Zowe administrators.
//*
//* 4) Update the SET STCGROUP= statement to match the desired
//*    group name for started tasks.
//*
//* 5) Update the SET ZOWEUSER= statement to match the desired
//*    user ID for the ZOWE started task.
//*
//* 6) Update the SET XMEMUSER= statement to match the desired
//*    user ID for the XMEM started task.
//*
//* 7) Update the SET AUXUSER= statement to match the desired
//*    user ID for the XMEM Auxilary started task.
//*
//* 8) Update the SET ZOWESTC= statement to match the desired
//*    Zowe started task name.
//*
//* 9) Update the SET XMEMSTC= statement to match the desired
//*    XMEM started task name.
//*
//* 10) Update the SET AUXSTC= statement to match the desired
//*    XMEM Auxilary started task name.
//*
//* 11) Update the SET HLQ= statement to match the desired
//*     Zowe data set high level qualifier.
//*
//* 12) Update the SET SYSPROG= statement to match the existing
//*     user ID or group used by z/OS system programmers.
//*
//* 13) When not using AUTOUID and AUTOGID to assign z/OS UNIX UID
//*     and GID values, update the SET *ID= statements to match the
//*     desired UID and GID values.
//*
//* 14) When using Top Secret, update the Top Secret specific SET
//*     statements.
//*
//* 15) Customize the commands in the DD statement that matches your
//*     security product so that they meet your system requirements.
//*
//* Note(s):
//*
//* 1. THE USER ID THAT RUNS THIS JOB MUST HAVE SUFFICIENT AUTHORITY
//*    TO ALTER SECURITY DEFINITONS
//*
//* 2. The sample ACF2 commands create ROLEs that match the group
//*    names. Due to permits assigned to the &STCGROUP ROLE, it is
//*    advised to ensure this ROLE has a unique identifier.
//*
//* 3. The Zowe started task user ID (variable ZOWEUSER) must be able
//*    to write persistent data in the zlux-app-server/deploy directory
//*    structure. This sample JCL makes the Zowe started task part of
//*    the Zowe administrator group (SET STCGROUP=&ADMINGRP. statement)
//*    to achieve this goal. Another solution, also below, which you can
//*    comment out, is giving the Zowe started task CONTROL access to
//*    the UNIXPRIV SUPERUSER.FILESYS profile.
//*
//* 4. This job WILL complete with return code 0.
//*    The results of each command must be verified after completion.
//*
//*********************************************************************
//         EXPORT SYMLIST=*
//*
//         SET  PRODUCT=RACF         * RACF, ACF2, or TSS
//*                     12345678
//         SET ADMINGRP=ZWEADMIN     * group for Zowe administrators
//         SET STCGROUP=&ADMINGRP.   * group for Zowe started tasks
//         SET ZOWEUSER=ZWESVUSR     * userid for Zowe started task
//         SET XMEMUSER=ZWESIUSR     * userid for xmem started task
//         SET  AUXUSER=&XMEMUSER.   * userid for xmem AUX started task
//         SET  ZOWESTC=ZWESVSTC     * Zowe started task name
//         SET  XMEMSTC=ZWESISTC     * xmem started task name
//         SET   AUXSTC=ZWESASTC     * xmem AUX started task name
//         SET      HLQ=ZWE          * data set high level qualifier
//         SET  SYSPROG=&ADMINGRP.   * system programmer user ID/group
//*                     12345678
//*
//* The sample RACF and ACF2 commands assume AUTOUID and AUTOGID are
//* enabled. When this is not the case, or you are using Top Secret,
//* provide appropriate (numeric) values to these SET commands.
//         SET ADMINGID=             * Group ID for ZOWE administrators
//         SET   STCGID=&ADMINGID.   * Group ID for ZOWE started tasks
//         SET  ZOWEUID=             * UID for ZOWE started task User
//         SET  XMEMUID=             * UID for xmem started task User
//         SET   AUXUID=&XMEMUID.    * UID for xm AUX started task User
//*
//* For RACF: If using AUTOUID and AUTOGID, the RACF database must be
//*           at AIM 2 or higher, and BPX.NEXT.USER must exist.
//* For ACF2: If using AUTOUID and AUTOGID, an AUTOIDOM GSO Record must
//*           exist.
//* For Top Secret: If a default UID and GID range is defined, you can
//*                 specify '?' in the SET *ID= statements to utilize
//*                 auto-assignment of UID and GID.
//*
//* Top Secret ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
//*                     12345678
//         SET ADMINDEP=             * department owning admin group
//         SET  STCGDEP=             * department owning STC group
//         SET  STCUDEP=             * department owning STC user IDs
//         SET  FACACID=             * ACID owning IBMFAC
//*                     12345678
//*
//* end Top Secret ONLY -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
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

/* ACTIVATE REQUIRED RACF SETTINGS AND CLASSES ..................... */

/* - Comment out the activation statements for the classes that are  */
/*   already active.                                                 */

/* display current settings                                          */
/*SETROPTS LIST                                                      */

/* activate FACILITY class for z/OS UNIX & Zowe XMEM profiles        */
  SETROPTS GENERIC(FACILITY)
  SETROPTS CLASSACT(FACILITY) RACLIST(FACILITY)

/** comment out to not use SUPERUSER.FILESYS, see JCL comments       */
/** activate UNIXPRIV class for z/OS UNIX profiles                   */
  SETROPTS GENERIC(UNIXPRIV)
  SETROPTS CLASSACT(UNIXPRIV) RACLIST(UNIXPRIV)

/* activate started task class                                       */
  SETROPTS GENERIC(STARTED)
  RDEFINE STARTED ** STDATA(USER(=MEMBER) GROUP(&STCGROUP.))
  SETROPTS CLASSACT(STARTED) RACLIST(STARTED)

/* show results .................................................... */
  SETROPTS LIST

/* DEFINE ADMINISTRATORS ........................................... */

/* - The sample commands assume automatic generation of GID is       */
/*   enabled.                                                        */

/* group for administrators                                          */
/* replace AUTOGID with GID(&ADMINGID.) if AUTOGID is not enabled    */
  LISTGRP  &ADMINGRP. OMVS
  ADDGROUP &ADMINGRP. OMVS(AUTOGID) -
   DATA('ZOWE ADMINISTRATORS')

/* uncomment to add existing user IDs to the &ADMINGRP group         */
/* CONNECT (userid,userid,...) GROUP(&ADMINGRP.) AUTH(USE)           */

/* DEFINE STARTED TASK ............................................. */

/* - Ensure that user IDs are protected with the NOPASSWORD keyword. */
/* - The sample commands assume automatic generation of UID and GID  */
/*   is enabled.                                                     */

/* comment out if &STCGROUP matches &ADMINGRP (default), expect      */
/*   warning messages otherwise                                      */
/* group for started tasks                                           */
/* replace AUTOGID with GID(&STCGID.) if AUTOGID is not enabled      */
  LISTGRP  &STCGROUP. OMVS
  ADDGROUP &STCGROUP. OMVS(AUTOGID) -
   DATA('STARTED TASK GROUP WITH OMVS SEGEMENT')

/* */

/* userid for ZOWE main server                                       */
/* replace AUTOUID with UID(&ZOWEUID.) if AUTOUID is not enabled     */
  LISTUSER &ZOWEUSER. OMVS
  ADDUSER  &ZOWEUSER. -
   NOPASSWORD -
   DFLTGRP(&STCGROUP.) -
   OMVS(HOME(/tmp) PROGRAM(/bin/sh) AUTOUID) -
   NAME('ZOWE SERVER') -
   DATA('ZOWE MAIN SERVER')

/* userid for XMEM cross memory server                               */
/* replace AUTOUID with UID(&XMEMUID.) if AUTOUID is not enabled     */
  LISTUSER &XMEMUSER. OMVS
  ADDUSER  &XMEMUSER. -
   NOPASSWORD -
   DFLTGRP(&STCGROUP.) -
   OMVS(HOME(/tmp) PROGRAM(/bin/sh) AUTOUID) -
   NAME('ZOWE XMEM SERVER') -
   DATA('ZOWE XMEM CROSS MEMORY SERVER')

/* comment out if &AUXUSER matches &XMEMUSER (default), expect       */
/*   warning messages otherwise                                      */
/* userid for XMEM auxilary cross memory server                      */
/* replace AUTOUID with UID(&AUXUID.) if AUTOUID is not enabled      */
  LISTUSER &AUXUSER. OMVS
  ADDUSER  &AUXUSER. -
   NOPASSWORD -
   DFLTGRP(&STCGROUP.) -
   OMVS(HOME(/tmp) PROGRAM(/bin/sh) AUTOUID) -
   NAME('ZOWE XMEM AUX SERVER') -
   DATA('ZOWE XMEM AUX CROSS MEMORY SERVER')

/* */

/* started task for ZOWE main server                                 */
  RLIST   STARTED &ZOWESTC..* ALL STDATA
  RDEFINE STARTED &ZOWESTC..* -
   STDATA(USER(&ZOWEUSER.) GROUP(&STCGROUP.) TRUSTED(NO)) -
   DATA('ZOWE MAIN SERVER')

/* started task for XMEM cross memory server                         */
  RLIST   STARTED &XMEMSTC..* ALL STDATA
  RDEFINE STARTED &XMEMSTC..* -
   STDATA(USER(&XMEMUSER.) GROUP(&STCGROUP.) TRUSTED(NO)) -
   DATA('ZOWE XMEM CROSS MEMORY SERVER')

/* started task for XMEM auxilary cross memory server                */
  RLIST   STARTED &AUXSTC..* ALL STDATA
  RDEFINE STARTED &AUXSTC..* -
   STDATA(USER(&AUXUSER.) GROUP(&STCGROUP.) TRUSTED(NO)) -
   DATA('ZOWE XMEM AUX CROSS MEMORY SERVER')

  SETROPTS RACLIST(STARTED) REFRESH

/* show results .................................................... */
  LISTGRP  &STCGROUP. OMVS
  LISTUSER &ZOWEUSER. OMVS
  LISTUSER &XMEMUSER. OMVS
  LISTUSER &AUXUSER.  OMVS
  RLIST STARTED &ZOWESTC..* ALL STDATA
  RLIST STARTED &XMEMSTC..* ALL STDATA
  RLIST STARTED &AUXSTC..*  ALL STDATA

/* DEFINE ZOWE SERVER PERMISIONS ................................... */

/* permit Zowe main server to use XMEM cross memory server           */
  RLIST   FACILITY ZWES.IS ALL
  RDEFINE FACILITY ZWES.IS UACC(NONE)
  PERMIT ZWES.IS CLASS(FACILITY) ACCESS(READ) ID(&ZOWEUSER.)

  SETROPTS RACLIST(FACILITY) REFRESH

/* permit Zowe main server to create a user's security environment   */
/* ATTENTION: Defining the BPX.DAEMON or BPX.SERVER profile makes    */
/*            z/OS UNIX switch to z/OS UNIX level security. This is  */
/*            more secure, but it can impact operation of existing   */
/*            applications. Test this thoroughly before activating   */
/*            it on a production system.                             */
  RLIST   FACILITY BPX.DAEMON ALL
  RDEFINE FACILITY BPX.DAEMON UACC(NONE)
  PERMIT BPX.DAEMON CLASS(FACILITY) ACCESS(UPDATE) ID(&ZOWEUSER.)

  RLIST   FACILITY BPX.SERVER ALL
  RDEFINE FACILITY BPX.SERVER UACC(NONE)
  PERMIT BPX.SERVER CLASS(FACILITY) ACCESS(UPDATE) ID(&ZOWEUSER.)

  SETROPTS RACLIST(FACILITY) REFRESH

/** comment out to not use SUPERUSER.FILESYS, see JCL comments       */
/** permit Zowe main server to write persistent data                 */
  RLIST   UNIXPRIV SUPERUSER.FILESYS ALL
  RDEFINE UNIXPRIV SUPERUSER.FILESYS UACC(NONE)
  PERMIT SUPERUSER.FILESYS CLASS(UNIXPRIV) ACCESS(CONTROL) -
   ID(&ZOWEUSER.)

   SETROPTS RACLIST(UNIXPRIV) REFRESH

/* show results .................................................... */
  RLIST   FACILITY ZWES.IS           ALL
  RLIST   FACILITY BPX.DAEMON        ALL
  RLIST   FACILITY BPX.SERVER        ALL
  RLIST   UNIXPRIV SUPERUSER.FILESYS ALL

/* DEFINE ZOWE DATA SET PROTECTION ................................. */

/* - &HLQ..SZWEAUTH is an APF authorized data set. It is strongly    */
/*   advised to protect it against updates.                          */
/* - The sample commands assume that EGN (Enhanced Generic Naming)   */
/*   is active, which allows the usage of ** to represent any number */
/*   of qualifiers in the DATASET class. Substitute *.** with * if   */
/*   EGN is not active on your system.                               */

/* HLQ stub                                                          */
  LISTGRP  &HLQ.
  ADDGROUP &HLQ. DATA('Zowe - HLQ STUB')

/* general data set protection                                       */
  LISTDSD PREFIX(&HLQ.) ALL
  ADDSD  '&HLQ..*.**' UACC(READ) DATA('Zowe')
  PERMIT '&HLQ..*.**' CLASS(DATASET) ACCESS(ALTER) ID(&SYSPROG.)

  SETROPTS GENERIC(DATASET) REFRESH

/* show results .................................................... */
  LISTGRP &HLQ.
  LISTDSD PREFIX(&HLQ.) ALL

/* ................................................................. */
/* only the last RC is returned, this comment ensures it is a 0      */
$$
//*
//*********************************************************************
//*
//* ACF2 ONLY, customize to meet your system requirements
//*
//ACF2     DD DATA,DLM=$$,SYMBOLS=JCLONLY
ACF
*
* DEFINE ADMINISTRATORS ...........................................
*
* group for administrators
* replace AUTOGID with GID(&ADMINGID.) if AUTOGID is not enabled
*
SET PROFILE(GROUP) DIV(OMVS)
INSERT &ADMINGRP. AUTOGID
F ACF2,REBUILD(GRP),CLASS(P)
*
* uncomment and customize to add an existing userid as administrator
*
* SET X(ROL)
* INSERT &ADMINGRP. INCLUDE(userid) ROLE
* F ACF2,NEWXREF,TYPE(ROL)
*
* DEFINE STARTED TASK .............................................
*
* comment out if &STCGROUP matches &ADMINGRP (default), expect
*   warning messages otherwise
* group for started tasks
* replace AUTOGID with GID(&STCGID.) if AUTOGID is not enabled
*
SET PROFILE(GROUP) DIV(OMVS)
INSERT &STCGROUP. AUTOGID
F ACF2,REBUILD(GRP),CLASS(P)
*
*****
*
* userid for ZOWE main server
* replace AUTOUID with UID(&ZOWEUID.) if AUTOUID is not enabled
*
SET LID
INSERT &ZOWEUSER. GROUP(&STCGROUP.)
SET PROFILE(USER) DIV(OMVS)
INSERT &ZOWEUSER. AUTOUID HOME(/tmp) OMVSPGM(/bin/sh)
F ACF2,REBUILD(USR),CLASS(P),DIVISION(OMVS)
*
* userid for XMEM cross memory server
* replace AUTOUID with UID(&XMEMUID.) if AUTOUID is not enabled
*
SET LID
INSERT &XMEMUSER. GROUP(&STCGROUP.)
SET PROFILE(USER) DIV(OMVS)
INSERT &XMEMUSER. AUTOUID HOME(/tmp) OMVSPGM(/bin/sh)
F ACF2,REBUILD(USR),CLASS(P),DIVISION(OMVS)
*
* comment out if &AUXUSER matches &XMEMUSER (default), expect
*   warning messages otherwise
* userid for XMEM auxilary cross memory server
* replace AUTOUID with UID(&AUXUID.) if AUTOUID is not enabled
*
SET LID
INSERT &AUXUSER. GROUP(&STCGROUP.)
SET PROFILE(USER) DIV(OMVS)
INSERT &AUXUSER. AUTOUID HOME(/tmp) OMVSPGM(/bin/sh)
F ACF2,REBUILD(USR),CLASS(P),DIVISION(OMVS)
*
*****
*
* started task for ZOWE main server
*
SET CONTROL(GSO)
INSERT STC.&ZOWESTC. LOGONID(&ZOWEUSER.) GROUP(&STCGROUP.) +
STCID(&ZOWESTC.)
F ACF2,REFRESH(STC)
*
* started task for XMEM cross memory server
*
SET CONTROL(GSO)
INSERT STC.&XMEMSTC. LOGONID(&XMEMUSER.) GROUP(&STCGROUP.) +
STCID(&XMEMSTC.)
F ACF2,REFRESH(STC)
*
* started task for XMEM auxilary cross memory server
*
SET CONTROL(GSO)
INSERT STC.&AUXSTC. LOGONID(&AUXUSER.) GROUP(&STCGROUP.) +
STCID(&AUXSTC.)
F ACF2,REFRESH(STC)
*
* DEFINE ZOWE SERVER PERMISIONS ...................................
*
* define a role holding the permissions and add &ZOWEUSER to it
*
SET X(ROL)
INSERT &STCGROUP. INCLUDE(&ZOWEUSER.) ROLE
F ACF2,NEWXREF,TYPE(ROL)
*
* permit Zowe main server to use XMEM cross memory server
*
SET RESOURCE(FAC)
RECKEY ZWES ADD(IS SERVICE(READ) ROLE(&STCGROUP.) ALLOW)
F ACF2,REBUILD(FAC)
*
* permit Zowe main server to create a user's security environment
* ATTENTION: Defining the BPX.DAEMON or BPX.SERVER profile makes
*            z/OS UNIX switch to z/OS UNIX level security. This is
*            more secure, but it can impact operation of existing
*            applications. Test this thoroughly before activating
*            it on a production system.
*
SET RESOURCE(FAC)
RECKEY BPX ADD(DAEMON SERVICE(UPDATE) ROLE(&STCGROUP.) ALLOW)
RECKEY BPX ADD(SERVER SERVICE(UPDATE) ROLE(&STCGROUP.) ALLOW)
F ACF2,REBUILD(FAC)
*
** comment out to not use SUPERUSER.FILESYS, see JCL comments
** permit Zowe main server to write persistent data
*
  SET RESOURCE(UNI)
  RECKEY SUPERUSER.FILESYS ADD(SERVICE(READ) ROLE(&STCGROUP.) ALLOW)
  F ACF2,REBUILD(UNI)
*
* DEFINE ZOWE DATA SET PROTECTION .................................
*
* - &HLQ..SZWEAUTH is an APF authorized data set. It is strongly
*   advised to protect it against updates.
*
*  HLQ stub
SET RULE
*  general data set protection
LIST &HLQ.
RECKEY $&HLQ. ADD(- UID(-) READ(A) EXEC(P))
RECKEY $&HLQ. ADD(- UID(&SYSPROG.) READ(A) EXEC(A) ALLOC(A) WRITE(A))
*
*  show results
LIST &HLQ.
*
* .................................................................
* only the last RC is returned, this comment ensures it is a 0
$$
//*
//*********************************************************************
//*
//* Top Secret ONLY, customize to meet your system requirements
//*
//TSS      DD DATA,DLM=$$,SYMBOLS=JCLONLY

/* DEFINE ADMINISTRATORS ........................................... */

/* group for administrators                                          */
  TSS LIST(&ADMINGRP.) SEGMENT(OMVS)
  TSS CREATE(&ADMINGRP.) TYPE(GROUP) +
   NAME('ZOWE ADMINISTRATORS') +
   DEPT(&ADMINDEP.)
  TSS ADD(&ADMINGRP.) GID(&ADMINGID.)

/* TODO add sample command to add admin to &ADMINGRP */

/* DEFINE STARTED TASK ............................................. */

/* comment out if &STCGROUP matches &ADMINGRP (default), expect      */
/*   warning messages otherwise                                      */
/* group for started tasks                                           */
  TSS LIST(&STCGROUP.) SEGMENT(OMVS)
  TSS CREATE(&STCGROUP.) TYPE(GROUP) +
   NAME('STC GROUP WITH OMVS SEGEMENT') +
   DEPT(&STCGDEP.)
  TSS ADD(&STCGROUP.) GID(&STCGID.)

/* */

/* userid for ZOWE main server                                       */
  TSS LIST(&ZOWEUSER.) SEGMENT(OMVS)
  TSS CREATE(&ZOWEUSER.) TYPE(USER) PASS(NOPW,0) +
   NAME('ZOWE MAIN SERVER') +
   DEPT(&STCUDEP.)
  TSS ADD(&ZOWEUSER.) GROUP(&STCGROUP.) DFLTGRP(&STCGROUP.) +
   HOME(/tmp) OMVSPGM(/bin/sh) UID(&ZOWEUID.)

/* userid for XMEM cross memory server                               */
  TSS LIST(&XMEMUSER.) SEGMENT(OMVS)
  TSS CREATE(&XMEMUSER.) TYPE(USER) PASS(NOPW,0) +
   NAME('ZOWE XMEM CROSS MEMORY SERVER') +
   DEPT(&STCUDEP.)
  TSS ADD(&XMEMUSER.) GROUP(&STCGROUP.) DFLTGRP(&STCGROUP.) +
   HOME(/tmp) OMVSPGM(/bin/sh) UID(&XMEMUID.)

/* comment out if &AUXUSER matches &XMEMUSER (default), expect       */
/*   warning messages otherwise                                      */
/* userid for XMEM auxilary cross memory server                      */
  TSS LIST(&AUXUSER.) SEGMENT(OMVS)
  TSS CREATE(&AUXUSER.) TYPE(USER) PASS(NOPW,0) +
   NAME('ZOWE XMEM AUX SERVER') +
   DEPT(&STCUDEP.)
  TSS ADD(&AUXUSER.) GROUP(&STCGROUP.) DFLTGRP(&STCGROUP.) +
   HOME(/tmp) OMVSPGM(/bin/sh) UID(&AUXUID.)

/* */

/* started task for ZOWE main server                                 */
  TSS LIST(STC) PROCNAME(&ZOWESTC.) PREFIX
  TSS ADD(STC) PROCNAME(&ZOWESTC.) ACID(&ZOWEUSER.)
  TSS ADD(&ZOWEUSER.) FAC(STC)

/* started task for XMEM cross memory server                         */
  TSS LIST(STC) PROCNAME(&XMEMSTC.) PREFIX
  TSS ADD(STC) PROCNAME(&XMEMSTC.) ACID(&XMEMUSER.)
  TSS ADD(&XMEMUSER.) FAC(STC)

/* started task for XMEM auxilary cross memory server                */
  TSS LIST(STC) PROCNAME(&AUXSTC.) PREFIX
  TSS ADD(STC) PROCNAME(&AUXSTC.) ACID(&AUXUSER.)
  TSS ADD(&AUXUSER.) FAC(STC)

/* DEFINE ZOWE SERVER PERMISIONS ................................... */

/* permit Zowe main server to use XMEM cross memory server           */
  TSS ADD(&FACACID.) IBMFAC(ZWES.IS)
  TSS WHOHAS IBMFAC(ZWES.IS)
  TSS PERMIT(&ZOWEUSER.) IBMFAC(ZWES.IS) ACCESS(READ)

/* permit Zowe main server to create a user's security environment   */
/* ATTENTION: Defining the BPX.DAEMON or BPX.SERVER profile makes    */
/*            z/OS UNIX switch to z/OS UNIX level security. This is  */
/*            more secure, but it can impact operation of existing   */
/*            applications. Test this thoroughly before activating   */
/*            it on a production system.                             */
  TSS ADD(&FACACID.) IBMFAC(BPX.)
  TSS WHOHAS IBMFAC(BPX.DAEMON)
  TSS PER(&ZOWEUSER.) IBMFAC(BPX.DAEMON) ACC(UPDATE)
  TSS WHOHAS IBMFAC(BPX.SERVER)
  TSS PER(&ZOWEUSER.) IBMFAC(BPX.SERVER) ACC(UPDATE)

/** comment out to not use SUPERUSER.FILESYS, see JCL comments       */
/** permit Zowe main server to write persistent data                 */
  TSS ADD(&FACACID.) UNIXPRIV(SUPERUSE)
  TSS WHOHAS IBMFAC(SUPERUSER.FILESYS)
  TSS PER(&ZOWEUSER.) UNIXPRIV(SUPERUSER.FILESYS) ACCESS(CONTROL)

/* DEFINE ZOWE DATA SET PROTECTION ................................. */

/* - &HLQ..SZWEAUTH is an APF authorized data set. It is strongly    */
/*   advised to protect it against updates.                          */

/* HLQ stub                                                          */
  TSS ADD DEPT(&ADMINDEP.) DATASET(&HLQ.)

/* general data set protection                                       */
  TSS WHOHAS DATASET(&HLQ.)
  TSS PER(ALL) DATASET(&HLQ..) ACCESS(READ)
  TSS PER(&SYSPROG.) DATASET(&HLQ..) ACCESS(ALL)

/* show results                                                      */
  TSS WHOHAS DATASET(&HLQ.)

/* If any of these started tasks are multiusers address spaces       */
/* a TSS FACILITY needs to be defined and assigned to the started    */
/* and should not be using the STC FACILITY . The all acids signing  */
/* on to the started tasks will need to be authorized to the         */
/* FACILITY.                                                         */
/*                                                                   */
/* Create FACILITY example:                                          */
/* In the TSSPARMS add the following lines to create                 */
/* the new FACILITY.                                                 */
/*                                                                   */
/* FACILITY(USER11=NAME=ZOWE)                                        */
/* FACILITY(ZOWE=MODE=FAIL)                                          */
/* FACILITY(ZOWE=RES)                                                */
/*                                                                   */
/* To assign the FACILITY to the started task issue the following    */
/* command:                                                          */
/*                                                                   */
/* TSS ADD(started_task_acid) MASTFAC(ZOWE)                          */
/*                                                                   */
/* To authorize a user to signon to the FACILITY, issues the         */
/* following command.                                                */
/*                                                                   */
/* TSS ADD(user_acid) FAC(ZOWE)                                      */

/* ................................................................. */
/* only the last RC is returned, this comment ensures it is a 0      */
$$
//*
