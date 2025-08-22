#!/usr/bin/env bash

set -eu

ROOT=$(dirname "$0")
ROOT=$(cd "$ROOT/.." &>/dev/null && pwd)

tag_name=build_crystal_amd64_static_binary

if which -a podman &>/dev/null; then
    cmd=podman
else
    cmd=docker
fi

# 调试输出，使用 --progress=plain --no-cache
$cmd build -t ${tag_name} -f $ROOT/script/Dockerfile.${tag_name} $ROOT

$cmd run -it -v $ROOT:/app ${tag_name} "${@}"
