#!/usr/bin/env bash

# Arch linux 上测试，使用 podman 新版的默认驱动，并且本地是 btrfs（不确定是相关因素）
# 有时候会出现卡死的情况，运行下面的命令可解决
# podman system renumber

# ROOT=`dirname "$0"`
# ROOT=`cd "$ROOT/.." &>/dev/null && pwd`

ROOT=${0%/*}
ROOT=`cd "$ROOT/.." &>/dev/null && pwd`

pod_name=${1-crystal_china}

# mkdir -p $ROOT/${pod_name}_data/pg_data

[ -f .env ] && source .env

DB_USERNAME=${DB_USERNAME-$(echo $DATABASE_URL |rev |cut -d / -f1 |rev)}
common_part=$(echo $DATABASE_URL |grep -o '://[^@]*' |rev |cut -d / -f1 |rev)
DB_NAME=${DB_NAME-$(echo $common_part |cut -d : -f1)}
DB_PASSWORD=${DB_PASSWORD-$(echo $common_part |cut -d : -f2)}

set -eu

if podman pod exists $pod_name; then
    podman pod start $pod_name
else
    podman pod create --name $pod_name -p 5432:5432 -p 6379:6379

    # podman pod list

    podman run \
           --pod $pod_name \
           --name ${pod_name}_pg \
           -e POSTGRES_USER=${DB_USERNAME:-postgres} \
           -e POSTGRES_DB=${DB_NAME:-${pod_name}_development} \
           -e POSTGRES_PASSWORD=${DB_PASSWORD:-postgres} \
           -d postgres \
           # -v $ROOT/${pod_name}_data/pg_data:/var/lib/postgresql/data

           podman run \
               --pod ${pod_name} \
               --name ${pod_name}_redis \
               -d redis
fi

podman ps --pod

# clean up

# podman pod stop crystal_china && podman pod rm -f crystal_china

# podman generate kube crystal_china > crystal_china_pod.yml
# podman play kube crystal_china_pod.yaml

# podman generate systemd  --name crystal_china_pod --new  --file

# sudo loginctl enable-linger $(whoami)
