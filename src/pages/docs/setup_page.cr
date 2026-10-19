class Docs::SetupPage < MainLayout
  needs missing_files : Array(String)

  def page_title : String
    r(".page_title").t
  end

  def content : Nil
    section class: "#{page_container_classes} py-10" do
      article class: "prose-neutral mx-auto max-w-3xl prose" do
        h1 r(".heading").t
        para r(".introduction").t
        para r(".working_directory").t

        h2 r(".missing_files").t

        ul do
          missing_files.each do |path|
            li do
              code path
            end
          end
        end

        if (me = current_user) && me.admin?
          form_for Admin::Docs::Create do
            submit r(".generate").t, class: "form-submit"
          end
          para r(".never_overwrite").t
        else
          para r(".admin_help").t

          unless current_user
            link(
              r("common.sign_in").t,
              to: SignIns::New.with(return_to: current_path),
              class: "form-submit"
            )
          end
        end

        h2 r(".navigation_heading").t
        para r(".navigation_help").t

        pre do
          code DocSetup::FILES[DocNavigation::CONFIG_PATH]
        end

        para r(".empty_navigation").t

        h2 r(".index_heading").t
        para r(".index_help").t

        pre do
          code DocSetup::FILES["public/markdowns/index.md"]
        end

        h2 r(".more_heading").t
        para r(".more_help").t
        para r(".sidebar_help").t

        pre do
          code <<-YAML
            - path: /docs/guide
              title: Getting started
            YAML
        end

        para r(".unlisted_help").t

        h2 r(".apply_heading").t
        para r(".refresh_help").t
        para r(".search_help").t
      end
    end
  end
end
