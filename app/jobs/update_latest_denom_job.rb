class UpdateLatestDenomJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Fetch all products with pagination
    api_items = []
    page = 1
    per_page = 100

    loop do
      response = VendorService.get_products(page: page, per_page: per_page)
      batch = response['data'] || []
      break if batch.empty?

      api_items.concat(batch)
      Rails.logger.info "Fetched page #{page}: #{batch.size} products (total: #{api_items.size})"

      # Break if we got fewer items than requested (last page)
      break if batch.size < per_page

      page += 1
    end

    Rails.logger.info "Total products fetched from vendor API: #{api_items.size}"

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
      prod.avatar_url = item["profilePictureUrl"] if item["profilePictureUrl"].present?
      prod.publisher_logo_url = item["publisherLogoUrl"] if item["publisherLogoUrl"].present?
      prod.ordering = item["ordering"] if item["ordering"].present?

      unless prod.save
        # Handle slug uniqueness conflicts
        if prod.errors[:slug].include?("has already been taken")
          # Find the conflicting product
          conflicting_prod = TopupProduct.find_by(slug: prod.slug)

          if conflicting_prod && conflicting_prod.code != code
            # The conflicting product has a different code
            # Check if it's in the current API response
            if api_codes.include?(conflicting_prod.code)
              # Both products are active - append code to make slug unique
              prod.slug = "#{prod.slug}-#{code}"
              Rails.logger.info "Slug conflict for #{code}: appending code to slug"
            else
              # Conflicting product is not in API - update its slug and retry
              old_code = conflicting_prod.code
              conflicting_prod.update_column(:slug, "#{conflicting_prod.slug}-old-#{old_code}")
              Rails.logger.info "Freed up slug '#{prod.slug}' from inactive product #{old_code}"
            end

            # Retry save
            unless prod.save
              error_msg = "Failed to save TopupProduct #{code} after slug conflict resolution: #{prod.errors.full_messages.join(', ')}"
              Rails.logger.error error_msg
              next
            end
          end
        else
          error_msg = "Failed to save TopupProduct #{code}: #{prod.errors.full_messages.join(', ')}"
          Rails.logger.error error_msg
          next
        end
      end

      if item["logoUrl"].present?
        begin
          require 'open-uri'
          file = URI.parse(item["logoUrl"]).open(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)
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
