#!/bin/bash
# PocketForge: host-side driver for the bootstrap build.
#
# Thin on purpose. scripts/run-docker.sh cannot be used on Windows (see
# scripts/pf-build.sh for why), so this does the three things that actually need to
# happen on the host -- pick a container, mount the checkout, exec the in-container
# script -- and leaves every build decision to upstream's build-bootstraps.sh.
#
# The volume path is passed in as PF_REPO_ROOT because Docker Desktop needs a
# Windows-style path for a bind mount while the container sees it as /home/builder.
# Git-for-Windows bash is not on PATH here, so this must be run from inside the
# container, which pf-build.sh arranges.
set -euo pipefail

CONTAINER_NAME=pf-termux-builder
IMAGE=ghcr.io/termux/package-builder
HOST_REPO="${PF_REPO_ROOT:?PF_REPO_ROOT must be set to this checkout's Windows path}"

if ! docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
	echo "[*] Creating builder container..."
	# --init so the container gets a real PID 1: the build forks compilers for
	# hours, and without an init the orphans accumulate until the build dies on
	# process limits. sleep infinity because the wrapper decides when to run what.
	docker run --detach --init --name "$CONTAINER_NAME" \
		--volume "$HOST_REPO:/home/builder/termux-packages" \
		--workdir /home/builder/termux-packages \
		"$IMAGE" sleep infinity >/dev/null
	echo "[*] Created $CONTAINER_NAME"
else
	echo "[*] Reusing $CONTAINER_NAME"
	if [ "$(docker container inspect -f '{{ .State.Running }}' "$CONTAINER_NAME")" != "true" ]; then
		echo "[*] Starting it..."
		docker start "$CONTAINER_NAME" >/dev/null
	fi
fi

docker exec "$CONTAINER_NAME" bash /home/builder/termux-packages/pf-build.sh "$@"