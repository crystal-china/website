class Docs::SetupPage < MainLayout
  needs missing_files : Array(String)

  def page_title
    "Documentation setup"
  end

  def content
    section class: "#{page_container_classes} py-10" do
      article class: "prose-neutral mx-auto max-w-3xl prose" do
        h1 "Set up your documentation"
        para "Documentation files live outside the application binary. Create the files below manually, or let an administrator generate the starter files."
        para "Paths are relative to the server's working directory, not the binary's location. For example, if you start ./bin/crystal_china from the project root, use public/markdowns/ inside that root."

        h2 "Missing files"

        ul do
          missing_files.each do |path|
            li do
              code path
            end
          end
        end

        if (me = current_user) && me.admin?
          form_for Admin::Docs::Create do
            submit "Generate starter files", class: "form-submit"
          end
          para "Only missing files are created. Existing files, including an empty navigation.yml, are never overwritten."
        else
          para "Automatic generation is available to administrators only. Configure ADMIN_EMAILS in the server environment and sign in with a listed account. You can also create the files manually."

          unless current_user
            link "Sign in", to: SignIns::New.with(return_to: current_path), class: "form-submit"
          end
        end

        h2 "1. Create navigation.yml"
        para "This YAML file is a list of pages. Each entry needs a path and a title. The path is a /docs/ URL without the .md extension. List order controls the previous/next page links; children can be used to group pages in the sidebar."

        pre do
          code DocSetup::FILES[DocNavigation::CONFIG_PATH]
        end

        para "An empty file or [] is also valid: documents remain accessible, but have no sidebar or previous/next page links. Titles can then come from the Markdown front matter."

        h2 "2. Create index.md"
        para "This is the documentation home page at /docs/index. The optional YAML front matter between --- lines defines its title and subtitle. Everything after it is Markdown. When a page is in navigation.yml, that file's title takes precedence."

        pre do
          code DocSetup::FILES["public/markdowns/index.md"]
        end

        h2 "3. Add more documents"
        para "For example, create public/markdowns/guide.md to publish /docs/guide. Subdirectories work too: public/markdowns/install/linux.md is available at /docs/install/linux."
        para "To add a page to the sidebar and pager, append an entry to navigation.yml:"

        pre do
          code <<-YAML
            - path: /docs/guide
              title: Getting started
            YAML
        end

        para "A Markdown file not listed in navigation.yml is still directly accessible and searchable. A navigation entry alone does not create its Markdown file."

        h2 "4. Apply changes"
        para "After creating or editing these files, refresh the document page. No application rebuild or restart is required. For a remote deployment, synchronize public/markdowns/ to the server first."
        para "Viewing a document syncs its content into the database for search. To sync all documents at once, run bin/tasks db.sync_doc_content from the project root with the site's database configuration."
      end
    end
  end
end
