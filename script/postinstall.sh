#!/bin/bash

set -e

echo ">> Downloading bundled Node"
node script/download-node.js

HOST_MODULE_VERSION=$(node -p 'process.versions.modules')
BUNDLED_MODULE_VERSION=$(./bin/node -p 'process.versions.modules')

echo
if [ "${HOST_MODULE_VERSION}" != "${BUNDLED_MODULE_VERSION}" ]; then
  echo ">> Rebuilding apm dependencies with bundled Node $(./bin/node -p "process.version + ' ' + process.arch")"
  ./bin/npm rebuild
else
  echo ">> No need to rebuild dependencies"
fi

echo
if [ -z "${NO_DEDUPE}" ]; then
  echo ">> Deduping apm dependencies"
  ./bin/npm dedupe
else
  echo ">> Deduplication disabled"
fi
