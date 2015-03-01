#!/usr/bin/env sh
#
# ProFTPd service

# import DroboApps framework functions
. /etc/service.subr

### app-specific section

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
pidweb="/tmp/DroboApps/${name}/web_server.pid"

# app-specific variables
prog_dir="$(dirname $(realpath ${0}))"
daemon="${prog_dir}/sbin/proftpd"
conffile="${prog_dir}/etc/proftpd.conf"
webserver="${prog_dir}/libexec/web_server"
confweb="${prog_dir}/etc/web_server.conf"
phpcgi="${prog_dir}/libexec/php-cgi"

# _is_pid_running
# $1: daemon
# $2: pidfile
# returns: 0 if pid is running, 1 if not running or if pidfile does not exist.
_is_pid_running() {
  /sbin/start-stop-daemon -K -t -x "${1}" -p "${2}" -q
}

# _is_running
# returns: 0 if app is running, 1 if not running or pidfile does not exist.
_is_running() {
  if ! _is_pid_running "${webserver}" "${pidweb}"; then return 1; fi
  if ! _is_pid_running "${daemon}" "${pidfile}"; then return 1; fi
  return 0;
}

# _is_stopped
# returns: 0 if app is stopped, 1 if running.
_is_stopped() {
  if _is_pid_running "${webserver}" "${pidweb}"; then return 1; fi
  if _is_pid_running "${daemon}" "${pidfile}"; then return 1; fi
  return 0;
}

start() {
  set -u # exit on unset variable
  set -e # exit on uncaught error code
  set -x # enable script trace
  "${daemon}" -c "${conffile}" -S 0.0.0.0
  "${webserver}" "${confweb}" & echo $! > "${pidweb}"
}

# override /etc/service.subrc
stop_service() {
  if _is_stopped; then
    echo ${name} is not running >&3
    if [[ "${1:-}" == "-f" ]]; then
      return 0
    else
      return 1
    fi
  fi
  set +e  # disable exit on uncaught error code
  /sbin/start-stop-daemon -K -x "${webserver}" -p "${pidweb}" -v
  /sbin/start-stop-daemon -K -x "${daemon}" -p "${pidfile}" -v
  set -e  # enable exit on uncaught error code
}

### common section

# script hardening
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable

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

_service_waitstop() {
  stop_service -f
  while ! _is_stopped; do
    sleep 1
  done
}

_service_restart() {
  _service_waitstop
  _service_start
}

_service_status() {
  status >&3
}

_service_help() {
  echo "Usage: $0 [start|stop|waitstop|restart|status]" >&3
  exit 1
}

# enable script tracing
set -o xtrace

case "${1:-}" in
  start|stop|waitstop|restart|status) _service_${1} ;;
  *) _service_help ;;
esac
