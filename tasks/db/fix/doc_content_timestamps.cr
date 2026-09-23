require "digest/md5"

class Db::Fix::DocContentTimestamps < LuckyTask::Task
  summary "Restore historical Markdown modification times"

  def call
    Db::Fix::DocContentTimestampsTask.run
  end
end

module Db::Fix::DocContentTimestampsTask
  # Recovered from the retired public/docs/markdowns_timestamps.yml file.
  HISTORICAL_TIMESTAMPS = {
    "package_manager"                          => 1739386799_i64,
    "for_advanced_rubyists/type"               => 1741528471_i64,
    "for_advanced_rubyists/migrate_to_crystal" => 1748334422_i64,
    "for_advanced_rubyists/misc"               => 1763104065_i64,
    "for_advanced_rubyists/block"              => 1786704103_i64,
    "for_advanced_rubyists/method"             => 1786704103_i64,
    "for_advanced_rubyists/performance"        => 1786704103_i64,
    "profile"                                  => 1740128289_i64,
    "concurrency/concurrency_vs_parallelism"   => 1784379672_i64,
    "concurrency/execution_context"            => 1786704103_i64,
    "install"                                  => 1750088479_i64,
    "basic"                                    => 1786704103_i64,
    "concurrency"                              => 1786704103_i64,
    "cross_compile"                            => 1786704103_i64,
    "for_advanced_rubyists"                    => 1786704103_i64,
    "introduction"                             => 1786704103_i64,
    "puppies"                                  => 1787488869_i64,
    "index"                                    => 1788800584_i64,
  }

  def self.run
    restored = 0

    AppDatabase.transaction do
      HISTORICAL_TIMESTAMPS.each do |request_path, timestamp|
        markdown_path = MarkdownFile.resolve(request_path)
        unless markdown_path
          puts "Skipped missing Markdown: #{request_path}"
          next
        end

        doc_path = "/docs/#{request_path}"
        doc = DocQuery.new.path_index(doc_path).first? || SaveDoc.create!(path_index: doc_path)
        SaveDoc.update!(
          doc,
          content_digest: Digest::MD5.hexdigest(File.read(markdown_path)),
          content_updated_at: Time.unix(timestamp)
        )
        restored += 1
      end
    end

    puts "Restored #{restored} document timestamps"
  end
end
