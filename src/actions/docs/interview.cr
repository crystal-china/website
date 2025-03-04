class Docs::Interview < DocAction
  get "/docs/interview" do
    html Docs::InterviewPage
  end
end
