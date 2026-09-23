# The website for https://crystal-china.org

# Development dependencies

- Crystal
- pg
- bun
- podman (or docker)

## Development

1. First, install Crystal. You can check out the instructions here: https://crystal-lang.org/install/

3. Run `script/setup`, Just make sure you’ve got `pg` and `bun` installed before running this.

4. Finally, run `lucky dev`, and you're all set!

## Deployment

The application is deployed as a static binary with its frontend assets baked in. Markdown documents deliberately remain outside the binary so they can be updated without recompiling the application.

1. Run `shards run index` to generate `public/markdowns/search-index.st` and its content-based version file. Both generated files are ignored by Git and must still be deployed.

2. Run `bun run prod` to build and precompress the frontend assets into `public/assets`.

3. Build the static binary with `script/build_amd64_static_binary.sh`. This requires Podman or Docker.

   Alternatively, use the [sb_static](https://github.com/crystal-china/magic-haversack/blob/main/bin/sb_static) script with Zig. See [Use Zig CC as an alternative linker](https://github.com/crystal-china/magic-haversack/blob/main/docs/use_zig_cc_as_an_alternative_linker.md) for details.

4. Synchronize `public/markdowns/` and `public/sitemap.xml` to the server with `rsync -a`. The Markdown directory must exist before starting the new binary because the application reads `navigation.yml` during startup.

5. Copy `bin/crystal_china` to the server and configure the environment in `.env`; see [.env.sample](/.env.sample). The deployed application has the following relevant structure:

   ```text
   .
   ├── .env
   ├── bin
   │   └── crystal_china
   └── public
       ├── markdowns
       │   ├── navigation.yml
       │   ├── search-index.st
       │   ├── search-index.st.version
       │   └── ...
       └── sitemap.xml
   ```

6. Add a systemd service to start the server. See [crystal_china.service](/nginx/crystal_china.service). [Procodile](https://github.com/crystal-china/procodile) can be used instead.

7. Optionally, use Nginx as a reverse proxy. Configuration examples are available in the [nginx folder](/nginx).

### Updating documentation

1. Edit files under `public/markdowns/` and update `navigation.yml` when the page should appear in the Sidebar and Pager.
2. Run `shards run index` locally to rebuild `search-index.st`.
3. Synchronize the complete directory with `rsync -a public/markdowns/ .../public/markdowns/`.
4. Refresh the document page. Recompiling or restarting the application is not required.

A Markdown file omitted from `navigation.yml` remains directly accessible as a standalone document, but it will not appear in the Sidebar, Pager, or Stork search index. Restarting the service never rebuilds the search index.

## Contributing

1. Fork it (<https://github.com/zw963/website/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Billy.Zheng](https://github.com/zw963) - creator and maintainer
