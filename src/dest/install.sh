#!/usr/bin/env sh
#
# proftpd install script

prog_dir="$(dirname $(realpath ${0}))"
name="$(basename ${prog_dir})"
logfile="/tmp/DroboApps/${name}/install.log"
servercrt="${prog_dir}/etc/server.crt"
serverkey="${prog_dir}/etc/server.key"

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

# enable script tracing
set -o xtrace

# copy default configuration files
for deffile in ${prog_dir}/etc/*.default; do
  basefile="${prog_dir}/etc/$(basename ${deffile} .default)"
  if [[ ! -f "${basefile}" ]]; then
    cp -vf "${deffile}" "${basefile}"
  fi
done

# generate ssh keys
if [[ ! -f "${servercrt}" ]]; then
  "${prog_dir}/libexec/openssl" req -new -x509 -keyout "${serverkey}" -out "${servercrt}" -days 3650 -nodes -subj '/C=US/ST=CA/L=Santa Clara/CN=drobo-5n.local'
fi
