#!/usr/bin/env bash

set -euo pipefail

podman run --rm -v "$PWD:/app" -w /app docker.io/oven/bun:1 bun run prod
build_folder=build_scripts/bin
script=build_scripts/bin/crystal_build_arm64_binary

[ -e "$script" ] || git submodule update --init --recursive

# 平时升级子模块运行这个，然后提交 commit
# git submodule update --remote build_scripts

"$script" --release
"$build_folder/crystal_package_image" bin/crystal_china localhost/crystal-china:latest

# 保留远端同名的未压缩归档，供下次 rsync 增量传输使用。
rm -f -- bin/crystal-china.tar
podman save -o bin/crystal-china.tar localhost/crystal-china:latest
ssh pi 'mkdir -p ~/apps/crystal_china_production'
rsync -vz --progress --stats bin/crystal-china.tar pi:apps/crystal_china_production/crystal-china.tar
ssh pi 'podman load -i ~/apps/crystal_china_production/crystal-china.tar'

# podman save localhost/crystal-china | ssh pi 'podman load'

# podman image scp localhost/crystal-china:latest pi::
