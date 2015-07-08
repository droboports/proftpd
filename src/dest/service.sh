#!/usr/bin/env sh
#
# ProFTPd service

# import DroboApps framework functions
. /etc/service.subr

framework_version="2.1"
name="proftpd"
version="1.3.5a"
description="FTP server"
depends=""
webui=":8021/"

prog_dir="$(dirname "$(realpath "${0}")")"
daemon="${prog_dir}/sbin/proftpd"
conffile="${prog_dir}/etc/proftpd.conf"
tmp_dir="/tmp/DroboApps/${name}"
pidfile="${tmp_dir}/pid.txt"
logfile="${tmp_dir}/log.txt"
statusfile="${tmp_dir}/status.txt"
errorfile="${tmp_dir}/error.txt"

webserver="${prog_dir}/libexec/web_server"
confweb="${prog_dir}/etc/web_server.conf"
pidweb="/tmp/DroboApps/${name}/web_server.pid"

# backwards compatibility
if [ -z "${FRAMEWORK_VERSION:-}" ]; then
  framework_version="2.0"
  . "${prog_dir}/libexec/service.subr"
fi

start() {
  "${daemon}" -c "${conffile}" -S 0.0.0.0
  if ! is_running "${pidweb}" "${webserver}"; then
    "${webserver}" "${confweb}" & echo $! > "${pidweb}"
  fi
}

stop() {
  /sbin/start-stop-daemon -K -x "${webserver}" -p "${pidweb}" -v
  /sbin/start-stop-daemon -K -x "${daemon}" -p "${pidfile}" -v
}

force_stop() {
  /sbin/start-stop-daemon -K -s 9 -x "${webserver}" -p "${pidweb}" -v
  /sbin/start-stop-daemon -K -s 9 -x "${daemon}" -p "${pidfile}" -v
}

# boilerplate
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
STDOUT=">&3"
STDERR=">&4"
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o pipefail # propagate last error code on pipe
set -o xtrace   # enable script tracing

main "${@}"
