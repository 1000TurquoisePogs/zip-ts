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

# 					# You must invoke this from the scripts directory
VAR=`dirname $0`			# Obtain the scripts directory name
cd $VAR/..				# Change to its parent which should be ZOWE_ROOT_DIR
ZOWE_ROOT_DIR=`pwd`			# Set our environment variable
$ZOWE_ROOT_DIR/scripts/internal/opercmd "S {{stc_name}},SRVRPATH='"$ZOWE_ROOT_DIR"'"
echo Start command issued, check SDSF job log ...