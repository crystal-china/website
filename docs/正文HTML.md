# 主题和评论的正文 HTML

## 保存与显示

主题和评论同时保存 Markdown 原文 `content` 与经过安全清洗的正文 HTML `content_html`。新建或修改正文时，先生成 HTML，再把原文和 HTML 一起写入数据库。

提及通知使用此次渲染实际生成链接的用户名名单。代码、已有链接、手写 HTML 的链接和代码标签，以及 `info` 提示框中的内容不会生成提及链接或通知。

HTML 字段只保存正文。用户资料、权限、投票和操作按钮仍由页面单独渲染。登录用户名改变后，不会自动重写历史提及链接。

全文搜索继续使用 Markdown 原文。编辑器预览只渲染，不保存，也不发送通知。

Doc 文档不保存 `content_html`，仍使用自己的 Markdown 缓存。

## 现有环境部署

`content_html` 已合并进主题和评论的初始建表 migration。全新环境执行 `bin/tasks db.migrate` 即可，不需要对空表回填。

尚未升级的旧数据库须先使用压缩前版本完成字段迁移，参见[历史升级要求](用户名与提及.md#现有环境升级)。对于已有 `content_html` 字段、需要更新历史 HTML 的数据库，部署重新构建的应用和任务两个 binary，停止服务器，然后运行：

```bash
bin/tasks db.migrate
bin/tasks db.rebuild.content_html
```

重建完成后再启动服务器。

## HTML 重建

`db.rebuild.content_html` 每批处理 200 条记录，包含软删除的主题和评论，避免恢复记录后缺少 HTML。

任务只重建 `content_html`，保留原来的创建时间、更新时间和编辑时间，不发送通知，也不改变评论计数。它使用 Query 更新，而不是用户编辑使用的 Operation；更新时显式传入旧的 `updated_at`，避免 Avram 自动把更新时间改为当前时间。

服务器停止时可以重复执行该任务。渲染器、提及规则或 sanitizer 发生变化后，也可以用它更新已有 HTML。

用户主页路径使用 `/users/:login_name/profile`，避免用户名末尾的 `.html`、`.xml` 等被 Lucky 当成请求格式后缀。升级之前已经保存的 HTML 可能仍包含旧的 `/users/:login_name` 提及链接，需要运行重建任务更新；只修改路由不会自动改写数据库里的 HTML。

如果重建失败，应修复原因后重新执行。尤其是收紧安全清洗规则后，不要继续使用尚未重建的旧 HTML。

## 空值与写入约束

为兼容历史数据，`content_html` 仍允许为 `NULL`。读取到 `NULL` 时，页面会临时将 Markdown 渲染成 HTML；空字符串 `""` 则表示已经生成、但没有可显示内容的 HTML，不会触发重新渲染。

修改 `content` 必须经过主题或评论的保存 Operation，不能直接使用 Query 更新或原始 SQL，否则无法保证原文和 HTML 同步。重建任务是例外：它不修改正文，只根据现有正文更新配套 HTML。
