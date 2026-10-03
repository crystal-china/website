# This task resets development data. Do not run it against a database you need to keep.
class Db::Seed::SampleData < LuckyTask::Task
  summary "Add sample database records helpful for development"

  def call
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
      {"admin@crystal-china.org", "社区管理员"},
      {"me@163.com", "小明"},
      {"user1@163.com", "Ruby转Crystal"},
      {"user2@163.com", "并发学习者"},
    ].map do |email, name|
      user = SignUpUser.create!(
        email: email,
        password: "temp1234",
        password_confirmation: "temp1234",
        captcha_code: "sample-data"
      )
      UpdateUser.update!(user, name: name)
    end

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

      SaveTopic.create!(
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

      SaveComment.create!(
        comment_thread_id: thread_id,
        user_id: users[(index + 1) % users.size].id,
        content: "我也遇到过类似场景。#{topic_data[index][2]} 我倾向于先写一个能复现问题的小例子，再决定是否抽象成通用方案。"
      )
      SaveComment.create!(
        comment_thread_id: thread_id,
        user_id: users[(index + 2) % users.size].id,
        content: "这个问题值得继续讨论。#{topic_data[index][3]} 如果能补上实际的代码和运行环境，其他人更容易给出有针对性的建议。"
      )
    end

    first_topic_thread_id = CommentThreadQuery.new.topic_id(topics.first.id).first.id
    topic_root = SaveComment.create!(
      comment_thread_id: first_topic_thread_id,
      user_id: users[1].id,
      content: "我会先选一个输入明确的小脚本来迁移，而不是一次搬整个项目。这样每处理一个 Nil 联合类型，都能马上运行对应示例验证行为。"
    )

    10.times do |index|
      SaveComment.create!(
        comment_thread_id: first_topic_thread_id,
        user_id: users[(index + 2) % users.size].id,
        content: "补充第 #{index + 1} 个迁移时遇到的细节：先把输入和输出类型写在方法边界，再逐个处理可能为 Nil 的值。这样报错位置更集中，也方便后来的人阅读。"
      )
    end

    12.times do |index|
      SaveComment.create!(
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
    doc_root = SaveComment.create!(
      comment_thread_id: doc_thread_id,
      user_id: users[2].id,
      content: <<-MARKDOWN
      前言里把 Crystal 与 Ruby 的关系讲得很清楚。我最关心的是从 Ruby 迁移现有脚本时，哪些动态写法值得保留，哪些应该趁机改成显式类型。

      > 能否再加一个小型迁移示例？

      我想先试一个只读配置文件并输出报告的脚本。
      MARKDOWN
    )

    12.times do |index|
      SaveComment.create!(
        comment_thread_id: doc_thread_id,
        user_id: users[(index + 1) % users.size].id,
        content: "阅读前言后的第 #{index + 1} 个问题：我正在把一个 Ruby 小工具迁到 Crystal。最有帮助的是完整示例，包括依赖安装、运行命令和常见类型错误的解释。"
      )
      SaveComment.create!(
        parent_id: doc_root.id,
        user_id: users[(index + 2) % users.size].id,
        content: "第 #{index + 1} 条补充：可以先把文件读取和内容解析拆开，再单独处理失败情况。这样同一段示例既能演示类型推断，也能说明错误消息从哪里来。"
      )
    end

    concurrency_thread_id = CommentThreadQuery.new.doc_id(DocQuery.new.path_index("/docs/concurrency").first.id).first.id
    SaveComment.create!(
      comment_thread_id: concurrency_thread_id,
      user_id: users[3].id,
      content: <<-MARKDOWN
      并发章节对 Fiber、Channel 和并行的区分很有帮助。我之前误以为启动多个 Fiber 就能让 CPU 密集任务自动跑满多核。

      > 并发描述的是如何组织任务，并行描述的是如何执行。

      这个区别配合一个计时例子会更容易理解。
      MARKDOWN
    )

    puts "Created #{topics.size} topics, #{users.size} users and comments on two searchable Markdown documents."
    puts "Try /forum?page=2, /forum/#{topics.first.id}, /docs/index, and search for PGroonga."
  end

  def print_exit(reason)
    STDERR.puts reason
    STDERR.puts "退出 ..."
    exit
  end
end
