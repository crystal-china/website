# 如果将这个实例变量放在 PageHelpers 里，页面、作者卡片、每张评论卡片都是不同实例，就会各自缓存一次，而不是整次请求只解析一次。
# 不是所有用户共享一个 Context：每个请求都有自己的对象
class HTTP::Server::Context
  @time_zone : Time::Location?

  # 页面和组件共用本次请求的时区，避免每显示一条时间就重新读取 Cookie 和加载时区。
  def time_zone : Time::Location
    @time_zone ||= resolve_time_zone
  end

  private def resolve_time_zone : Time::Location
    # 浏览器写入的是普通 Cookie，不经过 Lucky CookieJar 的加密/解密。
    if (name = request.cookies["time_zone"]?.try(&.value)) && !name.empty?
      return Time::Location.load?(URI.decode(name)) || Time::Location.local
    end

    Time::Location.local
  rescue Time::Error | ArgumentError
    # 无效名称或时区数据不可用时，不影响页面渲染。
    Time::Location.local
  end
end
