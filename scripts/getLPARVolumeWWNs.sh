#!/usr/bin/env bash
# Copyright 2025 IBM

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

usage() {
  # Display Help
    cat <<EOF
Syntax: $ getLPARVolumeWWNs.sh [-h] [-w WORKSPACE_NAME] [-i INSTANCE_NAME]
Get the WWNs of all volumes attached to an instance

  h     print help
  w     the PowerVS workspace name
  i     instance / LPAR name or ID
EOF
}

fatal() {
    echo "FATAL: $*"
    exit 1
}

check_runtime_prereqs() {
    echo "checking prereqs"
    [[ -z "$(which jq)" ]] && fatal "jq is not installed. See https://stedolan.github.io/jq/"
    [[ -z "$(which ibmcloud)" ]] && fatal "ibmcloud CLI is not installed"
    ibmcloud iam oauth-tokens > /dev/null 2>&1 || fatal "Please log in with the ibmcloud CLI (ibmcloud login)"
}

target_workspace() {
  echo "Targeting workspace $1"
  workspace_ids=$(ibmcloud pi ws list --json | jq -r '.Payload.workspaces[]? | "\(.details.crn) \(.name)"')
  workspace_found="false"
  while read crn name;
  do
      if [[ "x${name}" == "x${1}" ]]; then
          workspace_found="true"
          ibmcloud pi workspace target $crn
          break  # Exit the loop if the workspace is found
      fi
  done <<< "$workspace_ids"

  if [[ "$workspace_found" != "true" ]]; then
      echo "Workspace ${1} was not found!"
      exit 1
  fi
}

if [ $# -eq 0 ] ; then
    usage
    exit 0
fi

while getopts ":hi:t:w:" opt; do
  # for each argument present assign the correct value to override the default value
  # values defined after the flag are stored in $OPTARG
  case $opt in
  h) # if -h print usage
    usage
    exit 0
    ;;
  i) instanceName=$OPTARG ;;
  w) workspace=$OPTARG ;;
  t) tags=$OPTARG ;;
  \?) # this case is for when an unknown argument is passed (e.g. -c)
    echo "Invalid option: -$OPTARG"
    exit 1
    ;;
  esac
done

[[ -z "$instanceName" ]] && fatal "The instance/LPAR name or ID is required on the -i parameter"
[[ -z "$workspace" ]] && fatal "The PowerVS workspace name is required with the -w parameter"

target_workspace $workspace

check_runtime_prereqs

echo "Getting instance information"
instancedata=$(ibmcloud pi ins get "${instanceName}" --json)

volume_ids=$(echo $instancedata | jq -r '.volumeIDs[]')
[[ -z "$volume_ids" ]] && fatal "Failed to retrieve the volumes attached to instance $instanceName"

echo "Getting volumes WWN/Serial number and name"
echo ""

echo "WWN / Serial number                Volume Name"
while read vol_id;
do
    ibmcloud pi vol get $vol_id --json | jq -r '. | "\(.wwn)   \(.name)"'
done <<< "$volume_ids"
