#!/usr/bin/env bash
# Copyright 2025, 2026 IBM

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


[[ "${BASH_VERSINFO:-0}" -lt 4 ]] && { echo "FATAL: This script requires bash version 4 or higher. Version ${BASH_VERSINFO} is in use." ; exit 1 ; }

# Note this "-A" (associative arrays) requires bash 4
# Associative array (map) of lpar name to workspace CRN
declare -A workspace_crns
# Associative array (map) of lparname to workspace ID
declare -A workspace_ids
# Associative array (map) of lparname to instance ID
declare -A instance_ids
# Associative array (map) of lparname to powervs endpoint
declare -A powervs_endpoints

###############################################################################
# Start end user input section
###############################################################################

# The IBM Cloud IAM endpoint
IAM_ENDPOINT="private.iam.cloud.ibm.com"

# API key used for all PowerVS operations
API_KEY_FILE="/path/to/your/apikey"

# Instructions:
# Set values in the 3 associated arrays for each LPAR the script will
# manage. For example, if you have three LPARs, named "lparname1", "lparname2",
# and "lparname3", you would set values up like this:

# Values for "lparname1"
# The PowerVS workspace CRN
workspace_crns["lparname1"]="crn:v1:bluemix:public:power-iaas:dal10:a/....:workspaceID::"
# The PowerVS workspace ID, this is the part of the CRN after the last single
# colon and before the double colon, see the example value of the CRN above.
workspace_ids["lparname1"]="24...."
# LPAR's PowerVS instance ID
instance_ids["lparname1"]="7da...19df"
# PowerVS Endpoint for the LPAR's location
powervs_endpoints["lparname1"]="private.us-south.power-iaas.cloud.ibm.com"

# Values for "lparname2"
workspace_crns["lparname2"]="crn:v1:bluemix:public:power-iaas:wdc07:a/....:workspaceID::"
workspace_ids["lparname2"]="31...."
instance_ids["lparname2"]="cgf...4sdf"
powervs_endpoints["lparname2"]="private.us-east.power-iaas.cloud.ibm.com"

# Values for "lparname3"
workspace_crns["lparname3"]="crn:v1:bluemix:public:power-iaas:wdc07:a/....:workspaceID::"
workspace_ids["lparname3"]="41...."
instance_ids["lparname3"]="bbf...bhjkl"
powervs_endpoints["lparname3"]="private.us-east.power-iaas.cloud.ibm.com"

###############################################################################
# End user input section
###############################################################################


# These are the IBM i locations of curl and jq.
# These can be changed for other operating systems.
CURL_CMD="/QOpenSys/pkgs/bin/curl"
JQ_CMD="/QOpenSys/pkgs/bin/jq"

usage() {
  # Display Help
    cat <<EOF
Syntax: $ changeVSIVolumeTierWithAPI-multipleLPARs.sh [-h] -i LPARNAME -t TIER
Change the storage tier on all the volumes of a PowerVS instance.

  h     print help
  i     the name of the LPAR instance
  t     the desired storage tier. Allowed values for the workspace can be found by using the "ibmcloud pi storage-tiers" CLI.
EOF
}

validate_input() {

    if [ "x${tier}" == "x" ]; then
        fatal "The value for the storage tier required"
    fi

    [[ -z $lparname ]] && fatal "The LPAR name is required. Possible values are: ${!ips[@]}"

    if [ ! -s "${API_KEY_FILE}" ]; then
        fatal "The API key file, ${API_KEY_FILE}, does not exist or is empty."
    fi    
}

get_token() {
    APIKEY=`cat $API_KEY_FILE`
    log "Logging into IBM Cloud"
    token_output=$($CURL_CMD --no-progress-meter --fail-with-body -X POST \
        "https://${IAM_ENDPOINT}/identity/token" \
        -H 'content-type: application/x-www-form-urlencoded' \
        -H 'accept: application/json' \
        -d "grant_type=urn%3Aibm%3Aparams%3Aoauth%3Agrant-type%3Aapikey&apikey=${APIKEY}" 2>&1)
    rc=$?
    if [ $rc -ne 0 ] ; then
        log "${token_output}"
        fatal "An error occurred retreiving an IBM Cloud IAM token"
    fi

    TOKEN=$(echo $token_output | $JQ_CMD -r .access_token)

    if [ "$TOKEN" == "null" ]; then
        fatal "An error occurred parsing an IAM token from the token API output"
    fi
}

setVolumesVar() {
    # Set the global VOLUMES variable
    # We run curl with the --fail-with-body option. That option will fail curl if
    # it receives unsuccessful HTTP return codes
    log "Getting a list of instance volumes"
    local VOLUMES_JSON=$($CURL_CMD --fail-with-body --no-progress-meter -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "CRN: ${WORKSPACE_CRN}" \
        -X GET "https://${POWERIAAS_ENDPOINT}/pcloud/v1/cloud-instances/${WORKSPACE_ID}/pvm-instances/${INSTANCE_ID}" 2>&1)
    rc=$?
    if [ $rc -ne 0 ] ; then
        log "${VOLUMES_JSON}"
        fatal "An error occurred retrieving the instance volume list"
    fi
    VOLUMES=$(echo $VOLUMES_JSON | $JQ_CMD -r .volumeIDs[])
}

setVolumeTier() {
    # We run curl with the --fail-with-body option. That option will fail curl if
    # it receives unsuccessful HTTP return codes
    output=$($CURL_CMD --fail-with-body --no-progress-meter -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "CRN: ${WORKSPACE_CRN}" \
        -X POST "https://${POWERIAAS_ENDPOINT}/pcloud/v1/cloud-instances/${WORKSPACE_ID}/volumes/${1}/action" \
        -d "{\"targetStorageTier\": \"${2}\"}" 2>&1)
    rc=$?
    if [ $rc -ne 0 ] ; then
        log "${output}"
        log "\nAn error occurred setting volume tier ${2} on volume ${1}."
        return $rc
    fi
}

set_log_file() {
    LOG_FILE="${LOG_FILE:-"/tmp/${lparname}-change-vol-${tier}.log"}"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
}

log() {
    echo $1 | tee -a "$LOG_FILE"
}

fatal() {
    echo "FATAL: $*" | tee -a "$LOG_FILE"
    exit 1
}

if [ $# -eq 0 ] ; then
    usage
    exit 0
fi

while getopts ":hi:t:" opt; do
  # for each argument present assign the correct value to override the default value
  # values defined after the flag are stored in $OPTARG
  case $opt in
  h) # if -h print usage
    usage
    exit 0
    ;;
  i) lparname=$OPTARG ;;
  t) tier=$OPTARG ;;
  \?) # this case is for when an unknown argument is passed (e.g. -z)
    echo "Invalid option: -$OPTARG"
    exit 1
    ;;
  esac
done

validate_input
# Set global variables for the provided LPAR name
WORKSPACE_CRN="${workspace_crns[$lparname]}"
WORKSPACE_ID="${workspace_ids[$lparname]}"
INSTANCE_ID="${instance_ids[$lparname]}"
POWERIAAS_ENDPOINT="${powervs_endpoints[$lparname]}"

get_token
setVolumesVar
all_volumes_status=0
for vol in $VOLUMES
do
    log "Changing tier of volume $vol"
    setVolumeTier $vol $tier
    # Keep track of success or failure of the volume tier chang
    all_volumes_status=$((all_volumes_status | $?))
done

# If any of the volume tiers failed to change, fail the whole script
if [ $all_volumes_status -ne 0 ]; then
    fatal "Changing the tier failed on one or more volumes" 
fi

log "Done"
rm "$LOG_FILE"