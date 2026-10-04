#!/bin/bash
# PocketForge: build the Termux bootstrap for com.pocketforge.app, aarch64 only.
#
# Why this exists rather than using scripts/run-docker.sh
# -------------------------------------------------------
# run-docker.sh is written for a Linux host and does three things that cannot work
# here:
#
#   1. It passes --security-opt seccomp=scripts/profile.json and loads AppArmor
#      profiles. Both are Linux LSM mechanisms; Docker Desktop's Linux VM accepts
#      the seccomp file but has no apparmor_parser, and the script then dies on
#      `aa-status`. We are not upstream and do not need their LSM lockdown.
#   2. It chowns the checkout to the host uid (__change_builder_uid_gid). On a
#      Windows bind mount that mapping is meaningless and the chown walks the whole
#      tree; the container's own builder user is left alone.
#   3. It derives the repo root with `readlink -f $0`. Git-for-Windows bash is not
#      on PATH on this host (WSL has no distribution installed), so this file is
#      executed *inside* the container instead -- see scripts/pf-docker.sh.
#
# What is deliberately NOT changed: the builder image, the container, and every
# build step. This runs upstream's own build-bootstraps.sh inside upstream's own
# image. The only edits are to the build inputs -- scripts/properties.sh and
# packages/termux-tools/build.sh, both already applied in this checkout -- which is
# what makes the resulting binaries say com.pocketforge.app.
#
# Invoked as: scripts/pf-docker.sh clean | scripts/pf-docker.sh [extra args]
set -euo pipefail

cd /home/builder/termux-packages

if [ "${1:-}" = "clean" ]; then
	# Mandatory after changing the package name. The builder caches built debs
	# under /data/data/.built-packages keyed by package name, so a binary compiled
	# for com.termux would otherwise be reused silently -- the exact failure this
	# build exists to avoid.
	echo "[*] Running clean.sh..."
	./clean.sh
	echo "[*] Cleaned."
	exit 0
fi

echo "[*] Building bootstrap for com.pocketforge.app (aarch64)."
echo "[*] Hours, unattended. The host stays usable."
./scripts/build-bootstraps.sh --architectures aarch64 -f "$@"

echo "[*] Locating the bootstrap archive..."
find /home/builder/termux-packages/output -name 'bootstrap-aarch64.zip' -exec ls -la {} \;2>/dev/null || true