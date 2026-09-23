require "yaml"

module DocNavigation
  CONFIG_PATH = "public/markdowns/navigation.yml"

  class Page
    include YAML::Serializable

    getter path : String
    getter title : String
    getter sub_title : String = ""
    getter hidden : Bool = false
    getter children : Array(Page) = [] of Page
  end

  @@navigation : Array(Page)? = nil
  @@pages : Array(Page)? = nil
  @@pages_by_path : Hash(String, Page)? = nil
  @@modified_at : Time? = nil

  def self.load : Nil
    modified_at = File.info(CONFIG_PATH).modification_time
    return if @@modified_at == modified_at

    navigation = Array(Page).from_yaml(File.read(CONFIG_PATH))
    pages = navigation.flat_map { |page| flatten(page) }
    validate(pages)
    remove_hidden_pages(navigation)

    @@navigation = navigation
    @@pages = pages
    @@pages_by_path = pages.to_h { |page| {page.path, page} }
    @@modified_at = modified_at
  end

  def self.navigation : Array(Page)
    load unless @@navigation
    @@navigation.not_nil!
  end

  def self.pages : Array(Page)
    load unless @@pages
    @@pages.not_nil!
  end

  def self.pages_by_path : Hash(String, Page)
    load unless @@pages_by_path
    @@pages_by_path.not_nil!
  end

  private def self.validate(pages : Array(Page))
    duplicate_path = pages.group_by(&.path).find { |_, matching_pages| matching_pages.size > 1 }.try(&.[0])
    raise "Duplicate document path in #{CONFIG_PATH}: #{duplicate_path}" if duplicate_path

    pages.each do |page|
      raise "Invalid document path in #{CONFIG_PATH}: #{page.path}" unless page.path.starts_with?("/docs/")
    end
  end

  private def self.flatten(page : Page) : Array(Page)
    [page] + page.children.flat_map { |child| flatten(child) }
  end

  private def self.remove_hidden_pages(pages : Array(Page)) : Nil
    pages.reject!(&.hidden)
    pages.each { |page| remove_hidden_pages(page.children) }
  end
end
