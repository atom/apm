#!/bin/bash

set -e

echo ">> Downloading bundled Node"
node script/download-node.js

echo
echo ">> Rebuilding apm dependencies with bundled Node $(./bin/node -p "process.version + ' ' + process.arch")"
./bin/npm rebuild

echo
if [ -z "${NO_APM_DEDUPE}" ]; then
  echo ">> Deduping apm dependencies"
  ./bin/npm dedupe
else
  echo ">> Deduplication disabled"
fi
