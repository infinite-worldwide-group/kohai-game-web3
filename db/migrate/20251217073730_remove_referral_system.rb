class RemoveReferralSystem < ActiveRecord::Migration[7.1]
  def up
    # Clear all referral data while keeping table structures

    # 1. Clear referrer_earnings (has foreign keys to referrals and orders)
    execute "DELETE FROM referrer_earnings"

    # 2. Clear referrals (has foreign keys to referral_codes and users)
    execute "DELETE FROM referrals"

    # 3. Clear referral_codes (has foreign key to users)
    execute "DELETE FROM referral_codes"

    # 4. Clear referral_id from vouchers
    execute "UPDATE vouchers SET referral_id = NULL WHERE referral_id IS NOT NULL"

    # 5. Clear referral fields from users
    execute "UPDATE users SET referred_by_id = NULL, referral_applied_at = NULL WHERE referred_by_id IS NOT NULL"

    puts "✓ All referral data has been cleared from the database"
  end

  def down
    # Cannot restore deleted data
    raise ActiveRecord::IrreversibleMigration, "Cannot restore deleted referral data"
  end
end
