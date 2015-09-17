#!/usr/bin/env sh
#
# ProFTPd service

# import DroboApps framework functions
. /etc/service.subr

framework_version="2.1"
name="proftpd"
version="1.3.5a-1"
description="Highly configurable FTP server software"
depends=""
webui="WebUI"

prog_dir="$(dirname "$(realpath "${0}")")"
daemon="${prog_dir}/sbin/proftpd"
conffile="${prog_dir}/etc/proftpd.conf"
tmp_dir="/tmp/DroboApps/${name}"
pidfile="${tmp_dir}/pid.txt"
logfile="${tmp_dir}/log.txt"
statusfile="${tmp_dir}/status.txt"
errorfile="${tmp_dir}/error.txt"

autofile="${conffile}.auto"
sharesfile="${prog_dir}/etc/shares.conf"
rw_template="${prog_dir}/etc/readwrite.template"
ro_template="${prog_dir}/etc/readonly.template"
shares_conf="/mnt/DroboFS/System/DNAS/configs/shares.conf"
shares_dir="/mnt/DroboFS/Shares"

apachedaemon="${DROBOAPPS_DIR}/apache/service.sh"
appconffile="${prog_dir}/etc/proftpdapp.conf"
apachefile="${DROBOAPPS_DIR}/apache/conf/includes/proftpdapp.conf"

# backwards compatibility
if [ -z "${FRAMEWORK_VERSION:-}" ]; then
  framework_version="2.0"
  . "${prog_dir}/libexec/service.subr"
fi

# Only shares that are exposed for 'Everyone' will be auto-published
_load_shares() {
  local share_count
  local share_name
  local share_file
  local everyone

  echo -n "" > "${sharesfile}"
  share_count=$("${prog_dir}/libexec/xmllint" --xpath "count(//Share)" "${shares_conf}")
  if [ ${share_count} -eq 0 ]; then
    echo "No shares found."
  else
    echo "Found ${share_count} shares."
    for i in $(seq 1 ${share_count}); do
      share_name=$("${prog_dir}/libexec/xmllint" --xpath "//Share[${i}]/ShareName/text()" "${shares_conf}")
      share_file="${prog_dir}/etc/share_${share_name}.conf"
      # $everyone == 1, rw; $everyone == 0, ro; $everyone == '', no access
      everyone=$("${prog_dir}/libexec/xmllint" --xpath "//Share[${i}]/ShareUsers/ShareUser[ShareUsername/text()='Everyone']/ShareUserAccess/text()" "${shares_conf}" 2> /dev/null) || true
      if [ -z "${everyone}" ]; then
        # no access for Everyone
        continue
      elif [ ${everyone} -eq 1 ]; then
        # Everyone has write access
        sed -e "s|##0##|${shares_dir}/${share_name}|g" -e "s|##1##|${share_name}|g" "${rw_template}" > "${share_file}"
        echo "Include ${share_file}" >> "${sharesfile}"
      elif [ ${everyone} -eq 0 ]; then
        # Everyone has read-only access
        sed -e "s|##0##|${shares_dir}/${share_name}|g" -e "s|##1##|${share_name}|g" "${ro_template}" > "${share_file}"
        echo "Include ${share_file}" >> "${sharesfile}"
      fi
    done
  fi
}

start() {
  if [ -f "${autofile}" ]; then
    _load_shares
  fi

  "${daemon}" -c "${conffile}" -S 0.0.0.0
  cp -vf "${appconffile}" "${apachefile}"
  "${apachedaemon}" restart || true
}

stop() {
  rm -vf "${apachefile}"
  "${apachedaemon}" restart || true
  killall proftpd
}

force_stop() {
  rm -vf "${apachefile}"
  "${apachedaemon}" restart || true
  killall -9 proftpd
}

reload() {
  if [ -f "${autofile}" ]; then
    _load_shares
  fi
  killall -q -1 proftpd
}

# boilerplate
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
STDOUT=">&3"
STDERR=">&4"
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o xtrace   # enable script tracing

main "${@}"
