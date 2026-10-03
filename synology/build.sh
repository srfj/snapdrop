#!/bin/bash
#
# Build the Snapdrop Synology package (.spk) for DSM 6.2.3.
#
# The application source lives in the repository root; this script assembles a
# "noarch" package so it can be installed on any DSM 6.2.3 NAS. The Node.js
# runtime is provided by Synology's official "Node.js v12" package (declared via
# install_dep_packages in INFO), so only pure-JavaScript dependencies are bundled.
#
# Usage:  ./build.sh
# Output: snapdrop-noarch-6.2.3_<version>-<revision>.spk

set -euo pipefail

PKG_NAME="snapdrop"
PKG_VERSION="2.0.0"
PKG_REV="6"
SPK_OS="6.2.3"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
PAYLOAD_DIR="${BUILD_DIR}/package"
SPK_DIR="${BUILD_DIR}/spk"

echo "==> Cleaning build directory"
rm -rf "${BUILD_DIR}"
mkdir -p "${PAYLOAD_DIR}" "${SPK_DIR}/scripts" "${SPK_DIR}/conf" "${SPK_DIR}/WIZARD_UIFILES"

echo "==> Copying application payload"
cp "${SRC_DIR}/index.js" \
   "${SRC_DIR}/nameGenerator.js" \
   "${SRC_DIR}/package.json" \
   "${SRC_DIR}/README.md" \
   "${PAYLOAD_DIR}/"
cp -R "${SRC_DIR}/public" "${PAYLOAD_DIR}/public"
# Port-config protocol file (.sc). DSM copies it to /usr/local/etc/service.d so
# the service shows up in the firewall / port-forwarding application lists; the
# installer stamps the user-selected port into it (see scripts/set-port).
cp -R "${SCRIPT_DIR}/port_conf" "${PAYLOAD_DIR}/port_conf"
# DSM desktop shortcut (app/config + icons). The port inside app/config is
# stamped with the user-selected port at install time (see scripts/set-port).
cp -R "${SCRIPT_DIR}/app" "${PAYLOAD_DIR}/app"

echo "==> Installing production dependencies"
( cd "${PAYLOAD_DIR}" && npm install --omit=dev --no-audit --no-fund --loglevel=error )
rm -rf "${PAYLOAD_DIR}/node_modules/.bin" "${PAYLOAD_DIR}/package-lock.json"

echo "==> Packing package.tgz"
( cd "${PAYLOAD_DIR}" && tar czf "${BUILD_DIR}/package.tgz" . )

echo "==> Assembling package"
cp "${SCRIPT_DIR}/INFO" "${SPK_DIR}/INFO"
cp -R "${SCRIPT_DIR}/scripts/." "${SPK_DIR}/scripts/"
cp -R "${SCRIPT_DIR}/conf/." "${SPK_DIR}/conf/"
cp -R "${SCRIPT_DIR}/WIZARD_UIFILES/." "${SPK_DIR}/WIZARD_UIFILES/"
cp "${SCRIPT_DIR}/PACKAGE_ICON.PNG" "${SPK_DIR}/PACKAGE_ICON.PNG"
cp "${SCRIPT_DIR}/PACKAGE_ICON_256.PNG" "${SPK_DIR}/PACKAGE_ICON_256.PNG"
cp "${BUILD_DIR}/package.tgz" "${SPK_DIR}/package.tgz"

chmod 755 "${SPK_DIR}/scripts/"*
chmod 644 "${SPK_DIR}/INFO" "${SPK_DIR}/conf/"* "${SPK_DIR}/WIZARD_UIFILES/"* \
          "${SPK_DIR}/PACKAGE_ICON.PNG" "${SPK_DIR}/PACKAGE_ICON_256.PNG"

echo "==> Writing checksum into INFO"
CHECKSUM="$(md5sum "${SPK_DIR}/package.tgz" | cut -d' ' -f1)"
sed -i "s/__CHECKSUM__/${CHECKSUM}/" "${SPK_DIR}/INFO"
echo "    package.tgz md5 = ${CHECKSUM}"

echo "==> Creating .spk"
SPK_FILE="${SCRIPT_DIR}/${PKG_NAME}-noarch-${SPK_OS}_${PKG_VERSION}-${PKG_REV}.spk"
rm -f "${SPK_FILE}"
( cd "${SPK_DIR}" && tar czf "${SPK_FILE}" \
    INFO package.tgz scripts conf WIZARD_UIFILES PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG )

echo "==> Done: ${SPK_FILE}"
