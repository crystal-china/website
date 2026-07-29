class Home::IndexPage < MainLayout
  def content
    div class: "brand-logo f-col align-items:center justify-content:center" do
      h1 "The Crystal programming language 中文站"

      div(
        class: "latest-release-info",
        hx_trigger: "load",
        hx_get: Home::Htmx::CrystalLatestRelease.path_without_query_params,
        hx_swap: "outerHTML",
      ) do
        a href: "" do
          span class: "f-row align-items:center" do
            text "Latest release:"
            mount Shared::Spinner, text: "获取最新版本...", width: "10px"
          end
        end
      end

      tag(
        "canvas",
        height: 300,
        width: 300,
        id: "logo-canvas",
        style: "cursor:move",
        running: "false"
      )
    end

    div style: "display: grid; grid-template-columns: repeat(5, max-content); justify-content: space-between; align-items: flex-start; max-width: 1800px; margin: 0 auto; column-gap: 56px;" do
      div do
        h2 "Official", class: "font-bold", style: "white-space: nowrap;"
        ul class: "align-items:stretch" do
          li { normal_link("https://www.crystal-lang.org", "Crystal website") }
          li { github_icon_link("https://github.com/crystal-lang", "Crystal lang") }
          li { normal_link "https://forum.crystal-lang.org", "Crystal forum" }
          li { normal_link "https://play.crystal-lang.org/", "Play Crystal online" }
        end
      end

      div do
        h2 "Docs", class: "font-bold", style: "white-space: nowrap;"
        ul do
          li { normal_link "https://crystal-lang.org/api/latest/", "API document" }
          li { normal_link "https://devdocs.io/crystal", "devdocs Crystal" }
          li { normal_link "https://crystaldoc.info/", "crystaldoc.info" }
          li { normal_link "https://deepwiki.com/crystal-lang/crystal", "Deep WiKi" }
        end
      end

      div do
        h2 "Packages", class: "font-bold", style: "white-space: nowrap;"
        ul class: "align-items:stretch" do
          li do
            a "shards.info", href: "https://shards.info/"
          end
          li do
            a "shardbox.org", href: "https://shardbox.org/"
          end
        end
      end

      div do
        h2 "Organizations", class: "font-bold", style: "white-space: nowrap;"
        ul class: "align-items:stretch" do
          li { github_icon_link("https://github.com/veelenga/awesome-crystal", "Awesome Crystal") }
          li { github_icon_link("https://github.com/crystal-ameba", "Crystal ameba") }
          li { github_icon_link("https://github.com/crystal-china", "Crystal China") }
          li { github_icon_link("https://github.com/crystal-community", "Crystal community") }
          li { github_icon_link("https://github.com/crystal-community", "Crystal Data") }
          li { github_icon_link("https://github.com/crystal-lang-tools", "Crystal lang tools") }
          li { github_icon_link("https://github.com/luckyframework", "Lucky web framework") }
          li { github_icon_link("https://github.com/naqvis", "Naqvis's github") }
        end
      end

      div do
        h2 "Chat", class: "font-bold", style: "white-space: nowrap;"
        ul class: "align-items:stretch" do
          li { normal_link "https://discord.gg/YS7YvQy", "Discord", target: "_blank" }
          li { normal_link "https://www.reddit.com/r/crystal_programming/", "Reddit" }
        end
      end
    end
  end

  private def normal_link(link, content, **opts)
    a content, **opts, href: link
  end

  private def github_icon_link(link, content)
    a href: link, style: "display: inline-flex; align-items: center; gap: 0.35rem; white-space: nowrap;" do
      text "#{content} "
      img src: asset("svgs/github-icon.svg"), alt: "github", style: "width: 15px; height: 15px; flex-shrink: 0;"
    end
  end
end
