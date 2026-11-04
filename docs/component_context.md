# 组件的 current_user

## 默认继承

页面、组件里的 `mount`，以及 BrowserAction 的 `component`，现在会默认传入调用方的 `current_user`：

```crystal
mount Navbar::UserMenu
mount(
  Shared::Avatar,
  user: profile_user,
  classes: "h-8 w-8 rounded-md"
)
component(
  Shared::OnlineUsers,
  user_count: user_count,
  guest_count: guest_count
)
```

嵌套组件继续继承同一个用户。上例中的 `profile_user` 只是头像所属用户，不会改变访问者身份。
实现只转发已加载的对象，不增加数据库查询，不使用全局用户变量，也不修改认证逻辑。

## 显式覆盖

显式传入的用户或 `nil` 始终优先：

```crystal
mount Navbar::UserMenu, current_user: nil
```

通知全部已读后，数据库计数已改变，但本次请求的原用户对象仍是旧值。
因此 `render_notifications(current_user.reload)`，以及其中的 `component(..., current_user: user)` 必须保留。
组件之后的嵌套 `mount` 会自动继承这个刷新后的用户。

直接使用 `.new(...)` 没有调用方可供继承，需要用户信息时仍应显式传参。
例如 Markdown 排班表通过 `TableScheduler.new` 生成 HTML，其 `current_user` 参数继续保留。
第三方直接继承 `Lucky::BaseComponent` 的组件不受影响。

## 整页渲染与铃铛更新

Action 的 `html` 使用 Lucky 原有的 `expose current_user`，不是上面的组件包装。宏展开时会补上 `current_user: current_user`；调用位置有同名局部变量或方法参数时，传入的就是该值。

例如打开主题后，通知 trigger 已把数据库中的未读数从 3 改成 1，内存里的旧用户仍是 3。`ForumAction#render_topic` 用 `current_user = me.reload` 取得新对象，再调用 `html`。页面、Navbar 和铃铛逐层使用这个新对象，生成显示 1 的 HTML；整页替换时铃铛一起更新，不需要额外的 `hx-partial`。

这不是给变量赋值就自动修改浏览器，也不会把其他请求的登录用户一起修改。必须将新对象用于后续渲染，浏览器收到并替换 HTML 后才能看到变化。

## 实现与验证

核心逻辑位于 `src/actions/mixins/current_user_components.cr`，通过重载调用 Lucky 原有实现。
BrowserAction、MainLayout 和 BaseComponent 各自包含该模块，不修改 `lib/lucky`。

保留了位置参数、代码块及其返回参数、HTTP 状态码和显式用户覆盖。
回归测试位于 `spec/specs/current_user_components_spec.cr`；现有通知计数测试继续验证全部已读及发帖后铃铛的刷新。

## 本次变更文件

除统一入口和测试之外，其他调用处的修改只是删除重复的 `current_user: current_user` 或 `current_user: me`。

```text
spec/specs/current_user_components_spec.cr
src/actions/admin/trash/index.cr
src/actions/browser_action.cr
src/actions/forum/follows/create.cr
src/actions/forum/follows/delete.cr
src/actions/forum/index.cr
src/actions/htmx/comments/create_or_update.cr
src/actions/htmx/comments/delete.cr
src/actions/htmx/comments/edit.cr
src/actions/htmx/comments/index.cr
src/actions/htmx/comments/new.cr
src/actions/htmx/comments/restore.cr
src/actions/htmx/comments/withdraw.cr
src/actions/htmx/heartbeat.cr
src/actions/htmx/hourly_schedule.cr
src/actions/htmx/search.cr
src/actions/htmx/vote.cr
src/actions/mixins/current_user_components.cr
src/actions/online_users/index.cr
src/actions/user_audits/index.cr
src/actions/users/show.cr
src/components/base_component.cr
src/components/comments/card.cr
src/components/comments/card_body.cr
src/components/comments/card_controls.cr
src/components/comments/child_created.cr
src/components/comments/deleted.cr
src/components/comments/form.cr
src/components/comments/list.cr
src/components/comments/list_more.cr
src/components/comments/replies.cr
src/components/footer.cr
src/components/forum/topic_fields.cr
src/components/navbar.cr
src/components/notifications/list.cr
src/components/shared/common.cr
src/components/shared/online_users.cr
src/components/table_scheduler.cr
src/pages/admin/nodes/edit_page.cr
src/pages/admin/nodes/new_page.cr
src/pages/admin_layout.cr
src/pages/doc_layout.cr
src/pages/forum/edit_page.cr
src/pages/forum/new_page.cr
src/pages/forum/show_page.cr
src/pages/main_layout.cr
src/pages/user_audits/index_page.cr
src/pages/users/edit_page.cr
docs/component_context.md
```

