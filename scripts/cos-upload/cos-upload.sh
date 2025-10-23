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

CURL_CMD="/QOpenSys/pkgs/bin/curl"
JQ_CMD="/QOpenSys/pkgs/bin/jq"

usage() {
  # Display Help
    cat <<EOF
Syntax: $ cos-upload.sh [-h] -a APIKEY_FILE -b BUCKET_NAME -f FILE_PATH -c COS_ENDPOINT [-i IAM_ENDPOINT] [-o OBJECT_NAME]
Upload a file to a COS bucket

  h     print help
  a     the name of a file containing an IBM Cloud API key
  b     the name of the bucket to upload the file to
  f     the path to a file to upload
  c     the IBM Cloud Object Storage endpoint. Example: s3.direct.us-south.cloud-object-storage.appdomain.cloud
  i     the IBM Cloud IAM endpoint. Default: private.iam.cloud.ibm.com
  o     the object name in COS. Optional. Default: the base name of the filename
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

    if [ "x${thebucket}" == "x" ]; then
        echo "The bucket name is required"
        usage_error="true"
    fi

    if [ "x${thefile}" == "x" ]; then
        echo "The file to upload is required"
        usage_error="true"
    fi

    if [ "x${COS_ENDPOINT}" == "x" ]; then
        echo "The COS endpoint is required"
        usage_error="true"
    fi

    if [ "x${IAM_ENDPOINT}" == "x" ]; then
        IAM_ENDPOINT="private.iam.cloud.ibm.com"
    fi

    if [ "x${usage_error}" == "xtrue" ]; then
        echo "One or more required inputs are missing. See the messages above."
        usage
        exit 1
    fi

    if [ ! -s "${apikeyfile}" ]; then
        fatal "The API key file, ${apikeyfile}, does not exist or is empty."
    fi    

    if [ ! -s "${thefile}" ]; then
        fatal "The file to upload, ${thefile}, does not exist or is empty."
    fi

    if [ "x${OBJECT_NAME}" == "x" ]; then
        OBJECT_NAME=$(basename "${thefile}")
    fi
}

if [ $# -eq 0 ] ; then
    usage
    exit 0
fi

while getopts ":ha:b:f:i:c:o:" opt; do
  # for each argument present assign the correct value to override the default value
  # values defined after the flag are stored in $OPTARG
  case $opt in
  h) # if -h print usage
    usage
    exit 0
    ;;
  a) apikeyfile=$OPTARG ;;
  b) thebucket=$OPTARG ;;
  f) thefile=$OPTARG ;;
  i) IAM_ENDPOINT=$OPTARG ;;
  c) COS_ENDPOINT=$OPTARG ;;
  o) OBJECT_NAME=$OPTARG ;;
  \?) # this case is for when an unknown argument is passed (e.g. -z)
    fatal "Invalid option: -$OPTARG"
    ;;
  esac
done

validate_input

APIKEY=`cat $apikeyfile`
echo "Logging into IBM Cloud"
token=$($CURL_CMD --no-progress-meter --fail-with-body -X POST \
    "https://${IAM_ENDPOINT}/identity/token" \
    -H 'content-type: application/x-www-form-urlencoded' \
    -H 'accept: application/json' \
    -d "grant_type=urn%3Aibm%3Aparams%3Aoauth%3Agrant-type%3Aapikey&apikey=${APIKEY}" | $JQ_CMD -r .access_token)

if [ "$token" == "null" ]; then
    fatal "An error occurred retreiving an IBM Cloud IAM token"
fi

# We upload the file and use the --fail-with-body option. That option will fail curl if
# it receives unsuccessful HTTP return codes
echo "Uploading"
$CURL_CMD --fail-with-body -H "Content-Type: text/html" \
    -H "Authorization: Bearer ${token}" \
    -X PUT "https://${COS_ENDPOINT}/${thebucket}/${OBJECT_NAME}" \
    -T $thefile
rc=$?
if [ $rc -ne 0 ] ; then
    echo "\nAn error occurred uploading the file to COS."
    exit $rc
fi

echo "Done"
