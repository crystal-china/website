class UpdateSpaceSettings < Space::SaveOperation
  permit_columns(
    logo_url,
    contact_email,
    source_url
  )

  # 保存站点信息 Tab 的图片、联系邮箱、源码入口和 Footer 链接。
  before_save do
    normalize_site_fields
    validate_site_fields
    assign_and_validate_footer_links
  end

  # 显示本次编辑的链接行；未配置时使用默认值，校验失败时保留提交的行。
  def footer_link_rows : Array(Space::FooterLink)
    footer_links.value || Space::DEFAULT_FOOTER_LINKS
  end

  private def normalize_site_fields : Nil
    if (value = logo_url.value)
      logo_url.value = value.strip
    end

    if (value = contact_email.value)
      contact_email.value = value.strip
    end

    if (value = source_url.value)
      source_url.value = value.strip
    end
  end

  private def validate_site_fields : Nil
    if (url = logo_url.value) && !url.blank? && !image_url?(url)
      logo_url.add_error r("validations.site_image_url").t
    end

    if (url = source_url.value) && !url.blank? && !http_url?(url)
      source_url.add_error r("validations.site_http_url").t
    end

    unless contact_email.value.to_s.blank?
      validate_format_of(
        contact_email,
        with: /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/,
        allow_nil: true
      )
    end
  end

  private def assign_and_validate_footer_links : Nil
    if params.get?("footer_links")
      footer_links.value = params.many_nested?("footer_links").map do |row|
        Space::FooterLink.new(
          title: row["title"]?.to_s.strip,
          url: row["url"]?.to_s.strip,
          icon: row["icon"]?.to_s.strip
        )
      end.reject { |link| link.title.blank? && link.url.blank? && link.icon.blank? }
    end

    footer_link_rows.each_with_index do |link, index|
      if link.title.blank? || !http_url?(link.url) || !image_url?(link.icon)
        footer_links.add_error r("validations.site_footer_link").t(row: (index + 1).to_s)
      end
    end
  end

  private def image_url?(value : String) : Bool
    Lucky::AssetHelpers::ASSET_MANIFEST.has_key?(value) || http_url?(value)
  end

  private def http_url?(value : String) : Bool
    uri = URI.parse(value)

    uri.scheme.in?({"http", "https"}) && !uri.host.to_s.blank?
  rescue URI::Error
    false
  end
end
