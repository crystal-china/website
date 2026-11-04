# 主题分页计数

三个计数只统计未软删除的主题，由 PostgreSQL trigger 维护：

| 字段 | 用途 |
| --- | --- |
| `spaces.topics_count` | 默认 Space 的主题总数，用于社区全部主题分页 |
| `nodes.topics_count` | 指定节点的主题分页 |
| `users.topics_count` | 个人主页创建的主题分页 |

新建、软删除、恢复和物理删除自动增减；物理删除已软删除的主题不重复扣减。
每个主题通过非空外键 `topics.space_id` 归属一个 Space。`db.seed.required_data` 在空库创建默认 Space（`id = 1`，`slug = default`），
并创建默认社区节点；重复运行不会重复创建或覆盖已有配置。新主题由 `CreateTopic` 指定默认 Space，不接受客户端提供的 Space。
当前仅使用一个默认 Space，尚未提供多 Space 管理、切换或迁移主题的功能；也未开放主题作者转移。

三个计数均复用原有 `add_counters_for` / `rebuild_counter_for`，分别传入 `space_id`、`node_id`、`user_id`。
Helper 不再包含单行统计特例，也不自动维护外键变更。

移动节点时，`UpdateTopic` 的 `after_save` 在保存主题的同一事务内更新新旧节点计数。
例如，将主题从“交流”移到“求助”，两个节点分别减一、加一；Space 及作者的主题总数不变。
校验失败不会更新计数，事务回滚时计数也一起回滚；普通编辑不影响计数，不修改 Space、用户或节点的编辑时间。
请通过 `UpdateTopic` 移动主题。直接 SQL 或 Base SaveOperation 改关联不在自动维护范围内，之后应运行修复 task。
这里没有额外串行化同一主题的并发编辑；多个请求同时根据旧版本移动同一主题，也可能需要重建计数。

`TRUNCATE` 不触发逐行删除计数，sample seed 在清库后显式运行修复 task，将保留的 Space 和节点计数归零。

“仅关注”“近七天未读”及其节点组合仍使用实时 `COUNT`，个人主页的回复列表也未改动。
Counter 只替换总数统计，不改变排序、分页链接、每页数量和深页 `OFFSET`。
同一 Space 的计数会让并发主题增删短暂争用同一行，这是减少读取统计所增加的写入成本。

## 公共分页条数

两档条数定义在 `src/app.cr`，调用方直接引用，不再保留 Action 内的 `PER_PAGE` 别名：

| 常量 | 当前值 | 使用位置 |
| --- | --- | --- |
| `App::DEFAULT_PER_PAGE` | 20 | 社区、通知、个人主页的主题／回复／关注列表，以及回收站列表、批次成员、主题预览和关联评论页码定位 |
| `App::SMALL_PER_PAGE` | 10 | Doc／Topic 主评论区、子回复、评论通知页码定位，以及个人和后台账户记录 |

例如将 `SMALL_PER_PAGE` 改为 15，评论每页条数与通知定位的除数会同时改变，避免定位到错误页。修改常量后需重新编译；它不改变任何数据库 counter 或历史楼层。

这两档只控制分页，不控制搜索候选数量、Feed 条数或用户名长度。分页组件只显示传入的 Paginator，不自行决定每页多少条。

## 部署

增量 migration 已合并进对应的建表 migration，仅保证空数据库初始化；不再执行旧数据归属回填。
Space 保留独立的建表 migration；主题关联、计数字段和 trigger 在建表时直接创建，计数默认从零开始。

新机器启动服务前依次运行：

```bash
bin/tasks db.migrate
bin/tasks db.seed.required_data
```

迁移只创建结构，不插入 Space 或节点记录。不要跳过 required seed，也不要在生产环境运行 sample seed。
已完成压缩前全部迁移的数据库保留现有结构和迁移记录即可，不需要重新建表或重复运行历史迁移。

如果手工操作导致计数不一致，停止写入后执行 `bin/tasks db.fix.topic_counts`，可重复运行。
任务会重建三个计数，包括将没有主题的用户和节点归零，不修改正文或编辑时间，不发送通知。
