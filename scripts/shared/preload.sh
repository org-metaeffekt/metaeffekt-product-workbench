#!/bin/bash

PRELOAD_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$PRELOAD_SELF_DIR/../../external.rc" ];then
  source "$PRELOAD_SELF_DIR/../../external.rc"
  echo "Successfully sourced external.rc file"
else
  echo "Terminating: external.rc file not found in root of repository."
  exit 1
fi

if [ -n "${EXTERNAL_KONTINUUM_DIR:-}" ]; then
    if [ -f "$EXTERNAL_KONTINUUM_DIR/tests/scripts/processors/log.sh" ]; then
      source "$EXTERNAL_KONTINUUM_DIR/tests/scripts/processors/log.sh"
      echo "Successfully sourced log.sh file"
    else
      echo "Terminating: log.sh not found in $EXTERNAL_KONTINUUM_DIR/tests/scripts/processors/"
      exit 1
    fi
else
  echo "Terminating: EXTERNAL_KONTINUUM_DIR in external.rc is not set."
  exit 1
fi

if [ -n "${EXTERNAL_WORKBENCH_DIR:-}" ];then
    echo "EXTERNAL_WORKBENCH_DIR was set in external.rc file."
else
  echo "Terminating: EXTERNAL_WORKBENCH_DIR in external.rc is not set."
  exit 1
fi

if [ -n "${EXTERNAL_VULNERABILITY_MIRROR_DIR:-}" ];then
    echo "EXTERNAL_VULNERABILITY_MIRROR_DIR was set in external.rc file."
else
  echo "Terminating: EXTERNAL_VULNERABILITY_MIRROR_DIR in external.rc is not set."
  exit 1
fi

if [ -n "${EXTERNAL_VULNERABILITY_MIRROR_URL:-}" ];then
    echo "EXTERNAL_VULNERABILITY_MIRROR_URL was set in external.rc file."
else
  echo "EXTERNAL_VULNERABILITY_MIRROR_URL in external.rc is not set."
fi

if [ -n "${EXTERNAL_VULNERABILITY_MIRROR_NAME:-}" ];then
    echo "EXTERNAL_VULNERABILITY_MIRROR_NAME was set in external.rc file."
else
  echo "EXTERNAL_VULNERABILITY_MIRROR_NAME in external.rc is not set."
fi


