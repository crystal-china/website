# The website for https://crystal-china.org

# Development

## Development dependencies

- Crystal and Shards
- [Lucky CLI](https://luckyframework.org/guides/getting-started/installing)
- PostgreSQL client tools
- Bun
- Podman (required by the scripts; Docker compatibility is not guaranteed)

## Running locally

1. Install [Crystal](https://crystal-lang.org/install/) and the development dependencies above.

2. From the project root, start PostgreSQL with PGroonga and initialize the app:

   ```bash
   script/deps.sh
   crystal run script/setup.cr
   ```
3. Run `lucky dev` to start the app

# Deployment

**No local Crystal, Shards or Bun installation is needed for deployment only; Podman runs them all in containers.** Basic Linux tools and cross-architecture emulation are still required as shown below.

Frontend assets are embedded in the static binary. Markdown files remain external and can be updated without rebuilding.

## Rootless Podman Quadlet (recommended)

This example builds on AMD64 Arch Linux and deploys to an ARM64 Raspberry Pi 5 running Debian 13 with systemd, reachable with `ssh pi`.

1. Install the build tools and Podman with ARM64 emulation on the local development machine:

   ```bash
   sudo pacman -Syu --needed podman qemu-user-static qemu-user-static-binfmt binutils
   sudo systemctl restart systemd-binfmt.service
   mkdir -p ~/.config/containers/registries.conf.d
   printf '%s\n' 'unqualified-search-registries = ["docker.io"]' > ~/.config/containers/registries.conf.d/10-docker-io.conf
   podman run --rm --platform linux/arm64 docker.io/library/alpine:3.24 uname -m
   ```

   The last command should print `aarch64`. For rootless user setup, see [ArchWiki: Podman](https://wiki.archlinux.org/title/Podman#Rootless_Podman).

2. Connect with `ssh pi` and install Podman. [Debian 13 provides Podman 5.4](https://packages.debian.org/trixie/podman) with Quadlet:

   ```bash
   sudo apt update
   sudo apt install -y podman
   podman --version
   exit
   ```

3. On the local machine, clone the project and its submodules, install dependencies, and build the frontend:

   ```bash
   git clone --recurse-submodules https://github.com/crystal-china/website.git
   cd website
   build_scripts/bin/crystal_build_arm64_binary --deps-only # Install Shards dependencies into lib/.
   podman run --rm -v "$PWD:/app" -w /app docker.io/oven/bun:1 bun install --frozen-lockfile
   podman run --rm -v "$PWD:/app" -w /app docker.io/oven/bun:1 bun run prod
   ```

4. The script uses `shards build` to cross-compile the static ARM64 application binary:

   ```bash
   build_scripts/bin/crystal_build_arm64_binary --release # Generates bin/crystal_china
   ```

5. Pass `tasks.cr` as the first argument to use `crystal build` and generate the static `bin/tasks` binary:

   ```bash
   build_scripts/bin/crystal_build_arm64_binary ./tasks.cr -o bin/tasks
   ```

   `bin/tasks` is not included in the application image. It runs directly on the Pi, connecting to PostgreSQL through the pod's published port at `127.0.0.1:5432`.

   For an AMD64 target, replace the three build commands in steps 3-5 with:

   ```bash
   build_scripts/bin/crystal_build_amd64_binary --deps-only
   build_scripts/bin/crystal_build_amd64_binary --release
   build_scripts/bin/crystal_build_amd64_binary ./tasks.cr -o bin/tasks
   ```

   ARM64 emulation and its verification in step 1 can be skipped. The packaging command in step 6 automatically detects the binary's architecture.

6. Package and transfer the application image for Quadlet deployment.

   Create a local container image containing `bin/crystal_china`, timezone data and CA certificates:

   ```bash
   build_scripts/bin/crystal_package_image bin/crystal_china localhost/crystal-china:latest
   ```

   Transfer the image to the Pi's Podman storage over SSH:

   ```bash
   podman save localhost/crystal-china:latest | ssh pi 'podman load'
   ```

   Alternatively, copy `bin/crystal_china` directly to the Pi without packaging an image. See [Native binary deployment](#native-binary-deployment).

7. Create the runtime directories on the Pi:

   ```bash
   ssh pi 'mkdir -p ~/apps/crystal_china_production/bin ~/apps/crystal_china_production/public ~/apps/crystal_china_production/script ~/.config/containers/systemd'
   ```

   Copy these files from the local project directory to the Pi. The optional Patchy uploader is excluded:

   ```bash
   scp -p bin/tasks pi:apps/crystal_china_production/bin/
   scp -p script/wait-dependencies.sh pi:apps/crystal_china_production/script/
   scp -pr public/markdowns pi:apps/crystal_china_production/public/
   scp -p .env.sample pi:apps/crystal_china_production/
   scp -p \
     podman/containers/systemd/crystal_china.pod \
     podman/containers/systemd/crystal_china_pg.container \
     podman/containers/systemd/crystal_china_pg.env \
     podman/containers/systemd/crystal_china_pgdata.volume \
     podman/containers/systemd/crystal_china_redis.container \
     podman/containers/systemd/crystal_china_web.container \
     pi:.config/containers/systemd/
   ```

8. On the Pi, create `~/apps/crystal_china_production/.env`, for example:

   ```dotenv
   LUCKY_ENV=production
   SECRET_KEY_BASE=REPLACE_WITH_A_NEW_RANDOM_SECRET
   HOST=0.0.0.0
   PORT=5000
   APP_DOMAIN=https://community.example.com
   ASSET_HOST=
   DATABASE_URL=postgres://postgres:CHANGE_ME@127.0.0.1:5432/crystal_china_production
   ADMIN_EMAILS=admin@example.com
   TZ=Asia/Shanghai
   ```

   From `~/apps/crystal_china_production` on the Pi, generate a new `SECRET_KEY_BASE` with `bin/tasks gen.secret_key`.

   Replace the example values. The database password must match `POSTGRES_PASSWORD` in `~/.config/containers/systemd/crystal_china_pg.env`.

   Configure SMTP and the sender address in **Admin > Site settings** after deployment.

9. On the Pi, start the pod and initialize the database before allowing public access. PostgreSQL creates `crystal_china_production` automatically from `POSTGRES_DB` on its first start:

   ```bash
   sudo loginctl enable-linger "$USER"
   systemctl --user daemon-reload
   systemctl --user start crystal_china-pod.service

   cd ~/apps/crystal_china_production
   script/wait-dependencies.sh # Wait up to 100 seconds

   bin/tasks db.migrate
   bin/tasks db.seed.required_data
   bin/tasks db.sync_doc_content
   ```

10. Check that the pod and Web service are running:

    ```bash
    systemctl --user status crystal_china-pod.service crystal_china_web.service --no-pager
    ```

The website listens at `http://127.0.0.1:5000` on the Pi. Point an HTTPS reverse proxy or tunnel at it; production login cookies require HTTPS. The pod starts automatically after reboot. Logs: `journalctl --user -u crystal_china_web.service -n 100 --no-pager`.

PostgreSQL data lives in the `crystal_china_pgdata` volume. Uploads additionally require [Patchy](podman/containers/systemd/crystal_china_patchy.container) and adapting the upload domain in [upload.cr](src/actions/upload.cr).

## Native binary deployment

Run the application directly on the Pi, keeping its dependencies in the Quadlet pod above.

1. Follow steps 1-5 above to build the application and task binaries. Skip image packaging and transfer in step 6.

2. Reuse steps 7-9 for runtime files, environment configuration and database initialization, with these changes:

   Do not copy `crystal_china_web.container` to the Pi. Before starting the pod, remove `PublishPort=127.0.0.1:5000:5000` from its `crystal_china.pod` file so the host application can use port 5000. Keep the database port mapping.

   Set `HOST=127.0.0.1` in the application's `.env` when using a reverse proxy on the same machine.

3. On the local machine, copy the application binary to the Pi:

   ```bash
   scp -p bin/crystal_china pi:apps/crystal_china_production/bin/
   ```

4. On the Pi, run the application from its deployment directory:

   ```bash
   cd ~/apps/crystal_china_production
   bin/crystal_china
   ```

For background operation, use the [systemd service example](nginx/crystal_china.service). [Procodile](https://github.com/crystal-china/procodile) is another option. The HTTPS reverse proxy setup is the same as above.

## Updating documentation

1. Edit files under `public/markdowns/` and update `navigation.yml` when the page should appear in the Sidebar and Pager.
2. Synchronize the directory with `rsync -a public/markdowns/ .../public/markdowns/`. Manually delete obsolete `.md` files from the server.
3. Run `bin/tasks db.sync_doc_content` on the server to update searchable content and remove deleted documents from search. No rebuild or restart is needed.

A Markdown file omitted from `navigation.yml` remains directly accessible and searchable, but it will not appear in the Sidebar or Pager. Visiting a document also syncs its content into the search index.

# Project Notes

- [开发示例数据](docs/sample_data.md)
- [主题未读](docs/topic_unread.md)
- [通知与关注](docs/通知.md)
- [分页计数与公共条数](docs/topic_counters.md)
- [评论删除、撤回与长正文预览](docs/comment_removal.md)
- [用户事件与账户设置](docs/user_events.md)
- [国际化与时区](docs/i18n.md)
- [组件的 current_user](docs/component_context.md)
- [主题草稿](docs/主题草稿.md)
- [正文 HTML](docs/正文HTML.md)
- [用户名与提及](docs/用户名与提及.md)

# Contributing

1. Fork it (<https://github.com/zw963/website/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

# Contributors

- [Billy.Zheng](https://github.com/zw963) - creator and maintainer
