# OAuth Email Integration Guide

## Overview
The backend now automatically captures and validates emails from OAuth providers (Google, etc.) during wallet authentication. This eliminates the need for a separate email verification step when users log in with Google.

## Backend Changes

### Enhanced `authenticateWallet` Mutation

**New Arguments:**
- `email` (String, optional): The user's email from the OAuth provider
- `email_verified` (Boolean, optional): Whether the OAuth provider verified this email (default: false)

**New Response Field:**
- `message` (String, nullable): Informative message about email capture status

### Email Validation Rules

The backend validates:
1. ✅ **Email format**: Must be valid RFC-compliant email
2. ✅ **Email normalization**: Automatically converts to lowercase and trims whitespace
3. ✅ **Duplicate prevention**: Checks if email is already used by another user
4. ✅ **Auto-verification**: If `email_verified: true`, marks email as verified immediately
5. ✅ **Audit logging**: Tracks OAuth email captures for security

## Frontend Integration

### Example: Google OAuth Login

```typescript
import { googleLogout, useGoogleLogin } from '@react-oauth/google';
import axios from 'axios';

const LoginPage = () => {
  const login = useGoogleLogin({
    onSuccess: async (codeResponse) => {
      try {
        // 1. Get user info from Google
        const userInfo = await axios.get(
          'https://www.googleapis.com/oauth2/v3/userinfo',
          {
            headers: { Authorization: `Bearer ${codeResponse.access_token}` }
          }
        );

        const googleEmail = userInfo.data.email;
        const emailVerified = userInfo.data.email_verified; // Google verifies emails

        // 2. Get wallet address from user's wallet (Phantom, Solflare, etc.)
        const walletAddress = await getWalletAddress(); // Your wallet connection logic

        // 3. Authenticate with backend, including Google email
        const response = await authenticateWallet({
          walletAddress,
          email: googleEmail,
          emailVerified: emailVerified
        });

        // 4. Handle response
        if (response.data.authenticateWallet.errors.length > 0) {
          console.error('Authentication errors:', response.data.authenticateWallet.errors);
          showNotification('Login failed', 'error');
        } else {
          const { token, user, message } = response.data.authenticateWallet;

          // Save token
          localStorage.setItem('authToken', token);

          // Show feedback to user
          if (message) {
            console.log('Email status:', message);

            if (message.includes('already used by another user')) {
              showNotification('This email is already registered to another account', 'error');
            } else if (message.includes('automatically linked')) {
              showNotification('Email automatically linked and verified!', 'success');
            }
          }

          // Navigate to dashboard
          navigate('/dashboard');
        }
      } catch (error) {
        console.error('Google login error:', error);
        showNotification('Login failed', 'error');
      }
    },
    onError: (error) => console.error('Google OAuth error:', error)
  });

  return (
    <button onClick={() => login()}>
      Sign in with Google
    </button>
  );
};
```

### GraphQL Mutation

```graphql
mutation AuthenticateWallet(
  $walletAddress: String!
  $email: String
  $emailVerified: Boolean
) {
  authenticateWallet(
    walletAddress: $walletAddress
    email: $email
    emailVerified: $emailVerified
  ) {
    user {
      id
      walletAddress
      email
      emailVerified
      emailVerifiedAt
    }
    token
    errors
    message
  }
}
```

### Example Variables

```json
{
  "walletAddress": "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
  "email": "user@gmail.com",
  "emailVerified": true
}
```

## Testing Scenarios

### Test 1: First-time Google Login (New Account)
```
Steps:
1. User clicks "Sign in with Google"
2. User selects Google account
3. Frontend gets email from Google OAuth
4. Frontend calls authenticateWallet with email + emailVerified: true
5. Backend creates user with wallet + saves email + marks as verified

Expected Response:
{
  "user": {
    "walletAddress": "7xKXtg...",
    "email": "user@gmail.com",
    "emailVerified": true,
    "emailVerifiedAt": "2025-12-16T10:30:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "errors": [],
  "message": "Email automatically linked and verified"
}

Console: "Email automatically linked and verified"
UI: Show success notification
```

### Test 2: Duplicate Email (Email Already Used)
```
Steps:
1. User A already registered with email "user@gmail.com"
2. User B (different wallet) tries to login with Google using same email
3. Frontend calls authenticateWallet with User B's wallet + "user@gmail.com"

Expected Response:
{
  "user": {
    "walletAddress": "UserB_Wallet...",
    "email": null,  // Email NOT saved
    "emailVerified": false
  },
  "token": "eyJhbGciOiJIUzI1NiJ9...",  // Still authenticated
  "errors": [],
  "message": "This email is already used by another user"
}

Console: "This email is already used by another user"
UI: Show error notification: "This email is already registered to another account"
Note: User is still authenticated with wallet, just email wasn't linked
```

### Test 3: Wallet-only Login (No OAuth)
```
Steps:
1. User connects with Phantom wallet directly (no Google login)
2. Frontend calls authenticateWallet with ONLY walletAddress

Expected Response:
{
  "user": {
    "walletAddress": "7xKXtg...",
    "email": null,
    "emailVerified": false
  },
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "errors": [],
  "message": null
}

Console: "No social email detected" (or no message)
UI: Normal wallet login flow
Note: User can add email later via sendEmailVerificationCode mutation
```

### Test 4: Returning User with Email Already Linked
```
Steps:
1. User previously linked email via Google
2. User logs in again with same wallet + Google email
3. Frontend calls authenticateWallet with same email

Expected Response:
{
  "user": {
    "walletAddress": "7xKXtg...",
    "email": "user@gmail.com",
    "emailVerified": true
  },
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "errors": [],
  "message": "Email already linked and verified"
}

Console: "Email already linked and verified"
UI: Silent success (or optional notification)
```

## Error Handling

### Possible Messages

| Message | Meaning | Frontend Action |
|---------|---------|----------------|
| `"Email automatically linked and verified"` | ✅ Success - OAuth email saved and verified | Show success notification |
| `"Email already linked and verified"` | ✅ Info - User already has this email | Silent success or info message |
| `"This email is already used by another user"` | ❌ Error - Duplicate email detected | Show error: "Email already registered" |
| `"Invalid email format"` | ❌ Error - Malformed email | Show error: "Invalid email" |
| `null` | ℹ️ No email provided | Normal wallet-only login |

### Best Practices

1. **Always include email from OAuth providers**: If Google/Facebook provides email, send it
2. **Set `emailVerified: true` for trusted providers**: Google, Facebook, etc. verify emails
3. **Handle duplicate email gracefully**: User is still authenticated, just show warning
4. **Log messages for debugging**: Use console.log to track email capture flow
5. **Don't block authentication on email errors**: Email capture is secondary to wallet auth

## Database Schema

The `users` table includes:
```sql
email VARCHAR(255) UNIQUE NULL
email_verified_at DATETIME NULL
auth_code VARCHAR(6) NULL
```

## Audit Logs

OAuth email captures are logged in `audit_logs`:
```json
{
  "action": "oauth_email_captured",
  "metadata": {
    "email": "user@gmail.com",
    "email_verified": true,
    "captured_at": "2025-12-16T10:30:00Z",
    "source": "oauth_login"
  }
}
```

## Security Features

1. **Email normalization**: Prevents duplicates like "Test@Gmail.com" vs "test@gmail.com"
2. **Uniqueness validation**: One email per user account
3. **Format validation**: RFC-compliant email addresses only
4. **Audit logging**: Track all email captures for security monitoring
5. **Non-blocking errors**: Authentication succeeds even if email capture fails

## Migration Path

### For Existing Users
- Users who already verified emails manually: No change needed
- Users who linked Google later: Email updates automatically on next login
- Users with duplicate emails: Will see error message, need to use different email

### For New Users
- Google login → Email automatically captured and verified
- Wallet login → Can add email later via existing flow

## Related Files

- Backend mutation: `app/graphql/mutations/users/authenticate_wallet.rb`
- User model: `app/models/user.rb`
- GraphQL type: `app/graphql/types/user_type.rb`

## Support

If you encounter issues:
1. Check console logs for the `message` field
2. Verify email format is valid
3. Check if email is already registered to another account
4. Review audit logs in database for OAuth email captures
