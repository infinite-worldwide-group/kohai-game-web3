# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    # Authentication mutations
    field :generate_nonce, mutation: Mutations::Users::GenerateNonce
    field :authenticate_wallet, mutation: Mutations::Users::AuthenticateWallet

    # Email verification mutations
    field :send_email_verification_code, mutation: Mutations::Users::SendEmailVerificationCode
    field :verify_email, mutation: Mutations::Users::VerifyEmail
    field :update_email, mutation: Mutations::Users::UpdateEmail

    # Order mutations
    field :create_order, mutation: Mutations::Orders::CreateOrder
    field :confirm_payment, mutation: Mutations::Orders::ConfirmPayment

    # Purchase mutations
    field :purchase_game_credit, mutation: Mutations::User::Topups::PurchaseGameCredit

    # Game account mutations
    field :create_game_account, mutation: Mutations::User::GameAccounts::CreateGameAccount
    field :validate_game_account_mutation, mutation: Mutations::User::GameAccounts::ValidateGameAccountMutation
    field :delete_game_account, mutation: Mutations::User::GameAccounts::DeleteGameAccount
  end
end
