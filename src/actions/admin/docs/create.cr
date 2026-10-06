class Admin::Docs::Create < AdminAction
  post "/admin/docs" do
    created_files = DocSetup.create_missing_files

    if created_files.empty?
      flash.info = "Documentation files already exist. No files were changed."
    else
      flash.success = "Created #{created_files.join(" and ")}. Existing files were not changed."
    end

    redirect to: ::Docs::Markdowns.with(requested_path: "index")
  rescue error : File::Error
    flash.failure = "Could not create documentation files. Check write permissions for public/markdowns. #{error.message}"

    redirect to: ::Docs::Markdowns.with(requested_path: "index")
  end
end
