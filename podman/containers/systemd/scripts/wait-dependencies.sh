#!/usr/bin/env bash

# 最多等待 100 秒
deadline=$((SECONDS + 100))

while (( SECONDS < deadline )); do
    # 检查 PostgreSQL
    if timeout 5 podman exec systemd-crystal_china_pg \
        sh -c 'pg_isready -q -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
        >/dev/null 2>&1; then

        # 检查 Redis，必须真正返回 PONG
        pong=$(timeout 5 podman exec systemd-crystal_china_redis \
            redis-cli ping 2>/dev/null)

        if [[ "$pong" == "PONG" ]]; then
            echo "PostgreSQL and Redis are ready"
            exit 0
        fi
    fi

    echo "Waiting for PostgreSQL and Redis..."
    sleep 2
done

echo "Timeout waiting for dependencies" >&2
exit 1
