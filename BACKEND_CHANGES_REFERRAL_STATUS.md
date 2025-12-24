# Backend Changes: User Referral Status Fields

## Summary
Added referral status fields to the User GraphQL type so the frontend can check if a user has already applied a referral code.

---

## Changes Made

### 1. Updated User GraphQL Type
**File:** `/app/graphql/types/user_type.rb`

#### New Fields Added:

```graphql
type User {
  # ... existing fields

  # NEW: Referral status fields
  hasAppliedReferralCode: Boolean!      # Returns true if user has applied a code
  appliedReferralCode: String           # The actual code they applied (e.g., "ABC12345")
  referredById: ID                      # ID of the user who referred them
  referralAppliedAt: DateTime           # Timestamp when code was applied
}
```

#### Implementation Details:

```ruby
# Field definitions
field :has_applied_referral_code, Boolean, null: false,
      description: "Whether user has applied a referral code"
field :applied_referral_code, String, null: true,
      description: "The referral code this user applied (if any)"
field :referred_by_id, ID, null: true,
      description: "ID of the user who referred them"
field :referral_applied_at, GraphQL::Types::ISO8601DateTime, null: true,
      description: "When the referral code was applied"

# Resolver methods
def has_applied_referral_code
  object.referred_by_id.present?
end

def applied_referral_code
  return nil unless object.referral_received
  object.referral_received.referral_code&.code
end

def referred_by_id
  object.referred_by_id
end

def referral_applied_at
  object.referral_applied_at
end
```

---

## Database Schema (No Changes Needed)

The database already has the necessary fields:

```ruby
# users table
t.bigint "referred_by_id"              # FK to users table
t.datetime "referral_applied_at"       # Timestamp
```

These fields are automatically populated by the `Referral` model when a user applies a referral code.

---

## Frontend Usage

### Query Example:

```graphql
query GetCurrentUser {
  currentUser {
    id
    walletAddress
    hasAppliedReferralCode    # Check if user already used a code
    appliedReferralCode       # Get the code they used (if any)
    referredById              # Get referrer's ID
    referralAppliedAt         # Get timestamp
  }
}
```

### Response Example:

**User who hasn't applied a code:**
```json
{
  "data": {
    "currentUser": {
      "id": "1",
      "walletAddress": "0x123...",
      "hasAppliedReferralCode": false,
      "appliedReferralCode": null,
      "referredById": null,
      "referralAppliedAt": null
    }
  }
}
```

**User who applied a code:**
```json
{
  "data": {
    "currentUser": {
      "id": "2",
      "walletAddress": "0x456...",
      "hasAppliedReferralCode": true,
      "appliedReferralCode": "ABC12345",
      "referredById": "1",
      "referralAppliedAt": "2025-12-15T10:30:00Z"
    }
  }
}
```

---

## Use Cases

### 1. Conditional Display of Referral Input
Only show the referral code input if the user hasn't applied a code:

```tsx
const { data } = useQuery(GET_CURRENT_USER);

if (data?.currentUser?.hasAppliedReferralCode) {
  return <div>Already used code: {data.currentUser.appliedReferralCode}</div>;
}

return <ReferralCodeInput />;
```

### 2. Show Referral Status Badge
Display which code the user joined with:

```tsx
{currentUser.hasAppliedReferralCode && (
  <div className="referral-badge">
    ✓ Joined with code: {currentUser.appliedReferralCode}
  </div>
)}
```

### 3. Prevent Multiple Applications
Check before showing input:

```tsx
if (currentUser.hasAppliedReferralCode) {
  toast.info('You have already applied a referral code');
  return;
}
```

---

## Business Rules

1. **One code per user:** Users can only apply one referral code, ever
2. **Permanent:** Once applied, cannot be changed or removed
3. **Immediate:** Fields are populated immediately when code is applied
4. **Null-safe:** All nullable fields return null if no code was applied

---

## Testing

### Manual Testing via GraphQL Playground:

1. Query a new user (should return false/null):
```graphql
{
  currentUser {
    hasAppliedReferralCode
    appliedReferralCode
  }
}
```

2. Apply a referral code:
```graphql
mutation {
  applyReferralCode(code: "ABC12345") {
    message
    errors
  }
}
```

3. Query again (should now return true and the code):
```graphql
{
  currentUser {
    hasAppliedReferralCode
    appliedReferralCode
    referredById
    referralAppliedAt
  }
}
```

---

## Related Files

- **User Model:** `/app/models/user.rb`
- **Referral Model:** `/app/models/referral.rb`
- **User Type:** `/app/graphql/types/user_type.rb`
- **Apply Mutation:** `/app/graphql/mutations/referrals/apply_referral_code.rb`

---

## Migration Status

✅ No migration needed - database fields already exist

---

## Next Steps

1. ✅ Backend fields added to User type
2. ⏭️ Frontend: Update currentUser query to include new fields
3. ⏭️ Frontend: Add conditional logic to hide/show referral input
4. ⏭️ Frontend: Display referral status badge
5. ⏭️ Test end-to-end flow

---

**Date:** 2025-12-15
**Status:** Complete and Ready for Frontend Integration
