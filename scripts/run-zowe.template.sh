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

#
# Your JCL must invoke it like this:
#
# //        EXEC PGM=BPXBATSL,REGION=0M,TIME=NOLIMIT,
# //  PARM='PGM /bin/sh &SRVRPATH/scripts/internal/run-zowe.sh'
#
#

# New Cupids work - once we have PARMLIB/properties files removed properly this won't be needed anymore
ROOT_DIR={{root_dir}} # the install directory of zowe
USER_DIR={{user_dir}} # the workspace location for this instance. TODO Should we add this as a new to the yaml, or default it?
FILES_API_PORT={{files_api_port}} # the port the files api service will use
JOBS_API_PORT={{jobs_api_port}} # the port the files api service will use
STC_NAME={{stc_name}}

# details to be read from higher level entry that instance PARMLIB/prop file?
KEY_ALIAS={{key_alias}}
KEYSTORE={{keystore}}
KEYSTORE_PASSWORD={{keystore_password}}
STATIC_DEF_CONFIG_DIR={{static_def_config_dir}}
ZOSMF_PORT={{zosmf_port}}
ZOSMF_IP_ADDRESS={{zosmf_ip_address}}
ZOWE_EXPLORER_HOST={{zowe_explorer_host}}
ZOWE_JAVA_HOME={{java_home}}

LAUNCH_COMPONENTS=files-api,jobs-api #TODO this is WIP - component ids not finalised at the moment

export ZOWE_PREFIX={{zowe_prefix}}
ZOWE_API_GW=${ZOWE_PREFIX}AGW1
ZOWE_API_DS=${ZOWE_PREFIX}ADS1
ZOWE_API_CT=${ZOWE_PREFIX}AAC1
ZOWE_DESKTOP=${ZOWE_PREFIX}D1
ZOWE_EXPL_UI_JES=${ZOWE_PREFIX}EUJ1
ZOWE_EXPL_UI_MVS=${ZOWE_PREFIX}EUD1
ZOWE_EXPL_UI_USS=${ZOWE_PREFIX}EUU1

if [[ ! -f $NODE_HOME/"./bin/node" ]]
then
export NODE_HOME={{node_home}}
fi

DIR=`dirname $0`

cd $DIR/../../zlux-app-server/bin && _BPX_JOBNAME=$ZOWE_DESKTOP ./nodeCluster.sh --allowInvalidTLSProxy=true &
_BPX_JOBNAME=$ZOWE_API_DS $DIR/../../api-mediation/scripts/api-mediation-start-discovery.sh
_BPX_JOBNAME=$ZOWE_API_CT $DIR/../../api-mediation/scripts/api-mediation-start-catalog.sh
_BPX_JOBNAME=$ZOWE_API_GW $DIR/../../api-mediation/scripts/api-mediation-start-gateway.sh
_BPX_JOBNAME=$ZOWE_EXPL_UI_JES $DIR/../../jes_explorer/scripts/start-explorer-jes-ui-server.sh
_BPX_JOBNAME=$ZOWE_EXPL_UI_MVS $DIR/../../mvs_explorer/scripts/start-explorer-mvs-ui-server.sh
_BPX_JOBNAME=$ZOWE_EXPL_UI_USS $DIR/../../uss_explorer/scripts/start-explorer-uss-ui-server.sh
 
# Validate component properties if script exists
for i in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  VALIDATE_SCRIPT=${ROOT_DIR}/components/${i}/bin/validate.sh
  if [[ -f ${VALIDATE_SCRIPT} ]]
  then
    . ${VALIDATE_SCRIPT}
  fi
done

mkdir -p ${USER_DIR}

#Backup previous directory if it exists
if [[ -f ${USER_DIR}"/active_configuration.cfg" ]]
then
PREVIOUS_DATE=$(cat ${USER_DIR}/active_configuration.cfg | grep CREATION_DATE | cut -d'=' -f2)
mv ${USER_DIR}/active_configuration.cfg ${USER_DIR}/backup_configuration.${PREVIOUS_DATE}.cfg
# Backup previous
fi

NOW=$(date +"%y.%m.%d.%H.%M.%S")
#TODO - inject VERSION variable at build time?
# Create a new active_configuration.cfg properties file with all the parsed parmlib properties stored in it,
cat <<EOF >${USER_DIR}/active_configuration.cfg
VERSION=1.4
CREATION_DATE=${NOW}
ROOT_DIR=${ROOT_DIR}
USER_DIR=${USER_DIR}
FILES_API_PORT=${FILES_API_PORT}
JOBS_API_PORT=${JOBS_API_PORT}
STC_NAME=${STC_NAME}
KEY_ALIAS=${KEY_ALIAS}
KEYSTORE=${KEYSTORE}
KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD}
STATIC_DEF_CONFIG_DIR=${STATIC_DEF_CONFIG_DIR}
ZOSMF_PORT=${ZOSMF_PORT}
ZOSMF_IP_ADDRESS=${ZOSMF_IP_ADDRESS}
ZOWE_JAVA_HOME=${JAVA_HOME}
STARTED_COMPONENTS=f${STARTED_COMPONENTS}
EOF

# Copy manifest into user_dir so we know the version for support enquiries/migration
cp ${ROOT_DIR}/manifest.json ${USER_DIR}

# Run setup/configure on components if script exists
for i in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  CONFIGURE_SCRIPT=${ROOT_DIR}/components/${i}/bin/configure.sh
  if [[ -f ${CONFIGURE_SCRIPT} ]]
  then
    . ${CONFIGURE_SCRIPT}
  fi
done

for i in $(echo $LAUNCH_COMPONENTS | sed "s/,/ /g")
do
  . ${ROOT_DIR}/components/${i}/bin/start.sh
done
