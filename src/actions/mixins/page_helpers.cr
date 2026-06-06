require "ecr"
require "digest/md5"

module PageHelpers
  PAGINATION_RELATION_MAPPING = {
    "/docs/index"                                    => {title: "前言", sub_title: "写在开始之前"},
    "/docs/introduction"                             => {title: "简介", sub_title: ""},
    "/docs/install"                                  => {title: "安装", sub_title: ""},
    "/docs/package_manager"                          => {title: "包管理", sub_title: "shards 命令", parent: "/docs/install"},
    "/docs/for_advanced_rubyists"                    => {title: "写给 Rubyists", sub_title: "分类讨论 Crystal 和 Ruby 的异同"},
    "/docs/for_advanced_rubyists/type"               => {title: "类型", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/for_advanced_rubyists/method"             => {title: "方法", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/for_advanced_rubyists/block"              => {title: "代码块", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/for_advanced_rubyists/misc"               => {title: "杂项", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/for_advanced_rubyists/performance"        => {title: "性能因素", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/for_advanced_rubyists/migrate_to_crystal" => {title: "迁移 Ruby 代码到 Crystal", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/basic"                                    => {title: "基础知识", sub_title: "一些基础知识的简单总结"},
    "/docs/profile"                                  => {title: "查找性能瓶颈 (WIP)", sub_title: "", hidden: "true"},
    "/docs/cross_compile"                            => {title: "交叉编译", sub_title: ""},
    "/docs/concurrency"                              => {title: "并发原语", sub_title: ""},
    "/docs/concurrency/execution_context"            => {title: "执行上下文(WIP)", sub_title: "", parent: "/docs/concurrency", hidden: "true"},
    "/docs/concurrency/concurrency_vs_parallelism"   => {title: "并发和并行（比较）", sub_title: "", parent: "/docs/concurrency"},
  }
  PAGINATION_URLS = PAGINATION_RELATION_MAPPING.keys

  record(
    PageMapping,
    name : String,
    path : String,
    parent : String = "root",
    child = [] of PageMapping,
  )

  SIDEBAR_LINKS = {} of String => PageMapping

  PAGINATION_RELATION_MAPPING.each do |k, v|
    parent = v[:parent]? || "root"
    hidden = v[:hidden]?

    if parent == "root"
      SIDEBAR_LINKS[k] = PageMapping.new(
        name: v[:title],
        path: k,
      ) unless hidden == "true"
    else
      if SIDEBAR_LINKS.has_key?(parent)
        SIDEBAR_LINKS[parent].child << PageMapping.new(
          name: v[:title],
          path: k,
        ) unless hidden == "true"
      end
    end
  end

  MARKDOWN_OPTIONS = Markd::Options.new(gfm: true, toc: true)

  def markdown(text) : String
    Markd.to_html(
      text,
      formatter: formatter,
      options: MARKDOWN_OPTIONS
    )
  end

  def current_path
    context.request.path
  end

  def current_reply_path
    current_path.sub("/docs", "/htmx/replies/docs")
  end

  private def find_or_create_doc
    doc = DocQuery.new.path_index(current_path).first?
    doc = SaveDoc.create!(path_index: current_path) if doc.nil?

    doc
  end

  def print_doc_info(doc)
    doc_info = "创建于：#{doc.created_at.to_s("%Y年%m月%d日")}"

    Lucky::AssetHelpers::ASSET_MANIFEST["docs/markdowns_timestamps.yml"]?.try do |path|
      timestamp_file = "public#{path}"
      if File.exists?(timestamp_file)
        YAML.parse(File.read(timestamp_file))[markdown_path]?.try do |date|
          doc_info = "#{doc_info}       最后编辑于: #{Time.unix(date.as_i64).to_local.to_s("%Y年%m月%d日")}"
        end
      end
    end

    doc_info = "#{doc_info}  | #{doc.view_count}次阅读" if doc.view_count > 0

    "<blockquote>#{doc_info}</blockquote>"
  end

  def print_votes(doc)
    me = current_user

    voted_types = if me.nil?
                    [] of String
                  else
                    VoteQuery.new.user_id(me.id).doc_id(doc.id).map &.vote_type
                  end

    div class: "f-row", style: "margin-bottom: 0px;" do
      mount(
        Shared::VoteButton,
        votes: Hash(String, Int32).from_json(doc.votes.to_json),
        doc_id: doc.id,
        current_user: me,
        voted_types: voted_types
      )
    end
  end

  private def show_replies_when_revealed
    trigger = context.request.headers["Referer"]? ? "revealed" : "load"

    div role: "feed", id: "replies", hx_get: current_reply_path, hx_trigger: trigger, hx_swap: "outerHTML" do
      mount Shared::Spinner, text: "正在读取评论..."
    end
  end

  # def asset_host
  #   Lucky::Server.settings.asset_host
  # end

  # def fingerprinted_filename(file_path : String)
  #   return file_path unless LuckyEnv.production?

  #   path = Path[file_path]
  #   basename = path.stem
  #   digest = Digest::MD5.hexdigest(File.read(path))[0..7]

  #   if basename.ends_with? digest
  #     file_path
  #   else
  #     (Path[path.dirname] / "#{basename}-#{digest}#{path.extension}").to_s
  #   end
  # end
end
