require "baked_file_system_mounter"

BakedFileSystemMounter.assemble([
  "public/assets",
  "public/bun-manifest.json", "public/favicon.ico", "public/robots.txt", "public/social-preview.png",
])

if LuckyEnv.production?
  STDERR.puts "Mounting from baked file system ..."
  BakedFileSystemMounter::Storage.mount
end
