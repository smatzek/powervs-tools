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

usage() {
  # Display Help
    cat <<EOF
Syntax: $ getCerts.sh [-h] [-s host] [-p port] [-m]
Get SSL certificates from a host and write them to PEM files.

Options:
  h     Print help.
  s     The host (server) to connect to.
  p     The port to connect to.
  m     Connect to a SMTP server using TLS. Note this option does not take a value.
EOF
}

if [ $# -eq 0 ] ; then
    usage
    exit 0
fi

# get arguments
# define arguments for getopts to look for
while getopts ":mhs:p:" opt; do
  # for each argument present assign the correct value to override the default value
  # values defined after the flag are stored in $OPTARG
  case $opt in
  h) # if -h print usage
    usage
    exit 0
    ;;
  s) SERVER=$OPTARG ;;
  p) PORT=$OPTARG ;;
  m) SMTP="-starttls smtp" ;; # if -m set SMTP TLS parameer
  \?) # this case is for when an unknown argument is passed (e.g. -c)
    echo "Invalid option: -$OPTARG"
    exit 1
    ;;
  esac
done

if [ "x${SERVER}" == "x" ]; then
  echo "Server/host name or IP must be specified with the -s parameter"
  exit 1
fi

if [ "x${PORT}" == "x" ]; then
  echo "A port must be specified with the -p parameter"
  exit 1
fi

echo "Fetching certificates"
openssl s_client -showcerts -verify 5 $SMTP -connect $SERVER:$PORT < /dev/null |
   awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ if(/BEGIN CERTIFICATE/){a++}; out="cert"a".pem"; print >out}'

echo "Done fetching certificates"

unameval=$(uname)
if [ "$unameval" == "OS400" ]; then
    echo "Changing CCSID of certificates to 819"
    # Change cert file CCSID to 819. It is Unicode 1208 by default which doesn't work for DCM imports
    for cert in *.pem; do
        system "CHGATR OBJ('`pwd`/${cert}') ATR(*CCSID) VALUE(819)"
    done
fi

if [ "$unameval" != "OS400" ]; then
    # We can't do the rename on IBM i because IBM i's sed doesn't support the -E parameter
    echo "Renaming certificate files"
    for cert in *.pem; do
            newname=$(openssl x509 -noout -subject -in $cert | sed -nE 's/.*CN ?= ?(.*)/\1/; s/[ ,.*]/_/g; s/__/_/g; s/_-_/-/; s/^_//g;p' | tr '[:upper:]' '[:lower:]').pem
            echo "${newname}"; mv "${cert}" "${newname}"
    done
fi

echo "Certificate files and their certificate names:"
# output subject, filename
for cert in *.pem; do
        subject=$(openssl x509 -noout -subject -in $cert)
        echo "${cert}: ${subject}"
done
