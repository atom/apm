#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

case $1 in
  */gyp_main.py)
    export PYTHONPATH="${PYTHONPATH:-}:${SCRIPT_DIR}/../src/generator/"

    ARGS=()
    FORMAT_ARG_ADDED="no"
    while [ $# -gt 0 ]; do
      case "${1}" in
        -f=*|--format=*)
          if [ "${FORMAT_ARG_ADDED}" = "no" ]; then
            ARGS+=("--format" "safemake.py")
            FORMAT_ARG_ADDED="yes"
          fi
          ;;
        -f|--format)
          shift
          if [ "${FORMAT_ARG_ADDED}" = "no" ]; then
            ARGS+=("--format" "safemake.py")
            FORMAT_ARG_ADDED="yes"
          fi
          ;;
        *)
          ARGS+=("$1")
          ;;
      esac
      shift
    done

    if [ "${FORMAT_ARG_ADDED}" = "no" ]; then
      ARGS+=("--format=safemake.py")
    fi

    exec python "${ARGS[@]}"
    ;;
  *)
    exec python "$@"
    ;;
esac
