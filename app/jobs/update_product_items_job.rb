class UpdateProductItemsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    products = TopupProduct.where.not(code: [nil, ""])
    total = products.count
    success_count = 0
    failed_count = 0

    Rails.logger.info "Starting update_product_items for #{total} products"

    products.find_each do |product|
      if product.update_product_items
        success_count += 1
        Rails.logger.info "Updated product items for TopupProduct #{product.id} (#{product.title})"
      else
        failed_count += 1
        Rails.logger.error "Failed to update product items for TopupProduct #{product.id} (#{product.title})"
      end
    end

    Rails.logger.info "Completed update_product_items: #{success_count} succeeded, #{failed_count} failed out of #{total}"
  end
end
