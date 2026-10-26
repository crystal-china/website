require "../spec_helper"

private class ComponentUserIdentity < BaseComponent
  needs label : String

  def render : Nil
    span "#{label}:#{current_user.try(&.login_name) || "guest"}"
  end

  def render(&) : Nil
    render
    yield label
  end
end

private class ComponentUserNested < BaseComponent
  def render : Nil
    mount ComponentUserIdentity, label: "nested"
  end
end

private class PlainLuckyComponent < Lucky::BaseComponent
  needs label : String

  def render : Nil
    span label
  end
end

private class ComponentUserParent < BaseComponent
  needs alternate_user : User

  def render : Nil
    mount ComponentUserIdentity, label: "inherited"
    mount ComponentUserNested
    mount ComponentUserIdentity, label: "alternate", current_user: alternate_user
    mount ComponentUserIdentity, label: "anonymous", current_user: nil
    mount PlainLuckyComponent, label: "plain"

    mount ComponentUserIdentity, "block" do |label|
      text "yielded:#{label}"
    end
  end
end

private class ComponentUserAction
  include Lucky::Renderable
  include CurrentUserComponents

  getter current_user : User?
  getter context : HTTP::Server::Context

  def initialize(@current_user, @context)
  end
end

describe CurrentUserComponents do
  it "inherits users through nested mounts while preserving explicit overrides, positional arguments and blocks" do
    user = UserFactory.create
    alternate = UserFactory.create
    html = ComponentUserParent.new(
      alternate_user: alternate,
      current_user: user
    ).context(time_zone_context).render_to_string

    html.should contain("inherited:#{user.login_name}")
    html.should contain("nested:#{user.login_name}")
    html.should contain("alternate:#{alternate.login_name}")
    html.should contain("anonymous:guest")
    html.should contain("block:#{user.login_name}")
    html.should contain("yielded:block")
    html.should contain("<span>plain</span>")
  end

  it "inherits guest access without falling back to another request's user" do
    user = UserFactory.create
    context = time_zone_context
    signed_in = ComponentUserAction.new(user, context)
    guest = ComponentUserAction.new(nil, time_zone_context)

    signed_in.component(ComponentUserIdentity, label: "signed-in").body.should eq("<span>signed-in:#{user.login_name}</span>")
    guest.component(ComponentUserIdentity, label: "guest").body.should eq("<span>guest:guest</span>")
    signed_in.component(ComponentUserIdentity, label: "anonymous", current_user: nil).body.should eq("<span>anonymous:guest</span>")
  end

  it "preserves component response status and propagates explicitly supplied users into nested components" do
    user = UserFactory.create
    alternate = UserFactory.create
    action = ComponentUserAction.new(user, time_zone_context)
    response = action.component(
      ComponentUserNested,
      status: HTTP::Status::ACCEPTED,
      current_user: alternate
    )

    response.status.should eq(202)
    response.body.to_s.should contain("nested:#{alternate.login_name}")
    action.component(ComponentUserIdentity, 201, label: "created").status.should eq(201)
    action.component(ComponentUserIdentity, label: "default").status.should eq(200)
    action.component(PlainLuckyComponent, label: "plain").body.should eq("<span>plain</span>")
  end
end
