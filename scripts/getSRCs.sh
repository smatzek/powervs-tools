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
Syntax: $ getSRCs.sh [-h] [-w WORKSPACE_NAME] [-i INSTANCE_NAME] [-s SLEEP_TIME]
Continually get the SRCs of the specified LPAR/server in the specified workspace.
CTRL-C to stop.

Options:
  h     Print help.
  w     the PowerVS workspace name
  i     instance / LPAR name or ID
  s     How long to sleep between fetching SRCs. Optional, default: 2s
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

# get arguments
# define arguments for getopts to look for
while getopts ":hw:s:i:" opt; do
  # for each argument present assign the correct value to override the default value
  # values defined after the flag are stored in $OPTARG
  case $opt in
  h) # if -h print usage
    usage
    exit 0
    ;;
  s) SLEEPTIME=$OPTARG ;;
  w) WORKSPACE=$OPTARG ;;
  i) SERVER=$OPTARG ;;
  \?) # this case is for when an unknown argument is passed (e.g. -c)
    echo "Invalid option: -$OPTARG"
    exit 1
    ;;
  esac
done

[[ -z "$SERVER" ]] && fatal "The instance/LPAR name or ID is required on the -i parameter"
[[ -z "$WORKSPACE" ]] && fatal "The PowerVS workspace name is required with the -w parameter"

if [ "x${SLEEPTIME}" == "x" ]; then
  SLEEPTIME=2
fi

check_runtime_prereqs
target_workspace $WORKSPACE

echo "Fetching SRCs forever. CTRL-C to exit."
while true; do
    echo "-------- Fetch at `date` -------"
    # Read SRCS, get them in to a string of "timestamp src src src etc"
    srcs=$(ibmcloud pi ins get "${SERVER}" --json | jq -r '.srcs[][]? | "\(.src) \(.timestamp)"')
    #echo "SRC      SRC timestamp"
    # cycle through the list
    first_loop="true"
    while read src timestamp;
    do
        if [[ "$first_loop" != "false" ]]; then
            echo -n "$timestamp "
            first_loop="false"
        fi
        echo -n "$src "
    done <<< "$srcs"
    echo ""
    echo ""
    sleep $SLEEPTIME
done
