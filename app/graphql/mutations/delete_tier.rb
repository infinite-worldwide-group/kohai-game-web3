module Mutations
  class DeleteTier < Mutations::BaseMutation
    description "Delete a tier (soft delete via is_active flag)"

    argument :id, ID, required: true

    field :success, Boolean
    field :message, String
    field :errors, [String]

    def resolve(id:)
      tier = Tier.find_by(id: id)
      return { success: false, message: "Tier not found", errors: ["Tier not found"] } unless tier

      if tier.update(is_active: false)
        { success: true, message: "Tier deleted successfully", errors: [] }
      else
        { success: false, message: "Failed to delete tier", errors: tier.errors.full_messages }
      end
    end
  end
end
