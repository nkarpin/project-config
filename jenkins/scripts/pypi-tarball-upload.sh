#!/bin/bash -xe
#
# Copyright 2012 Hewlett-Packard Development Company, L.P.
# Copyright 2013 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# Retrieve a python sdist and upload it to pypi with Curl.

PROJECT=$1
TARBALL_SITE=$2
TAG=$(echo $ZUUL_REF | sed 's/^refs.tags.//')

# Look in the setup.cfg to determine if a package name is specified, but
# fall back on the project name if necessary
DISTNAME=$(/usr/local/jenkins/slave_scripts/pypi-extract-name.py --tarball \
    || echo $PROJECT)
FILENAME="$DISTNAME-$TAG.tar.gz"

rm -rf *tar.gz
curl --fail -o $FILENAME http://$TARBALL_SITE/$PROJECT/$FILENAME

# Make sure we actually got a gzipped file
file -b $FILENAME | grep gzip

# Uploads may claim to fail but actually succeed so we check if we
# can download after upload to determine success. They can also fail
# intermittently, so retrying in a delayed loop helps improve
# robustness.
TRY=0
RETVAL=255
set +e
while [[ $TRY -lt 3 ]] && [[ $RETVAL -ne 0 ]]; do
    twine upload -r pypi $FILENAME
    curl --head --silent --fail \
        "https://pypi.python.org/simple/$PROJECT/$FILENAME" >/dev/null 2>&1
    RETVAL=$?
    (( TRY++ ))
    if [[ $TRY -lt 3 ]] && [[ $RETVAL -ne 0 ]]; then
        echo "Upload failed, retrying in $TRY seconds." >&2
        sleep $TRY
    fi
done
exit $RETVAL
