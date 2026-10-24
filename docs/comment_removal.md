# 评论删除与撤回

## 规则

| 评论类型 | 可以删除的条件 | 不满足条件时 |
| --- | --- | --- |
| 根评论 | `descendants_count == 0`，所有层级的后代均已软删除 | 撤回正文 |
| 子评论 | `children_count == 0`，直接回复均已软删除 | 撤回正文 |

删除、撤回和恢复均允许作者或管理员操作，管理员同样不能跳过删除所需的计数限制。

撤回卡片仍可见、仍参与计数和分页。删除根评论会隐藏整个分支；删除普通子评论只隐藏本条。

例如 A → B → C → D：D 删除后，C 的直接回复数变为零，可以删除 C；之后 B 也可以删除。根评论 A 必须等到所有未删除后代都消失后才可删除。

## 撤回和恢复

`withdrawn : Bool` 默认是 `false`。两个 Action 直接通过 `Comment::SaveOperation.update!` 将它设为 `true` 或 `false`，不再单独定义 Operation。

两种操作都保留 `content`、`content_html`、编辑时间、楼层、评论计数及已有投票。普通新建和编辑继续拒绝空白正文；撤回期间先恢复，才能再次编辑或投票。

撤回后整张卡片缩成一条提示，不显示作者、头像、时间、楼层或投票。作者或管理员可以恢复；没有回复时还可以删除。根评论仍向所有读者提供展开回复按钮，不隐藏后代。

撤回和恢复不发送通知，既有通知快照不清除。管理员删除他人评论时仍沿用原有删除通知。

通知仍链接到 `/comments/:id`，通过原来的分页定位流程找到撤回卡片并高亮，不返回 404。只有软删除、根评论或主题被删除、文档不可访问时，才显示内容不可用页面。

## 局部刷新与并发

撤回和恢复只返回 `Comments::CardBody`，替换 `comment-ID-body`。外面的 `article` 和回复列表不在替换范围内，不需要用 `hx-preserve` 保留回复列表。

展开／折叠按钮与回复列表一起放在独立的 `comment-thread` 区域，始终位于评论操作栏下方同一位置。折叠时显示圆形加号和回复数量，展开后原位置显示圆形减号和折叠文字。分支弯线和图标均使用 CSS，不需要 SVG 或布局 JS。

例如 A 已展开 B、C，撤回 A 时只更新正文和操作按钮，B、C 以及减号按钮完全不参与替换；如果原本折叠，则仍保持折叠。不再需要 `preserve_thread_toggle` 或 `hx-preserve`。

`Comments::ListMore` 判断当前评论与定位目标的关系：目标根评论收到 `reply_expanded: true` 和目标 ID，目标评论收到自己的 ID，其余评论的目标 ID 为 `nil`。`Card` 不再判断根评论关系，也不再接收完整的目标评论对象。

新增、删除回复会重新渲染当前分支列表，并通过 `hx-partial` 同步更新根评论操作区和独立的展开按钮。因此最后一条回复删除后，展开按钮消失，父评论重新显示删除按钮，即使父评论已经撤回。

回复、删除、撤回和恢复均在事务内先锁根评论，再锁目标评论。回复在取得锁后重新检查可见性，删除在取得锁后检查最新计数。

## 阅读顺序

1. migration 和 `src/models/comment.cr`：新增状态、保留原有删除条件。
2. `src/actions/htmx/comments/withdraw.cr`、`restore.cr`：权限、事务、切换状态与评论主体响应。
3. `src/components/comments/list_more.cr`、`card.cr`：定位关系、回复展开与列表容器。
4. `src/components/comments/card_body.cr`：正常主体和撤回后的紧凑主体。
5. `src/components/comments/card_action.cr`、`delete_or_withdraw.cr`：恢复、删除、撤回按钮。

部署时先执行 `lucky db.migrate`，再重启服务。保留原来的 `children_count` 和软删除计数 trigger，不需要计数回填任务。
