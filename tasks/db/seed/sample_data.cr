# This task resets development data. Do not run it against a database you need to keep.
class Db::Seed::SampleData < LuckyTask::Task
  summary "Add sample database records helpful for development"

  def call : Nil
    abort "db.seed.sample_data 只允许在 development 环境运行" unless LuckyEnv.development?

    Signal::INT.trap do
      print_exit("\n按下 Ctrl C")
    end

    unless ENV.fetch("RUN_SCRIPT_SETUP", "false") == "true"
      print "重置所有开发数据？（y/yes 继续）"
      input = gets.try &.rstrip

      print_exit("拒绝执行") unless input.to_s.downcase.in? ["y", "yes"]
    end

    DocQuery.truncate(cascade: true)
    UserQuery.truncate(cascade: true)
    CommentQuery.truncate(cascade: true)

    users = [
      {"admin@crystal-china.org", "社区管理员", "admin"},
      {"me@163.com", "小明", "xiaoming"},
      {"user1@163.com", "Ruby 转 Crystal", "ruby_to_crystal"},
      {"user2@163.com", "并发学习者", "concurrency"},
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

    nodes = {} of String => Node
    [
      {"general", "综合讨论", "Crystal 语言及其生态相关的综合讨论。", "#16a34a", 100},
      {"help", "求助", "使用 Crystal 时遇到的问题与解决方案。", "#db2777", 90},
      {"projects", "项目与工具", "分享使用 Crystal 构建的项目、库与开发工具。", "#64748b", 70},
      {"learning", "学习资源", "教程、书籍及其他 Crystal 学习资料。", "#9333ea", 60},
    ].each do |slug, name, summary, color, position|
      nodes[slug] = NodeQuery.new.slug(slug).first? ||
                    SaveNode.create!(name: name, slug: slug, summary: summary, color: color, position: position)
    end

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
      {"help", "上传图片成功但预览里没有显示，先查哪里？", "图片上传接口返回了链接，编辑框里也插入了 Markdown，但点击预览后没有出现图片。", "你会先检查表单提交的字段、Markdown 渲染结果，还是浏览器的资源请求？"},
    ]

    topics = topic_data.each_with_index.map do |data, index|
      slug, title, background, question = data

      CreateTopic.create!(
        user_id: users[index % users.size].id,
        node_id: nodes[slug].id,
        title: title,
        content: <<-MARKDOWN
        ## 背景

        #{background}

        ## 想讨论的问题

        #{question}

        如果你遇到过类似情况，也欢迎附上具体代码、取舍理由或踩坑经过。
        MARKDOWN
      )
    end.to_a

    topics.each_with_index do |topic, index|
      thread_id = CommentThreadQuery.new.topic_id(topic.id).first.id

      CreateComment.create!(
        comment_thread_id: thread_id,
        user_id: users[(index + 1) % users.size].id,
        content: "我也遇到过类似场景。#{topic_data[index][2]} 我倾向于先写一个能复现问题的小例子，再决定是否抽象成通用方案。"
      )
      CreateComment.create!(
        comment_thread_id: thread_id,
        user_id: users[(index + 2) % users.size].id,
        content: "这个问题值得继续讨论。#{topic_data[index][3]} 如果能补上实际的代码和运行环境，其他人更容易给出有针对性的建议。"
      )
    end

    first_topic_thread_id = CommentThreadQuery.new.topic_id(topics.first.id).first.id
    topic_root = CreateComment.create!(
      comment_thread_id: first_topic_thread_id,
      user_id: users[1].id,
      content: "我会先选一个输入明确的小脚本来迁移，而不是一次搬整个项目。这样每处理一个 Nil 联合类型，都能马上运行对应示例验证行为。"
    )

    10.times do |index|
      CreateComment.create!(
        comment_thread_id: first_topic_thread_id,
        user_id: users[(index + 2) % users.size].id,
        content: "补充第 #{index + 1} 个迁移时遇到的细节：先把输入和输出类型写在方法边界，再逐个处理可能为 Nil 的值。这样报错位置更集中，也方便后来的人阅读。"
      )
    end

    12.times do |index|
      CreateComment.create!(
        parent_id: topic_root.id,
        user_id: users[(index + 2) % users.size].id,
        content: "关于第 #{index + 1} 处类型处理，我会先为外部输入写一个明确的转换方法，再让内部代码使用更窄的类型。这样不用到处加 not_nil!，测试也更容易覆盖失败分支。"
      )
    end

    ["/docs/index", "/docs/concurrency"].each do |path|
      markdown_path = MarkdownFile.resolve(path.sub(%r{\A/docs/}, "")) || raise "Missing Markdown for #{path}"
      DocContent.sync(path, File.read(markdown_path))
    end

    doc_thread_id = CommentThreadQuery.new.doc_id(DocQuery.new.path_index("/docs/index").first.id).first.id
    doc_root = CreateComment.create!(
      comment_thread_id: doc_thread_id,
      user_id: users[2].id,
      content: <<-MARKDOWN
      前言里把 Crystal 与 Ruby 的关系讲得很清楚。我最关心的是从 Ruby 迁移现有脚本时，哪些动态写法值得保留，哪些应该趁机改成显式类型。

      > 能否再加一个小型迁移示例？

      我想先试一个只读配置文件并输出报告的脚本。

      @#{users[0].login_name} 这个示例适合放在前言后面吗？
      MARKDOWN
    )

    doc_child = CreateComment.create!(
      parent_id: doc_root.id,
      user_id: users[1].id,
      content: <<-MARKDOWN
      我赞成从读取配置文件开始。这个练习能同时覆盖文件路径、字符串处理和可能失败的输入，比一开始迁移完整 Web 项目更容易定位问题。

      可以分三步实现：

      1. 读取文件并输出原始内容。
      2. 解析 JSON，再为配置定义明确的类型。
      3. 为文件不存在、字段缺失和格式错误分别给出提示。

      如果示例还介绍 PGroonga 中文搜索，后续就能把读取的内容存入数据库并验证检索结果。
      MARKDOWN
    )
    doc_grandchild = CreateComment.create!(
      parent_id: doc_child.id,
      user_id: users[3].id,
      content: <<-MARKDOWN
      @#{users[1].login_name} 我按这个顺序试了一遍，确实容易理解。补充一个细节：外部输入可能为空，但转换后的内部配置可以保持非空，避免在每个方法里重复处理 Nil。

      ```crystal
      require "json"

      config = JSON.parse(File.read("config.json"))
      title = config["title"].as_s
      puts title
      ```

      @#{users[2].login_name} 可以先运行这段最小示例，再补上异常处理。这条是对子评论的回复，页面应显示我回复的是小明，而不是根评论作者。
      MARKDOWN
    )

    # Later floors put the root, child and grandchild on page 2 in descending order.
    12.times do |index|
      CreateComment.create!(
        comment_thread_id: doc_thread_id,
        user_id: users[(index + 1) % users.size].id,
        content: "阅读前言后的第 #{index + 1} 个问题：我正在把一个 Ruby 小工具迁到 Crystal。最有帮助的是完整示例，包括依赖安装、运行命令和常见类型错误的解释。"
      )
      CreateComment.create!(
        parent_id: doc_root.id,
        user_id: users[(index + 2) % users.size].id,
        content: "第 #{index + 1} 条补充：可以先把文件读取和内容解析拆开，再单独处理失败情况。这样同一段示例既能演示类型推断，也能说明错误消息从哪里来。"
      )
    end

    concurrency_thread_id = CommentThreadQuery.new.doc_id(DocQuery.new.path_index("/docs/concurrency").first.id).first.id
    CreateComment.create!(
      comment_thread_id: concurrency_thread_id,
      user_id: users[3].id,
      content: <<-MARKDOWN
      并发章节对 Fiber、Channel 和并行的区分很有帮助。我之前误以为启动多个 Fiber 就能让 CPU 密集任务自动跑满多核。

      > 并发描述的是如何组织任务，并行描述的是如何执行。

      这个区别配合一个计时例子会更容易理解。
      MARKDOWN
    )

    CreateTopic.create!(
      user_id: users[1].id,
      node_id: nodes["learning"].id,
      title: "准备做一个 Crystal 入门练习，欢迎补充建议",
      content: "我准备从读取配置文件、解析 JSON 和输出 Markdown 报告开始练习。这篇主题暂时没有回复，可以检查列表中的零回复状态，以及作者编辑和删除按钮。"
    )

    UpdateTopic.update!(
      topics[2],
      content: "#{topics[2].content}\n\n## 作者补充\n\n检查失败时应返回非零退出码，方便 CI 阻止继续发布。",
      actor_id: topics[2].user_id
    )
    UpdateTopic.update!(
      topics[1],
      node_id: nodes["general"].id,
      title: "Channel 消费者退出后，生产者应该如何收尾？（补充讨论范围）",
      actor_id: users[0].id
    )
    UpdateComment.update!(
      doc_child,
      content: "#{doc_child.content}\n\n补充：每一步都保留可以直接运行的命令，方便读者验证结果。",
      actor_id: doc_child.user_id
    )
    UpdateComment.update!(
      doc_grandchild,
      content: "#{doc_grandchild.content}\n\n管理员补充：示例中的配置文件需要先在当前目录创建。",
      actor_id: users[0].id
    )

    seed_trash(users, nodes["general"], concurrency_thread_id, first_topic_thread_id)

    users.each do |user|
      NotificationQuery.new.user_id(user.id).id.asc_order.limit(3).each do |notification|
        SaveNotification.update!(notification, read_at: Time.utc)
      end
    end

    puts "Created #{TopicQuery.new.select_count} visible topics, #{users.size} users and comments on two searchable Markdown documents."
    puts "Try /forum?page=2, /forum/#{topics.first.id}, /docs/index, and search for PGroonga."
    puts "Foreword: 13 root comments and 14 replies in the first root's branch (10 per page)."
    puts "Jump to page 2 in descending order:"
    puts "  Root: /comments/#{doc_root.id}"
    puts "  Child: /comments/#{doc_child.id}"
    puts "  Grandchild: /comments/#{doc_grandchild.id}"
    puts "Sign in as admin@crystal-china.org, me@163.com or user1@163.com to test notification jumps."
    puts "All sample accounts use password: temp1234."
    puts "Set ADMIN_EMAILS=admin@crystal-china.org before starting the app to enable the sample administrator."
    puts "Trash: /admin/trash (#{CommentQuery.new.only_soft_deleted.select_count} comments, including page 2), /admin/trash?kind=topics."
    puts "Notifications include read/unread replies, mentions, and administrator edits, moves and deletions."
    puts "Account history: /me/events; admin and xiaoming have multiple pages, ruby_to_crystal has one event, concurrency has none."
    puts "History includes nickname/login-name changes, password changes, password/OAuth logins, and administrator password removals."
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

      user = UpdateUser.update!(user, password: "sample1234", password_confirmation: "sample1234")
      # 模拟历史移除事件，保留实际操作者；不禁用演示账号当前的密码登录。
      SaveUserAudit.create!(user_id: user.id, actor_id: users.first.id, kind: :password_removed)
      user = UpdateUser.update!(user, password: "temp1234", password_confirmation: "temp1234")
      SaveUserAudit.create!(user_id: user.id, kind: :password_signed_in)

      # 真实修改生成事件后，仅调整演示日期；改名事件仍位于注册后前七天。
      User::SaveOperation.update!(user, created_at: now - 1096.days)
      UserAuditQuery.new.user_id(user.id).id.asc_order.results.each_with_index do |audit, index|
        at = now - event_ages[index]

        SaveUserAudit.update!(audit, created_at: at, updated_at: at)
      end
    end

    User::SaveOperation.update!(users[2], created_at: now - 2.days)
    SaveUserAudit.create!(user_id: users[2].id, kind: :oauth_signed_in, oauth_provider: "github", created_at: now - 1.day, updated_at: now - 1.day)
  end

  private def seed_trash(users : Array(User), node : Node, doc_thread_id : Int64, topic_thread_id : Int64) : Nil
    admin, author, replier, reader = users

    [{"文档", doc_thread_id}, {"社区", topic_thread_id}].each do |source, thread_id|
      visible_root = CreateComment.create!(
        comment_thread_id: thread_id,
        user_id: author.id,
        content: "回收站演示：#{source}评论的中间一层被删除后，其他回复仍然保留。展开本分支，可以检查引用已删除评论时的提示。"
      )
      deleted_child = CreateComment.create!(
        parent_id: visible_root.id,
        user_id: replier.id,
        content: "这条#{source}子评论将由管理员删除，但它下面仍有一条保留的回复。可以从回收站恢复本条评论，比较恢复前后的引用文字和数量。"
      )
      CreateComment.create!(
        parent_id: deleted_child.id,
        user_id: reader.id,
        content: "我回复的是中间一层，而不是根评论。即使中间一层被删除，这条回复仍然可见，页面应提示我回复的是已删除的评论。"
      )
      DeleteComment.delete!(deleted_child, actor_id: admin.id)

      deleted_root = CreateComment.create!(
        comment_thread_id: thread_id,
        user_id: author.id,
        content: "回收站演示：这条#{source}根评论被删除后，整个分支暂时不可见，但子评论记录和已生成的 HTML 都应保留。"
      )
      hidden_child = CreateComment.create!(
        parent_id: deleted_root.id,
        user_id: replier.id,
        content: "请先单独恢复这条#{source}子评论。由于根评论还在回收站，恢复后仍不可见，后台应该显示相应提示。"
      )
      hidden_grandchild = CreateComment.create!(
        parent_id: hidden_child.id,
        user_id: reader.id,
        content: "这条后代评论没有被软删除，只因根评论被删除而不可见。恢复根评论后，可以再次通过原来的跳转链接访问。"
      )
      DeleteComment.delete!(hidden_child, actor_id: admin.id)
      DeleteComment.delete!(deleted_root, actor_id: admin.id)

      # 两种来源各补七条叶子评论，让评论回收站超过每页二十条。
      7.times do |index|
        leaf = CreateComment.create!(
          parent_id: visible_root.id,
          user_id: author.id,
          content: "#{source}回收站分页示例 #{index + 1}：这条没有子回复的评论可以由作者删除。恢复后应重新出现在原来的楼层，而不是重新分配楼层号。"
        )
        DeleteComment.delete!(leaf, actor_id: index.even? ? author.id : admin.id)
      end

      puts "#{source} trash example: visible branch /comments/#{visible_root.id}; hidden descendant /comments/#{hidden_grandchild.id}."
    end

    topic = CreateTopic.create!(
      user_id: author.id,
      node_id: node.id,
      title: "已删除主题：讨论如何验证备份恢复流程",
      content: <<-MARKDOWN
      ## 演练目标

      这篇主题由管理员软删除，用来验证主题与评论的恢复顺序。

      - 主题删除后，正文和整个评论区都不可访问。
      - 先恢复子评论，应提示所属主题仍被删除。
      - 恢复主题后，未单独删除的评论重新可见；单独删除的评论仍留在回收站。

      @#{reader.login_name} 可以从通知里测试已删除内容的友好提示页。
      MARKDOWN
    )
    thread_id = CommentThreadQuery.new.topic_id(topic.id).first.id
    root = CreateComment.create!(
      comment_thread_id: thread_id,
      user_id: replier.id,
      content: "这条根评论没有被删除，只是所属主题被删除后暂时不可见。恢复主题时，不需要再单独恢复它。"
    )
    child = CreateComment.create!(
      parent_id: root.id,
      user_id: reader.id,
      content: "这条评论在主题删除之前就已经单独删除。只恢复主题，不应该把它一起恢复。"
    )
    CreateComment.create!(
      parent_id: child.id,
      user_id: author.id,
      content: "恢复主题后，这条没有被删除的后代评论仍然保留，并显示回复已删除评论的提示。"
    )
    DeleteComment.delete!(child, actor_id: admin.id)
    DeleteTopic.delete!(topic, actor_id: admin.id)

    empty_topic = CreateTopic.create!(
      user_id: reader.id,
      node_id: node.id,
      title: "已删除主题：作者撤回了尚无回复的练习计划",
      content: "我原本打算发布一个配置文件解析练习，后来发现示例还需要补充。由于没有任何回复，作者可以自己删除；管理员可以从回收站恢复。"
    )
    DeleteTopic.delete!(empty_topic, actor_id: reader.id)

    puts "Deleted topic: /forum/#{topic.id}; separately deleted comment: /comments/#{child.id}."
  end

  def print_exit(reason) : NoReturn
    STDERR.puts reason
    STDERR.puts "退出 ..."
    exit
  end
end
