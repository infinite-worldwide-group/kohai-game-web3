class TopupProduct < ApplicationRecord
  # Associations
  has_many :topup_product_items, dependent: :destroy
  has_many :game_accounts, dependent: :nullify

  # Validations
  validates :title, presence: true
  validates :slug, uniqueness: true, allow_blank: true
  validates :is_active, inclusion: { in: [true, false] }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :featured, -> { where(featured: true) }
  scope :by_priority, -> { order(featured: :desc, created_at: :desc) }
  scope :by_ordering, -> { order(Arel.sql("ordering ASC NULLS LAST")) }
  scope :recent, -> { order(created_at: :desc) }

  after_update :update_user_input
  after_create :update_product_items
  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? && title.present? }

 # private

  def generate_slug
    self.slug = title.parameterize
  end

  def update_user_input
    return unless code.present?

    product = VendorService.get_product(product_id: code)
    return unless product.present? && product["data"].present? && product["data"]["userInput"].present?

    user_input_data = product["data"]["userInput"]
    return unless user_input_data["fields"].present?

    # Transform userInput fields into simplified format
    formatted_input = {}

    user_input_data["fields"].each do |field|
      next unless field["attrs"].present?

      attrs = field["attrs"]
      field_name = attrs["placeholder"]
      next unless field_name.present?

      case field["tag"]
      when "input"
        # For input fields, set value as "string" (or the type)
        formatted_input[field_name] = attrs["type"] || "string"
      when "dropdown"
        # For dropdown fields, extract array of values
        if attrs["datas"].present? && attrs["datas"].is_a?(Array)
          formatted_input[field_name] = attrs["datas"].map { |d| d["value"] }.compact
        else
          formatted_input[field_name] = []
        end
      end
    end

    # Update the user_input column with formatted data
    update_column(:user_input, formatted_input) if formatted_input.present?
  rescue => e
    Rails.logger.error "Failed to update user_input for TopupProduct #{id}: #{e.message}"
  end

  def update_product_items
    # Fetch all items with pagination
    all_vendor_items = []
    page = 1
    per_page = 100

    loop do
      product_items = VendorService.get_product_items(product_id: code, page: page, per_page: per_page)

      # Check if response is valid
      if product_items.blank? || product_items["data"].blank? || product_items["data"]["items"].blank?
        break if page > 1  # We've fetched previous pages, just no more items

        # First page returned no items - deactivate product
        update(is_active: false)
        Rails.logger.warn "No items found from vendor for TopupProduct #{id} (code: #{code})"
        return false
      end

      batch = product_items["data"]["items"]
      all_vendor_items.concat(batch)
      Rails.logger.info "Fetched page #{page}: #{batch.size} items for TopupProduct #{id} (total: #{all_vendor_items.size})"

      # Break if we got fewer items than requested (last page)
      break if batch.size < per_page

      page += 1
    end

    # Collect vendor item IDs
    vendor_item_ids = all_vendor_items.map { |d| d["id"].to_s }

    # Deactivate local items not returned by vendor
    topup_product_items.where.not(origin_id: vendor_item_ids).update_all(active: false)

    # Process vendor items
    all_vendor_items.each do |item_data|
      item = topup_product_items.find_or_initialize_by(origin_id: item_data["id"].to_s)

      item.name  = item_data["name"] || item_data["title"] || "Item #{item.origin_id}"
      item.price = item_data["retailPrice"] if item_data["retailPrice"].present?
      item.icon  = item_data["icon"]  if item_data["icon"].present?
      item.active = true

      unless item.save
        Rails.logger.error "Failed to save TopupProductItem #{item.origin_id} for TopupProduct #{origin_id}: #{item.errors.full_messages.join(', ')}"
      end
    end

    Rails.logger.info "Total items synced for TopupProduct #{id}: #{all_vendor_items.size}"

    # Activate product only if it has at least 1 active item
    if topup_product_items.where(active: true).exists?
      update(is_active: true)
    else
      update(is_active: false)
    end

    true

  rescue => e
    Rails.logger.error "Failed to update product items for TopupProduct #{id}: #{e.message}"
    update(is_active: false)
    false
  end


  # Check if product has items from vendor and update active status
  # @return [Boolean] true if items found and product has items, false otherwise
  def check_and_update_active_status
    return false unless code.present?

    # Try to get product items from vendor
    vendor_items = VendorService.get_product_items(product_id: code)

    # Check if vendor returned items
    if vendor_items.present? && vendor_items["data"].present? && vendor_items["data"]["items"].present?
      # Check if this product has topup_product_items
      if topup_product_items.exists?
        update(is_active: true)
        return true
      end
    end

    # No items found
    update(is_active: false)
    false
  rescue => e
    Rails.logger.error "Failed to check vendor items for product #{id}: #{e.message}"
    update(is_active: false)
    false
  end

end
