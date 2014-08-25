#!/usr/bin/env bash

appname="$(basename $(pwd))"
appfile="${appname}.tgz"

if [[ -f "${appfile}" ]]; then
  rm -v "${appfile}"
fi

tar --verbose --create --numeric-owner --owner=0 --group=0 --gzip --file "${appfile}" -C "${DEST}" .
