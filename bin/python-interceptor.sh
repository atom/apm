#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

case $1 in
  */gyp_main.py)
    GENERATOR_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'generator')
    trap "rm -r ${GENERATOR_DIR}" EXIT
    FORMAT_PY="${GENERATOR_DIR}/safemake.py"
    cp "${SCRIPT_DIR}/../src/generator/safemake.py" "${FORMAT_PY}"

    ARGS=()
    FORMAT_ARG_ADDED="no"
    while [ $# -gt 0 ]; do
      case "${1}" in
        -f=*|--format=*)
          if [ "${FORMAT_ARG_ADDED}" = "no" ]; then
            ARGS+=("--format" "${FORMAT_PY}")
            FORMAT_ARG_ADDED="yes"
          fi
          ;;
        -f|--format)
          shift
          if [ "${FORMAT_ARG_ADDED}" = "no" ]; then
            ARGS+=("--format" "${FORMAT_PY}")
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
      ARGS+=("--format=${FORMAT_PY}")
    fi

    python "${ARGS[@]}"
    ;;
  *)
    exec python "$@"
    ;;
esac
