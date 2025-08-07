#!/usr/bin/env bash

set -eu

ROOT=${0%/*}/
ROOT=`cd "$ROOT/.." &>/dev/null && pwd`

tag_name=build_crystal_amd64_static_binary

# 调试输出，使用 --progress=plain --no-cache
docker build -t ${tag_name} -f $ROOT/script/Dockerfile.${tag_name} $ROOT

docker run -it -v $ROOT:/app ${tag_name} "${@}"
