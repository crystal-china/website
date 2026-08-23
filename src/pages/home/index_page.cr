class Home::IndexPage < MainLayout
  def content
    div class: page_container_classes do
      header class: "flex flex-col items-center" do
        h1 "The Crystal programming language 中文站"

        div(
          class: "latest-release-info",
          hx_trigger: "load",
          hx_get: Home::Htmx::CrystalLatestRelease.path_without_query_params,
          hx_swap: "outerHTML",
        ) do
          a href: "", class: "inline-flex items-center gap-2" do
            text "Latest release:"
            mount Shared::Spinner, text: "获取最新版本...", width: "10px"
          end
        end

        tag(
          "canvas",
          height: 330,
          width: 330,
          id: "logo-canvas",
          class: "cursor-move",
          running: "false"
        )
      end

      # 使用 CSS Grid 布局。子元素不再按普通文档流堆叠，而是放进网格里。
      nav "aria-label": "常用站点链接", class: "mb-10 grid w-full grid-cols-[repeat(5,max-content)] items-start justify-between gap-x-10" do
        section do
          h2 "Official"
          ul do
            li { normal_link("https://www.crystal-lang.org", "Crystal website") }
            li { github_icon_link("https://github.com/crystal-lang", "Crystal lang") }
            li { normal_link "https://forum.crystal-lang.org", "Crystal forum" }
            li { normal_link "https://play.crystal-lang.org/", "Play Crystal online" }
          end
        end

        section do
          h2 "Docs"
          ul do
            li { normal_link "https://crystal-lang.org/api/latest/", "API document" }
            li { normal_link "https://devdocs.io/crystal", "devdocs Crystal" }
            li { normal_link "https://crystaldoc.info/", "crystaldoc.info" }
            li { normal_link "https://deepwiki.com/crystal-lang/crystal", "Deep WiKi" }
          end
        end

        section do
          h2 "Packages"
          ul do
            li { normal_link "https://shards.info/", "shards.info" }
            li { normal_link "https://shardbox.org/", "shardbox.org" }
          end
        end

        section do
          h2 "Organizations"
          ul do
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

        section do
          h2 "Chat"
          ul do
            li { normal_link "https://discord.gg/YS7YvQy", "Discord", target: "_blank" }
            li { normal_link "https://www.reddit.com/r/crystal_programming/", "Reddit" }
          end
        end
      end
    end
  end

  private def normal_link(link, content, **opts)
    a content, **opts, href: link
  end

  private def github_icon_link(link, content)
    a href: link, class: "inline-flex items-center gap-1 whitespace-nowrap" do
      text "#{content} "
      img src: asset("svgs/github-icon.svg"), alt: "github", class: "h-4 w-4 shrink-0"
    end
  end
end
