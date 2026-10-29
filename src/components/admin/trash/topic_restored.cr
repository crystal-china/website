class Admin::Trash::TopicRestored < BaseComponent
  needs flash : Lucky::FlashStore

  def render : Nil
    # 表单负责移除卡片；本响应只额外更新提示，不重新加载回收站列表。
    tag(
      "hx-partial",
      hx_target: "#page-flash",
      hx_swap: "innerHTML"
    ) do
      mount Shared::FlashMessages, flash: flash
    end
  end
end
