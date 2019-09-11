#!/bin/sh

# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.

BASEDIR=$(dirname "$0")
OPERCMD=$1
loadmodule=$2
xmemKey=$3

echo "Obtain PPT information"
ppt=`${OPERCMD} "d ppt,name=${loadmodule}" | grep "${loadmodule}  ."`
module=$(echo $ppt | cut -f1 -d ' ')
isNonSwappable=$(echo $ppt | cut -f3 -d ' ')
key=$(echo $ppt | cut -f8 -d ' ')
if [[ "${module}" == "${loadmodule}" ]]; then
  echo "Info:  module ${loadmodule} has a PPT-entry with NS=${isNonSwappable}, key=${key}"
  if [[ "${isNonSwappable}" != "Y" ]]; then
    echo "Error:  module ${loadmodule} must be non-swappable"
    exit 8
  fi
  if [[ "${key}" != "${xmemKey}" ]]; then
    echo "Error:  module ${loadmodule} must run in key ${xmemKey}"
    exit 8
  fi
  exit 0
else
  echo "Error:  PPT-entry has not been found for module ${loadmodule}"
  exit 8
fi


