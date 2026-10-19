class OnlinePresence
  # 维护一个网站在线用户的内存哈希，{id1.to_s => last_actived_at, id2 => .., id3 ...}
  @users = Cache::MemoryStore(Time).new(expires_in: 3.minutes)
  # 类似，值是布尔
  @guests = Cache::MemoryStore(Bool).new(expires_in: 3.minutes)
  # 结构： {id => {last_active_at: 最后激活时间, duration:  自从上次写入数据库，且处于连续激活状态，过去的时间间隔。}}
  # 不设过期时间，因为之后写入 user 的 online_seconds/last_active_at 字段后，删除。
  @pending = {} of Int64 => NamedTuple(last_active_at: Time, duration: Time::Span)
  @mutex = Mutex.new

  # 登记用户的 last_active_at、统计在线人数，累计尚未写入数据库的在线时长
  def record(user_id : Int64?, ip : String) : Tuple(Int32, Int32)
    @mutex.synchronize do
      if user_id
        at = Time.utc
        pending = @pending[user_id]?
        duration = pending ? pending[:duration] : 0.seconds

        # 即使用户多个页面存在多次 record 调用，@mutex.synchronize 也能保证顺序执行。
        # 后一次看到的 previous 是前一次 @users.write 刚刚写入的，因此
        # 请求                           本次增加
        # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━
        # 10:00:00，标签页 A 首次心跳        0 秒
        # ─────────────────────────────  ──────────
        # 10:02:00，标签页 A 心跳          120 秒
        # ─────────────────────────────  ──────────
        # 10:02:01，标签页 B 心跳            1 秒
        # ─────────────────────────────  ──────────
        # 10:02:30，刷新页面                29 秒

        # duration 累计是 150 秒不变。
        if (previous = @users.read(user_id.to_s))
          # 防止服务器时钟往回调整
          at = previous if at < previous
          interval = at - previous
          # 多标签页、刷新只累计真实间隔；中断超过三分钟就算离线。
          duration += interval
        end

        @users.write(user_id.to_s, at)
        @pending[user_id] = {last_active_at: at, duration: duration}
      else
        @guests.write(ip, true)
      end

      {@users.keys.size, @guests.keys.size}
    end
  end

  def flush : Nil
    @mutex.synchronize do
      @pending.keys.each do |user_id|
        activity = @pending[user_id]

        # SET online_seconds = online_seconds + $1 pg 能够保证原子递增。
        # 修改 updated_at 或生成账户事件；
        AppDatabase.exec(
          "UPDATE users SET online_seconds = online_seconds + $1, last_active_at = GREATEST(last_active_at, $2) WHERE id = $3",
          activity[:duration].total_seconds.to_i64,
          activity[:last_active_at],
          user_id
        )
        # exec 失败会抛异常，中断执行，成功后才清除待写回值。
        @pending.delete(user_id)
      end
    end
  end
end
