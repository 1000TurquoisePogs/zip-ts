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

print_message "I'm the init command"
print_message

print_message "-----------------"
if [ -z "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
  print_error_and_exit "Error: config file is required."
elif [ ! -f "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
  print_error_and_exit "Error: config file does not exist."
else
  print_message "Content of ${ZWE_CLI_PARAMETER_CONFIG}"
  cat "${ZWE_CLI_PARAMETER_CONFIG}"
fi
