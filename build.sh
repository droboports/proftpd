#!/usr/bin/env bash

### bash best practices ###
# exit on error code
set -o errexit
# exit on unset variable
set -o nounset
# return error of last failed command in pipe
set -o pipefail
# expand aliases
shopt -s expand_aliases
# print trace
set -o xtrace

### logfile ###
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
logfile="logfile_${timestamp}.txt"
echo "${0} ${@}" > "${logfile}"
# save stdout to logfile
exec 1> >(tee -a "${logfile}")
# redirect errors to stdout
exec 2> >(tee -a "${logfile}" >&2)

### environment variables ###
source crosscompile.sh
export NAME="proftpd"
export DEST="/mnt/DroboFS/Shares/DroboApps/${NAME}"
export DEPS="${PWD}/target/install"
export CFLAGS="${CFLAGS:-} -Os -fPIC"
export CXXFLAGS="${CXXFLAGS:-} ${CFLAGS}"
export CPPFLAGS="-I${DEPS}/include"
export LDFLAGS="${LDFLAGS:-} -Wl,-rpath,${DEST}/lib -L${DEST}/lib"
alias make="make -j8 V=1 VERBOSE=1"

# $1: file
# $2: url
# $3: folder
_download_tgz() {
  [[ ! -f "download/${1}" ]] && wget -O "download/${1}" "${2}"
  [[ -d "target/${3}" ]] && rm -v -fr "target/${3}"
  [[ ! -d "target/${3}" ]] && tar -zxvf "download/${1}" -C target
}

### ZLIB ###
_build_zlib() {
local VERSION="1.2.8"
local FOLDER="zlib-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://zlib.net/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd target/"${FOLDER}"
./configure --prefix="${DEPS}" --libdir="${DEST}/lib"
make
make install
rm -v "${DEST}/lib"/*.a
popd
}

### OPENSSL ###
_build_openssl() {
local OPENSSL_VERSION="1.0.1i"
local OPENSSL_FOLDER="openssl-${OPENSSL_VERSION}"
local OPENSSL_FILE="${OPENSSL_FOLDER}.tar.gz"
local OPENSSL_URL="http://www.openssl.org/source/${OPENSSL_FILE}"

_download_tgz "${OPENSSL_FILE}" "${OPENSSL_URL}" "${OPENSSL_FOLDER}"
pushd target/"${OPENSSL_FOLDER}"
./Configure --prefix="${DEPS}" \
  --openssldir="${DEST}/etc/ssl" \
  --with-zlib-include="${DEPS}/include" \
  --with-zlib-lib="${DEPS}/lib" \
  shared zlib-dynamic threads linux-armv4 -DL_ENDIAN ${CFLAGS} ${LDFLAGS}
sed -i -e "s/-O3//g" Makefile
make -j1
make install_sw
mkdir -p "${DEST}"/libexec
cp -avR "${DEPS}/bin/openssl" "${DEST}/libexec/"
cp -avR "${DEPS}/lib"/* "${DEST}/lib/"
rm -fvr "${DEPS}/lib"
rm -fv "${DEST}/lib"/*.a
sed -i -e "s|^exec_prefix=.*|exec_prefix=${DEST}|g" "${DEST}"/lib/pkgconfig/openssl.pc
popd
}

### SQLITE ###
_build_sqlite() {
local VERSION="3080600"
local FOLDER="sqlite-autoconf-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://sqlite.org/2014/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd target/"${FOLDER}"
./configure --host=arm-none-linux-gnueabi --prefix="${DEPS}" --libdir="${DEST}/lib" --disable-static
make
make install
mkdir -p "${DEST}/libexec"
cp -av "${DEPS}/bin/sqlite3" "${DEST}/libexec/"
popd
}

### MYSQL-CONNECTOR ###
_build_mysql() {
local VERSION="6.1.5"
local FOLDER="mysql-connector-c-${VERSION}-src"
local FILE="${FOLDER}.tar.gz"
local URL="http://cdn.mysql.com/Downloads/Connector-C/${FILE}"
export FOLDER_HOST="${FOLDER}-host"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
[[ -d target/"${FOLDER_HOST}" ]] && rm -v -fr target/"${FOLDER_HOST}"
[[ ! -d target/"${FOLDER_HOST}" ]] && cp -v -aR target/"${FOLDER}" target/"${FOLDER_HOST}"

( source uncrosscompile.sh
  pushd target/"${FOLDER_HOST}"
  cmake .
  make comp_err )

pushd target/"${FOLDER}"
cat > "cmake_toolchain_file.$ARCH" << EOF
SET(CMAKE_SYSTEM_NAME Linux)
SET(CMAKE_SYSTEM_PROCESSOR ${ARCH})
SET(CMAKE_C_COMPILER ${CC})
SET(CMAKE_CXX_COMPILER ${CXX})
SET(CMAKE_AR ${AR})
SET(CMAKE_RANLIB ${RANLIB})
SET(CMAKE_STRIP ${STRIP})
SET(CMAKE_CROSSCOMPILING TRUE)
SET(STACK_DIRECTION 1)
SET(CMAKE_FIND_ROOT_PATH ${TOOLCHAIN}/arm-none-linux-gnueabi/libc)
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

ln -v -fs $DEST/lib/libz.so $DEST/lib/libzlib.so
mv -v zlib/CMakeLists.txt{,.orig}
touch zlib/CMakeLists.txt
LDFLAGS="${LDFLAGS} -lz" cmake . -DCMAKE_TOOLCHAIN_FILE="./cmake_toolchain_file.${ARCH}" -DCMAKE_AR="${AR}" -DCMAKE_STRIP="${STRIP}" -DCMAKE_INSTALL_PREFIX="${DEPS}" -DENABLED_PROFILING=OFF -DENABLE_DEBUG_SYNC=OFF -DWITH_PIC=ON -DWITH_SSL=system -DOPENSSL_ROOT_DIR="${DEPS}" -DOPENSSL_INCLUDE_DIR="${DEPS}/include" -DOPENSSL_LIBRARY="${DEST}/lib/libssl.so" -DCRYPTO_LIBRARY="$DEST/lib/libcrypto.so" -DWITH_ZLIB=system -DZLIB_INCLUDE_DIR="$DEPS/include" -DCMAKE_REQUIRED_LIBRARIES=z -DHAVE_LLVM_LIBCPP_EXITCODE=1 -DHAVE_GCC_ATOMIC_BUILTINS=1
make -j1 || true
sed -i -e "s|\&\& comp_err|\&\& ./comp_err|g" extra/CMakeFiles/GenError.dir/build.make
cp -v ../mysql-connector-c-6.1.5-src-host/extra/comp_err extra/
make -j1
make install
cp -v -aR "${DEPS}/lib"/*.so* "${DEST}/lib/"
rm -v -fr "${DEPS}/lib"
popd
}

### PROFTPD ###
## TODO: mod_geoip, mod_ldap, mod_snmp
_build_proftpd() {
local VERSION="1.3.5"
local FOLDER="proftpd-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="ftp://ftp.proftpd.org/distrib/source/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd target/"${FOLDER}"
./configure --host=arm-none-linux-gnueabi --prefix="${DEST}" --mandir="${DEST}/man" --disable-static \
  --disable-strip --enable-dso --enable-ctrls --enable-openssl \
  --with-modules=mod_copy:mod_dnsbl:mod_exec:mod_ifsession:mod_load:mod_quotatab:mod_quotatab_file:mod_quotatab_sql:mod_ratio:mod_readme:mod_rewrite:mod_sftp:mod_sftp_sql:mod_shaper:mod_site_misc:mod_sql:mod_sql_mysql:mod_sql_sqlite:mod_sql_passwd:mod_tls:mod_unique_id \
  --with-libraries="${DEST}/lib" --with-openssl-cmdline="${DEST}/libexec/openssl" \
  install_user="$(id -un)" install_group="$(id -gn)" \
  ac_cv_func_setpgrp_void=yes ac_cv_func_setgrent_void=yes LIBS="${LIBS:-} $(${CC} -print-file-name=libresolv.a)"
pushd lib/libcap
make CC=cc CFLAGS="" LDFLAGS="" _makenames
popd
make
make install
popd
}

### BUILD ###
_build() {
  _build_zlib
  _build_openssl
  _build_sqlite
  _build_mysql
  _build_proftpd
  _package
}

_create_tgz() {
  local appname="$(basename ${PWD})"
  local appfile="${PWD}/${appname}.tgz"

  if [[ -f "${appfile}" ]]; then
    rm -v "${appfile}"
  fi

  pushd "${DEST}"
  tar --verbose --create --numeric-owner --owner=0 --group=0 --gzip --file "${appfile}" *
  popd
}

_package() {
  mv -v "${DEST}/etc/proftpd.conf"{,.orig} || true
  ln -v -fs "${DEST}/etc/config_admin.php" "src/dest/www/configs/config.php"
  chmod a+rwx "${DEST}/var"

  cp -v -faR src/dest/* "${DEST}"/
  find "${DEST}" -name "._*" -print -delete
  _create_tgz
}

_clean() {
  rm -v -fr "${DEPS}"
  rm -v -fr "${DEST}"
  rm -v -fr target/*
}

_dist_clean() {
  _clean
  rm -v -f logfile*
  rm -v -fr download/*
}

case "${1:-}" in
  clean)     _clean ;;
  distclean) _dist_clean ;;
  package)   _package ;;
  "")        _build ;;
  *)         _build_${1} ;;
esac
