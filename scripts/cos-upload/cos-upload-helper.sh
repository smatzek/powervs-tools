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

#########################################
# Inputs
# Set the following input variables for
# the specific environment.
#########################################
COS_BUCKET="my-bucket-in-us-east"
COS_ENDPOINT="s3.private.us-east.cloud-object-storage.appdomain.cloud"
API_KEY_FILE="/home/qsecofr/apikey"
COS_UPLOAD_SCRIPT="/home/qsecofr/cos-upload.sh"
#########################################
# End Inputs
#########################################

fatal() {
    echo "FATAL: $*"
    exit 1
}

if [ $# -eq 0 ] ; then
    fatal "Specify a filename to upload as the first positional parameter"
    exit 1
fi

if [ ! -s "${1}" ]; then
    fatal "The file to upload, ${1}, does not exist or is empty."
fi

# Get the system hostname
hn="`uname -n`"

# Get a timestamp
ts="`date +%Y-%m-%d.%H%M%S`"

# Get the file basename (the name with all paths removed)
filebasename=$(basename "${1}")

# Get the file extension
extension="${filebasename##*.}"

# Object name (hostname.filebasename.timestamp.extension)
OBJECT_NAME="${hn}.${filebasename}.${ts}.${extension}"

$COS_UPLOAD_SCRIPT -c "${COS_ENDPOINT}" \
  -b "${COS_BUCKET}" \
  -a "${API_KEY_FILE}" \
  -o "${OBJECT_NAME}" \
  -f "${1}"