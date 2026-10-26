# 主题分页计数

三个计数只统计未软删除的主题，由 PostgreSQL trigger 维护：

| 字段 | 用途 |
| --- | --- |
| `spaces.topics_count` | 默认 Space 的主题总数，用于社区全部主题分页 |
| `nodes.topics_count` | 指定节点的主题分页 |
| `users.topics_count` | 个人主页创建的主题分页 |

新建、软删除、恢复和物理删除自动增减；物理删除已软删除的主题不重复扣减。
每个主题通过非空外键 `topics.space_id` 归属一个 Space。迁移创建默认 Space（`id = 1`，`slug = default`），
并将已有主题归入它。新主题由 `CreateTopic` 指定默认 Space，不接受客户端提供的 Space。
当前仅使用一个默认 Space，尚未提供多 Space 管理、切换或迁移主题的功能；也未开放主题作者转移。

三个计数均复用原有 `add_counters_for` / `rebuild_counter_for`，分别传入 `space_id`、`node_id`、`user_id`。
Helper 不再包含单行统计特例，也不自动维护外键变更。

移动节点时，`UpdateTopic` 的 `after_save` 在保存主题的同一事务内更新新旧节点计数。
例如，将主题从“交流”移到“求助”，两个节点分别减一、加一；Space 及作者的主题总数不变。
校验失败不会更新计数，事务回滚时计数也一起回滚；普通编辑不影响计数，不修改 Space、用户或节点的编辑时间。
请通过 `UpdateTopic` 移动主题。直接 SQL 或 Base SaveOperation 改关联不在自动维护范围内，之后应运行修复 task。
这里没有额外串行化同一主题的并发编辑；多个请求同时根据旧版本移动同一主题，也可能需要重建计数。

`TRUNCATE` 不触发逐行删除计数，sample seed 在清库后显式运行修复 task，将保留的 Space 和节点计数归零。

“仅关注”及其节点组合仍使用实时 `COUNT`，个人主页的回复列表也未改动。
Counter 只替换总数统计，不改变排序、分页链接、每页数量和深页 `OFFSET`。
同一 Space 的计数会让并发主题增删短暂争用同一行，这是减少读取统计所增加的写入成本。

## 部署

停服后先执行 `bin/tasks db.migrate`，再启动新版本。

1. `20260908080000_create_spaces.cr`：独立创建 Space 表（包含 `topics_count`）、slug 唯一索引及默认 Space，保留为单独的 migration，顺序早于主题建表。
2. `20261026120000_add_topic_counters.cr`：增加主题关联、节点和用户的计数字段，创建三个计数的 trigger 并自动回填，无须额外 task。

回滚第二个 migration 移除主题关联、节点和用户的计数字段及相关 trigger，保留 Space 表及其全部字段。

如果手工操作导致计数不一致，停止写入后执行 `bin/tasks db.fix.topic_counts`，可重复运行。
任务会重建三个计数，包括将没有主题的用户和节点归零，不修改正文或编辑时间，不发送通知。
