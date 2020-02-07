#!/bin/sh

# Variables to be supplied:
# - HOSTNAME - The hostname of the system running API Mediation
# - IPADDRESS - The IP Address of the system running API Mediation
# - VERIFY_CERTIFICATES - true/false - Should APIML verify certificates of services (defaults to true)
# - ZOSMF_KEYRING - Name of the z/OSMF keyring
# - ZOSMF_USER - z/OSMF server user ID
# - EXTERNAL_CERTIFICATE - optional - Path to a PKCS12 keystore with a server certificate for APIML
# - EXTERNAL_CERTIFICATE_ALIAS - optional - Alias of the certificate in the keystore
# - EXTERNAL_CERTIFICATE_AUTHORITIES - optional - Public certificates of trusted CAs

# - KEYSTORE_DIRECTORY - Location for generated certificates (defaults to /global/zowe/keystore)
# - KEYSTORE_PASSWORD - a password that is used to secure EXTERNAL_CERTIFICATE keystore and 
#                       that will be also used to secure newly generated keystores for API Mediation.
# - ZOWE_USER_ID - zowe user id to set up ownership of the generated certificates


# Set up logging
LOG_DIR=${HOME}/zowe_certificate_setup_log
# Make the log directory if needed - first time through - subsequent installs create new .log files
if [[ ! -d $LOG_DIR ]]; then
    mkdir -p $LOG_DIR
    chmod a+rwx $LOG_DIR 
fi

export LOG_FILE="certificate_config_`date +%Y-%m-%d-%H-%M-%S`.log"
LOG_FILE=$LOG_DIR/$LOG_FILE
touch $LOG_FILE
chmod a+rw $LOG_FILE

echo "<zowe-setup-certificates.sh>" >> $LOG_FILE

# process input parameters.
while getopts "p:" opt; do
  case $opt in
    p) CERTIFICATES_CONFIG_FILE=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift "$(($OPTIND-1))"

if [[ -z ${ZOWE_ROOT_DIR} ]]
then
  export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi

# Load default values
DEFAULT_CERTIFICATES_CONFIG_FILE=${ZOWE_ROOT_DIR}/bin/zowe-setup-certificates.env
echo "Loading default variables from ${DEFAULT_CERTIFICATES_CONFIG_FILE} file."
. ${DEFAULT_CERTIFICATES_CONFIG_FILE}

if [[ -z ${CERTIFICATES_CONFIG_FILE} ]]
then
  echo "-p parameter not set. Using default ${DEFAULT_CERTIFICATES_CONFIG_FILE} file instead."
else
  if [[ -f ${CERTIFICATES_CONFIG_FILE} ]]
  then
    echo "Loading ${CERTIFICATES_CONFIG_FILE} file and overriding default variables."
    # Load custom values
    . ${CERTIFICATES_CONFIG_FILE}  
  else
    echo "${CERTIFICATES_CONFIG_FILE} file does not exist."
    exit 1
  fi
fi

ZOWE_EXPLORER_HOST=${HOSTNAME}
ZOWE_IP_ADDRESS=${IPADDRESS}
. ${ZOWE_ROOT_DIR}/bin/zowe-init.sh
. ${ZOWE_ROOT_DIR}/scripts/utils/configure-java.sh

ZOWE_CERT_ENV_NAME=zowe-certificates.env
LOCAL_KEYSTORE_SUBDIR=local_ca

# create keystore directories
if [ ! -d ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR} ]; then
  if ! mkdir -p ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}; then 
    echo "Unable to create ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR} directory."
    exit 1;
  fi
fi

if [ ! -d ${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS} ]; then
  if ! mkdir -p ${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}; then
    echo "Unable to create ${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS} directory."
    exit 1;
  fi
fi

echo "Creating certificates and keystores... STARTED"
# set up parameters for apiml_cm.sh script
KEYSTORE_PREFIX="${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}/${KEYSTORE_ALIAS}.keystore"
TRUSTSTORE_PREFIX="${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}/${KEYSTORE_ALIAS}.truststore"
EXTERNAL_CA_PREFIX=${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}/extca
LOCAL_CA_PREFIX=${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}/localca
SAN="SAN=dns:${ZOWE_EXPLORER_HOST},ip:${ZOWE_IP_ADDRESS},dns:localhost.localdomain,dns:localhost,ip:127.0.0.1"

# If any external certificate fields are zero [blank], do not use the external setup method.
# If all external certificate fields are zero [blank], create everything from scratch.
# If all external fields are not zero [valid string], use external setup method.

if [[ -z "${EXTERNAL_CERTIFICATE}" ]] || [[ -z "${EXTERNAL_CERTIFICATE_ALIAS}" ]] || [[ -z "${EXTERNAL_CERTIFICATE_AUTHORITIES}" ]]; then
  if [[ -z "${EXTERNAL_CERTIFICATE}" ]] && [[ -z "${EXTERNAL_CERTIFICATE_ALIAS}" ]] && [[ -z "${EXTERNAL_CERTIFICATE_AUTHORITIES}" ]]; then
    ${ZOWE_ROOT_DIR}/bin/apiml_cm.sh --verbose --log $LOG_FILE --action setup --service-ext ${SAN} --service-password ${KEYSTORE_PASSWORD} \
      --service-alias ${KEYSTORE_ALIAS} --service-keystore ${KEYSTORE_PREFIX} --service-truststore ${TRUSTSTORE_PREFIX} --local-ca-filename ${LOCAL_CA_PREFIX}
    RC=$?
    echo "apiml_cm.sh --action setup returned: $RC" >> $LOG_FILE
  else
    (>&2 echo "Zowe Install setup configuration is invalid; check your zowe-setup-certificates.env file.")
    (>&2 echo "Some external apiml certificate fields are supplied...Fields must be filled out in full or left completely blank.")
    (>&2 echo "See $LOG_FILE for more details.")
    echo "</zowe-setup-certificates.sh>" >> $LOG_FILE
    exit 1
  fi
else
  EXT_CA_PARM=""
  for CA in ${EXTERNAL_CERTIFICATE_AUTHORITIES}; do
      EXT_CA_PARM="${EXT_CA_PARM} --external-ca ${CA} "
  done

  ${ZOWE_ROOT_DIR}/bin/apiml_cm.sh --verbose --log $LOG_FILE --action setup --service-ext ${SAN} --service-password ${KEYSTORE_PASSWORD} \
    --external-certificate ${EXTERNAL_CERTIFICATE} --external-certificate-alias ${EXTERNAL_CERTIFICATE_ALIAS} ${EXT_CA_PARM} \
    --service-alias ${KEYSTORE_ALIAS} --service-keystore ${KEYSTORE_PREFIX} --service-truststore ${TRUSTSTORE_PREFIX} --local-ca-filename ${LOCAL_CA_PREFIX} \
    --external-ca-filename ${EXTERNAL_CA_PREFIX}
  RC=$?

  echo "apiml_cm.sh --action setup returned: $RC" >> $LOG_FILE
fi

if [ "$RC" -ne "0" ]; then
    (>&2 echo "apiml_cm.sh --action setup has failed. See $LOG_FILE for more details")
    echo "</zowe-setup-certificates.sh>" >> $LOG_FILE
    exit 1
fi

if [[ "${VERIFY_CERTIFICATES}" == "true" ]]; then
  ${ZOWE_ROOT_DIR}/bin/apiml_cm.sh --verbose --log $LOG_FILE --action trust-zosmf --zosmf-keyring ${ZOSMF_KEYRING} --zosmf-userid ${ZOSMF_USER} \
    --service-password ${KEYSTORE_PASSWORD} --service-truststore ${TRUSTSTORE_PREFIX}
  RC=$?

  echo "apiml_cm.sh --action trust-zosmf returned: $RC" >> $LOG_FILE
  if [ "$RC" -ne "0" ]; then
      (>&2 echo "apiml_cm.sh --action trust-zosmf has failed. See $LOG_FILE for more details")
      (>&2 echo "WARNING: z/OSMF is not trusted by the API Mediation Layer. Follow instructions in Zowe documentation about manual steps to trust z/OSMF")
      (>&2 echo "  Issue the following command as a user that has permissions to export public certificates from z/OSMF keyring:")
      (>&2 echo "    ${ZOWE_ROOT_DIR}/bin/apiml_cm.sh --action trust-zosmf --zosmf-keyring ${ZOSMF_KEYRING} --zosmf-userid ${ZOSMF_USER} \
      --service-password ${KEYSTORE_PASSWORD} --service-truststore ${TRUSTSTORE_PREFIX}")
  fi
fi
echo "Creating certificates and keystores... DONE"

# re-create and populate the zowe-certificates.env file.
ZOWE_CERTIFICATES_ENV=${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
rm ${ZOWE_CERTIFICATES_ENV} 2> /dev/null

cat >${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME} <<EOF
  KEY_ALIAS=${KEYSTORE_ALIAS}
  KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD}
  KEYSTORE=${KEYSTORE_PREFIX}.p12
  TRUSTSTORE=${TRUSTSTORE_PREFIX}.p12
  KEYSTORE_KEY=${KEYSTORE_PREFIX}.key
  KEYSTORE_CERTIFICATE=${KEYSTORE_PREFIX}.cer-ebcdic
  KEYSTORE_CERTIFICATE_AUTHORITY=${LOCAL_CA_PREFIX}.cer-ebcdic
  ZOWE_APIM_VERIFY_CERTIFICATES=${VERIFY_CERTIFICATES}
  ZOSMF_USERID=${ZOSMF_USER}
  ZOSMF_KEYRING=${ZOSMF_KEYRING}
EOF

# set up privileges and ownership
chmod -R 500 ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}/* ${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}/*
echo "Trying to change an owner of the ${KEYSTORE_DIRECTORY}."
if ! chown -R ${ZOWE_USER_ID} ${KEYSTORE_DIRECTORY} >> $LOG_FILE 2>&1 ; then
  echo "Unable to change the current owner of the ${KEYSTORE_DIRECTORY} directory to the ${ZOWE_USER_ID} owner. See $LOG_FILE for more details."
  echo "Trying to change a group of the ${KEYSTORE_DIRECTORY}."
  chmod -R 550 ${KEYSTORE_DIRECTORY}
  if ! chgrp -R ${ZOWE_GROUP_ID} ${KEYSTORE_DIRECTORY} >> $LOG_FILE 2>&1 ; then
    echo "Unable to change the group of the ${KEYSTORE_DIRECTORY} directory to the ${ZOWE_GROUP_ID} group. See $LOG_FILE for more details."
    echo "Please change the owner or the group of the ${KEYSTORE_DIRECTORY} manually so that keystores are protected correctly!"
    echo "Ideally, only ${ZOWE_USER_ID} should have access to the ${KEYSTORE_DIRECTORY}."
  else
    echo "Group of the ${KEYSTORE_DIRECTORY} changed successfully to the ${ZOWE_GROUP_ID} owner."
  fi
else
  echo "Owner of the ${KEYSTORE_DIRECTORY} changed successfully to the ${ZOWE_USER_ID} owner."
fi

echo "</zowe-setup-certificates.sh>" >> $LOG_FILE
