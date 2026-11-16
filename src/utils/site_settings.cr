class HTTP::Server::Context
  include Lucky::Memoizable

  # 本次请求只读取一次默认 Space，供 Navbar、Footer 和社区计数共用。
  memoize def site_space : Space?
    Space::BaseQuery.new.id(Space::DEFAULT_ID).first?
  end
end
