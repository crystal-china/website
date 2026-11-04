# The website for https://crystal-china.org

# Development dependencies

- Crystal
- pg
- bun
- podman (or docker)

## Development

1. First, install Crystal. You can check out the instructions here: https://crystal-lang.org/install/

2. Run `crystal run script/setup.cr`, Just make sure you’ve got `pg` and `bun` installed before running this.

3. Finally, run `lucky dev`, and you're all set!

## Deployment

The application is deployed as a static binary with its frontend assets baked in. Markdown documents deliberately remain outside the binary so they can be updated without recompiling the application.

1. Run `bun run prod` to build and precompress the frontend assets into `public/assets`.

2. Build the static binary with `script/build_amd64_static_binary.sh`. This requires Podman or Docker.

   Alternatively, use the [sb_static](https://github.com/crystal-china/magic-haversack/blob/main/bin/sb_static) script with Zig. See [Use Zig CC as an alternative linker](https://github.com/crystal-china/magic-haversack/blob/main/docs/use_zig_cc_as_an_alternative_linker.md) for details.

3. Synchronize `public/markdowns/` with `rsync -a --delete` (apply `--delete` only to that directory) and `public/sitemap.xml` with `rsync -a`. Missing or blank `navigation.yml` means no Sidebar or Pager. If `navigation.yml` or `index.md` is missing, `/docs/index` shows a setup page listing the missing files; no files are created automatically.

   The setup page includes file format examples and a "Generate starter files" button for signed-in administrators listed in `ADMIN_EMAILS`. The button creates only missing files and never overwrites existing files. The server needs write permission for `public/markdowns/` to use it.

4. Copy `bin/crystal_china` and `bin/tasks` to the server and configure the environment in `.env`; see [.env.sample](/.env.sample). The deployed application has the following relevant structure:

   ```text
   .
   ├── .env
   ├── bin
   │   ├── crystal_china
   │   └── tasks
   └── public
       ├── markdowns
       │   ├── navigation.yml
       │   └── ...
       └── sitemap.xml
   ```

5. On a fresh database, run `bin/tasks db.migrate` and `bin/tasks db.seed.required_data`. Required seeds create the default Space and community nodes; rerunning them preserves existing configuration. Once `public/markdowns/` contains `navigation.yml` and at least one Markdown file, run `bin/tasks db.sync_doc_content` to populate the PGroonga-backed document search index. If these files are missing, start the application and use the setup page from step 3 before syncing. The sync task can be rerun after Markdown changes; files removed from the synchronized directory have their stored content cleared, making their comments unavailable too.

6. Add a systemd service to start the server. See [crystal_china.service](/nginx/crystal_china.service). [Procodile](https://github.com/crystal-china/procodile) can be used instead.

7. Optionally, use Nginx as a reverse proxy. Configuration examples are available in the [nginx folder](/nginx).

### Updating documentation

1. Edit files under `public/markdowns/` and update `navigation.yml` when the page should appear in the Sidebar and Pager.
2. Synchronize the complete directory with `rsync -a --delete public/markdowns/ .../public/markdowns/` so removed Markdown files also disappear from the server.
3. Run `bin/tasks db.sync_doc_content` on the server to update searchable content, then refresh the document page. Recompiling or restarting the application is not required.

A Markdown file omitted from `navigation.yml` remains directly accessible and searchable, but it will not appear in the Sidebar or Pager. Visiting a document also syncs its content into the search index.

## Project Notes

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

## Contributing

1. Fork it (<https://github.com/zw963/website/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Billy.Zheng](https://github.com/zw963) - creator and maintainer
