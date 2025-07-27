class Me::EditPage < MainLayout
  needs op : UpdateUser

  def content
    figure do
      figcaption "编辑我的信息"

      form_for Me::Update, class: "table rows" do
        para do
          label_for op.name, "昵称"
          text_input op.name
        end

        para do
          label_for op.avatar, "头像（目前仅支持 http/https 链接）"
          text_input op.avatar
          if (avatar = op.avatar.value)
            img src: avatar
          end
        end

        para do
          label_for op.password, "密码"
          password_input op.password, auto_focus: true
        end

        para do
          label_for op.password, "确认密码"
          password_input op.password_confirmation
        end

        para class: "f-row align-items:center" do
          submit "保存"

          a "返回", href: previous_url(fallback: Home::Index)
        end
      end
    end
  end
end
