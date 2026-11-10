#!/usr/bin/env bash

set -euo pipefail

build_folder=build_scripts/bin
script=build_scripts/bin/crystal_build_arm64_binary

[ -e "$script" ] || git submodule update --init --recursive

# 平时升级子模块运行这个，然后提交 commit
# git submodule update --remote build_scripts

$script --release &&
    $build_folder/crystal_package_image bin/crystal_china localhost/crystal-china:latest &&
    podman save localhost/crystal-china | ssh pi 'podman load'

# podman image scp localhost/crystal-china:latest pi::
