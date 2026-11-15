#!/usr/bin/env bash

# Arch linux 上测试，使用 podman 新版的默认驱动，并且本地是 btrfs（不确定是相关因素）
# 有时候会出现卡死的情况，运行下面的命令可解决
# podman system renumber

ROOT=$(dirname "$0")
ROOT=$(cd "$ROOT/.." &>/dev/null && pwd)

remove=false

if [[ "${1-}" == "--remove" ]]; then
    remove=true
    shift
fi

project_name=${1-crystal_china}
# 与 Quadlet 默认生成的 Pod 和容器名称一致。
pod_name="systemd-${project_name}"

[ -f .env ] && source .env

DB_NAME=${DB_NAME-$(echo $DATABASE_URL |rev |cut -d / -f1 |rev)}
common_part=$(echo $DATABASE_URL |grep -o '://[^@]*' |rev |cut -d / -f1 |rev)
DB_USERNAME=${DB_USERNAME-$(echo $common_part |cut -d : -f1)}
DB_PASSWORD=${DB_PASSWORD-$(echo $common_part |cut -d : -f2)}

set -eu

# --remove 重建依赖容器，保留数据库 volume。
if [[ "$remove" == true ]] && podman pod exists "$pod_name"; then
    podman pod stop "$pod_name"
    podman pod rm -f "$pod_name"
    exit 0
fi

if podman volume exists crystal_china_pgdata; then
    echo "crystal_china_pgdata volume exists"
else
    podman volume create crystal_china_pgdata
fi

if podman pod exists $pod_name; then
    if [ "$(podman inspect --format '{{.Config.Image}}' "${pod_name}_pg")" != "docker.io/groonga/pgroonga:4.1.0-debian-18" ]; then
        echo "${pod_name}_pg 仍是旧镜像；请先备份数据库并重建 pod（不要删除 crystal_china_pgdata volume）" >&2
        exit 1
    fi
    podman pod start $pod_name
else
    podman pod create --name $pod_name -p 127.0.0.1:5432:5432 -p 127.0.0.1:6379:6379

    # podman pod list

    podman run \
           --pod $pod_name \
           --name ${pod_name}_pg \
           -e POSTGRES_USER=${DB_USERNAME:-postgres} \
           -e POSTGRES_DB=${DB_NAME:-${project_name}_development} \
           -e POSTGRES_PASSWORD=${DB_PASSWORD:-postgres} \
           -v crystal_china_pgdata:/var/lib/postgresql \
           -d docker.io/groonga/pgroonga:4.1.0-debian-18

    podman run \
           --pod ${pod_name} \
           --name ${pod_name}_redis \
           -d docker.io/library/redis:8-alpine
fi

for _ in {1..30}; do
    if podman exec "${pod_name}_pg" pg_isready -q -U "${DB_USERNAME:-postgres}" > /dev/null 2>&1; then
        break
    fi
    sleep 1
done
podman exec "${pod_name}_pg" pg_isready -U "${DB_USERNAME:-postgres}"

podman ps --pod

# clean up

# podman generate kube "$pod_name" > crystal_china_pod.yml
# podman play kube crystal_china_pod.yaml

# podman generate systemd --name "$pod_name" --new --file

# sudo loginctl enable-linger $(whoami)
