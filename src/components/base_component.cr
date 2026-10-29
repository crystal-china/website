abstract class BaseComponent < Lucky::BaseComponent
  include PageHelpers
  include CurrentUserComponents

  # mount/component 自动从调用方传入；直接 new 不会自动继承。
  needs current_user : User?
end
