#!/usr/bin/env sh
#
# ProFTPd service

# import DroboApps framework functions
source /etc/service.subr

### app-specific section

# DroboApp framework version
framework_version="2.0"

# app description
name="proftpd"
version="1.3.5"
description="FTP server"

# framework-mandated variables
pidfile="/tmp/DroboApps/${name}/pid.txt"
pidweb="/tmp/DroboApps/${name}/web_server.pid"
logfile="/tmp/DroboApps/${name}/log.txt"
statusfile="/tmp/DroboApps/${name}/status.txt"
errorfile="/tmp/DroboApps/${name}/error.txt"

# app-specific variables
prog_dir="$(dirname $(realpath ${0}))"
daemon="${prog_dir}/sbin/proftpd"
webserver="${prog_dir}/libexec/web_server"
phpcgi="${prog_dir}/libexec/php-cgi"
conffile="${prog_dir}/etc/proftpd.conf"
confweb="${prog_dir}/etc/web_server.conf"

# script hardening
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o pipefail # propagate last error code on pipe

# _is_pid_running
# $1: daemon
# $2: pidfile
# returns: 0 if pid is running, 1 if not running or if pidfile does not exist.
_is_pid_running() {
  /sbin/start-stop-daemon -K -s 0 -x "$1" -p "$2" -q
}

# _is_running
# returns: 0 if nfs is running, 1 if not running.
_is_running() {
  if ! _is_pid_running "${webserver}" "${pidweb}"; then return 1; fi
  if ! _is_pid_running "${daemon}" "${pidfile}"; then return 1; fi
  return 0;
}

start() {
  set -u # exit on unset variable
  set -e # exit on uncaught error code
  set -x # enable script trace
  "${daemon}" -c "${conffile}"
  "${webserver}" "${confweb}" & echo $! > "${pidweb}"
}

# override /etc/service.subrc
stop_service() {
  /sbin/start-stop-daemon -K -x "${webserver}" -p "${pidweb}" -v || true
  /sbin/start-stop-daemon -K -x "${daemon}" -p "${pidfile}" -v || echo "${name} is not running" >&3
}

### common section

# script hardening
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o pipefail # propagate last error code on pipe

# ensure log folder exists
if ! grep -q ^tmpfs /proc/mounts; then mount -t tmpfs tmpfs /tmp; fi
logfolder="$(dirname ${logfile})"
if [[ ! -d "${logfolder}" ]]; then mkdir -p "${logfolder}"; fi

# redirect all output to logfile
exec 3>&1 1>> "${logfile}" 2>&1

# log current date, time, and invocation parameters
echo $(date +"%Y-%m-%d %H-%M-%S"): ${0} ${@}

_service_start() {
  if _is_running; then
    echo ${name} is already running >&3
    return 1
  fi
  set +x # disable script trace
  set +e # disable error code check
  set +u # disable unset variable check
  start_service
}

_service_stop() {
  stop_service
}

_service_restart() {
  _service_stop
  sleep 3
  _service_start
}

_service_status() {
  status >&3
}

_service_help() {
  echo "Usage: $0 [start|stop|restart|status]" >&3
  set +e # disable error code check
  exit 1
}

# enable script tracing
set -o xtrace

case "${1:-}" in
  start|stop|restart|status) _service_${1} ;;
  *) _service_help ;;
esac
