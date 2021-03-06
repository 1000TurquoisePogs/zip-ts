#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

print_level0_message "Command: sample sub deep"
print_message "I'm the sample sub deep command"
print_message

print_level1_debug "Inherited Parameters"
print_debug "ZWE_CLI_PARAMETER_TARGET_DIR=${ZWE_CLI_PARAMETER_TARGET_DIR}"
print_debug "ZWE_CLI_PARAMETER_AUTO_ENCODING=${ZWE_CLI_PARAMETER_AUTO_ENCODING}"
print_debug

print_level1_message "require_node"
require_node
echo "NODE_HOME=${NODE_HOME}"
print_message

print_level1_message "require_java"
require_java
echo "JAVA_HOME=${JAVA_HOME}"
print_message
