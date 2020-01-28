#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019
################################################################################

while getopts "c:y" opt; do
  case $opt in
    c) INSTANCE_DIR=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

# TODO LATER - once not called from zowe-configure.sh remove if and keep the export
if [[ -z ${ZOWE_ROOT_DIR} ]]
then
	export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi

# Ensure that newly created files are in EBCDIC codepage
export _CEE_RUNOPTS=""
export _TAG_REDIR_IN=""
export _TAG_REDIR_OUT=""
export _TAG_REDIR_ERR=""
export _BPXK_AUTOCVT="OFF"

if [[ -z ${INSTANCE_DIR} ]]
then
  echo "-c parameter not set. Please re-run 'zowe-configure-instance.sh -c <Instance directory>' specifying the location of the new zowe instance directory you want to create"
  exit 1
fi

echo_and_log() {
  echo "$1"
  echo "$1" >> ${LOG_FILE}
}

create_new_instance() {
  sed \
    -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
    -e "s#{{java_home}}#${JAVA_HOME}#" \
    -e "s#{{node_home}}#${NODE_HOME}#" \
    -e "s#{{zosmf_port}}#${ZOWE_ZOSMF_PORT}#" \
    -e "s#{{zosmf_host}}#${ZOWE_ZOSMF_HOST}#" \
    -e "s#{{zowe_explorer_host}}#${ZOWE_EXPLORER_HOST}#" \
    -e "s#{{zowe_ip_address}}#${ZOWE_IP_ADDRESS}#" \
    "${TEMPLATE}" \
    > "${INSTANCE}"

  chmod -R 750 "${INSTANCE}"
  echo "Created ${INSTANCE} with injected content">> $LOG_FILE
}

check_existing_instance_for_updates() {
  echo_and_log "Checking existing ${INSTANCE} for updated properties"

  while read -r line
  do
    test -z "${line%%#*}" && continue      # skip line if first char is #
    key=${line%%=*}
    PROP_VALUE=`cat $INSTANCE | grep ^$key=`
    if [[ -z $PROP_VALUE ]]
    then
      LINES_TO_APPEND=${LINES_TO_APPEND}"${line}\n"
    fi
  done < ${TEMPLATE}

  if [[ -n $LINES_TO_APPEND ]]
  then
    LINES_TO_APPEND=$(echo "$LINES_TO_APPEND" | sed \
      -e "s#{{java_home}}#${JAVA_HOME}#" \
      -e "s#{{node_home}}#${NODE_HOME}#" \
      -e "s#{{zosmf_port}}#${ZOWE_ZOSMF_PORT}#" \
      -e "s#{{zosmf_host}}#${ZOWE_ZOSMF_HOST}#" \
      -e "s#{{zowe_explorer_host}}#${ZOWE_EXPLORER_HOST}#" \
      -e "s#{{zowe_ip_address}}#${ZOWE_IP_ADDRESS}#")

    echo_and_log "Missing properties that will be appended to $INSTANCE:\n$LINES_TO_APPEND"
    echo "\n$LINES_TO_APPEND" >> $INSTANCE
    echo "Properties added, please review these before starting zowe."
  else
    echo_and_log "No updates required"
  fi
}

echo "Creating zowe instance in ${INSTANCE_DIR}"
$(mkdir -p ${INSTANCE_DIR}/bin/internal)
DIRECTORY_CREATE_RC=$?
if [[ $DIRECTORY_CREATE_RC != "0" ]]
then
  echo "We could not create the instance directory and sub-directories in ${INSTANCE_DIR}. Please check permissions and re-run."
  exit 1
fi

LOG_DIR=${INSTANCE_DIR}/logs
mkdir -p ${LOG_DIR}
chmod 777 ${LOG_DIR}
export LOG_FILE=${LOG_DIR}/"configure-`date +%Y-%m-%d-%H-%M-%S`.log"
echo "Created instance directory ${INSTANCE_DIR}" >> $LOG_FILE

# get a list of variables, from the template instance and the existing config to see which ones are missing and add them to the instance
TEMPLATE=${ZOWE_ROOT_DIR}/scripts/instance.template.env
INSTANCE=${INSTANCE_DIR}/instance.env

# Try and work out the variables that we can
. ${ZOWE_ROOT_DIR}/bin/zowe-init.sh
echo "Ran zowe-init.sh from ${ZOWE_ROOT_DIR}/bin/zowe-init.sh" >> $LOG_FILE

# Check if instance .env already exists
if [[ -f "${INSTANCE}" ]]
then
  check_existing_instance_for_updates
else
  create_new_instance
fi

#Make install-app.sh present per-instance for convenience
cp ${ZOWE_ROOT_DIR}/components/app-server/share/zlux-app-server/bin/install-app.sh ${INSTANCE_DIR}/bin/install-app.sh

cat <<EOF >${INSTANCE_DIR}/bin/read-instance.sh
# Requires INSTANCE_DIR to be set
# Read in properties by executing, then export all the keys so we don't need to shell share
. \${INSTANCE_DIR}/instance.env

while read -r line
do
test -z "\${line%%#*}" && continue      # skip line if first char is #
key=\${line%%=*}
export \$key
done < \${INSTANCE_DIR}/instance.env
EOF
echo "Created ${INSTANCE_DIR}/bin/read-instance.sh">> $LOG_FILE

cat <<EOF >${INSTANCE_DIR}/bin/read-keystore.sh
# Requires KEYSTORE_DIRECTORY to be set
# Read in properties by executing, then export all the keys so we don't need to shell share

# exit immediately if file cannot be accessed
. \${KEYSTORE_DIRECTORY}/zowe-certificates.env || exit 1


while read -r line
do
test -z "\${line%%#*}" && continue      # skip line if first char is #
key=\${line%%=*}
export \$key
done < \${KEYSTORE_DIRECTORY}/zowe-certificates.env
EOF
echo "Created ${INSTANCE_DIR}/bin/read-keystore.sh">> $LOG_FILE

cat <<EOF >${INSTANCE_DIR}/bin/internal/run-zowe.sh
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../../;pwd)
. \${INSTANCE_DIR}/bin/read-instance.sh
# Validate keystore directory accessible before we try and use it
. \${ROOT_DIR}/scripts/utils/validate-keystore-directory.sh
. \${INSTANCE_DIR}/bin/read-keystore.sh
\${ROOT_DIR}/bin/internal/run-zowe.sh -c \${INSTANCE_DIR}
EOF
echo "Created ${INSTANCE_DIR}/bin/internal/run-zowe.sh">> $LOG_FILE

cat <<EOF >${INSTANCE_DIR}/bin/zowe-start.sh
set -e
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../;pwd)
. \${INSTANCE_DIR}/bin/read-instance.sh

\${ROOT_DIR}/scripts/internal/opercmd \"S ZWESVSTC,INSTANCE='"\${INSTANCE_DIR}"',JOBNAME=\${ZOWE_PREFIX}\${ZOWE_INSTANCE}SV\"
echo Start command issued, check SDSF job log ...
EOF
echo "Created ${INSTANCE_DIR}/bin/zowe-start.sh">> $LOG_FILE

cat <<EOF >${INSTANCE_DIR}/bin/zowe-stop.sh
set -e
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../;pwd)
. \${INSTANCE_DIR}/bin/read-instance.sh

\${ROOT_DIR}/scripts/internal/opercmd "c \${ZOWE_PREFIX}\${ZOWE_INSTANCE}SV"
EOF

cat <<EOF >${INSTANCE_DIR}/bin/zowe-support.sh
set -e
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../;pwd)
. \${INSTANCE_DIR}/bin/read-instance.sh

. \${ROOT_DIR}/bin/zowe-support.sh
EOF
echo "Created ${INSTANCE_DIR}/bin/zowe-stop.sh">> $LOG_FILE

# Make the instance directory writable by all so the zowe process can use it, but not the bin directory so people can't maliciously edit it
chmod 777 ${INSTANCE_DIR}
chmod -R 755 ${INSTANCE}
chmod -R 755 ${INSTANCE_DIR}/bin

echo "Configure instance completed. Please now review the properties in ${INSTANCE} to check they are correct."
echo "To start Zowe run the script "${INSTANCE_DIR}/bin/zowe-start.sh
echo "   (or in SDSF directly issue the command /S ZWESVSTC,INSTANCE='${INSTANCE_DIR}')"
echo "To stop Zowe run the script "${INSTANCE_DIR}/bin/zowe-stop.sh
echo "  (or in SDSF directly the command /C ZWESVSTC)"

echo "zowe-configure-instance.sh completed">> $LOG_FILE
