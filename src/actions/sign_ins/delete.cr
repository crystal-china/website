class SignIns::Delete < BrowserAction
  delete "/sign_out" do
    sign_out
    flash.success = "取消登录成功"

    if context.request.headers["HX-Request"]?
      context.response.headers["HX-Redirect"] = SignIns::New.path
      head 200
    else
      redirect to: SignIns::New
    end
  end
end
