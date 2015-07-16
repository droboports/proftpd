### ZLIB ###
_build_zlib() {
local VERSION="1.2.8"
local FOLDER="zlib-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://zlib.net/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --prefix="${DEPS}" --libdir="${DEST}/lib"
make
make install
rm -v "${DEST}/lib/libz.a"
popd
}

### OPENSSL ###
_build_openssl() {
local VERSION="1.0.2d"
local FOLDER="openssl-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://www.openssl.org/source/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
cp -vf "src/${FOLDER}-parallel-build.patch" "target/${FOLDER}/"
pushd "target/${FOLDER}"
patch -p1 -i "${FOLDER}-parallel-build.patch"
./Configure --prefix="${DEPS}" --openssldir="${DEST}/etc/ssl" \
  zlib-dynamic --with-zlib-include="${DEPS}/include" --with-zlib-lib="${DEPS}/lib" \
  shared threads linux-armv4 -DL_ENDIAN ${CFLAGS} ${LDFLAGS} -Wa,--noexecstack -Wl,-z,noexecstack
sed -i -e "s/-O3//g" Makefile
make
make install_sw
mkdir -p "${DEST}/libexec/"
cp -vfa "${DEPS}/bin/openssl" "${DEST}/libexec/"
cp -vfaR "${DEPS}/lib"/* "${DEST}/lib/"
rm -vfr "${DEPS}/lib"
rm -vf "${DEST}/lib/libcrypto.a" "${DEST}/lib/libssl.a"
sed -i -e "s|^exec_prefix=.*|exec_prefix=${DEST}|g" "${DEST}/lib/pkgconfig/openssl.pc"
popd
}

### SQLITE ###
_build_sqlite() {
local VERSION="3081002"
local FOLDER="sqlite-autoconf-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://sqlite.org/$(date +%Y)/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --host="${HOST}" --prefix="${DEPS}" --libdir="${DEST}/lib" --disable-static
make
make install
mkdir -p "${DEST}/libexec/"
cp -vfa "${DEPS}/bin/sqlite3" "${DEST}/libexec/"
popd
}

### MYSQL-CONNECTOR ###
_build_mysql() {
local VERSION="6.1.5"
local FOLDER="mysql-connector-c-${VERSION}-src"
local FILE="${FOLDER}.tar.gz"
local URL="http://cdn.mysql.com/Downloads/Connector-C/${FILE}"
export FOLDER_LOCAL="${PWD}/target/${FOLDER}-local"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
[[   -d "${FOLDER_LOCAL}" ]] && rm -vfr "${FOLDER_LOCAL}"
[[ ! -d "${FOLDER_LOCAL}" ]] && cp -faR "target/${FOLDER}" "${FOLDER_LOCAL}"

# native compilation of comp_err
( source uncrosscompile.sh
  pushd "${FOLDER_LOCAL}"
  cmake .
  make comp_err )

pushd "target/${FOLDER}"
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
SET(CMAKE_FIND_ROOT_PATH ${TOOLCHAIN}/${HOST}/libc)
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

# Use existing zlib
ln -vfs libz.so $DEST/lib/libzlib.so
mv -v zlib/CMakeLists.txt{,.orig}
touch zlib/CMakeLists.txt

# Fix regex to find openssl 1.0.2 version
sed -i -e "s/\^#define/^#[\t ]*define/g" -e "s/\+0x/*0x/g" cmake/ssl.cmake

LDFLAGS="${LDFLAGS} -lz" cmake . -DCMAKE_TOOLCHAIN_FILE="./cmake_toolchain_file.${ARCH}" -DCMAKE_AR="${AR}" -DCMAKE_STRIP="${STRIP}" -DCMAKE_INSTALL_PREFIX="${DEPS}" -DENABLED_PROFILING=OFF -DENABLE_DEBUG_SYNC=OFF -DWITH_PIC=ON -DWITH_SSL="${DEPS}" -DOPENSSL_ROOT_DIR="${DEST}" -DOPENSSL_INCLUDE_DIR="${DEPS}/include" -DOPENSSL_LIBRARY="${DEST}/lib/libssl.so" -DCRYPTO_LIBRARY="${DEST}/lib/libcrypto.so" -DWITH_ZLIB=system -DZLIB_INCLUDE_DIR="${DEPS}/include" -DCMAKE_REQUIRED_LIBRARIES=z -DHAVE_LLVM_LIBCPP_EXITCODE=1 -DHAVE_GCC_ATOMIC_BUILTINS=1
if ! make -j1; then
  sed -i -e "s|\&\& comp_err|\&\& ./comp_err|g" extra/CMakeFiles/GenError.dir/build.make
  cp -vf "${FOLDER_LOCAL}/extra/comp_err" extra/
  make -j1
fi
make install
cp -vfaR "${DEPS}/lib"/*.so* "${DEST}/lib/"
popd
}

### PROFTPD ###
_build_proftpd() {
local VERSION="1.3.5a"
local FOLDER="proftpd-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="ftp://ftp.proftpd.org/distrib/source/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
# TODO: mod_geoip, mod_ldap, mod_snmp
./configure --host="${HOST}" --prefix="${DEST}" --mandir="${DEST}/man" --disable-static \
  --disable-strip --enable-dso --enable-ctrls --enable-openssl \
  --with-modules=mod_copy:mod_dnsbl:mod_exec:mod_ifsession:mod_load:mod_quotatab:mod_quotatab_file:mod_quotatab_sql:mod_ratio:mod_readme:mod_rewrite:mod_sftp:mod_sftp_sql:mod_shaper:mod_site_misc:mod_sql:mod_sql_mysql:mod_sql_sqlite:mod_sql_passwd:mod_tls:mod_unique_id \
  --with-libraries="${DEST}/lib" --with-openssl-cmdline="${DEST}/libexec/openssl" \
  install_user="$(id -un)" install_group="$(id -gn)" \
  ac_cv_func_setpgrp_void=yes ac_cv_func_setgrent_void=yes
# compile libltdtl separately to avoid
# "undefined reference to `lt__PROGRAM__LTX_preloaded_symbols'"
pushd lib/libltdl
./configure --host="${HOST}" --prefix="${DEPS}" --libdir="${DEST}/lib" --disable-static --enable-ltdl-convenience --with-pic
make
popd
# compile local tool _makenames
pushd lib/libcap
make CC=cc CFLAGS="" LDFLAGS="" _makenames
popd
make
make install
rm -vf "${DEST}/etc/proftpd.conf"
popd
}

### PHP ###
_build_php() {
local VERSION="5.6.10"
local FOLDER="php-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://ch1.php.net/get/${FILE}/from/this/mirror"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
sed -i -e "/unset ac_cv_func_dlopen/d" -e "/unset ac_cv_lib_dl_dlopen/d" configure
QEMU_LD_PREFIX="${TOOLCHAIN}/${DROBO}/${HOST}/libc" ./configure --host="${HOST}" --prefix="${DEPS}" --bindir="${DEST}/libexec" --libdir="${DEST}/lib" --disable-all --disable-static --disable-cli --enable-cgi --enable-hash --with-pic --with-config-file-path="${DEST}/etc" --with-mysql=shared,"${DEPS}" --with-sqlite3=shared,"${DEPS}" LIBS="-ldl" ac_cv_func_dlopen=yes ac_cv_lib_dl_dlopen=yes
make
make install
rm -vf "${DEST}/libexec/php" "${DEST}/libexec/php-config" "${DEST}/libexec/phpize"
popd
}

### MONGOOSE ###
_build_mongoose() {
local COMMIT="524aa2e58699491b5a0bca53d5fb3e4c33e05d8e"
local FOLDER="mongoose-${COMMIT}"
local FILE="${FOLDER}.zip"
local URL="https://github.com/cesanta/mongoose/archive/${COMMIT}.zip"

_download_zip "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}/examples/web_server"
make
mkdir -p "${DEST}/libexec"
cp web_server "${DEST}/libexec/"
popd
}

### PROFTPD-ADMIN ###
_build_admin() {
local COMMIT="cf4525c88fd97541a29548a6a272270a3364bb93"
local FOLDER="ProFTPd-Admin-${COMMIT}"
local FILE="${FOLDER}.zip"
local URL="https://github.com/droboports/ProFTPd-Admin/archive/${COMMIT}.zip"

_download_zip "${FILE}" "${URL}" "${FOLDER}"
mkdir -p "${DEST}/www"
cp -vfaR "target/${FOLDER}/"* "${DEST}/www/"
}

### BUILD ###
_build() {
  _build_zlib
  _build_openssl
  _build_sqlite
  _build_mysql
  _build_proftpd
  _build_php
  _build_mongoose
  _build_admin
  _package
}
