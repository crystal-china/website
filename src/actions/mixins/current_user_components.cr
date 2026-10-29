module CurrentUserComponents
  # 默认继承调用方的用户；显式传入其他用户或 nil 时，以显式值为准。
  # 只包装本站的 BaseComponent，不影响第三方 Lucky 组件。
  def mount(
    comp : BaseComponent.class,
    *args,
    current_user : User? = self.current_user,
    **named_args,
  ) : Nil
    super(
      comp,
      *args,
      **named_args,
      current_user: current_user
    )
  end

  def mount(
    comp : BaseComponent.class,
    *args,
    current_user : User? = self.current_user,
    **named_args,
    &
  ) : Nil
    super(
      comp,
      *args,
      **named_args,
      current_user: current_user
    ) do |*yield_args|
      yield *yield_args
    end
  end

  def component(
    comp : BaseComponent.class,
    status : Int32? = nil,
    *,
    current_user : User? = self.current_user,
    **named_args,
  ) : Lucky::TextResponse
    super(
      comp,
      status,
      **named_args,
      current_user: current_user
    )
  end

  def component(
    comp : BaseComponent.class,
    status : HTTP::Status,
    *,
    current_user : User? = self.current_user,
    **named_args,
  ) : Lucky::TextResponse
    component(
      comp,
      status.value,
      **named_args,
      current_user: current_user
    )
  end
end
