# frozen_string_literal: true

module Mutations
  module User
    module Topups
      class PurchaseGameCredit < Mutations::BaseMutation
        argument :input, Mutations::User::Topups::PurchaseGameCreditInput, required: true
        field :message, String, null: true
        field :order_number, String, null: true

        def resolve(input:)
          banned_emails = ['aosdnsaduasd6a45@qq.com', 'codeggpl1033@gmail.com']
          return respond_single_error("Something went wrong. Please try again later.") if banned_emails.include? input[:email].strip.downcase

          existing_order = ::Order.where(email: input[:email], status: [:pending, :processing]).exists?
          return respond_single_error("Please wait your previous order to be done first before purchase another order") if existing_order

          topup_product = ::TopupProduct.find(input[:product_id])
          return respond_single_error("Product not found") unless topup_product.present?
          return respond_single_error("Product is currently under maintenance") unless topup_product.is_active == true

          product_item = topup_product.topup_product_items.find_by_origin_id(input[:item_id])
          return respond_single_error("Item not found") unless product_item.present?

          order_number = generate_order_number(title: topup_product.title)

          job_input = input.to_h
          if job_input[:redirect_url].present?
            job_input[:redirect_url] = "#{job_input[:redirect_url]}#{order_number}"
          end
          job_input[:order_number] = order_number

          job = ::CreateOrderJob.perform_later(job_input)

          {
            message: "Your order is being processed...",
            order_number: order_number
          }
        end

        private

        def generate_order_number(title:, name: nil)
          title_initials = if title.present?
            title.gsub(/\s*\(.*?\)\s*/, '')
                 .split
                 .map { |word| word[0] }
                 .join
                 .upcase
          else
            "TOPUP"
          end

          sanitized_name = name.to_s.strip.gsub(/\s+/, '')[0, 5].upcase

          prefix = if name.present?
            "#{sanitized_name}#{title_initials}"
          else
            "KMY#{title_initials}"
          end

          loop do
            random_token = SecureRandom.hex(6).upcase
            order_number = "#{prefix}#{random_token}"
            break order_number unless order_number_exists?(order_number)
          end
        end

        def order_number_exists?(order_number)
          ::Order.exists?(order_number: order_number)
        end
      end
    end
  end
end
