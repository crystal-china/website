# 站点设置

管理员通过后台侧栏的“站点设置”（`/admin/settings`）修改默认 Space：

- `logo_url`：导航栏完整品牌图片，默认 `svgs/crystal-china.svg`。
- `contact_email`：Footer 联系邮箱，默认 `admin@crystal-china.org`。
- `source_url`：导航栏“本站源码”地址，默认 `https://github.com/crystal-china/website`。
- `footer_links`：JSONB 链接数组，每项包含名称 `title`、跳转地址 `url` 和图标地址 `icon`。

三个字符串字段都使用 `allow_blank: true`：数据库为 `NULL` 时，页面使用默认值，后台也填入默认值，但查看页面不会写入数据库；点击保存后才存入实际值。用户清空后保存为空字符串，隐藏对应内容，不再回退默认值。

链接通过表单逐行增删，按行顺序显示，不需要编辑 JSON。
每行以 `footer_links[0]:title`、`footer_links[0]:url`、`footer_links[0]:icon` 提交，由 Lucky 的 `many_nested?("footer_links")` 按行读取 Hash，不再使用三个平行数组。表单还提交一个隐藏的 `footer_links` 空值，用于表示删除全部行；没有提交这个键时保留已有链接。
`footer_links` 为 `NULL` 时，Footer 和后台表单共用 `Space::DEFAULT_FOOTER_LINKS`，查看时不入库；保存后存入实际数组。全部删除或全部留空后保存为 `[]`，隐藏全部图标，没有“使用默认链接”开关。
图片可填写 HTTP／HTTPS 地址或本站资源路径，例如 `svgs/github-icon.svg`。默认图片和图标保存稳定的资源路径，展示时解析当前构建的指纹地址，不在数据库中固定某次构建的文件名。链接跳转地址必须是完整的 HTTP／HTTPS URL。

设置分为“站点信息”和“邮件发送”两个 Tab，各自使用独立的表单和 Operation。保存只提交、校验并重绘当前表单，通过 `hx-partial` 更新提示，不重定向或重建另一个 Tab。
例如修改 Logo 后尚未保存，切到邮件 Tab 保存 SMTP，再切回时 Logo 输入仍在，但尚未入库。刷新或离开设置页仍会丢失未保存的输入。

配置保存后在下一次完整页面渲染时生效，无须重启。已经打开的页面不会主动推送更新，设置保存及仅替换社区／文档内容的局部导航都不会重绘 Navbar、Footer。
Navbar、Footer 和社区计数通过 `context.site_space` 共用本次请求读取的默认 Space，不使用跨请求缓存。
管理员身份仍由 `ADMIN_EMAILS` 决定，邮件发件人也不受联系邮箱影响。

## 邮件发送

SMTP 服务器、端口、用户名、密码／授权码及发件邮箱也保存在默认 Space，没有默认值，不再读取 `CARBON_SMTP_*` 环境变量。
填写服务器、端口和发件邮箱后启用发送；用户名和密码可以同时留空，表示不使用 SMTP 认证。
`smtp_tls_mode` 保存连接加密方式，后台下拉框目前只有 STARTTLS 一个选项，默认值为 `Space::SmtpTlsMode::Starttls`（数据库存储整数 1）。
连接沿用 Carbon SMTP adapter 的 STARTTLS 模式，应填写服务商的 STARTTLS 端口，不支持通常在 465 端口使用的隐式 TLS。

密码通过 Lucky 的加密签名工具加密后存储，不回显。密码输入框留空会保留原密码，勾选清除后才删除；若继续启用 SMTP，清除密码时也应清空用户名，以停用认证。
清空服务器、端口和发件邮箱会停用邮件发送。未配置时，生产环境的密码重置页面给出正常失败提示，不会尝试使用 localhost 或默认发件人。

生产环境使用 Carbon 原有的 SMTP adapter：Web 启动时读取配置，后台保存成功后重新配置当前进程的 adapter；校验失败不修改运行中的配置。发件邮箱在发送时读取。开发和测试仍使用 Carbon 的 DevAdapter，不实际连接 SMTP。
后台保存只更新处理该请求的进程；多进程部署时应重启所有 Web 进程，以统一配置。
SMTP 密码加密依赖 `SECRET_KEY_BASE`，备份数据库时应同时保管此密钥；更换密钥后，需要重新保存 SMTP 密码。

部署时先运行 `bin/tasks db.migrate`，再重启应用。首次部署的默认 Space 仍由 `db.seed.required_data` 创建，重复运行 seed 不会覆盖管理员保存的设置。
