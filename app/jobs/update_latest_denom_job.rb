class UpdateLatestDenomJob < ApplicationJob
  queue_as :default

  def perform(*args)
    all = VendorService.get_products
    api_items = all['data'] || []

    # 🔥 NEW — Collect all codes from API
    api_codes = api_items.map { |item| item["id"].to_s }

    # 🔥 NEW — Deactivate products not in API list
    TopupProduct.where.not(code: api_codes).update_all(is_active: false)

    api_items.each do |item|
      code = item["id"].to_s
      prod = TopupProduct.find_or_initialize_by(code: code)

      # Set product fields from API data
      prod.title = item["name"] || item["title"] || "Product #{code}"
      prod.description = item["description"] if item["description"].present?
      prod.category = item["category"] if item["category"].present?
      prod.is_active = item["active"] || item["isActive"] || true   # remain active if API includes it
      prod.origin_id = item["id"].to_s
      prod.publisher = item["publisher"] if item["publisher"].present?
      prod.logo_url = item["logoUrl"] if item["logoUrl"].present?
      prod.avatar_url = item["avatarUrl"] if item["avatarUrl"].present?
      prod.publisher_logo_url = item["publisherLogoUrl"] if item["publisherLogoUrl"].present?
      
      unless prod.save
        Rails.logger.error "Failed to save TopupProduct #{code}: #{prod.errors.full_messages.join(', ')}"
        next
      end

      if item["logoUrl"].present?
        begin
          file = URI.open(item["logoUrl"])
          extension = file.content_type.split('/').last
          prod.logo.attach(io: file, filename: "logo_#{code}.#{extension}")
          Rails.logger.info "Attached logo for product #{code}"
        rescue => e
          Rails.logger.error "Failed to attach logo for product #{code}: #{e.message}"
        end
      end
    end
  end
end
