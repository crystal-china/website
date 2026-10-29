require "../fix/topic_counts"
require "./required_data"

# This task resets development data. Do not run it against a database you need to keep.
class Db::Seed::SampleData < LuckyTask::Task
  summary "Add sample database records helpful for development"

  def call : Nil
    abort "db.seed.sample_data 只允许在 development 环境运行" unless LuckyEnv.development?

    Process.on_terminate do
      print_exit("\n操作已中断")
    end

    unless ENV.fetch("RUN_SCRIPT_SETUP", "false") == "true"
      print "重置所有开发数据？（y/yes 继续）"
      input = gets.try &.rstrip

      print_exit("拒绝执行") unless input.to_s.downcase.in? ["y", "yes"]
    end

    DocQuery.truncate(cascade: true)
    UserQuery.truncate(cascade: true)
    CommentQuery.truncate(cascade: true)

    Db::Seed::RequiredData.new.call

    # TRUNCATE 不触发逐行删除计数；Space 和节点配置保留，重新计算为零。
    Db::Fix::TopicCounts.new.call

    users = [
      {"admin@crystal-china.org", "社区管理员", "admin"},
      {"me@163.com", "小明", "xiaoming"},
      {"user1@163.com", "Ruby 转 Crystal", "ruby_to_crystal"},
      {"user2@163.com", "并发学习者", "concurrency"},
      {"user3@163.com", "小红", "xiaohong"},
      {"user4@163.com", "小李", "xiaoli"},
    ].map do |email, nickname, login_name|
      SignUpUser.create!(
        email: email,
        nickname: nickname,
        login_name: login_name,
        password: "temp1234",
        password_confirmation: "temp1234",
        captcha_code: "sample-data"
      )
    end

    seed_account_events(users)

    User::SaveOperation.update!(
      users[1],
      last_active_at: Time.utc - 2.hours,
      online_seconds: (8.hours + 36.minutes).total_seconds.to_i64
    )
    UpdateUser.update!(
      users[1],
      tagline: "从 Ruby 出发，认真学一点 Crystal",
      bio: "正在把配置检查脚本迁到 Crystal，喜欢能直接运行的小例子。前言和第一篇主题里都有我的讨论，可以测试个人主页的主题、回复和账户记录。"
    )
    UpdateUser.update!(users[3], mention_notifications_enabled: false, hide_online_status: true)

    nodes = NodeQuery.new.results.to_h { |node| {node.slug, node} }

    topic_data = [
      {"general", "从 Ruby 迁移到 Crystal，第一周最容易踩的坑", "我把一个命令行脚本从 Ruby 迁到 Crystal，最费时间的是处理 Nil 联合类型和块的返回值。编译器给出的错误很精确，但我一开始总想照搬 Ruby 的写法。", "你们通常先把边界类型标清楚，还是先让代码能编译，再逐步收紧类型？"},
      {"help", "Channel 消费者退出后，生产者应该如何收尾？", "一个后台任务持续向 Channel 发送数据；页面关闭后消费者会退出。我想确保生产者不会一直挂在 send 上，也不会丢掉已经开始处理的记录。", "这个场景应该关闭 Channel、传递取消信号，还是让生产者持有一个独立的生命周期对象？"},
      {"projects", "分享一个用 Crystal 写的 Markdown 链接检查工具", "这个小工具扫描文档目录，检查相对链接指向的文件是否存在，并输出包含行号的报告。目前只处理本地文件，不主动请求外链。", "如果把它发布成 shard，命令行参数和错误退出码应该怎样设计才方便接入 CI？"},
      {"learning", "给第一次接触 Crystal 的 Ruby 开发者推荐什么练习？", "我在整理一份面向 Ruby 开发者的练习清单，希望练习覆盖类型推断、枚举、异常处理和 Fiber，而不是只做语法翻译。", "你会用哪个小项目作为第一步？哪些概念值得配一段可运行的示例？"},
      {"general", "Crystal 的类型推断在大型项目里该如何使用？", "小脚本里不写类型签名很舒服；当方法跨越多个模块时，推断结果偶尔不够直观，改动一处后编译错误会出现在很远的地方。", "公开 API 是否应该统一写返回类型？内部私有方法又该保持多大自由度？"},
      {"help", "Lucky 表单校验失败后怎样保留用户输入？", "表单里有标题、正文和节点选择。提交失败时，我想让错误信息贴在相应字段附近，同时保留已经输入的 Markdown，避免用户重新输入。", "使用 SaveOperation 重新渲染页面时，哪些值应读 operation，哪些值需要单独传入页面？"},
      {"projects", "用 PGroonga 给中文文档做全文搜索的实践记录", "我把 Markdown 原文同步到 PostgreSQL，用 PGroonga 建索引，再把命中的片段展示在搜索弹窗中。数据同步和查询页面由不同的入口负责。", "当文件删除或搜索索引暂时落后于磁盘时，你们会选择隐藏结果还是显示旧快照？"},
      {"learning", "理解 Fiber 与系统线程的区别", "我发现很多介绍把并发和并行混在一起，读者很容易以为有 Fiber 就一定会用满所有 CPU 核心。", "有没有一段最小示例，可以分别展示等待 I/O 时的调度和 CPU 密集计算的差别？"},
      {"general", "为个人网站选择 Crystal 还是 Ruby？", "我想做一个内容不多、但需要全文搜索和评论的个人站点。Ruby 的库更多，Crystal 的单文件部署则很吸引人。", "如果主要由一个人维护，应该优先比较哪些长期成本，而不只是首屏性能？"},
      {"help", "Crystal JSON::Serializable 的字段兼容怎么做？", "上游接口新增了字段，也有旧版本客户端仍在发送较早的结构。直接要求所有字段非空会让兼容变得困难。", "哪些字段适合使用默认值，哪些字段应该通过自定义转换明确拒绝？"},
      {"projects", "一个在树莓派上运行的轻量论坛", "论坛页面由 Lucky 渲染，评论交互交给 HTMX，PostgreSQL 保存主题和回复。机器资源有限，我尽量避免引入完整的前端框架。", "除了数据库备份与错误日志，单机部署时还有哪些运维细节容易被忽略？"},
      {"learning", "从写脚本到写 shard：目录和测试如何组织？", "我已经有一个可以工作的 Crystal 脚本，准备把解析逻辑抽成 shard，让命令行和其他程序都能复用。", "一开始就分离 CLI 与核心库是否值得？公开类型又该如何避免过早固定？"},
      {"general", "社区文档应该优先翻译还是写原创教程？", "官方文档覆盖面广，但初学者常需要针对具体问题的中文解释。原创教程更贴近本地读者，却需要长期维护。", "如果每周只能投入一点时间，怎样安排翻译、勘误和原创内容的优先级？"},
      {"help", "数据库迁移失败后如何安全地继续？", "新增索引时迁移在一半失败，数据库里留下了部分结构，但迁移记录没有写入。再次执行会遇到同名对象。", "应该先手动核对数据库状态，再修迁移，还是设计成可以重复执行的 SQL？"},
      {"projects", "把静态 Markdown 同步到数据库供搜索使用", "文档仍由 Git 和文件编辑器管理，数据库只保存一份用于搜索的内容副本。这样作者不用在后台编辑，但必须处理索引滞后。", "同步任务应该在部署时运行、定时运行，还是在读取文档时检测摘要变化？"},
      {"learning", "什么时候应该使用枚举而不是字符串？", "我的项目里有一些状态值，最初用字符串写得很快，但后来不同页面拼写不一致，导致分支没有命中。", "如果状态还会持久化到数据库，枚举重命名时你们会如何安排兼容迁移？"},
      {"general", "评论楼层按创建顺序还是按展示顺序编号？", "同一个讨论串可以按最新或最早排序。如果楼层号跟着排序变化，引用别人发言时就会变得不稳定。", "你们更倾向于持久化楼层号，还是只在页面中计算展示位置？"},
      {"help", "HTMX 局部请求失败时怎样给出友好反馈？", "局部刷新接口偶尔会超时，用户只看到按钮没有变化。直接把错误页替换进卡片里，又会破坏整页布局。", "对于网络失败、权限不足和服务端错误，提示应该分别处理到什么程度？"},
      {"projects", "做一个文档导航 YAML 的一致性检查任务", "导航配置里的路径可能指向已经删除的 Markdown，反过来也可能有文档没有被放进侧边栏。", "任务应该强制所有文件都有导航入口，还是允许隐藏页面并只报告真正不存在的文件？"},
      {"learning", "用小型 Web 应用练习 Avram 关联查询", "我想用主题、作者和评论三张表练习 preload 与分页，观察 N+1 查询在日志中的表现。", "除了比较 SQL 次数，还有哪些指标能判断预加载是否值得？"},
      {"general", "如何组织一次线上数据库升级演练？", "开发环境已经验证迁移能跑，但线上有真实数据，升级扩展和 PostgreSQL 版本时更需要可恢复的步骤。", "演练时应先验证备份恢复、迁移耗时，还是应用在旧新结构之间的兼容窗口？"},
    ]

    now = Time.utc
    topics = topic_data.each_with_index.map do |data, index|
      slug, title, background, question = data
      content = <<-MARKDOWN
      ## 背景

      #{background}

      ## 想讨论的问题

      #{question}

      如果你遇到过类似情况，也欢迎附上具体代码、取舍理由或踩坑经过。
      MARKDOWN

      if index.zero?
        content += <<-MARKDOWN


        ## 一个可以一起完善的练习

        我想从读取 JSON 配置、检查必填字段、输出 Markdown 报告开始。第一阶段不做 Web 界面，只要求每一步都有可以执行的命令和明确的错误提示。

        ```json
        {"title": "Crystal 配置检查", "output": "report.md"}
        ```

        - 正常输入：报告包含配置名称和检查结果。
        - 错误输入：区分文件不存在、JSON 格式错误和字段类型错误。
        - 后续练习：用 PGroonga 搜索中文报告，分别验证标题和正文命中。

        > 不只是让代码通过编译，还要能说明失败时会发生什么。

        ```info
        示例中的路径均相对于当前工作目录。运行前请先创建配置文件，不需要连接外部服务。
        ```
        MARKDOWN
      end

      CreateTopic.create!(
        user_id: index.zero? ? users[1].id : users[(index - 1) % users.size].id,
        node_id: nodes[slug].id,
        title: title,
        created_at: now - 5.days + index.hours,
        content: content
      )
    end.to_a

    # 小明关注第一篇和第二篇主题；管理员关注小明的第一篇主题。
    [{topics[0], users[1]}, {topics[1], users[1]}, {topics[0], users[0]}].each do |topic, follower|
      SaveTopicFollow.create!(topic_id: topic.id, follower_id: follower.id)
    end

    markdown_path = MarkdownFile.resolve("index") || raise "Missing Markdown for /docs/index"
    doc = DocContent.sync("/docs/index", File.read(markdown_path))
    doc = SaveDoc.update!(doc, created_at: now - 8.days)
    doc_thread = CommentThreadQuery.new.doc_id(doc.id).first
    topic_thread = CommentThreadQuery.new.topic_id(topics.first.id).first

    doc_root = seed_comment_examples(users, doc_thread, "前言")
    seed_comment_examples(users, topic_thread, "主题")
    seed_notifications(users, nodes, topics.first, topics[1], doc_root)
    CreateComment.create!(
      comment_thread_id: topic_thread.id,
      user_id: users[1].id,
      content: "【作者整理】感谢大家的补充。我会把配置读取、校验和报告输出拆成三个步骤，并保留文件缺失、格式错误与字段类型错误的示例。撤回的建议不再作为结论，但下面的纠正仍保留供读者参考；这条最新回复也方便检查主题置顶、最后回复人和活跃时间。"
    )
    TopicActivity.refresh(topic_thread)

    SaveVote.create!(user_id: users[1].id, doc_id: doc.id, vote_type: "👍")
    doc_vote_counts = doc.vote_counts
    doc_vote_counts.👍 = 1
    UpdateDocVoteCounts.update!(doc, vote_counts: doc_vote_counts)

    puts "已创建 #{TopicQuery.new.select_count} 篇可见主题、#{users.size} 个用户。"
    puts "主要测试入口：/docs/index 和 /forum/#{topics.first.id}，两者都有根评论与子评论分页。"
    puts "其他主题大多无回复，用于测试零回复、作者删除、/forum?page=2 和仅关注过滤。"
    puts "所有示例账号密码：temp1234；小明：me@163.com / xiaoming；管理员：admin@crystal-china.org / admin。"
    puts "输入 @xi 可以补全 xiaohong、xiaoli、xiaoming；concurrency 关闭提及通知并隐身，但仍有普通回复通知。"
    puts "启动应用前设置 ADMIN_EMAILS=admin@crystal-china.org，以启用示例管理员。"
    puts "回收站：/admin/trash，共 #{CommentQuery.new.only_soft_deleted.select_count} 条评论，超过一页；主题回收站：/admin/trash?kind=topics。"
    puts "小明有 36 条通知，两页均包含全部 9 种类型；27 条未读、9 条已读，日期分散在三天。"
    puts "小明账户记录：#{UserAudits::Index.with(user_id: users[1].id).path}；全站账户记录：#{UserAudits::Index.path}。"
    puts "管理员和小明的账户记录超过一页，ruby_to_crystal 有一条，concurrency 没有；可测试改名、密码与 OAuth 登录事件。"
    puts "搜索可试 PGroonga、配置；完整场景说明见 docs/sample_data.md。"
  end

  private def seed_notifications(
    users : Array(User),
    nodes : Hash(String, Node),
    topic : Topic,
    followed_topic : Topic,
    doc_root : Comment,
  ) : Nil
    admin, user, replier, reader = users.first(4)
    topic_title = topic.title
    topic_thread_id = CommentThreadQuery.new.topic_id(topic.id).first.id
    followed_thread_id = CommentThreadQuery.new.topic_id(followed_topic.id).first.id
    doc_first_reply = CommentQuery.new.parent_id(doc_root.id).id.asc_order.first
    topic_first_reply = CommentQuery.new.comment_thread_id(topic_thread_id).parent_id.is_not_nil.id.asc_order.first
    topic_reader_reply = CommentQuery.new
      .comment_thread_id(topic_thread_id)
      .user_id(reader.id)
      .parent_id.is_not_nil
      .id.asc_order.first

    # 清除前面准备主题和回收站时产生的通知，下面通过真实操作生成固定的演示场景。
    # DELETE 才会触发逐行计数更新，TRUNCATE 会让用户上的通知计数保留旧值。
    NotificationQuery.new.delete

    [
      "Channel 关闭后如何让生产者正常退出",
      "给 Markdown 链接检查工具补充 CI 测试",
      "为中文全文搜索设计可重复执行的同步任务",
      "在树莓派上演练 PostgreSQL 备份与恢复",
    ].each_with_index do |title, index|
      reply_content = "@#{reader.login_name} 迁移脚本时还可以练习「#{title}」。建议先列出正常、失败和重复执行三种情况，再逐项验证。你关闭了提及通知，但第一条是对你的直接回复，普通回复通知仍应保留；小明作为主题作者也会收到普通回复通知。"

      if index.zero?
        CreateComment.create!(
          parent_id: topic_reader_reply.id,
          user_id: replier.id,
          content: reply_content
        )
      else
        CreateComment.create!(
          comment_thread_id: topic_thread_id,
          user_id: replier.id,
          content: reply_content
        )
      end

      CreateComment.create!(
        parent_id: doc_root.id,
        user_id: replier.id,
        content: "关于前言提到的练习，我补充「#{title}」这个方向。可以先覆盖资源释放和异常传播，再验证重复执行不会留下额外任务；这条通知应定位到前言讨论的子分页。"
      )
      if index < 2
        reply = index.zero? ? doc_first_reply : topic_first_reply

        UpdateComment.update!(
          reply,
          content: "#{reply.content}\n\n@#{user.login_name} 补充一下「#{title}」的复现步骤。这次编辑新增了提及，通知应跳到较早的子评论，自动加载根评论和子评论所在的第二页。",
          actor_id: replier.id
        )
      else
        mention = CreateComment.create!(
          comment_thread_id: doc_root.comment_thread_id,
          user_id: replier.id,
          content: "@#{user.login_name} 关于「#{title}」，可以先给出一段最小可运行示例，再附上预期输出和实际结果，其他读者会更容易复现。"
        )

        Comment::SaveOperation.update!(mention, withdrawn: true) if index == 2
      end
      topic = UpdateTopic.update!(
        topic,
        title: "#{topic_title}（第 #{index + 1} 次补充）",
        actor_id: admin.id
      )
      topic = UpdateTopic.update!(
        topic,
        node_id: nodes[index.even? ? "help" : "general"].id,
        actor_id: admin.id
      )

      deleted_topic = CreateTopic.create!(
        user_id: user.id,
        node_id: nodes["general"].id,
        title: "重复讨论：#{title}",
        content: "这篇主题与已有讨论重复，管理员将其移入回收站。通知保留当时的标题和正文摘要，点击后应显示内容已不可用的提示。"
      )

      if index.zero?
        deleted_thread_id = CommentThreadQuery.new.topic_id(deleted_topic.id).first.id
        kept_root = CreateComment.create!(
          comment_thread_id: deleted_thread_id,
          user_id: user.id,
          content: "主题删除后，这条评论只因所属主题不可见而隐藏，并没有被单独删除。管理员可以从主题回收站预览它；恢复主题后它会重新可见。"
        )
        deleted_child = CreateComment.create!(
          parent_id: kept_root.id,
          user_id: user.id,
          content: "我先删除了这条重复回复，之后主题才被移入回收站。主题未恢复时不能恢复本条；只恢复主题，也不应把本条一起恢复。"
        )
        DeleteComment.delete!(deleted_child, actor_id: user.id)

        puts "已删除主题预览：/admin/trash/topics/#{deleted_topic.id}/preview；主题恢复前不可恢复的评论：/admin/trash/comments/#{deleted_child.id}。"
      end

      DeleteTopic.delete!(deleted_topic, actor_id: admin.id)
      doc_root = UpdateComment.update!(
        doc_root,
        content: "#{doc_root.content}\n\n管理员补充 #{index + 1}：讨论「#{title}」时，请附上 Crystal 版本、执行命令和预期结果。",
        actor_id: admin.id
      )

      deleted_comment = CreateComment.create!(
        parent_id: doc_root.id,
        user_id: user.id,
        content: "关于「#{title}」的重复留言，管理员会删除这条评论。可以检查删除通知的摘要，以及跳转到已删除评论时的提示。"
      )
      DeleteComment.delete!(deleted_comment, actor_id: admin.id)

      CreateComment.create!(
        comment_thread_id: followed_thread_id,
        user_id: replier.id,
        content: "我在练习「#{title}」时，也遇到了 Channel 消费者退出后的收尾问题。小明关注了这个主题，但不是作者，也没有被直接回复或提及，因此应收到关注主题的新回复通知。"
      )
    end

    now = Time.local
    users.each do |recipient|
      notifications = NotificationQuery.new.user_id(recipient.id).id.asc_order.results

      # 每轮依次生成九种通知，保证两页都有全部类型；日期和已读状态只用于演示。
      notifications.each_with_index do |notification, index|
        at = now - (2 - index * 3 // notifications.size).days

        SaveNotification.update!(
          notification,
          created_at: at,
          updated_at: at,
          read_at: recipient.id == user.id && index % 4 == 0 ? at : nil
        )
      end
    end
  end

  private def seed_account_events(users : Array(User)) : Nil
    now = Time.utc
    event_ages = [
      1095.days, 1094.days, 900.days, 730.days, 600.days,
      540.days, 365.days, 300.days, 240.days, 180.days,
      120.days, 90.days, 60.days, 30.days, 21.days,
      14.days, 7.days, 5.days, 3.days, 2.days,
      1.day, 12.hours, 6.hours, 1.hour, 10.minutes, 1.minute,
    ]

    users.first(2).each do |user|
      nickname = user.nickname
      login_name = user.login_name

      user = UpdateUser.update!(user, login_name: "#{login_name}_test")
      user = UpdateUser.update!(user, login_name: login_name)

      10.times do |index|
        user = UpdateUser.update!(user, nickname: index.even? ? "#{nickname}（学习中）" : nickname)
        # 登录事件与实际 Action 使用相同的 Operation；不访问外部 OAuth 服务。
        if index.even?
          SaveUserAudit.create!(
            user_id: user.id,
            kind: :oauth_signed_in,
            oauth_provider: index % 4 == 0 ? "github" : "google"
          )
        else
          SaveUserAudit.create!(user_id: user.id, kind: :password_signed_in)
        end
      end

      user = UpdateUser.update!(
        user,
        password: "sample1234",
        password_confirmation: "sample1234"
      )
      # 模拟历史移除事件，保留实际操作者；不禁用演示账号当前的密码登录。
      SaveUserAudit.create!(
        user_id: user.id,
        actor_id: users.first.id,
        kind: :password_removed
      )
      user = UpdateUser.update!(
        user,
        password: "temp1234",
        password_confirmation: "temp1234"
      )
      SaveUserAudit.create!(user_id: user.id, kind: :password_signed_in)

      # 真实修改生成事件后，仅调整演示日期；改名事件仍位于注册后前七天。
      User::SaveOperation.update!(user, created_at: now - 1096.days)
      UserAuditQuery.new.user_id(user.id).id.asc_order.results.each_with_index do |audit, index|
        at = now - event_ages[index]

        SaveUserAudit.update!(
          audit,
          created_at: at,
          updated_at: at
        )
      end
    end

    users.skip(2).each do |user|
      User::SaveOperation.update!(user, created_at: now - 6.days)
    end

    SaveUserAudit.create!(
      user_id: users[2].id,
      kind: :oauth_signed_in,
      oauth_provider: "github",
      created_at: now - 1.day,
      updated_at: now - 1.day
    )
  end

  private def seed_comment_examples(users : Array(User), thread : CommentThread, source : String) : Comment
    admin, author, replier, reader = users.first(4)
    at = Time.utc - 3.days
    root = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      created_at: at,
      content: <<-MARKDOWN
      ## #{source}讨论：从配置检查脚本开始迁移

      我准备先把一个 Ruby 配置检查工具迁到 Crystal，而不是一次搬整个 Web 项目。这个工具读取 JSON，检查必填项，再生成 Markdown 报告，输入输出都很明确。

      > 外部输入允许失败，内部数据尽量保持明确的类型。

      计划先做这三件事：

      1. 区分文件不存在、JSON 格式错误和配置字段缺失。
      2. 把文件读取与数据校验分开，不在业务代码里反复使用 `not_nil!`。
      3. 用 PGroonga 搜索生成的中文报告，验证标题和正文都能命中。

      @#{replier.login_name}，你会怎样安排第一步？这条讨论保留较长正文、引用和列表，用来检查实际阅读效果。

      ```info
      示例配置里的 @admin 只是说明文字，不应生成提及链接或通知。
      ```
      MARKDOWN
    )
    child = CreateComment.create!(
      parent_id: root.id,
      user_id: replier.id,
      created_at: at + 10.minutes,
      content: "我会先固定输入和输出，再逐步替换解析逻辑。比如明确哪些字段可以缺省、哪些字段缺失时必须报错，并为每种失败准备一个最小配置文件；这样以后修改类型时，也能判断行为是否发生变化。"
    )
    grandchild = CreateComment.create!(
      parent_id: child.id,
      user_id: reader.id,
      created_at: at + 20.minutes,
      content: <<-MARKDOWN
      @#{author.login_name}中文也可以紧跟提及。我按这个顺序试了一遍，先把配置转换成明确的对象，后面的报告生成就不必反复处理 Nil。

      ```crystal
      require "json"

      config = JSON.parse(File.read("config.json"))
      puts config["title"].as_s
      ```

      这条回复的直接父评论是 Ruby 转 Crystal，不是根评论作者，可以检查回复对象和跨页定位。
      MARKDOWN
    )
    CreateComment.create!(
      parent_id: grandchild.id,
      user_id: admin.id,
      created_at: at + 30.minutes,
      content: "@#{reader.login_name} 我会再补一个字段类型错误的配置。你关闭了提及通知，但这也是对你的直接回复，因此普通回复通知仍应保留。这条是第四层评论，可以检查父评论名称和连续展开效果。"
    )

    [
      "先把文件路径作为命令行参数，不在程序里写死工作目录，这样本地和 CI 才能使用同一条命令。",
      "缺少 title 与 title 不是字符串应该给出不同提示，避免读者只看到一个笼统的转换异常。",
      "解析失败时保留原始文件名和行号，输出报告时再统一整理，而不是在每个方法里打印日志。",
      "如果报告用于 CI，检查失败就返回非零退出码；只有警告时仍可成功退出。",
      "不要为了消除 Nil 一开始就给所有字段设空字符串，否则可能把真正的配置错误隐藏掉。",
      "可以先比较一份有效配置和一份无效配置的输出，再决定是否引入更通用的校验对象。",
      "PGroonga 搜索应分别试标题命中、正文命中和没有结果；中文词组与英文库名也应各试一次。",
      "Markdown 报告中的文件名要注意转义；包含下划线、百分号或反斜杠时，不应改变原始路径。",
      "最后把依赖版本和运行命令写进 README，让后来的人不必猜测示例需要什么环境。",
    ].each_with_index do |advice, index|
      CreateComment.create!(
        parent_id: root.id,
        user_id: users[(index + 2) % users.size].id,
        created_at: at + (index + 1).hours,
        content: "关于#{source}的配置练习，我补充一点：#{advice} 我会先用一个可以直接运行的小例子验证，再把结果整理进教程。"
      )
    end

    seed_comment_votes(root, users)

    leaf = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: "【可以删除，也可以撤回】我准备把这份配置练习整理成一个独立目录，包含有效配置、错误配置和运行命令。这条还没有任何回复，小明应同时看到删除与撤回按钮；其他普通用户不应看到这些操作。"
    )
    withdrawn_root = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: "【已撤回的根评论】我最初认为所有配置错误都应该自动填默认值，后来发现这会掩盖输入问题，所以先撤回这段建议。原文仍然保留，恢复后应重新出现，下面的讨论不能因此消失。"
    )
    CreateComment.create!(
      parent_id: withdrawn_root.id,
      user_id: replier.id,
      content: "默认值适合确实可选的字段，不适合强行补齐必填字段。虽然根评论已撤回，我的这条回复仍应能展开、阅读和通过链接访问。"
    )
    Comment::SaveOperation.update!(withdrawn_root, withdrawn: true)

    withdrawal_branch = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: "【子评论撤回演示】这一支讨论异常处理的边界。可以先展开，再撤回或恢复中间的评论，检查回复列表是否保持展开，以及加减号、分支线和其他操作图标的位置。"
    )
    withdrawn_child = CreateComment.create!(
      parent_id: withdrawal_branch.id,
      user_id: author.id,
      content: "我原先建议捕获所有异常后直接返回空报告，但这会让真正的程序错误也被忽略。先撤回这条建议，保留下面其他人的纠正；恢复时应保留原来的投票和楼层号。"
    )
    withdraw_child_reply = CreateComment.create!(
      parent_id: withdrawn_child.id,
      user_id: replier.id,
      content: "我更倾向于只捕获预期的文件和解析错误，让意外错误继续暴露。小明可以撤回父评论，但有我这条直接回复时不能单独删除；删除我这条后，父评论应重新出现删除按钮。"
    )
    seed_comment_votes(withdrawn_child, users)
    Comment::SaveOperation.update!(withdrawn_child, withdrawn: true)

    delete_ready = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: "【回复已删除，父评论可删除】我曾在这里询问示例的文件编码，唯一的直接回复后来由作者删除了。现在没有可见后代，所以我的删除按钮应该重新出现，而不是继续被历史记录阻止。"
    )
    removed_reply = CreateComment.create!(
      parent_id: delete_ready.id,
      user_id: replier.id,
      content: "这条单独删除的回复曾建议使用本地默认编码，后来发现应明确使用 UTF-8，所以作者删除了它。它不属于任何级联删除批次，回收站不应显示查看同批删除。"
    )
    DeleteComment.delete!(removed_reply, actor_id: replier.id)

    deleted_root = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: "【整支级联删除】这一支重复讨论了已经修正的配置格式，管理员将根评论和后代一起删除。恢复时应先恢复根评论，再恢复子评论，不能越过父评论。"
    )
    deleted_child = CreateComment.create!(
      parent_id: deleted_root.id,
      user_id: replier.id,
      content: "这是随根评论一起删除的第二层评论。同批列表中根评论应排在我前面，先恢复根评论再恢复我，不再额外显示父评论链接。"
    )
    deleted_grandchild = CreateComment.create!(
      parent_id: deleted_child.id,
      user_id: reader.id,
      content: "这是随根评论一起删除的第三层评论。展开同批记录可找到祖先，不再额外显示父评论链接。父评论仍被删除时，点击恢复应被拒绝。"
    )
    earlier_deletion = CreateComment.create!(
      parent_id: deleted_child.id,
      user_id: replier.id,
      content: "【更早单独删除】我在管理员删除整支之前就删除了这条重复回复。原删除时间不能被覆盖，也不应混入后来的同批删除列表。搜索 100% a_b C:\\temp 时，这些字符应按字面匹配。"
    )
    DeleteComment.delete!(earlier_deletion, actor_id: replier.id)
    DeleteComment.delete!(deleted_root, actor_id: admin.id, delete_descendants: true)

    branch_root = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: "【只删除中间分支】这一支同时讨论输入校验和报告格式。管理员只移除了错误的输入校验分支，根评论与另一条讨论报告格式的回复仍然保留。"
    )
    deleted_branch = CreateComment.create!(
      parent_id: branch_root.id,
      user_id: replier.id,
      content: "这条中间评论以及下面的回复被管理员级联删除。根评论没有删除，回收站不提供父评论或根评论链接。"
    )
    CreateComment.create!(
      parent_id: deleted_branch.id,
      user_id: reader.id,
      content: "这条回复随中间评论一起删除；它与被删父评论属于同一批，但不能连带删除另一条兄弟分支。"
    )
    CreateComment.create!(
      parent_id: branch_root.id,
      user_id: reader.id,
      content: "我是仍然保留的兄弟分支，讨论的是报告格式。其他分支被管理员删除后，我仍然可以阅读、回复和投票，根评论的数量与最后活跃信息也应正确。"
    )
    DeleteComment.delete!(deleted_branch, actor_id: admin.id, delete_descendants: true)

    restored_root = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: "【部分恢复】这一支曾经被整支删除，现在已经按顺序恢复了根评论和子评论，孙评论还在回收站。恢复操作不能重排楼层，也不能重新发送回复通知。"
    )
    restored_child = CreateComment.create!(
      parent_id: restored_root.id,
      user_id: author.id,
      content: "我已经从回收站恢复，唯一的子评论仍被删除。因此我可以再次删除，也可以撤回；回收站剩下的那条记录不应再显示查看同批删除。"
    )
    remaining_deleted = CreateComment.create!(
      parent_id: restored_child.id,
      user_id: replier.id,
      content: "【同批只剩一条】祖先已经恢复，我仍在回收站。不再显示父评论链接；现在可以恢复我，并保持原来的楼层。"
    )
    DeleteComment.delete!(restored_root, actor_id: admin.id, delete_descendants: true)
    restored_root.reload.restore
    restored_child.reload.restore

    withdrawn_leaf = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: "【撤回但没有回复】我先撤回这份尚未验证的优化建议。因为没有任何回复，作者仍可直接删除；也可以恢复正文，不需要先打开编辑框。"
    )
    Comment::SaveOperation.update!(withdrawn_leaf, withdrawn: true)
    CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: <<-MARKDOWN
      【提及与 Markdown】这份配置练习希望请 @#{admin.login_name}、@#{replier.login_name}、@#{reader.login_name}、@#{users[4].login_name}、@#{users[5].login_name} 一起检查。第六个不同用户 @#{author.login_name} 超过五人上限，应保留为普通文字。

      行内代码 `@#{admin.login_name}`、[手写链接里的 @#{replier.login_name}](https://crystal-lang.org/) 和转义的 \\@#{users[4].login_name} 都不应额外识别为提及。

      text <iframe>@#{admin.login_name}</iframe>：清洗后不应留下 iframe 或它的提及链接。
      MARKDOWN
    )
    edited = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: "【作者编辑】建议先分别测试有效配置、文件不存在、JSON 无效和字段类型错误，再决定是否抽取统一的错误对象。"
    )
    UpdateComment.update!(
      edited,
      content: "#{edited.content}\n\n作者补充：校验失败后也要保留原始输入，方便复现；这条应显示编辑时间，且缓存 HTML 必须与修改后的 Markdown 一致。",
      actor_id: author.id
    )
    restored_leaf = CreateComment.create!(
      comment_thread_id: thread.id,
      user_id: author.id,
      content: "【删除后已恢复】这条没有回复的评论曾由作者删除，现在已经恢复。正文、HTML 和楼层都应保留；普通作者现在仍可再次删除或撤回它。"
    )
    DeleteComment.delete!(restored_leaf, actor_id: author.id)
    restored_leaf.reload.restore

    2.times do |index|
      removed = CreateComment.create!(
        parent_id: delete_ready.id,
        user_id: author.id,
        content: "#{source}单独删除示例 #{index + 1}：补充说明已经合入教程，这条重复留言不再保留。它没有后代，不应被错误地归入前后的级联删除批次。"
      )
      DeleteComment.delete!(removed, actor_id: index.zero? ? author.id : admin.id)
    end

    puts "#{source}：根评论 /comments/#{root.id}；第二页子评论 /comments/#{child.id}；孙评论 /comments/#{grandchild.id}。"
    puts "  删除／撤回均可用：/comments/#{leaf.id}；撤回根评论：/comments/#{withdrawn_root.id}；撤回中间评论：/comments/#{withdrawn_child.id}。"
    puts "  删除这条回复后父评论可删除：/comments/#{withdraw_child_reply.id}；回复已删的父评论：/comments/#{delete_ready.id}。"
    puts "  整支删除的孙评论：/admin/trash/comments/#{deleted_grandchild.id}；更早单独删除：/admin/trash/comments/#{earlier_deletion.id}。"
    puts "  中间分支删除：/admin/trash/comments/#{deleted_branch.id}；同批只剩一条：/admin/trash/comments/#{remaining_deleted.id}。"

    root
  end

  private def seed_comment_votes(comment : Comment, users : Array(User)) : Nil
    counts = Hash(String, Int32).from_json(comment.vote_counts.to_json)

    [{users[0], "👍"}, {users[2], "👍"}, {users[3], "😄"}, {users[4], "🎉"}, {users[0], "❤️"}].each do |user, vote_type|
      SaveVote.create!(user_id: user.id, comment_id: comment.id, vote_type: vote_type)
      counts[vote_type] += 1
    end

    # 与投票 Action 一样：先保存投票记录，再通过 Operation 同步 JSON 计数。
    UpdateCommentVoteCounts.update!(comment, vote_counts: Comment::VoteCounts.from_json(counts.to_json))
  end

  def print_exit(reason) : NoReturn
    STDERR.puts reason
    STDERR.puts "退出 ..."
    exit
  end
end
