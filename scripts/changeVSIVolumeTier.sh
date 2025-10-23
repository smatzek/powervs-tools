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
Syntax: $ changeVSIVolumeTier.sh [-h] [-w WORKSPACE_NAME] [-i INSTANCE_NAME] [-t STORAGE_TIER]
Changes the storage tier on all the volumes of a PowerVS instance.

  h     print help
  w     the PowerVS workspace name
  i     instance / LPAR name or ID
  t     storage tier value as shown by "ibmcloud pi storage-tiers"
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
  i) vsi_name=$OPTARG ;;
  w) workspace=$OPTARG ;;
  t) tier=$OPTARG ;;
  \?) # this case is for when an unknown argument is passed (e.g. -c)
    echo "Invalid option: -$OPTARG"
    exit 1
    ;;
  esac
done

[[ -z "$vsi_name" ]] && fatal "The instance/LPAR name or ID is required on the -i parameter"
[[ -z "$workspace" ]] && fatal "The PowerVS workspace name is required with the -w parameter"
[[ -z "$tier" ]] && fatal "The storage tier is required"

check_runtime_prereqs
target_workspace $workspace

# Validate the provided tier is available
tiers=`ibmcloud pi storage-tiers --json | jq -r '.[] | .name'`
avail=false
for t in $tiers
do
  if [ $t == $tier ]; then
    avail=true
    break
  fi
done

if [ $avail == false ]; then
  tiers=`ibmcloud pi storage-tiers --json | jq -r 'map(.name) | join(", ")'`
  fatal "The storage tier \"$tier\" is not available. The available values from the \"ibmcloud pi storage-tiers\" command are: $tiers"
fi

echo "Retrieving VSI volume list"
vols=`ibmcloud pi ins get $vsi_name --json | jq -r .volumeIDs[]`
for vol in $vols
do
    echo "Changing tier of volume $vol"
    ibmcloud pi volume action $vol --target-tier $tier
done
