#!/bin/sh
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

# The PowerVS workspace CRN
WORKSPACE_CRN="crn:v1:bluemix:public:power-iaas:dal10:a/....:workspaceID::"

# The PowerVS workspace ID, this is the part of the CRN after the last single
# colon and before the double colon, see the example value of the CRN above.
WORKSPACE_ID="24...."
INSTANCE_ID="7da...19df"

# Endpoints for PowerVS APIs and IBM Cloud APIs. These can be either
# public or private endpoints. Private endpoints are preferred.
# https://cloud.ibm.com/apidocs/power-cloud#endpoint
POWERIAAS_ENDPOINT="private.us-south.power-iaas.cloud.ibm.com"
IAM_ENDPOINT="private.iam.cloud.ibm.com"


# These are the IBM i locations of curl and jq.
# These can be changed for other operating systems.
CURL_CMD="/QOpenSys/pkgs/bin/curl"
JQ_CMD="/QOpenSys/pkgs/bin/jq"

usage() {
  # Display Help
    cat <<EOF
Syntax: $ changeVSIVolumeTierAPI.sh [-h] -a APIKEY_FILE -t TIER
Change the storage tier on all the volumes of a PowerVS instance.

  h     print help
  a     the name of a file containing an IBM Cloud API key
  t     the desired storage tier. Allowed values for the workspace can be found by using the "ibmcloud pi storage-tiers" CLI.
EOF
}

fatal() {
    echo "FATAL: $*"
    exit 1
}

validate_input() {
    local usage_error="false"
    if [ "x${apikeyfile}" == "x" ]; then
        echo "The API key filename is required"
        usage_error="true"
    fi

    if [ "x${tier}" == "x" ]; then
        echo "The a value for the storage tier required"
        usage_error="true"
    fi

    if [ "x${usage_error}" == "xtrue" ]; then
        echo "One or more required inputs are missing. See the messages above."
        usage
        exit 1
    fi

    if [ ! -s "${apikeyfile}" ]; then
        fatal "The API key file, ${apikeyfile}, does not exist or is empty."
    fi    
}

get_token() {
    APIKEY=`cat $apikeyfile`
    echo "Logging into IBM Cloud"
    TOKEN=$($CURL_CMD --no-progress-meter --fail-with-body -X POST \
        "https://${IAM_ENDPOINT}/identity/token" \
        -H 'content-type: application/x-www-form-urlencoded' \
        -H 'accept: application/json' \
        -d "grant_type=urn%3Aibm%3Aparams%3Aoauth%3Agrant-type%3Aapikey&apikey=${APIKEY}" | $JQ_CMD -r .access_token)

    if [ "$TOKEN" == "null" ]; then
        fatal "An error occurred retreiving an IBM Cloud IAM token"
    fi
}

setVolumesVar() {
    # Set the global VOLUMES variable
    # We run curl with the --fail-with-body option. That option will fail curl if
    # it receives unsuccessful HTTP return codes
    echo "Getting a list of instance volumes"
    local VOLUMES_JSON=$($CURL_CMD --fail-with-body -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "CRN: ${WORKSPACE_CRN}" \
        -X GET "https://${POWERIAAS_ENDPOINT}/pcloud/v1/cloud-instances/${WORKSPACE_ID}/pvm-instances/${INSTANCE_ID}")
    rc=$?
    if [ $rc -ne 0 ] ; then
        fatal "An error occurred retrieving the instance volume list"
    fi
    VOLUMES=$(echo $VOLUMES_JSON | $JQ_CMD -r .volumeIDs[])
}

setVolumeTier() {
    # We run curl with the --fail-with-body option. That option will fail curl if
    # it receives unsuccessful HTTP return codes
    $CURL_CMD --fail-with-body -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "CRN: ${WORKSPACE_CRN}" \
        -X POST "https://${POWERIAAS_ENDPOINT}/pcloud/v1/cloud-instances/${WORKSPACE_ID}/volumes/${1}/action" \
        -d "{\"targetStorageTier\": \"${2}\"}"
    rc=$?
    if [ $rc -ne 0 ] ; then
        echo "\nAn error occurred setting volume tier ${2} on volume ${1}."
        exit $rc
    fi
}

if [ $# -eq 0 ] ; then
    usage
    exit 0
fi

while getopts ":ha:t:" opt; do
  # for each argument present assign the correct value to override the default value
  # values defined after the flag are stored in $OPTARG
  case $opt in
  h) # if -h print usage
    usage
    exit 0
    ;;
  a) apikeyfile=$OPTARG ;;
  t) tier=$OPTARG ;;
  \?) # this case is for when an unknown argument is passed (e.g. -z)
    fatal "Invalid option: -$OPTARG"
    ;;
  esac
done

validate_input
get_token
setVolumesVar
for vol in $VOLUMES
do
    echo "Changing tier of volume $vol"
    setVolumeTier $vol $tier
done
echo "Done"