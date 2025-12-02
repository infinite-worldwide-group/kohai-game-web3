# frozen_string_literal: true

module Types
  class GatewayType < Types::BaseEnum
    description "Payment gateway types"

    value "CRYPTO", "Cryptocurrency payment (SOL, USDC, USDT)", value: "crypto"
    value "FIAT", "Fiat currency payment", value: "fiat"
  end
end
