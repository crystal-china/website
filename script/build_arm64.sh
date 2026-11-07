#!/usr/bin/env bash

build_folder=build_scripts/bin
script=build_scripts/bin/crystal_build_arm64_binary

[ -e "$script" ] || git submodule update --init --recursive

# 平时升级子模块运行这个，然后提交 commit
# git submodule update --remote build_scripts

$script --release && $build_folder/crystal_package_image
# docker run --rm crystal_china /app/binary

# podman image scp localhost/crystal-china:latest pi::
podman save localhost/crystal-china | ssh pi 'podman load'
