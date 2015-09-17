#!/usr/bin/env sh
#
# update script

prog_dir="$(dirname "$(realpath "${0}")")"
name="$(basename "${prog_dir}")"
tmp_dir="/tmp/DroboApps/${name}"
logfile="${tmp_dir}/update.log"

# boilerplate
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o xtrace   # enable script tracing

/bin/sh "${prog_dir}/service.sh" stop

if [ -f "/var/log/xferlog" ]; then
  mv "/var/log/xferlog"* "${tmp_dir}"
fi

if [ -f "${prog_dir}/etc/proftpd.conf" ]; then
  if ! grep -q "TransferLog" "${prog_dir}/etc/proftpd.conf"; then
    echo "TransferLog ${tmp_dir}/xferlog" >> "${prog_dir}/etc/proftpd.conf"
  fi
  if grep -q "SystemLog.*${tmp_dir}/log.txt" "${prog_dir}/etc/proftpd.conf"; then
    sed -e "s|SystemLog.*${tmp_dir}/log.txt|SystemLog ${tmp_dir}/proftpd.log|g" -i "${prog_dir}/etc/proftpd.conf"
  fi
  if ! grep -q "Include.*shares.conf" "${prog_dir}/etc/proftpd.conf"; then
    echo "Include ${prog_dir}/etc/shares.conf" >> "${prog_dir}/etc/proftpd.conf"
  fi
fi
