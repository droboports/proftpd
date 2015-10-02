#!/usr/bin/env sh
#
# install script

prog_dir="$(dirname "$(realpath "${0}")")"
name="$(basename "${prog_dir}")"
tmp_dir="/tmp/DroboApps/${name}"
logfile="${tmp_dir}/install.log"
servercrt="${prog_dir}/etc/server.crt"
serverkey="${prog_dir}/etc/server.key"
incron_dir="/etc/incron.d"

# boilerplate
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o xtrace   # enable script tracing

# copy default configuration files
find "${prog_dir}" -type f -name "*.default" -print | while read deffile; do
  basefile="$(dirname "${deffile}")/$(basename "${deffile}" .default)"
  if [ ! -f "${basefile}" ]; then
    cp -vf "${deffile}" "${basefile}"
  fi
done

# generate ssh keys
if [ ! -f "${servercrt}" ] || [ ! -f "${serverkey}" ]; then
  "${prog_dir}/libexec/openssl" req -new -x509 \
    -keyout "${serverkey}" -out "${servercrt}" -days 3650 -nodes \
    -subj '/C=US/ST=CA/L=Santa Clara/CN=drobo-5n.local'
fi

if [ -d "${incron_dir}" ] && [ ! -f "${incron_dir}/${name}" ]; then
  cp -f "${prog_dir}/${name}.incron" "${incron_dir}/${name}"
fi

# install apache 2.x
/usr/bin/DroboApps.sh install_version apache 2
