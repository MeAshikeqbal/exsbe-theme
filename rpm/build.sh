#!/usr/bin/env bash
# Build exsbe-plymouth RPM in a throwaway Fedora container (no host packages needed).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-$HERE/../plymouth/exsbe}"
podman run --rm --security-opt label=disable \
  -v "$HERE:/work" -v "$SRC:/src/exsbe:ro" registry.fedoraproject.org/fedora:44 bash -c '
    dnf -y -q install rpm-build >/dev/null
    mkdir -p /root/rpmbuild/SOURCES && cp -r /src/exsbe /root/rpmbuild/SOURCES/
    rpmbuild -bb /work/exsbe-plymouth.spec >/dev/null
    cp /root/rpmbuild/RPMS/noarch/*.rpm /work/'
ls "$HERE"/*.rpm
