#!/usr/bin/env sh
#
# ProFTPd service

# import DroboApps framework functions
. /etc/service.subr

# DroboApp framework version
framework_version="2.0"

# app description
name="proftpd"
version="1.3.5"
description="FTP server"

# framework-mandated variables
pidfile="/tmp/DroboApps/${name}/pid.txt"
logfile="/tmp/DroboApps/${name}/log.txt"
statusfile="/tmp/DroboApps/${name}/status.txt"
errorfile="/tmp/DroboApps/${name}/error.txt"

# app-specific variables
prog_dir="$(dirname $(realpath ${0}))"
conffile="${prog_dir}/etc/proftpd.conf"
servercrt="${prog_dir}/etc/server.crt"
serverkey="${prog_dir}/etc/server.key"
authfile="${prog_dir}/var/auth.sqlite3"
daemon="${prog_dir}/sbin/proftpd"

# script hardening
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o pipefail # propagate last error code on pipe

# ensure log folder exists
grep -q ^tmpfs /proc/mounts || mount -t tmpfs tmpfs /tmp
logfolder="$(dirname ${logfile})"
[[ ! -d "${logfolder}" ]] && mkdir -p "${logfolder}"

# redirect all output to logfile
exec 3>&1 1>> "${logfile}" 2>&1

# log current date, time, and invocation parameters
echo $(date +"%Y-%m-%d %H-%M-%S"): ${0} ${@}

# enable script tracing
set -o xtrace

_create_config() {
  for src in "${prog_dir}/etc"/*.default; do
    local dst="${prog_dir}/etc/$(basename ${src} .default)"
    if [[ ! -f "${dst}" ]]; then
      cp -v "${src}" "${dst}"
    fi
  done
}

_create_database() {
  if [[ ! -f "${authfile}" ]]; then
    "${prog_dir}/libexec/sqlite3" "${authfile}" < "${prog_dir}/www/tables-sqlite3.sql"
    chmod a+rw "${authfile}"
  fi
}

_create_cert() {
  if [[ ! -f "${servercrt}" ]]; then
    "${prog_dir}/libexec/openssl" req -new -x509 -keyout "${serverkey}" -out "${servercrt}" -days 3650 -nodes -subj '/C=US/ST=CA/L=Santa Clara/CN=drobo-5n.local'
  fi
}

start() {
  _create_config
  _create_database
  _create_cert
  "${daemon}" -c "${conffile}"
}

_service_start() {
  # disable error code and unset variable checks
  set +e
  set +u
  # /etc/service.subr uses DROBOAPPS without setting it first
  DROBOAPPS=""
  # 
  start_service
  set -u
  set -e
}

_service_stop() {
  /sbin/start-stop-daemon -K -x "${daemon}" -p "${pidfile}" -v || echo "${name} is not running" >&3
}

_service_restart() {
  service_stop
  sleep 3
  service_start
}

_service_status() {
  status >&3
}

_service_help() {
  echo "Usage: $0 [start|stop|restart|status]" >&3
  set +e
  exit 1
}

case "${1:-}" in
  start|stop|restart|status) _service_${1} ;;
  *) _service_help ;;
esac
