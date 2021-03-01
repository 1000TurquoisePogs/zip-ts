#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

###############################
# Find component root directory
#
# Required environment variables:
# - ROOT_DIR
#
# Optional environment variables:
# - ZWE_EXTENSION_DIR
#
# This function will find the component in this sequence:
#   - check if component id paramter is a path to lifecycle scripts directory
#   - ${ROOT_DIR}/components/<component-id>
#   - ${ZWE_EXTENSION_DIR}/<component-id>
#
# @param string     component id, or path to component lifecycle scripts
# Output            component directory will be written to stdout
find_component_directory() {
  component_id=$1
  # find component lifecycle scripts directory
  component_dir=
  if [ -d "${component_id}" ]; then
    component_lifecycle_dir="${component_id}"
    if [[ ${component_lifecycle_dir} == */bin ]]; then
      # the lifecycle dir ends with /bin, we assume the component root directory is one level up
      component_dir=$(cd ${component_lifecycle_dir}/../;pwd)
    else
      parent_dir=$(cd ${component_lifecycle_dir}/../;pwd)
      if [ -f "${parent_dir}/manifest.yaml" -o -f "${parent_dir}/manifest.yml" -o -f "${parent_dir}/manifest.json" ]; then
        # parent directory has manifest file, we assume it's Zowe component manifest and that's the root folder
        component_dir="${parent_dir}"
      fi
    fi
  else
    if [ -d "${ROOT_DIR}/components/${component_id}" ]; then
      # this is a Zowe build-in component
      component_dir="${ROOT_DIR}/components/${component_id}"
    elif [ -n "${ZWE_EXTENSION_DIR}" ]; then
      if [ -d "${ZWE_EXTENSION_DIR}/${component_id}" ]; then
        # this is an extension installed/linked in ZWE_EXTENSION_DIR
        component_dir="${ZWE_EXTENSION_DIR}/${component_id}"
      fi
    fi
  fi

  echo "${component_dir}"
}

###############################
# Check if component is core component
#
# Required environment variables:
# - ROOT_DIR
#
# @param string     component directory
# Output            true|false
is_core_component() {
  component_dir=$1

  core_component_dir=${ROOT_DIR}/components
  [[ $component_dir == "${core_component_dir}"* ]] && echo true || echo false
}

###############################
# Detect and verify file encoding
#
# This function will try to verify file encoding by reading sample string.
#
# Note: this function always exits with 0. Depends on the cases, the output is
#       confirmed encoding to stdout.
#       - file is already tagged: the output will be the encoding tag,
#       - file is not tagged:
#         - expected encoding is auto: the output will be one of IBM-1047, 
#                 ISO8859-1, IBM-850 based on the guess. Output is empty if none
#                 of those encodings are correct.
#         - expected encoding is not auto: the output will be same as expected
#                 encoding if it's correct. otherwise output will be empty.
#
# Example:
# - detect manifest encoding by checking result "name"
#   detect_file_encoding "/path/to/zowe/components/my-component/manifest.yaml" "name"
#
# @param string   path to file to verify
# @param string   expected sample string to verify result
# @param string   expected encoding. This is optional, and default value is "auto".
#                 When this value is auto, the function will try to guess common
#                 encodings (IBM-1047, ISO8859-1, IBM-850). 
detect_file_encoding() {
  file_name=$1
  expected_sample=$2
  expected_encoding=$3

  expected_encoding_uc=$(echo "${expected_encoding}" | tr '[:lower:]' '[:upper:]')

  confirmed_encoding=

  current_tag=$(ls -T "${file_name}" | awk '{print $2}')
  if [ "${current_tag}" != "untagged" ]; then
    confirmed_encoding="${current_tag}"
  fi

  if [ -z "${confirmed_encoding}" ]; then
    if [ "${expected_encoding_uc}" = "IBM-1047" ]; then
      result=$(cat "${file_name}" | grep "${expected_sample}" 2>/dev/null)
      if [ -n "${result}" ]; then
        confirmed_encoding=IBM-1047
      fi
    elif [ "${expected_encoding_uc}" = "AUTO" -o -z "${expected_encoding_uc}" ]; then
      # check IBM-1047
      result=$(cat "${file_name}" | grep "${expected_sample}" 2>/dev/null)
      if [ -n "${result}" ]; then
        confirmed_encoding=IBM-1047
      fi
      # check common encodings
      common_encodings="ISO8859-1 IBM-850"
      for enc in ${common_encodings}; do
        if [ -z "${confirmed_encoding}" ]; then
          result=$(iconv -f "${enc}" -t IBM-1047 "${file_name}" | grep "${expected_sample}" 2>/dev/null)
          if [ -n "${result}" ]; then
            confirmed_encoding=${enc}
          fi
        fi
      done
    else
      result=$(iconv -f "${expected_encoding_uc}" -t IBM-1047 "${file_name}" | grep "${expected_sample}" 2>/dev/null)
      if [ -n "${result}" ]; then
        confirmed_encoding=${expected_encoding_uc}
      fi
    fi
  fi

  if [ -n "${confirmed_encoding}" ]; then
    echo "${confirmed_encoding}"
  fi
}

###############################
# Detect and verify component manifest encoding
#
# Note: this function always returns 0 and if succeeds, it will output encoding
#       to stdout.
#
# Example:
# - detect manifest encoding of my-component
#   detect_component_manifest_encoding "/path/to/zowe/components/my-component"
#
# @param string   component directory
detect_component_manifest_encoding() {
  component_dir=$1

  component_manifest=
  if [ -f "${component_dir}/manifest.yaml" ]; then
    component_manifest="${component_dir}/manifest.yaml"
  elif [ -f "${component_dir}/manifest.yml" ]; then
    component_manifest="${component_dir}/manifest.yml"
  elif [ -f "${component_dir}/manifest.json" ]; then
    component_manifest="${component_dir}/manifest.json"
  fi
  if [ -n "${component_manifest}" ]; then
    # manifest at least should have name defined
    confirmed_encoding=$(detect_file_encoding "${component_manifest}" "name")
    if [ -n "${confirmed_encoding}" ]; then
      echo "${confirmed_encoding}"
    fi
  fi
}

###############################
# Convert component YAML format manifest to JSON and place into workspace foler
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# Note: this function is for runtime only to prepare workspace
#
# Required environment variables:
# - ROOT_DIR
# - NODE_HOME
# - WORKSPACE_DIR
#
# Example:
# - convert my-component manifest, a .manifest.json will be created in <WORKSPACE_DIR>/my-component folder
#   convert_component_manifest "/path/to/zowe/components/my-component"
#
# @param string   component directory
convert_component_manifest() {
  component_dir=$1

  if [ -z "$NODE_HOME" ]; then
    >&2 echo "NODE_HOME is required by this function"
    return 1
  fi
  # node should have already been put into PATH

  if [ -z "${WORKSPACE_DIR}" ]; then
    >&2 echo "WORKSPACE_DIR is required by this function"
    return 1
  fi

  utils_dir="${ROOT_DIR}/bin/utils"
  fconv="${utils_dir}/fconv/src/index.js"
  component_name=$(basename "${component_dir}")
  component_manifest=

  if [ -f "${component_dir}/manifest.yaml" ]; then
    component_manifest="${component_dir}/manifest.yaml"
  elif [ -f "${component_dir}/manifest.yml" ]; then
    component_manifest="${component_dir}/manifest.yml"
  fi

  if [ -n "${component_manifest}" ]; then
    mkdir -p "${WORKSPACE_DIR}/${component_name}"
    node "${fconv}" -o "${WORKSPACE_DIR}/${component_name}/.manifest.json" "${component_manifest}"
    return $?
  else
    # this could be the package doesn't have manifest, or has it in JSON format
    return 0
  fi
}

###############################
# Read component manifest
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# Required environment variables:
# - ROOT_DIR
# - NODE_HOME
#
# Optional environment variables:
# - WORKSPACE_DIR
#
# Example:
# - read my-component commands.start value
#   read_component_manifest "/path/to/zowe/components/my-component" ".commands.start"
#
# @param string   component directory
# @param string   string of manifest key. For example: ".commands.configure"
# Output          empty if component doesn't have manifest
#                          , or manifest doesn't have the key
#                          , or NODE_HOME is not defined
#                 the value defined in the manifest of the selected key
read_component_manifest() {
  component_dir=$1
  manifest_key=$2

  if [ -z "$NODE_HOME" ]; then
    >&2 echo "NODE_HOME is required by this function"
    return 1
  fi
  # node should have already been put into PATH

  component_name=$(basename "${component_dir}")
  manifest_in_workspace=
  if [ -n "${WORKSPACE_DIR}" ]; then
    manifest_in_workspace="${WORKSPACE_DIR}/${component_name}/.manifest.json"
  fi

  if [ -n "${manifest_in_workspace}" -a -f "${manifest_in_workspace}" ]; then
    read_json "${manifest_in_workspace}" "${manifest_key}"
    return $?
  elif [ -f "${component_dir}/manifest.yaml" ]; then
    read_yaml "${component_dir}/manifest.yaml" "${manifest_key}"
    return $?
  elif [ -f "${component_dir}/manifest.yml" ]; then
    read_yaml "${component_dir}/manifest.yml" "${manifest_key}"
    return $?
  elif [ -f "${component_dir}/manifest.json" ]; then
    read_json "${component_dir}/manifest.json" "${manifest_key}"
    return $?
  else
    >&2 echo "no manifest found in ${component_dir}"
    return 1
  fi
}

###############################
# Parse and process manifest service APIML static definition
#
# The supported manifest entry is ".apimlServices.static[].file". All files defined
# here will be parsed and put into Zowe static definition directory in IBM-850 encoding.
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# Required environment variables:
# - ROOT_DIR
# - NODE_HOME
# - STATIC_DEF_CONFIG_DIR
#
# @param string   component directory
process_component_apiml_static_definitions() {
  component_dir=$1

  if [ -z "${STATIC_DEF_CONFIG_DIR}" ]; then
    >&2 echo "Error: STATIC_DEF_CONFIG_DIR is required to process component definitions for API Mediation Layer."
    return 1
  fi

  component_name=$(basename "${component_dir}")
  all_succeed=true

  static_defs=$(read_component_manifest "${component_dir}" ".apimlServices.static[].file" 2>/dev/null)
  if [ -z "${static_defs}" -o "${static_defs}" = "null" ]; then
    # does the component define it as object instead of array
    static_defs=$(read_component_manifest "${component_dir}" ".apimlServices.static.file" 2>/dev/null)
  fi

  cd "${component_dir}"
  while read -r one_def; do
    one_def_trimmed=$(echo "${one_def}" | xargs)
    if [ -n "${one_def_trimmed}" -a "${one_def_trimmed}" != "null" ]; then
      echo "process ${component_name} service static definition file ${one_def_trimmed} ..."
      sanitized_def_name=$(echo "${one_def_trimmed}" | sed 's/[^a-zA-Z0-9]/_/g')
      # FIXME: we may change the static definitions files to real template in the future.
      #        currently we support to use environment variables in the static definition template
      parsed_def=$( ( echo "cat <<EOF" ; cat "${one_def}" ; echo ; echo EOF ) | sh 2>&1)
      retval=$?
      if [ "${retval}" != "0" ]; then
        >&2 echo "failed to parse ${component_name} API Mdeialtion Layer static definition file ${one_def}: ${parsed_def}"
        if [[ "${parsed_def}" == *unclosed* ]]; then
          >&2 echo "this is very likely an encoding issue that file is not tagged properly"
        fi
        all_succeed=false
        break
      fi
      echo "${parsed_def}" | iconv -f IBM-1047 -t IBM-850 > ${STATIC_DEF_CONFIG_DIR}/${component_name}_${sanitized_def_name}.yml
      chmod 770 ${STATIC_DEF_CONFIG_DIR}/${component_name}_${sanitized_def_name}.yml
    fi
  done <<EOF
$(echo "${static_defs}")
EOF

  if [ "${all_succeed}" = "true" ]; then
    return 0
  else
    # error message should have be echoed before this
    return 1
  fi
}

###############################
# Parse and process manifest desktop iframe plugin definition
#
# The supported manifest entry is ".desktopIframePlugins". All plugins
# defined will be passed to zowe-install-iframe-plugin.sh for proper installation.
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# Required environment variables:
# - ROOT_DIR
# - NODE_HOME
#
# Optional environment variables (but very likely are required):
# - ZOWE_EXPLORER_HOST
# - GATEWAY_PORT
#
# @param string   component directory
process_component_desktop_iframe_plugin() {
  component_dir=$1

  component_name=$(basename "${component_dir}")
  all_succeed=true

  cd "${component_dir}"

  # we maximum support 20 desktop iframe plugins in one package
  iterator_index=0
  while [ $iterator_index -lt 20 ]; do
    iframe_plugin_def=$(read_component_manifest "${component_dir}" ".desktopIframePlugins[${iterator_index}]" 2>/dev/null)
    if [ -z "${iframe_plugin_def}" -o "${iframe_plugin_def}" = "null" ]; then
      # not defined, which means no more definitions
      break
    fi

    plugin_id=$(read_component_manifest "${component_dir}" ".desktopIframePlugins[${iterator_index}].id" 2>/dev/null)
    if [ -z "${plugin_id}" -o "${plugin_id}" = "null" ]; then
      plugin_id=$(read_component_manifest "${component_dir}" ".id" 2>/dev/null)
    fi
    plugin_title=$(read_component_manifest "${component_dir}" ".desktopIframePlugins[${iterator_index}].title" 2>/dev/null)
    if [ -z "${plugin_title}" -o "${plugin_title}" = "null" ]; then
      plugin_title=$(read_component_manifest "${component_dir}" ".title" 2>/dev/null)
    fi
    plugin_url=$(read_component_manifest "${component_dir}" ".desktopIframePlugins[${iterator_index}].url" 2>/dev/null)
    if [ -z "${plugin_url}" -o "${plugin_url}" = "null" ]; then
      plugin_url=
      # this is a big guess to check configs, should we do this?
      # or should we check APIML static defs?
      base_uri=$(read_component_manifest "${component_dir}" ".configs.baseUri" 2>/dev/null)
      if [ -n "${base_uri}" -a "${base_uri}" != "null" ]; then
        plugin_url="https://${ZOWE_EXPLORER_HOST}:${GATEWAY_PORT}${base_uri}"
      fi
    elif [[ ${plugin_url} == http://* || ${plugin_url} == https://* ]]; then
      : # already a full url, do nothing
      # FIXME: we may need to parse the url as template
    elif [[ ${plugin_url} == /* ]]; then
      # a url path, prefix with gateway access
      plugin_url="https://${ZOWE_EXPLORER_HOST}:${GATEWAY_PORT}${plugin_url}"
    fi
    plugin_icon=$(read_component_manifest "${component_dir}" ".desktopIframePlugins[${iterator_index}].icon" 2>/dev/null)
    plugin_version=$(read_component_manifest "${component_dir}" ".version" 2>/dev/null)
    if [ -z "${plugin_version}" -o "${plugin_version}" = "null" ]; then
      # this is the same default version in bin/utils/zowe-install-iframe-plugin.sh
      plugin_version=1.0.0
    fi

    echo "process desktop plugin #${iterator_index}"

    if [ -z "${plugin_id}" -o "${plugin_id}" = "null" ]; then
      all_succeed=false
      >&2 echo "plugin id is not defined"
    fi
    if [ -z "${plugin_title}" -o "${plugin_title}" = "null" ]; then
      all_succeed=false
      >&2 echo "plugin title is not defined"
    fi
    if [ -z "${plugin_url}" -o "${plugin_url}" = "null" ]; then
      all_succeed=false
      >&2 echo "plugin url is not defined"
    fi
    if [ -z "${plugin_icon}" -o "${plugin_icon}" = "null" ]; then
      all_succeed=false
      >&2 echo "plugin icon is not defined"
    elif [ ! -f "${component_dir}/${plugin_icon}" ]; then
      all_succeed=false
      >&2 echo "plugin icon ${component_dir}/${plugin_icon} does not exist"
    fi

    if [ "${all_succeed}" = "true" ]; then
      echo "* id      : ${plugin_id}"
      echo "* title   : ${plugin_title}"
      echo "* version : ${plugin_version}"
      echo "* url     : ${plugin_url}"
      echo "* icon    : ${component_dir}/${plugin_icon}"
      echo "* folder  : ${WORKSPACE_DIR}/${component_name}"

      ${ROOT_DIR}/bin/utils/zowe-install-iframe-plugin.sh \
        -d "${WORKSPACE_DIR}/${component_name}" \
        -i "${plugin_id}" \
        -s "${plugin_title}" \
        -t "${component_dir}/${plugin_icon}" \
        -u "${plugin_url}" \
        -v "${plugin_version}"
    fi

    iterator_index=`expr $iterator_index + 1`
  done

  if [ "${all_succeed}" = "true" ]; then
    return 0
  else
    # error message should have be echoed before this
    return 1
  fi
}

###############################
# Parse and process manifest App Framework Plugin (appfwPlugins) definitions
#
# The supported manifest entry is ".appfwPlugins". All plugins
# defined will be passed to install-app.sh for proper installation.
#
# Note: this function requires node, which means NODE_HOME should have been defined,
#       and ensure_node_is_on_path should have been executed.
#
# Required environment variables:
# - INSTANCE_DIR
# - NODE_HOME
#
# @param string   component directory
process_component_appfw_plugin() {
  component_dir=$1

  all_succeed=true
  iterator_index=0
  appfw_plugin_path=$(read_component_manifest "${component_dir}" ".appfwPlugins[${iterator_index}].path" 2>/dev/null)
  while [ "${appfw_plugin_path}" != "null" ] && [ -n "${appfw_plugin_path}" ]; do
      cd "${component_dir}"
      ${INSTANCE_DIR}/bin/install-app.sh "$(get_full_path ${appfw_plugin_path})"
      # FIXME: do we know if install-app.sh fails. if so, we need to set all_succeed=false

      iterator_index=`expr $iterator_index + 1`
      appfw_plugin_path=$(read_component_manifest "${component_dir}" ".appfwPlugins[${iterator_index}].path" 2>/dev/null)
  done

  if [ "${all_succeed}" = "true" ]; then
    return 0
  else
    # error message should have be echoed before this
    return 1
  fi
}
