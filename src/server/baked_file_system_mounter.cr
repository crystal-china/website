require "baked_file_system_mounter"

BakedFileSystemMounter.assemble([
  "public/assets", "markdowns",
  "public/bun-manifest.json", "public/favicon.ico", "public/robots.txt",
])

if LuckyEnv.production?
  STDERR.puts "Mounting from baked file system ..."
  BakedFileSystemMounter::Storage.mount
end
