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
Syntax: $ setVSIProcMem.sh [-h] -a APIKEY_FILE -p PROCESSORS -m MEMORY
Set a VSIs processor and memory

  h     print help
  a     the name of a file containing an IBM Cloud API key
  p     the desired number of processors. example: 0.5
  m     the desired amount of memory in GB. example: 8
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

    if [ "x${proc}" == "x" ]; then
        echo "The a value for the number of processors is required"
        usage_error="true"
    fi

    if [ "x${mem}" == "x" ]; then
        echo "The a value for the amount of memory is required"
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

if [ $# -eq 0 ] ; then
    usage
    exit 0
fi

setProcMem() {
    # We run curl with the --fail-with-body option. That option will fail curl if
    # it receives unsuccessful HTTP return codes
    echo "Setting processor and memory"
    $CURL_CMD --fail-with-body -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "CRN: ${WORKSPACE_CRN}" \
        -X PUT "https://${POWERIAAS_ENDPOINT}/pcloud/v1/cloud-instances/${WORKSPACE_ID}/pvm-instances/${INSTANCE_ID}" \
        -d "{\"processors\": ${1}, \"memory\": ${2}}"
    rc=$?
    if [ $rc -ne 0 ] ; then
        echo "\nAn error occurred setting processor and memory."
        exit $rc
    fi
}

while getopts ":ha:p:m:" opt; do
  # for each argument present assign the correct value to override the default value
  # values defined after the flag are stored in $OPTARG
  case $opt in
  h) # if -h print usage
    usage
    exit 0
    ;;
  a) apikeyfile=$OPTARG ;;
  p) proc=$OPTARG ;;
  m) mem=$OPTARG ;;
  \?) # this case is for when an unknown argument is passed (e.g. -z)
    fatal "Invalid option: -$OPTARG"
    ;;
  esac
done

validate_input
get_token
setProcMem $proc $mem
echo "Done"