#!/usr/bin/env bash

# Compare native AMD64 Crystal compilers generating ARM64 release object files.
# Run from the project root. Requires Bash and rootless Podman, not QEMU.
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf -- "$tmpdir"' EXIT

cat > "$tmpdir/Dockerfile" <<'DOCKERFILE'
ARG BASE
FROM --platform=linux/amd64 ${BASE}
RUN apk add --no-cache bash git time ca-certificates tzdata \
    yaml-dev openssl-dev zlib-dev libxml2-dev libunwind-dev && \
    if ! command -v crystal >/dev/null; then apk add --no-cache crystal shards; fi
WORKDIR /app
DOCKERFILE

# Pin the official image used for the LLVM 22 measurement.
llvm22_base=docker.io/crystallang/crystal@sha256:450f111328d83be86117c96a795e3ebb1694f6249c45041f94e1a571ccf935ec

for version in 22 23; do
    base=$llvm22_base

    if [[ "$version" == 23 ]]; then
        base=docker.io/library/alpine:edge
    fi

    podman build --platform linux/amd64 --build-arg "BASE=$base" \
        -t "localhost/crystal-llvm-benchmark:$version" -f "$tmpdir/Dockerfile" "$tmpdir"
done

podman run --rm --platform linux/amd64 -v "$PWD:/app" -w /app \
    localhost/crystal-llvm-benchmark:22 \
    shards install --production --ignore-crystal-version --skip-postinstall --skip-executables

if [[ ! -f public/bun-manifest.json ]]; then
    podman run --rm --platform linux/amd64 -v "$PWD:/app" -w /app \
        docker.io/oven/bun:1 bun install --frozen-lockfile
    podman run --rm --platform linux/amd64 -v "$PWD:/app" -w /app \
        docker.io/oven/bun:1 bun run prod
fi

for version in 22 23; do
    output="bin/llvm-benchmark/$version"
    mkdir -p "$output/cache"

    podman run --rm -i --platform linux/amd64 \
        -v "$PWD:/app" -v "$PWD/$output/cache:/root/.cache" \
        -e LLVM_VERSION="$version" -e OUTPUT="$output" \
        "localhost/crystal-llvm-benchmark:$version" bash -s <<'BUILD'
set -euo pipefail

crystal --version | tee "$OUTPUT/compiler-version.txt"
grep -q '^Crystal 1\.22\.3' "$OUTPUT/compiler-version.txt"
grep -q "^LLVM: $LLVM_VERSION\." "$OUTPUT/compiler-version.txt"

args=(
    src/crystal_china.cr -o "$OUTPUT/crystal_china"
    --release --static --stats --time --cross-compile --target=aarch64-linux-musl
    -Dstrict_multi_assign -Dno_number_autocast -Duse_pcre2 -Dpreview_overload_order
    --link-flags=-Wl,-L/app --link-flags=-s --link-flags=-no-pie
)

# Build macro helper programs before timing; do not generate the application .o.
crystal build "${args[@]}" --no-codegen > "$OUTPUT/warmup.log" 2>&1

/usr/bin/time -p -o "$OUTPUT/compile.time" \
    crystal build "${args[@]}" > "$OUTPUT/compile.log" 2>&1

cat "$OUTPUT/compile.time"
grep 'Codegen (bc+obj):' "$OUTPUT/compile.log"
BUILD
done
