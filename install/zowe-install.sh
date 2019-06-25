################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

# Run zowe-locate-zosmf.sh to ensure the environment variables for where
# ZOSMF/lib and bootstrap.properties are persisted in ZOSMF_DIR and ZOSMF_BOOTSTRAP_PROPERTIES

# on a mac the profile is .bash_profile, on z/OS it will be .profile
export PROFILE=.profile
export INSTALL_DIR=$PWD/../

# extract Zowe version from manifest.json
export ZOWE_VERSION=$(cat $INSTALL_DIR/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')

separator() {
    echo "---------------------------------------------------------------------"
}
separator

# Create a log file with the year and time.log in a log folder 
# that scripts can echo to and can be written to by scripts to diagnose any install 
# problems.  

export LOG_DIR=$INSTALL_DIR/log
# Make the log directory if needed - first time through - subsequent installs create new .log files
if [[ ! -d $LOG_DIR ]]; then
    mkdir -p $LOG_DIR
    chmod a+rwx $LOG_DIR 
fi
# Make the log file (unique assuming there is only one install per second)
export LOG_FILE="`date +%Y-%m-%d-%H-%M-%S`.log"
LOG_FILE=$LOG_DIR/$LOG_FILE
touch $LOG_FILE
chmod a+rw $LOG_FILE

if [ -z "$ZOWE_VERSION" ]; then
  echo "Error: failed to determine Zowe version."
  echo "Error: failed to determine Zowe version." >> $LOG_FILE
  exit 1
fi

echo "Install started at: "`date` >> $LOG_FILE

# Populate the environment variables for ZOWE_SDSF_PATH, ZOWE_ZOSMF_PATH, ZOWE_JAVA_HOME, ZOWE_EXPLORER_HOST
. $INSTALL_DIR/scripts/zowe-init.sh

echo "After zowe-init ZOWE_JAVA_HOME variable value="$ZOWE_JAVA_HOME >> $LOG_FILE

# zowe-parse-yaml.sh to get the variables for install directory, APIM certificate resources, installation proc, and server ports
. $INSTALL_DIR/scripts/zowe-parse-yaml.sh

echo "Beginning install of Zowe ${ZOWE_VERSION} into directory " $ZOWE_ROOT_DIR

# warn about any prior installation
if [[ -d $ZOWE_ROOT_DIR ]]; then
    directoryListLines=`ls -al $ZOWE_ROOT_DIR | wc -l`
    # Has total line, parent and self ref
    if [[ $directoryListLines -gt 3 ]]; then
        echo "    $ZOWE_ROOT_DIR is not empty"
        echo "    Please clear the contents of this directory, or edit zowe-install.yaml's root directory location before attempting the install."
        echo "Exiting non emptry install directory $ZOWE_ROOT_DIR has `expr $directoryListLines - 3` directory entries" >> $LOG_FILE
        exit 0
    fi
else
    mkdir -p $ZOWE_ROOT_DIR
fi
chmod a+rx $ZOWE_ROOT_DIR

# copy manifest.json to root folder
cp "$INSTALL_DIR/manifest.json" "$ZOWE_ROOT_DIR"

# Create a temp directory to be a working directory for sed replacements
export TEMP_DIR=$INSTALL_DIR/temp_"`date +%Y-%m-%d`"
mkdir -p $TEMP_DIR

# Install the API Mediation Layer
. $INSTALL_DIR/scripts/zowe-api-mediation-install.sh

# Install the zLUX server
. $INSTALL_DIR/scripts/zlux-install-script.sh

# Install the Explorer API
. $INSTALL_DIR/scripts/zowe-explorer-api-install.sh

# Install Explorer UI plugins
. $INSTALL_DIR/scripts/zowe-explorer-ui-install.sh

# Configure Explorer UI plugins
. $INSTALL_DIR/scripts/zowe-explorer-ui-configure.sh

# Configure the ports for the zLUX server
. $INSTALL_DIR/scripts/zowe-zlux-configure-ports.sh

# Configure the TLS certificates for the zLUX server
. $INSTALL_DIR/scripts/zowe-zlux-configure-certificates.sh

if [[ $ZOWE_APIM_ENABLE_SSO == "true" ]]; then
    # Add APIML authentication plugin to zLUX
    . $INSTALL_DIR/scripts/zowe-install-existing-plugin.sh $ZOWE_ROOT_DIR "org.zowe.zlux.auth.apiml" $ZOWE_ROOT_DIR/api-mediation/apiml-auth

    # Activate the plugin
    _JSON='"apiml": { "plugins": ["org.zowe.zlux.auth.apiml"] }'
    ZLUX_SERVER_CONFIG_PATH=${ZOWE_ROOT_DIR}/zlux-app-server/config
    sed 's/"zss": {/'"${_JSON}"', "zss": {/g' ${ZLUX_SERVER_CONFIG_PATH}/zluxserver.json > ${TEMP_DIR}/transform1.json
    cp ${TEMP_DIR}/transform1.json ${ZLUX_SERVER_CONFIG_PATH}/zluxserver.json
    rm ${TEMP_DIR}/transform1.json
    
    # Access API Catalog with token injector
    CATALOG_GATEWAY_URL=https://$ZOWE_EXPLORER_HOST:$ZOWE_ZLUX_SERVER_HTTPS_PORT/ZLUX/plugins/org.zowe.zlux.auth.apiml/services/tokenInjector/1.0.0/ui/v1/apicatalog/
else
    # Access API Catalog directly
    CATALOG_GATEWAY_URL=https://$ZOWE_EXPLORER_HOST:$ZOWE_APIM_GATEWAY_PORT/ui/v1/apicatalog
fi

# Add API Catalog application to zLUX - required before we issue ZLUX deploy.sh
. $INSTALL_DIR/scripts/zowe-install-iframe-plugin.sh $ZOWE_ROOT_DIR "org.zowe.api.catalog" "API Catalog" $CATALOG_GATEWAY_URL $INSTALL_DIR/files/assets/api-catalog.png

echo "---- After expanding zLUX artifacts this is a directory listing of "$ZOWE_ROOT_DIR >> $LOG_FILE
ls $ZOWE_ROOT_DIR >> $LOG_FILE
echo "-----"

. $INSTALL_DIR/scripts/zowe-prepare-runtime.sh
# Run deploy on the zLUX app server to propagate the changes made

# TODO LATER - revisit to work out the best permissions, but currently needed so deploy.sh can run	
chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/deploy/product	
chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/deploy/instance

cd $ZOWE_ROOT_DIR/zlux-build
chmod a+x deploy.sh
./deploy.sh > /dev/null

echo "Zowe ${ZOWE_VERSION} runtime install completed into directory "$ZOWE_ROOT_DIR
echo "The install script zowe-install.sh does not need to be re-run as it completed successfully"
separator

# Configure API Mediation layer.  Because this script may fail because of priviledge issues with the user ID
# this script is run after all the folders have been created and paxes expanded above
echo "Attempting to setup Zowe API Mediation Layer certificates ... "
. $INSTALL_DIR/scripts/zowe-api-mediation-configure.sh

# Configure Explorer API servers. This should be after APIML CM generated certificates
echo "Attempting to setup Zowe Explorer API certificates ... "
. $INSTALL_DIR/scripts/zowe-explorer-api-configure.sh

separator
echo "Attempting to set Unix file permissions ..."

# Create the /scripts folder in the runtime directory
# where the scripts to start and the Zowe server will be coped into
mkdir $ZOWE_ROOT_DIR/scripts
chmod a+w $ZOWE_ROOT_DIR/scripts
# The file zowe-runtime-authorize.sh is in the install directory /scripts
# copy this to the runtime directory /scripts, and replace {ZOWE_ZOSMF_PATH}
# with where ZOSMF is located, so that the script can create symlinks and if it fails
# be able to be run stand-alone
echo "Copying zowe-runtime-authorize.sh to "$ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh >> $LOG_FILE
sed "s#%zosmfpath%#$ZOWE_ZOSMF_PATH#g" $INSTALL_DIR/scripts/zowe-runtime-authorize.sh > $ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh

#cp $INSTALL_DIR/scripts/zowe-runtime-authorize.sh $ZOWE_ROOT_DIR/scripts
chmod a+x $ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh
$(. $ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh)
AUTH_RETURN_CODE=$?
if [[ $AUTH_RETURN_CODE == "0" ]]; then
    echo "  The permissions were successfully changed"
    echo "  zowe-runtime-authorize.sh run successfully" >> $LOG_FILE
    else
    echo "  The current user does not have sufficient authority to modify all the file and directory permissions."
    echo "  A user with sufficient authority must run $ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh"
    echo "  zowe-runtime-authorize.sh failed to run successfully" >> $LOG_FILE
fi

separator
echo "Attempting to create $ZOWE_SERVER_PROCLIB_MEMBER PROCLIB member ..."
# Create the ZOWESVR JCL
# Insert the default Zowe install path in the JCL

echo "Copying the zowe-start;stop;server-start.sh into "$ZOWE_ROOT_DIR/scripts >> $LOG_FILE
cd $INSTALL_DIR/scripts
sed 's/ZOWESVR/'$ZOWE_SERVER_PROCLIB_MEMBER'/' $INSTALL_DIR/scripts/zowe-start.sh > $ZOWE_ROOT_DIR/scripts/zowe-start.sh
sed 's/ZOWESVR/'$ZOWE_SERVER_PROCLIB_MEMBER'/' $INSTALL_DIR/scripts/zowe-stop.sh > $ZOWE_ROOT_DIR/scripts/zowe-stop.sh
cp $INSTALL_DIR/scripts/zowe-verify.sh $ZOWE_ROOT_DIR/scripts/zowe-verify.sh
chmod -R 777 $ZOWE_ROOT_DIR/scripts

mkdir $ZOWE_ROOT_DIR/scripts/internal
chmod a+x $ZOWE_ROOT_DIR/scripts/internal

echo "Copying the opercmd into "$ZOWE_ROOT_DIR/scripts/internal >> $LOG_FILE
cp $INSTALL_DIR/scripts/opercmd $ZOWE_ROOT_DIR/scripts/internal/opercmd
echo "Copying the run-zowe.sh into "$ZOWE_ROOT_DIR/scripts/internal >> $LOG_FILE
sed -e 's|$nodehome|'$NODE_HOME'|; s|$prefix|'$ZOWE_PREFIX'|' $INSTALL_DIR/scripts/run-zowe.sh > $TEMP_DIR/run-zowe.sh
cp $TEMP_DIR/run-zowe.sh $ZOWE_ROOT_DIR/scripts/internal/run-zowe.sh
chmod -R 755 $ZOWE_ROOT_DIR/scripts/internal

sed -e 's|/zowe/install/path|'$ZOWE_ROOT_DIR'|' $INSTALL_DIR/files/templates/ZOWESVR.jcl > $TEMP_DIR/ZOWESVR.jcl
$INSTALL_DIR/scripts/zowe-copy-proc.sh $TEMP_DIR/ZOWESVR.jcl $ZOWE_SERVER_PROCLIB_MEMBER $ZOWE_SERVER_PROCLIB_DSNAME

separator
echo "To start Zowe run the script "$ZOWE_ROOT_DIR/scripts/zowe-start.sh
echo "   (or in SDSF directly issue the command /S $ZOWE_SERVER_PROCLIB_MEMBER)"
echo "To stop Zowe run the script "$ZOWE_ROOT_DIR/scripts/zowe-stop.sh
echo "  (or in SDSF directly the command /C $ZOWE_SERVER_PROCLIB_MEMBER)"

# save install log in runtime directory
mkdir  $ZOWE_ROOT_DIR/install_log
cp $LOG_FILE $ZOWE_ROOT_DIR/install_log

# remove the working directory
rm -rf $TEMP_DIR
