#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

# Verify that an installed Zowe build is healthy after you install it on z/OS
# Note:  This script does not change anything on your system.

echo Script zowe-verify.sh started
echo

# This script is expected to be located in ${ZOWE_ROOT_DIR}/scripts,
# otherwise you must set ZOWE_ROOT_DIR to where the Zowe runtime is installed before you run this script
# e.g. export ZOWE_ROOT_DIR=/u/userid/zowe/1.0.0       

if [[ -n "${ZOWE_ROOT_DIR}" ]]
then 
    echo Info: ZOWE_ROOT_DIR environment variable is set to ${ZOWE_ROOT_DIR}
else 
    echo Info: ZOWE_ROOT_DIR environment variable is empty
    if [[ `basename $PWD` != scripts ]]
    then
        echo Warning: You are not in the ZOWE_ROOT_DIR/scripts directory
        echo Warning: '${ZOWE_ROOT_DIR} is not set'
        echo Warning: '${ZOWE_ROOT_DIR} must be set to where Zowe runtime is installed'
        echo Warning: script will run, but with errors
    else
        ZOWE_ROOT_DIR=`dirname $PWD`
        echo Info: ZOWE_ROOT_DIR environment variable is now set to ${ZOWE_ROOT_DIR}
    fi    
fi

# Check number of started tasks and ports (varies by Zowe release)

# Zowe version 1.2.0, using nodeCluster
# STC #  1 2 3 4 5 6 7 8 9          # Zowe job numbers 1-9
zowestc="1 0 3 1 2 2 2 2 4"         # how many Zowe jobs 

# jobname   ports assigned
# --------  --------------
# ZOWESVR3  api gateway port
# ZOWESVR3  jes explorer server
# ZOWESVR4  zss server port
# ZOWESVR5  mvs explorer server port
# ZOWESVR6  api discovery port
# ZOWESVR6  explorer jobs api server port
# ZOWESVR7  uss explorer server port
# ZOWESVR7  zlux server httpsPort
# ZOWESVR9  api catalog port
# ZOWESVR9  explorer datasets api server port

zowenports=10       # how many ports Zowe uses


echo
echo Check SAF security settings are correct

# 2.1 RACF 
tsocmd lg izuadmin 2>/dev/null |grep IZUSVR >/dev/null
if [[ $? -ne 0 ]]
then
  echo Error: userid IZUSVR is not in RACF group IZUADMIN
fi

echo Check IZUSVR has UPDATE access to BPX.SERVER and BPX.DAEMON
# For zssServer to be able to operate correctly 
profile_error=0
for profile in SERVER DAEMON
do
    tsocmd rl facility "*" 2>/dev/null | grep BPX\.$profile >/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: profile BPX\.$profile is not defined
        profile_error=1
    fi

    tsocmd rl facility bpx.$profile authuser 2>/dev/null |grep "IZUSVR *UPDATE" >/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: User IZUSVR does not have UPDATE access to profile BPX\.$profile
        profile_error=1
    fi
done
if [[ profile_error -eq 0 ]]
then
    echo OK
fi


# 2.1.1 RDEFINE STARTED ZOESVR.* UACC(NONE) 
#  STDATA(USER(IZUSVR) GROUP(IZUADMIN) PRIVILEGED(NO) TRUSTED(NO) TRACE(YES)) 

# Discover ZOWESVR name for this runtime
# Look in zowe-start.sh
serverName=`sed -n 's/.*opercmd.*S \([^ ]*\),SRVRPATH=.*/\1/p' zowe-start.sh 2> /dev/null`

if [[ $? -eq 0 && -n "$serverName" ]]
then 
    ZOWESVR=$serverName
    # echo Info: ZOWESVR name is ${ZOWESVR}
else 
    echo Error: Failed to find ZOWESVR name in zowe-start.sh, defaulting to ZOWESVR for this check 
    ZOWESVR=ZOWESVR
fi
echo
echo Check ${ZOWESVR} processes are runnning ${ZOWE_ROOT_DIR} code

# Look in processes that are runnning ${ZOWE_ROOT_DIR} code - there may be none
./internal/opercmd "d omvs,a=all" \
    | sed "{/ ${ZOWESVR}/N;s/\n */ /;}" \
    | grep -v CMD=grep \
    | grep ${ZOWESVR}.*LATCH.*${ZOWE_ROOT_DIR} \
    | awk '{ print $2 }'\
    | sed 's/[1-9]$//' | sort | uniq > /tmp/zowe.omvs.ps 
n=$((`cat /tmp/zowe.omvs.ps | wc -l`))
case $n in
    
    0) echo Warning: No ${ZOWESVR} jobs are running ${ZOWE_ROOT_DIR} code
    ;;
    1) # is it the right job?
    jobname=`cat /tmp/zowe.omvs.ps`
    if [[ $jobname != ${ZOWESVR} ]]
    then 
        echo Warning: Found PROC ${ZOWESVR} in zowe-start.sh, but ${ZOWE_ROOT_DIR} code is running in $jobname instead
        echo Info: Switching to job $jobname
        ZOWESVR=$jobname
    else
        echo OK: ${ZOWE_ROOT_DIR} code is running in $jobname
    fi 
    ;;
    *) echo Warning: $n different jobs are running ${ZOWE_ROOT_DIR} code
    echo List of jobs
    cat /tmp/zowe.omvs.ps
    echo End of list
esac 
rm /tmp/zowe.omvs.ps 2> /dev/null

echo
echo Check ${ZOWESVR} processes are runnning nodeCluster code

for cluster in nodeCluster zluxCluster
do
    count=$((`./internal/opercmd "d omvs,a=all" \
            | sed "{/ ${ZOWESVR}/N;s/\n */ /;}" \
            | grep -v CMD=grep \
            | grep ${ZOWESVR}.*LATCH.*${cluster} \
            | awk '{ print $2 }'\
            | wc -l`))
    if [[ $count -ne 0 ]]
    then
        echo $cluster OK
    else
        echo Error: $cluster is not running in ${ZOWESVR}
    fi
done

echo
echo Check ${ZOWESVR} is defined as STC to RACF and is assigned correct userid and group.

# similar function as in pre-install.sh ...
match_profile ()        # match a RACF profile entry to the ZOWESVR task name.
{
    set -f
  entry=$1                  # the RACF definition entry in the list

  if [[ $entry = '*' ]]     # RLIST syntax does not permit listing of just the '*' profile
  then
    return 1    # no strings matched
  fi  
  
  profileName=${ZOWESVR}  # the profile that we want to match in that list



  l=$((`echo $profileName | wc -c`))  # length of profile we're looking for, including null terminator e.g. "ZOWESVR"

    i=1
    while [[ $i -lt $l ]]
    do
        r=`echo $entry        | cut -c $i,$i` # ith char from RACF definition
        p=`echo $profileName  | cut -c $i,$i` # ith char from profile we're looking for

        if [[ $r = '*' ]]
        then
          return 0  # asterisk matches rest of string
        fi

        if [[ $r != $p ]]
        then
          break   # mismatch char for this profile, quit
        fi

        i=$((i+1))
    done

    if [[ $i -eq $l ]]
    then
      return 0  # whole string matched
    fi

  return 1    # no strings matched
}               #`` # needed for VS code

izusvr=0        # set success flag
izuadmin=0      # set success flag

# # find names of STARTED profiles
set -f

  tsocmd rl started \* 2>/dev/null |sed -n 's/STARTED *\([^ ]*\) .*/\1/p' > /tmp/find_profile.out
  while read entry 
  do
        match_profile ${entry}
        if [[ $? -eq 0 ]]
        then
                echo OK: Found matching STARTED profile entry $entry for task ${ZOWESVR}

                tsocmd rl started $entry stdata 2>/dev/null | grep "^USER= IZUSVR" > /dev/null    # is the profile user name IZUSVR?
                if [[ $? -ne 0 ]]
                then 
                    echo Error: profile $entry is not assigned to user IZUSVR
                else
                    echo OK: Profile $entry is assigned to user IZUSVR
                    izusvr=1        # set success flag
                fi

                tsocmd rl started $entry stdata 2>/dev/null | grep "^GROUP= IZUADMIN" > /dev/null # is the profile group name IZUADMIN?
                if [[ $? -ne 0 ]]
                then 
                    echo Warning: profile $entry is not assigned to group IZUADMIN
                    # This is not a barrier to correct execution, but if the group is not null, we think it must be IZUADMIN.
                else
                    echo OK: Profile $entry is assigned to group IZUADMIN
                    izuadmin=1        # set success flag
                fi
            
                break   # don't look for any more matches        
        fi
  done <    /tmp/find_profile.out
  rm        /tmp/find_profile.out

if [[ $izusvr -eq 0 || $izuadmin -eq 0 ]]
then    
    echo Warning: Started task $ZOWESVR not assigned to the correct RACF user or group
else
    echo OK: Started task $ZOWESVR is assigned to the correct RACF user and group
fi

set +f 


# 2.1.2  Activate the SDSF RACF class and add the following 3 profiles your system:
    # - GROUP.ISFSPROG
    # - GROUP.ISFSPROG.SDSF                 
    # - ISF.CONNECT.**
    # - ISF.CONNECT.sysname (e.g. TVT6019)
# 2.1.3 external scripts (amended)

# 2.2    ACF2
# 2.3    TOPSECRET


# Users must belong to a group that has READ access to these profiles.
# have the following ISF profile defined:
# class profile SDSF ISF.CONNECT.** (G)




# 4. Hostname is correct in 
# web directory:
#  in the index.html file in the web directory of atlasJES, atlasMVS and atlasUSS 
#  to point to the hostname of your machine
# plugin config:  
# Check hostname of the plugin configuration per "Giza zD&T boxnote.pdf"
# (File: /zaas1/giza/zluxexampleserver/
# deploy/instance/ZLUX/pluginStorage/com.rs.mvd.tn3270/sessions/_defaultTN3270.json)

# 6. localhost is defined for real, VM and zD&T systems:
# Add “127.0.0.1 localhost” to ADCD.Z23A.TCPPARMS(GBLIPNOD)

# 1.2.2.	function
#  

echo
echo Info: ZOWE job name is ${ZOWESVR}
echo Check ${ZOWESVR} job is started with user IZUSVR


function checkJob {
jobname=$1
tsocmd status ${jobname} 2> /dev/null | grep "JOB ${jobname}(S.*[0-9]*) EXECUTING" >/dev/null
if [[ $? -ne 0 ]]
then 
    echo Error: job ${jobname} is not executing
    return 1
else 
    echo OK: job ${jobname} is executing
    return 0
fi
}

checkJob ${ZOWESVR}

# 0.  Check user of ZOWESVR is IZUSVR

if [[ -n "${ZOWE_ROOT_DIR}" ]]
then 
    echo Info: ZOWE_ROOT_DIR is set to ${ZOWE_ROOT_DIR} 
else
    echo Error: ZOWE_ROOT_DIR is not set
    echo Info: Some parts of this script will not work as a result
fi 

${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d t" 1> /dev/null 2> /dev/null  # is 'opercmd' available and working?
if [[ $? -ne 0 ]]
then
  echo Error: Unable to run opercmd REXX exec from # >> $LOG_FILE
  ls -l ${ZOWE_ROOT_DIR}/scripts/internal/opercmd # try to list opercmd
  echo Error: No Zowe jobs will be checked
  echo Error: Correct this error and re-run this script
else
    echo OK: opercmd is available

    # Check STCs

    # There could be >1 STC named ZOWESVR

    echo
    echo Check all ZOWESVR jobs have userid IZUSVR

    # check status first ...

    checkJob ${ZOWESVR}
    if [[ $? -ne 0 ]]
    then    
        echo Error:  job ${ZOWESVR} is not executing, ${ZOWESVR} userid and STCs will not be checked
    else 
        # check userid is IZUSVR
        ${ZOWE_ROOT_DIR}/scripts/internal/opercmd d j,${ZOWESVR} | grep "USERID=IZUSVR" > /dev/null
        if [[ $? -ne 0 ]]
        then    
            echo Error:  USERID of ${ZOWESVR} is not IZUSVR

        else    # we found >0 zowe STCs, do any of them NOT have USERID=IZUSVR?
            ${ZOWE_ROOT_DIR}/scripts/internal/opercmd d j,${ZOWESVR} | grep "USERID=" | grep -v "USERID=IZUSVR" > /dev/null
            if [[ $? -eq 0 ]]
            then    
                echo Error:  Some USERID of ${ZOWESVR} is not IZUSVR
            else
                echo OK:  All USERIDs of ${ZOWESVR} are IZUSVR
            fi
        fi

        # number of ZOESVR started tasks expected to be active in a running system
        echo
        echo Check ${ZOWESVR} jobs in execution

        jobsOK=1
        # If jobname is > 7 chars, all tasks will have same jobname, no digit suffixes
        if [[ `echo ${ZOWESVR} | wc -c` -lt 9 ]]        # 9 includes the string-terminating null character
        then
            # echo job name ${ZOWESVR} is short enough to have numeric suffixes


            i=1                 # first STC number
            for enj in $zowestc   # list of expected number of jobs per STC
            do
                jobname=${ZOWESVR}$i

                ${ZOWE_ROOT_DIR}/scripts/internal/opercmd d j,${jobname}|grep " ${jobname} .* A=[0-9,A-F][0-9,A-F][0-9,A-F][0-9,A-F] " >/tmp/${jobname}.dj
                    # the selected lines will look like this ...
                                                            # ZOEJAD9  *OMVSEX  IZUSVR   IN   AO  A=00F0   PER=NO   SMC=000
                                                            # ZOEJAD9  STEP1    IZUSVR   OWT  AO  A=00F2   PER=NO   SMC=000
                                                            # ZOEJAD9  *OMVSEX  IZUSVR   OWT  AO  A=00F1   PER=NO   SMC=000

                nj=`cat /tmp/${jobname}.dj | wc -l`     # set nj to actual number of jobs found
                rm /tmp/${jobname}.dj >/dev/null

                # check we found the expected number of jobs
                if [[ $nj -ne $enj ]]
                then
                    echo Error: Expecting $enj jobs for $jobname, found $nj
                    jobsOK=0
                else
                    : # echo OK: Found $nj jobs for $jobname
                fi
                i=$((i+1))      # next STC number
            done
        else
            echo Info: ${ZOWESVR} jobs have no digit suffixes, all jobs have the same name
            jobname=${ZOWESVR}

            ${ZOWE_ROOT_DIR}/scripts/internal/opercmd d j,${jobname}|grep " ${jobname} .* A=[0-9,A-F][0-9,A-F][0-9,A-F][0-9,A-F] " >/tmp/${jobname}.dj
            
            # expected number of jobs is derived from the number of STCs per jobname.
            enj=1   # include the master STC in the count
            for i in $zowestc
            do
                enj=$((enj+i)) 
            done 

            nj=`cat /tmp/${jobname}.dj | wc -l`     # set nj to actual number of jobs found
            if [[ $nj -ne $enj ]]
            then
                echo Error: Expecting $enj jobs for $jobname, found $nj
                jobsOK=0
            else
                : # echo OK: Found $nj jobs for $jobname
            fi 
            rm /tmp/${jobname}.dj >/dev/null
            
        fi
        if [[ $jobsOK -eq 1 ]]
        then    
            echo OK
        fi
    fi

    echo 
    echo Check ZSS server is running

    zss_error_status=0  # no errors yet
    IZUSVR=IZUSVR   # remove this line when IZUSVR is an env variable

    # Is program ZWESIS01 running?
    ${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d omvs,a=all" | grep -v "grep CMD=ZWESIS01" | grep CMD=ZWESIS01  > /dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: Program ZWESIS01 is not running
        zss_error_status=1
        else
            # Is program ZWESIS01 running under user ${IZUSVR}?
            ${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d omvs,u=${IZUSVR}" | grep CMD=ZWESIS01 > /dev/null
            if [[ $? -ne 0 ]]
            then
                echo Error: Program ZWESIS01 is not running under user ${IZUSVR}
                zss_error_status=1
            fi
    fi

    # Try to determine ZSS server job name
    ZSSSVR=`${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d omvs,a=all" | sed "{/ /N;s/\n */ /;}"|grep -v "CMD=grep CMD=ZWESIS01" | grep CMD=ZWESIS01|awk '{ print $2 }'`
    if [[ -n "$ZSSSVR" ]] then
        echo ZSS server job name is $ZSSSVR
        ${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d j,${ZSSSVR}" | grep WUID=STC > /dev/null
        if [[ $? -ne 0 ]]
        then
            echo Error: Job "${ZSSSVR}" is not running as a started task
            zss_error_status=1
        fi
    else 
        echo Error:  Could not determine ZSSSVR job name
        zss_error_status=1
    fi

    # Is the status of the ZSS server OK?
    grep "ZIS status - Ok" `ls  -t ${ZOWE_ROOT_DIR}/zlux-app-server/log/zssServer-* | head -1` > /dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: The status of the ZSS server is not OK in ${ZOWE_ROOT_DIR}/zlux-app-server/log/zssServer log
        zss_error_status=1
        grep "ZIS status " `ls  -t ${ZOWE_ROOT_DIR}/zlux-app-server/log/zssServer-*` 
        if [[ $? -ne 0 ]]
        then
            echo Error: Could not determine the status of the ZSS server 
        fi
    fi

    if [[ $zss_error_status -eq 0 ]]
    then
        echo OK
    fi

fi


# 3. Ports are available

    # explorer-server:
    #   httpPort=7080
    #   httpsPort=7443
    # http and https ports for the node server
    #   zlux-server:
    #   httpsPort=8544
    #   zssPort=8542


# 0. check netstat portlist or other view of pre-allocated ports    


# 0. Extract port settings from Zowe config files.  

echo 
echo Check port settings from Zowe config files

# here are the defaults:
  api_mediation_catalog_http_port=7552      # api-mediation/scripts/api-mediation-start-catalog.sh
  api_mediation_discovery_http_port=7553    # api-mediation/scripts/api-mediation-start-discovery.sh
  api_mediation_gateway_https_port=7554     # api-mediation/scripts/api-mediation-start-gateway.sh

  explorer_server_jobsPort=8545             # explorer-jobs-api/scripts/jobs-api-server-start.sh
  explorer_server_dataSets_port=8547        # explorer-data-sets-api/scripts/data-sets-api-server-start.sh

  zlux_server_https_port=8544               # zlux-app-server/config/zluxserver.json
  zss_server_http_port=8542                 # zlux-app-server/config/zluxserver.json

  terminal_sshPort=22                       # vt-ng2/_defaultVT.json
  terminal_telnetPort=23                    # tn3270-ng2/_defaultTN3270.json

  jes_explorer_server_port=8546            # jes_explorer/server/configs/config.json
  mvs_explorer_server_port=8548            # mvs_explorer/server/configs/config.json
  uss_explorer_server_port=8550            # uss_explorer/server/configs/config.json




for file in \
 "api-mediation/scripts/api-mediation-start-catalog.sh" \
 "api-mediation/scripts/api-mediation-start-discovery.sh" \
 "api-mediation/scripts/api-mediation-start-gateway.sh" \
 "explorer-jobs-api/scripts/jobs-api-server-start.sh" \
 "explorer-data-sets-api/scripts/data-sets-api-server-start.sh" \
 "zlux-app-server/config/zluxserver.json" \
 "vt-ng2/_defaultVT.json" \
 "tn3270-ng2/_defaultTN3270.json" \
 "jes_explorer/server/configs/config.json" \
 "mvs_explorer/server/configs/config.json" \
 "uss_explorer/server/configs/config.json"
do
    case $file in
    ### WIP MARKER ###
        tn3270*) 
        # echo Checking tn3270
        # fragile search
        terminal_telnetPort=`sed -n 's/.*"port" *: *\([0-9]*\).*/\1/p' ${ZOWE_ROOT_DIR}/$file`
        if [[ -n "$terminal_telnetPort" ]]
        then 
            echo OK: terminal_telnetPort is $terminal_telnetPort
        else
            echo Error: terminal_telnetPort not found in ${ZOWE_ROOT_DIR}/$file
        fi 
        
        ;;

        vt*) 
        # echo Checking vt
        # fragile search
        terminal_sshPort=`sed -n 's/.*"port" *: *\([0-9]*\).*/\1/p' ${ZOWE_ROOT_DIR}/$file`
        if [[ -n "$terminal_sshPort" ]]
        then
            echo OK: terminal_sshPort is $terminal_sshPort
        else
            echo Error: terminal_sshPort not found in ${ZOWE_ROOT_DIR}/$file
        fi 
        
        ;;

        *\.sh) 
        # echo Checking .sh files  
        port=`sed -n 's/.*port=\([0-9]*\) .*/\1/p'  ${ZOWE_ROOT_DIR}/$file`
        case $file in 
            *catalog*)
                if [[ -n "$port" ]]
                then
                    api_mediation_catalog_http_port=$port
                    echo OK: api catalog port is $port
                else
                    echo Error: api catalog port not found in ${ZOWE_ROOT_DIR}/$file
                fi    
                ;;
            *discovery*)
                if [[ -n "$port" ]]
                then
                    echo OK: api discovery port is $port
                    api_mediation_discovery_http_port=$port
                else
                    echo Error: api discovery port not found in ${ZOWE_ROOT_DIR}/$file
                fi    
                
                ;;
            *gateway*)
                if [[ -n "$port" ]]
                then
                    echo OK: api gateway port is $port
                    api_mediation_gateway_https_port=$port
                else
                    echo Error: api gateway port not found in ${ZOWE_ROOT_DIR}/$file
                fi   

                ;;
            *jobs*)
                if [[ -n "$port" ]]
                then
                    echo OK: explorer jobs api server port is $port
                    explorer_server_jobsPort=$port
                else
                    echo Error: explorer jobs api server port not found in ${ZOWE_ROOT_DIR}/$file
                fi 

                ;;
            *data-sets*)
                if [[ -n "$port" ]]
                then
                    echo OK: explorer datasets api server port is $port
                    explorer_server_dataSets_port=$port
                else
                    echo Error: explorer datasets api server port not found in ${ZOWE_ROOT_DIR}/$file
                fi 
  

        esac
        
        ;;

        *\.xml) 
        # echo Checking .xml files
        
        explorer_server_http_port=`iconv -f IBM-850 -t IBM-1047 ${ZOWE_ROOT_DIR}/$file | sed -n 's/.*httpPort="\([0-9]*\)" .*/\1/p'`
        if [[ -n "$explorer_server_http_port" ]]
        then
            echo OK: explorer server httpPort is $explorer_server_http_port
        else
            echo Error: explorer server httpPort not found in ${ZOWE_ROOT_DIR}/$file
        fi 
        
        explorer_server_https_port=`iconv -f IBM-850 -t IBM-1047 ${ZOWE_ROOT_DIR}/$file | sed -n 's/.*httpsPort="\([0-9]*\)" .*/\1/p'`
        if [[ -n "$explorer_server_https_port" ]]
        then
            echo OK: explorer server httpsPort is $explorer_server_https_port
        else
            echo Error: explorer server httpsPort not found in ${ZOWE_ROOT_DIR}/$file
        fi 
        
        ;;

        *\.json) 
        # echo Checking .json files 
        case $file in
        zlux*)
            # fragile search
            zlux_server_https_port=`sed -n 's/.*"port" *: *\([0-9]*\) *,.*/\1/p; /}/q' ${ZOWE_ROOT_DIR}/$file`
            if [[ -n "$zlux_server_https_port" ]]
            then
                echo OK: zlux server httpsPort is $zlux_server_https_port
            else
                echo Error: zlux server httpsPort not found in ${ZOWE_ROOT_DIR}/$file
            fi         
            
            agent_http_port=`sed -n 's/.*"port": \([0-9]*\)$/\1/p' ${ZOWE_ROOT_DIR}/$file`
            if [[ -n "$agent_http_port" ]]
            then
                echo OK: zss server port is $agent_http_port
            else
                echo Error: agent http port not found in ${ZOWE_ROOT_DIR}/$file
            fi 

            zss_server_http_port=`sed -n 's/.*"zssPort" *: *\([0-9]*\) *$/\1/p'   ${ZOWE_ROOT_DIR}/$file`
            if [[ -n "$zss_server_http_port" ]]
            then
                echo OK: zss server port is $zss_server_http_port
            else
                echo Error: zss server port not found in ${ZOWE_ROOT_DIR}/$file
            fi         
            echo 

            ;;

        jes_explorer*)
            # fragile search
            jes_explorer_server_port=`sed -n 's/.*"port" *: *\([0-9]*\) *,.*/\1/p;' ${ZOWE_ROOT_DIR}/$file`
            if [[ -n "$jes_explorer_server_port" ]]
            then
                echo OK: jes explorer server port is $jes_explorer_server_port
            else
                echo Error: jes explorer server port not found in ${ZOWE_ROOT_DIR}/$file
            fi       

            ;;

        mvs_explorer*)
            # fragile search
            mvs_explorer_server_port=`sed -n 's/.*"port" *: *\([0-9]*\) *,.*/\1/p;' ${ZOWE_ROOT_DIR}/$file`
            if [[ -n "$mvs_explorer_server_port" ]]
            then
                echo OK: mvs explorer server port is $mvs_explorer_server_port
            else
                echo Error: mvs explorer server port not found in ${ZOWE_ROOT_DIR}/$file
            fi    
            ;;

        uss_explorer*)
            # fragile search
            uss_explorer_server_port=`sed -n 's/.*"port" *: *\([0-9]*\) *,.*/\1/p;' ${ZOWE_ROOT_DIR}/$file`
            if [[ -n "$uss_explorer_server_port" ]]
            then
                echo OK: uss explorer server port is $uss_explorer_server_port
            else
                echo Error: uss explorer server port not found in ${ZOWE_ROOT_DIR}/$file
            fi    
            ;;

        esac

        ;;

        *) 
        echo Error:  Unexpected file $file
        
    esac
    echo
done

# check MVD web index files
echo
echo Check explorer server https port in the 3 explorer web/index.html files 

# sed -n 's+.*https:\/\/.*:\([0-9]*\)/explorer-..s.*+\1+p' `ls ${ZOWE_ROOT_DIR}/explorer-??S/web/index.html`    

for file in  `ls ${ZOWE_ROOT_DIR}/??s_explorer/web/index.html`
do
    port=`sed -n 's+.*https:\/\/.*:\([0-9]*\)/.*+\1+p' $file`  


    if [[ -n "$port" ]]  
    then
        if [[ $port -ne $api_mediation_gateway_https_port ]]
        then 
            echo Error: Found $port expecting $api_mediation_gateway_https_port
            echo in file $file
        else 
            echo OK: Port $port
        fi
    else
        echo Error: Could not determine port in file $file
    fi

    #
    #   0.  TBD: also check hostname or IP is right for this machine
    #
done                                       

echo
echo Check Ports are assigned to jobs

# zowenports
totPortsAssigned=0
# Is job name too long to have a suffix?
if [[ `echo ${ZOWESVR} | wc -c` -lt 9 ]]        # 9 includes the string-terminating null character
then    # job name is short enough to have a suffix
    i=1
    for enj in $zowestc   # list of expected number of jobs per STC
    do
            if [[ $enj -ne 0 ]]
            then
                jobname=${ZOWESVR}$i
                # echo $jobname active jobs
                # ${ZOWE_ROOT_DIR}/scripts/internal/opercmd d j,${jobname}|grep " ${jobname} .* A=[0-9,A-F][0-9,A-F][0-9,A-F][0-9,A-F] "
                echo Info: Ports in use by $jobname jobs
                netstat -b -E $jobname 2>/dev/null|grep Listen | awk '{ print $4 }' > /tmp/${jobname}.ports
                cat /tmp/${jobname}.ports

                # check correct ports are assigned to each job

                case $i in 
                3)
# ZOWESVR3  api gateway port
# ZOWESVR3  jes explorer server
                # job3
                    for port in \
                        $api_mediation_gateway_https_port \
                        $jes_explorer_server_port
                    do
                        grep $port /tmp/${jobname}.ports > /dev/null
                        if [[ $? -ne 0 ]]
                        then
                            echo Error: Port $port not assigned to $jobname
                        fi
                    done
                ;;

                4)
# ZOWESVR4  zss server port
                    for port in \
                        $zss_server_http_port
                    do
                        grep $port /tmp/${jobname}.ports > /dev/null
                        if [[ $? -ne 0 ]]
                        then
                            echo Error: Port $port not assigned to $jobname
                        fi
                    done
                ;;                

                5)
# ZOWESVR5  mvs explorer server port              
                    for port in \
                        $mvs_explorer_server_port
                    do
                        grep $port /tmp/${jobname}.ports > /dev/null
                        if [[ $? -ne 0 ]]
                        then
                            echo Error: Port $port not assigned to $jobname
                        fi
                    done
                ;;

                6)
# ZOWESVR6  api discovery port
# ZOWESVR6  explorer jobs api server port                
                # job6
                    for port in \
                        $explorer_server_jobsPort \
                        $api_mediation_discovery_http_port 
                    do
                        grep $port /tmp/${jobname}.ports > /dev/null
                        if [[ $? -ne 0 ]]
                        then
                            echo Error: Port $port not assigned to $jobname
                        fi
                    done
                ;;

                7)
# ZOWESVR7  uss explorer server port
# ZOWESVR7  zlux server httpsPort                
                    for port in \
                        $zlux_server_https_port \
                        $uss_explorer_server_port 
                    do
                        grep $port /tmp/${jobname}.ports > /dev/null
                        if [[ $? -ne 0 ]]
                        then
                            echo Error: Port $port not assigned to $jobname
                        fi
                    done


                ;;

                9)
# ZOWESVR9  api catalog port
# ZOWESVR9  explorer datasets api server port  
                # job9
                    for port in \
                        $api_mediation_catalog_http_port \
                        $explorer_server_dataSets_port
                    do
                        grep $port /tmp/${jobname}.ports > /dev/null
                        if [[ $? -ne 0 ]]
                        then
                            echo Error: Port $port not assigned to $jobname
                        fi
                    done
                ;;
                esac

                totPortsAssigned=$((totPortsAssigned+`cat /tmp/${jobname}.ports | wc -l `))
                rm /tmp/${jobname}.ports
                echo
            fi
            i=$((i+1))      # next STC number
    done
else        # job name is too long to have a suffix
            jobname=${ZOWESVR}
            echo Info: Ports in use by $jobname jobs
            netstat -b -E $jobname 2>/dev/null|grep Listen | awk '{ print $4 }' > /tmp/${jobname}.ports
            # cat /tmp/${jobname}.ports
            
            # check they are the right ports
            for port_number in \
                $api_mediation_catalog_http_port \
                $api_mediation_discovery_http_port \
                $api_mediation_gateway_https_port \
                $explorer_server_jobsPort \
                $explorer_server_dataSets_port \
                $zlux_server_https_port \
                $zss_server_http_port \
                $jes_explorer_server_port \
                $mvs_explorer_server_port \
                $uss_explorer_server_port 
            do 
                grep $port_number /tmp/${jobname}.ports > /tmp/$port_number.port
                port_count=`cat /tmp/$port_number.port | wc -l `
                if [[ $port_count -eq 1 ]]
                then 
                    if [[ `cat /tmp/$port_number.port` -eq $port_number ]]
                    then
                        echo $port_number
                    else
                        # this is very unlikely
                        echo Error: Port `cat /tmp/$port_number.port` does not match $port_number
                    fi
                else 
                    echo Error: Found $port_count ports assigned for port $port_number
                fi 
            done 

            totPortsAssigned=`cat /tmp/${jobname}.ports | wc -l `
            rm /tmp/${jobname}.ports 2> /dev/null
            rm /tmp/$port_number.port 2> /dev/null
            echo
fi
if [[ $totPortsAssigned -ne $zowenports ]]  
then
    echo Error: Found $totPortsAssigned ports assigned, expecting $zowenports
fi

echo
echo Check Node is at right version

# evaluate NODE_HOME from potential sources ...

# 1. run-zowe.sh?
# Zowe uses the version of Node.js located in NODE_HOME as set in run-zowe.sh
if [[ ! -n "$nodehome" ]]
then 
    ls $ZOWE_ROOT_DIR/scripts/internal/run-zowe.sh 1> /dev/null
    if [[ $? -ne 0 ]]
    then 
        echo Error: run-zowe.sh not found
    else
        grep " *export *NODE_HOME=.* *$" $ZOWE_ROOT_DIR/scripts/internal/run-zowe.sh 1> /dev/null
        if [[ $? -ne 0 ]]
        then 
            echo Error: \"export NODE_HOME\" not found in run-zowe.sh
        else
            node_set=`sed -n 's/ *export *NODE_HOME=\(.*\) *$/\1/p' $ZOWE_ROOT_DIR/scripts/internal/run-zowe.sh`
            if [[ ! -n "$node_set" ]]
            then
                echo Error: NODE_HOME is empty in run-zowe.sh
            else
                nodehome=$node_set
                echo Info: Found in run-zowe.sh 
            fi 
        fi
    fi    
fi 

# 2. install log?
if [[ ! -n "$nodehome" ]]
then 
    ls $ZOWE_ROOT_DIR/install_log/*.log 1> /dev/null
    if [[ $? -eq 0 ]]
    then
        # install log exists
        install_log=`ls -t $ZOWE_ROOT_DIR/install_log/*.log | head -1`
        node_set=`sed -n 's/NODE_HOME environment variable was set=\(.*\) *$/\1/p' $install_log`
        if [[ -n "node_set" ]]
        then 
            nodehome=$node_set
            echo Info: Found in install_log
        else 
            echo Error: NODE_HOME environment variable was not set in $install_log
        fi 
    else 
        echo Error: no install_log found in $ZOWE_ROOT_DIR/install_log
    fi
fi


# 3. /etc/profile?
if [[ ! -n "$nodehome" ]]
then 
    ls /etc/profile 1> /dev/null
    if [[ $? -ne 0 ]]
    then 
        echo Info: /etc/profile not found
    else
        grep " *export *NODE_HOME=.* *$" /etc/profile 1> /dev/null
        if [[ $? -ne 0 ]]
        then 
            echo Info: \"export NODE_HOME\" not found in /etc/profile
        else
            node_set=`sed -n 's/ *export *NODE_HOME=\(.*\) *$/\1/p' /etc/profile`
            if [[ ! -n "$node_set" ]]
            then
                echo Warning: NODE_HOME is empty in /etc/profile
            else
                nodehome=$node_set
                echo Info: Found in /etc/profile
            fi 
        fi
    fi    
fi 

# 4. zowe_profile?

if [[ ! -n "$nodehome" ]]
then 
    ls ~/.zowe_profile 1> /dev/null
    if [[ $? -ne 0 ]]
    then 
        echo Info: ~/.zowe_profile not found
    else
        grep " *export *NODE_HOME=.* *$" ~/.zowe_profile 1> /dev/null
        if [[ $? -ne 0 ]]
        then 
            echo Info: \"export NODE_HOME\" not found in ~/.zowe_profile
        else
            node_set=`sed -n 's/ *export *NODE_HOME=\(.*\) *$/\1/p' ~/.zowe_profile`
            if [[ ! -n "$node_set" ]]
            then
                echo Warning: NODE_HOME is empty
            else
                nodehome=$node_set
                echo Info: Found in ~/.zowe_profile
            fi 
        fi
    fi    
fi 

#
# finished searching, check resultant $nodehome
#

if [[ ! -n "$nodehome" ]]
then 
    echo Error: Could not determine value of NODE_HOME
    echo Warning:  node version cannot be determined
else
    node_version=`$nodehome/bin/node --version` # also works if it's a symlink
    if [[ $? -ne 0 ]]
    then 
        echo Error: Failed to obtain version of $nodehome/bin/node
    else 
        if [[ $node_version < v6.14.4 ]]
        then
            echo Error: version $node_version is lower than required 
        else 
            echo OK: version is $node_version 
        fi
    fi 
fi


echo
echo Check version of z/OS

release=`${ZOWE_ROOT_DIR}/scripts/internal/opercmd 'd iplinfo'|grep RELEASE`
# the selected line will look like this ...
# RELEASE z/OS 02.03.00    LICENSE = z/OS

vrm=`echo $release | sed 's+.*RELEASE z/OS \(........\).*+\1+'`
echo Info: release of z/OS is $release
if [[ $vrm < "02.02.00" ]]
    then echo Error: version $vrm not supported
    else echo OK: version $vrm is supported
fi

# 4. z/OSMF is up 

# echo
# echo Check Zowe environment variables are set correctly.

# # • ZOWE_ZOSMF_PATH: The path where z/OSMF is installed. Defaults to /usr/lpp/zosmf/lib/
# # defaults/servers/zosmfServer
# if [[ -n "${ZOWE_ZOSMF_PATH}" ]]
# then 
#     echo OK: ZOWE_ZOSMF_PATH is not empty 
#     ls ${ZOWE_ZOSMF_PATH}/server.xml > /dev/null    # pick a file to check
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: ZOWE_ZOSMF_PATH does not point to a valid install of z/OSMF
#     fi
# else 
#     echo Error: ZOWE_ZOSMF_PATH is empty
# fi

# # • ZOWE_JAVA_HOME: The path where 64 bit Java 8 or later is installed. Defaults to /usr/lpp/java/
# # J8.0_64
# if [[ -n "${ZOWE_JAVA_HOME}" ]]
# then 
#     echo OK: ZOWE_JAVA_HOME is not empty 
#     ls ${ZOWE_JAVA_HOME}/bin | grep java$ > /dev/null    # pick a file to check
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: ZOWE_JAVA_HOME does not point to a valid install of Java
#     fi
# else 
#     echo Error: ZOWE_JAVA_HOME is empty
# fi


# # • ZOWE_EXPLORER_HOST: The IP address of where the explorer servers are launched from. Defaults to
# # running hostname
# if [[ -n "${ZOWE_EXPLORER_HOST}" ]]
# then 
#     echo OK: ZOWE_EXPLORER_HOST is not empty 
#     ping ${ZOWE_EXPLORER_HOST} > /dev/null    # check host
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: ZOWE_EXPLORER_HOST does not point to a valid hostname
#     fi
# else 
#     echo Error: ZOWE_EXPLORER_HOST is empty
# fi

# # ZOE_SDSF_PATH="/usr/lpp/sdsf/java"
# if [[ -n "${ZOE_SDSF_PATH}" ]]
# then 
#     echo OK: ZOE_SDSF_PATH is not empty 
#     ls ${ZOE_SDSF_PATH}/classes | grep 'isfjcall\.jar'  > /dev/null    # check one .jar file
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: ZOE_SDSF_PATH does not point to a valid SDSF path
#     fi
# else 
#     echo Error: ZOE_SDSF_PATH is empty
# fi



# # ZOWE_IPADDRESS="9.20.5.48"
# if [[ -n "${ZOWE_IPADDRESS}" ]]
# then 
#     echo OK: ZOWE_IPADDRESS is not empty 
#     echo ${ZOWE_IPADDRESS} | grep '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*'  > /dev/null    # check one .jar file
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: ZOWE_IPADDRESS does not point to a numeric IP address
#     fi
        
#     ping ${ZOWE_IPADDRESS} > /dev/null    # check host
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: can not ping ZOWE_IPADDRESS ${ZOWE_IPADDRESS}
#     else
#         echo OK: can ping ZOWE_IPADDRESS ${ZOWE_IPADDRESS}
#     fi
# else 
#     echo Error: ZOWE_IPADDRESS is empty
# fi

# # • localhost: The IP address of this host
# # 
#     ping localhost > /dev/null    # check host
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: can not ping localhost
#     else
#         echo OK: can ping localhost
#     fi


# 0. IZUFPROC
echo
echo Check IZUFPROC

fPROC=1
# The PROC that z/OSMF uses to run your request
# It requires access to a link lib, and this is usually provided via a DD statement
#
# //ISPLLIB  DD DISP=SHR,DSN=SYS1.SIEALNKE <----extra dataset
#
# tsocmd listc "ent('SYS1.SIEALNKE')" 2>/dev/null| sed -n 's/^N.*- \(.*\)/\1/p'
tsocmd listd "('sys1.SIEALNKE')" 2> /dev/null 1> /dev/null
if [[ $? -eq 0 ]]
then
    : # echo OK: Dataset SYS1.SIEALNKE exists
else
    echo Warning: SYS1.SIEALNKE not found
    echo Another *.SIEALNKE dataset must be allocated in IZUFPROC, or link-listed
    fPROC=0
fi

# find IZUFPROC in PROCLIB concatenation
# ${ZOWE_ROOT_DIR}/scripts/internal/opercmd '$d proclib'

IZUFPROC_found=0        # set initial condition

# fetch a list of PROCLIBs
${ZOWE_ROOT_DIR}/scripts/internal/opercmd '$d proclib'| sed -n 's/.*DSNAME=\(.*[A-Z0-9]\).*/\1/p' > /tmp/proclib.list
while read dsn 
do
    tsocmd listd "('$dsn')" mem 2> /dev/null | grep IZUFPROC 1> /dev/null 2> /dev/null
    if [[ $? -ne 0 ]]
    then
        : # echo IZUFPROC not found in $dsn
    else
        : # echo OK: IZUFPROC found in $dsn
        IZUFPROC_found=1
        break
    fi
done <      /tmp/proclib.list
rm          /tmp/proclib.list

if [[ IZUFPROC_found -eq 0 ]]
then
    echo Error: PROC IZUFPROC not found in any active PROCLIB
    fPROC=0
else
    : # echo Check contents of IZUFPROC
    tsocmd "oput '$dsn(izufproc)' '/tmp/izufproc.txt'" 1> /dev/null 2> /dev/null
    SIEALNKE_DSN=`sed -n 's/.*DS.*=\(.*SIEALNKE\).*/\1/p' /tmp/izufproc.txt`    # check for DSN (but not ISPLLIB DD)

    if [[ $? -ne 0 ]]
    then
        echo Error: SIEALNKE not found in $dsn"(IZUFPROC)"
        fPROC=0
    else
        : # echo OK: Reference to SIEALNKE dataset $SIEALNKE_DSN found in $dsn"(IZUFPROC)"
        tsocmd listd "('$SIEALNKE_DSN')" 1> /dev/null 2> /dev/null
        if [[ $? -ne 0 ]]
        then
            echo Error: $SIEALNKE_DSN not found
            fPROC=0
        fi

        : # echo check that ISPLLIB is present # ... 
        grep "\/\/ISPLLIB *DD *" /tmp/izufproc.txt > /dev/null
        if [[ $? -ne 0 ]]
        then
            echo Error : No ISPLLIB DD statement found in IZUFPROC
            fPROC=0
        else
            : # echo OK: ISPLLIB DD statement found in IZUFPROC
            grep "\/\/ISPLLIB *DD *.*DS.*=.*SIEALNKE" /tmp/izufproc.txt > /dev/null
            if [[ $? -eq 0 ]]
            then
                : # echo OK: SIEALNKE dataset is allocated to ISPLLIB
            fi
        fi


    fi
fi
rm /tmp/izufproc.txt 2> /dev/null

if [[ $fPROC -eq 1 ]]
then    
    echo OK
fi

# 5. z/OSMF
echo
echo Check zosmfServer is ready to run a smarter planet
#  is zosmfServer ready to run a smarter planet?
zosmfMsgLog=/var/zosmf/data/logs/zosmfServer/logs/messages.log
ls $zosmfMsgLog 1> /dev/null 
if [[ $? -eq 0 ]]
then    
    # log file could be large ... msg is normally at record number 79.  Allow for 200.
    head -200 $zosmfMsgLog | iconv -f IBM-850 -t IBM-1047 | grep "zosmfServer is ready to run a smarter planet" > /dev/null
    if [[ $? -ne 0 ]]
    then    
        echo Error: zosmfServer is not ready to run a smarter planet # > /dev/null
    else
        echo OK
    fi
fi

echo 

# 6. Other required jobs
echo
echo Check servers are up


 echo
  echo Check jobs AXR CEA ICSF CSF  # jobs with no JCT
  jobsOK=1

  ICSF=0        #   neither ICSF nor CSF is running?
  for jobname in AXR CEA ICSF CSF
  do
    ${ZOWE_ROOT_DIR}/scripts/internal/opercmd d j,${jobname}|grep " ${jobname} .* A=[0-9,A-F][0-9,A-F][0-9,A-F][0-9,A-F] " >/dev/null
      # the selected line will look like this ...
      #  AXR      AXR      IEFPROC  NSW  *   A=001B   PER=NO   SMC=000
      
    if [[ $? -eq 0 ]]
    then 
        : # echo Job ${jobname} is executing
        if [[ ${jobname} = ICSF || ${jobname} = CSF ]]
        then
            ICSF=1
        fi
    else 
        if [[ ${jobname} = ICSF || ${jobname} = CSF ]]
        then
            :
        else 
            echo Error: Job ${jobname} is not executing
            jobsOK=0
        fi
        
    fi
  done

    if [[ ${ICSF} -eq 1 ]]
    then
    : # echo OK:  ICSF or CSF is running
    else
        echo Error:  neither ICSF nor CSF is running
        jobsOK=0
    fi

# 4.2 Jobs with JCT

for jobname in IZUANG1 IZUSVR1 # RACF
do
  tsocmd status ${jobname} 2>/dev/null | grep "JOB ${jobname}(S.*[0-9]*) EXECUTING" >/dev/null
  if [[ $? -eq 0 ]]
  then 
      : # echo Job ${jobname} is executing
  else 
      echo Error: Job ${jobname} is not executing
      jobsOK=0
  fi
done

if [[ $jobsOK -eq 1 ]]      
then 
    echo OK
fi

echo
echo Check relevant -s extattr bits 
ls -RE ${ZOWE_ROOT_DIR} |grep " [-a][-p]s[^ ] " > /tmp/extattr.s.list
bitsOK=1

for file in \
    zssServer 
do
    grep " ${file}$" /tmp/extattr.s.list 1>/dev/null 2>/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: File $file does not have the -s extattr bit set
        bitsOK=0
    else
        : # echo File $file is OK
    fi
done
if [[ $bitsOK -eq 1 ]]
then
    echo OK
fi

echo
echo Check relevant -p extattr bits 
ls -RE ${ZOWE_ROOT_DIR} |grep " [-a]p[-s][^ ] " > /tmp/extattr.p.list
bitsOK=1
for file in \
    zssServer 
do
    grep " ${file}$" /tmp/extattr.p.list 1>/dev/null 2>/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: File $file does not have the -p extattr bit set
        bitsOK=0
    else
        : # echo File $file is OK
    fi
done
if [[ $bitsOK -eq 1 ]]
then
    echo OK
fi

rm /tmp/extattr.*.list

echo
echo Check files are executable 
filesxeq=1
find ${ZOWE_ROOT_DIR} -name bin -exec ls -l {} \; | grep ^- | grep -v \.bat$ | grep -v "^-r.xr.xr.x " 2> /dev/null
if [[ $? -ne 0 ]]
then    
    : # echo OK: 
else 
    echo Error: the bin files above in ${ZOWE_ROOT_DIR} are not readable and executable 
    filesxeq=0
fi 

# check permission of parent directories.  Iterate back up to root directory, checking each is executable.
savedir=$PWD    # save CWD

cd ${ZOWE_ROOT_DIR}
while [[ 1 ]]
do
    ls -l ${PWD} | grep "^dr.x..x..x " 1> /dev/null 2> /dev/null
    if [[ $? -eq 0 ]]
    then    
        : # echo OK: ${PWD} is executable
    else 
        echo Error: ${PWD} is not executable
    fi 
    if  [[ $PWD = "/" ]]
    then
        break
    fi
    cd ..
done

if [[ $filesxeq -eq 1 ]]
then 
    echo OK
fi

cd $savedir # restore CWD

echo
echo Script zowe-verify.sh finished
