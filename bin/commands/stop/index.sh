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

print_level0_message "Stopping Zowe"

###############################
# validation
require_zowe_yaml

# read Zowe STC name and apply default value
security_stcs_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.stcs.zowe")
if [ -z "${security_stcs_zowe}" ]; then
  security_stcs_zowe=${ZWE_PRIVATE_DEFAULT_ZOWE_STC}
fi
# read job name and apply default value
jobname=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.job.name")
if [ -z "${jobname}" ]; then
  jobname="${security_stcs_zowe}"
fi
# read SYSNAME if --ha-instance is specified
route_sysname=
sanitize_ha_instance_id
if [ -n "${ZWE_CLI_PARAMETER_HA_INSTANCE}" ]; then
  route_sysname=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".haInstances.${ZWE_CLI_PARAMETER_HA_INSTANCE}.sysname")
fi

###############################
# start job
cmd="P ${jobname}"
if [ -n "${route_sysname}" ]; then
  cmd="RO ${route_sysname},${cmd}"
fi
result=$(operator_command "${cmd}")
code=$?
if [ ${code} -ne 0 ]; then
  print_error_and_exit "Error ZWEL0166E: Failed to stop ${jobname}: exit code ${code}." "" 166
else
  error_message=$(echo "${result}" | awk "/-P ${jobname}/{x=NR+1;next}(NR<=x){print}" | sed "s/^\([^ ]\+\) \+\([^ ]\+\) \+\([^ ]\+\) \+\(.\+\)\$/\4/" | trim)
  if [ -n "${error_message}" ]; then
    print_error_and_exit "Error ZWEL0166E: Failed to stop ${security_stcs_zowe}: ${error_message}." "" 166
  fi
fi

###############################
# exit message
print_level1_message "Job ${jobname} is stopped successfully."
