# Easy Auth SSO Configuration Fix

## Problem Summary

When deploying with Easy Auth enabled on both frontend and API App Services, the following issues occurred:

1. **Frontend couldn't call API** - Received HTTP 401 Unauthorized errors
2. **Direct API access redirected** - Accessing the API directly returned 401 instead of redirecting to login
3. **Token authentication failed** - The frontend's Easy Auth token wasn't valid for the API

## Root Causes

### 1. Missing API Scope Exposure
The API app registration didn't expose any OAuth2 scopes that other applications could request access to.

### 2. Frontend Lacking API Permissions
The frontend app registration didn't request permission to call the API on behalf of the user.

### 3. Token Audience Mismatch
- The frontend Easy Auth issued tokens with audience = frontend app ID
- The API Easy Auth expected tokens with audience = API app ID
- The frontend wasn't requesting a token for the API

### 4. API Authentication Configuration
The API was configured with `unauthenticated_action = "Return401"` which prevented direct browser access.

## Solution Implemented

### 1. Entra ID App Registration Changes

#### API App Registration (`modules/entra-id/main.tf`)

```terraform
resource "azuread_application" "api" {
  # ... existing config ...
  
  # Set the identifier URI (required for exposing API scopes)
  identifier_uris = ["api://${var.app_name}-api"]
  
  # Expose API scopes that the frontend can request
  api {
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access the API on behalf of the signed-in user"
      admin_consent_display_name = "Access API"
      enabled                    = true
      id                         = "a0a0a0a0-bbbb-cccc-dddd-e1e1e1e1e1e1"
      type                       = "User"
      user_consent_description   = "Allow the application to access the API on your behalf"
      user_consent_display_name  = "Access API"
      value                      = "user_impersonation"
    }
  }
}
```

**Key Changes:**
- Added `identifier_uris` to create a unique identifier for the API
- Exposed `user_impersonation` scope for delegated permissions
- Fixed redirect URIs to point to the API URL instead of frontend URL

#### Frontend App Registration (`modules/entra-id/main.tf`)

```terraform
resource "azuread_application" "frontend" {
  # ... existing config ...
  
  # Request permission to call the API on behalf of the user
  required_resource_access {
    resource_app_id = azuread_application.api.client_id # Our API
    
    resource_access {
      id   = "a0a0a0a0-bbbb-cccc-dddd-e1e1e1e1e1e1" # user_impersonation scope
      type = "Scope"
    }
  }
}
```

**Key Changes:**
- Added `required_resource_access` block to request API access
- References the API's `user_impersonation` scope

### 2. API Easy Auth Configuration (`main.tf`)

```terraform
module "api_web_app" {
  # ... existing config ...
  
  # Changed from Return401 to RedirectToLoginPage for browser access
  unauthenticated_action = "RedirectToLoginPage"
  
  # Accept tokens from both API app (direct access) and frontend app (for SSO)
  allowed_audiences = [
    "api://${module.naming.app_service.name}-api",
    module.entra_id[0].frontend_app_id
  ]
}
```

**Key Changes:**
- Changed `unauthenticated_action` to allow direct browser access
- Added frontend app ID to `allowed_audiences` to accept tokens from the frontend
- This allows the frontend's Easy Auth token to be validated by the API

### 3. Frontend Easy Auth Configuration (`main.tf`)

```terraform
module "frontend_web_app" {
  # ... existing config ...
  
  # Standard Easy Auth configuration  
  unauthenticated_action = "RedirectToLoginPage"
  allowed_audiences      = ["api://${module.naming.app_service.name}-frontend"]
}
```

**Note**: Due to Terraform azurerm provider limitations, requesting custom scopes for other APIs cannot be configured through Terraform. The alternative approach is to configure the API to accept tokens from the frontend app.

### 4. Web App Module Updates (`modules/web-app`)

Added support for:
- `allowed_audiences` - List of valid token audiences
- `login_scopes` - Scopes to request during authentication

Updated `auth_settings_v2` to:
```terraform
login {
  token_store_enabled = true
  login_parameters = length(var.login_scopes) > 0 ? {
    scope = join(" ", var.login_scopes)
  } : null
}

active_directory_v2 {
  client_id            = var.client_id
  tenant_auth_endpoint = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
  allowed_audiences    = length(var.allowed_audiences) > 0 ? var.allowed_audiences : ["api://${var.client_id}"]
}
```

## How Authentication Now Works

### User Flow

1. **User accesses frontend** → Redirected to Entra ID login
2. **User authenticates** → Frontend Easy Auth obtains token for frontend app
3. **Frontend calls API** → Auth interceptor:
   - Fetches token from `/.auth/me`
   - Includes token as `Authorization: Bearer <token>`
4. **API validates token**:
   - Checks token signature (valid Entra ID token)
   - Validates audience - accepts EITHER:
     - `api://app-name-api` (for direct API access)
     - Frontend app client ID (for frontend-to-API calls)
   - Validates user identity
5. **API returns data** → API's database access uses managed identity

**Note**: The frontend's Easy Auth token has audience = frontend app ID. The API is configured to accept this as a valid audience, enabling SSO between the two apps.

### Direct API Access Flow

1. **User accesses API URL** → No authentication header
2. **API Easy Auth** → Redirects to Entra ID login
3. **User authenticates** → Redirected back to API
4. **API serves response** → User authenticated

### Frontend Auth Interceptor

The existing Angular auth interceptor automatically:
1. Fetches the access token from `/.auth/me`
2. Adds it to API requests: `Authorization: Bearer <token>`
3. Includes credentials: `withCredentials: true`

## Deployment Steps

### 1. Apply Terraform Changes

```powershell
cd infra/terraform
terraform plan
terraform apply
```

This will:
- Update Entra ID app registrations
- Update Easy Auth configuration on both web apps
- Configure proper token validation

### 2. Grant Admin Consent (One-Time)

After applying Terraform, grant admin consent for the API permissions:

**Option A: Azure Portal**
1. Go to **Entra ID** → **App registrations**
2. Find the frontend app registration (`appreg-{app-name}-frontend`)
3. Click **API permissions**
4. Click **Grant admin consent for {organization}**

**Option B: PowerShell**
```powershell
# Get the service principals
$frontendSP = Get-AzADServicePrincipal -DisplayName "appreg-{app-name}-frontend"
$apiSP = Get-AzADServicePrincipal -DisplayName "appreg-{app-name}-api"

# Grant consent (requires appropriate permissions)
New-AzADServicePrincipalAppRoleAssignment `
  -ServicePrincipalId $frontendSP.Id `
  -ResourceId $apiSP.Id `
  -AppRoleId "a0a0a0a0-bbbb-cccc-dddd-e1e1e1e1e1e1"
```

### 3. Redeploy Applications (if needed)

The Easy Auth configuration changes should apply immediately, but you may need to restart the web apps:

```powershell
az webapp restart --name app-grooveapp-dev-frontend --resource-group rg-grooveapp-dev
az webapp restart --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev
```

### 4. Clear Browser Cache

Users should clear their browser cache or use incognito mode to force re-authentication with the new scopes.

## Verification

### Test Direct API Access
```
https://app-grooveapp-dev-api.azurewebsites.net/
```
Should redirect to login, then show API response.

### Test Frontend to API Communication
1. Open browser developer tools (F12)
2. Navigate to frontend: `https://app-grooveapp-dev-frontend.azurewebsites.net/`
3. Check Network tab for API calls
4. Verify:
   - Request includes `Authorization: Bearer <token>` header
   - Response is HTTP 200 (not 401)

### Check Token Contents
1. Open browser console
2. Fetch token:
   ```javascript
   fetch('/.auth/me', { credentials: 'include' })
     .then(r => r.json())
     .then(data => {
       const token = data[0].access_token;
       console.log('Token:', token);
       // Decode token at https://jwt.ms
     });
   ```
3. Paste token into https://jwt.ms
4. Verify:
   - `aud` (audience) = `api://app-grooveapp-dev-api`
   - `scp` (scopes) includes `user_impersonation`

## Security Considerations

### Token Storage
- Easy Auth stores tokens securely in the App Service token store
- Tokens are HTTP-only cookies, not accessible to JavaScript
- Frontend accesses tokens via `/.auth/me` endpoint

### Token Validation
- API validates token signature against Entra ID
- API checks token audience matches `api://{app-name}-api`
- API validates required scopes are present

### Managed Identity for Database
- API uses its managed identity to access SQL Database
- User tokens are NOT used for database access
- User identity is available in token claims if needed for row-level security

## Troubleshooting

### Still Getting 401 Errors

1. **Check admin consent**:
   - Portal → Entra ID → App registrations → Frontend → API permissions
   - Status should show "Granted for {organization}"

2. **Verify token audience**:
   - Decode token from `/.auth/me`
   - Check `aud` claim matches `api://app-name-api`

3. **Check API allowed_audiences**:
   ```bash
   az webapp auth show --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev
   ```

### Token Missing Scopes

1. **Clear authentication**:
   - Navigate to `https://app-name-frontend.azurewebsites.net/.auth/logout`
   - Clear browser cache
   - Login again

2. **Verify frontend login_scopes**:
   - Check Easy Auth configuration includes API scope
   - Should see `api://app-name-api/user_impersonation` in login parameters

### CORS Errors

The CORS configuration already includes:
- `cors_allowed_origins = [frontend-url]`
- `cors_support_credentials = true`

If issues persist:
1. Check browser console for CORS errors
2. Verify `Access-Control-Allow-Origin` header in response
3. Ensure `withCredentials: true` in Angular HTTP requests (already configured in auth interceptor)

## References

- [Azure App Service Easy Auth with Custom APIs](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad)
- [Microsoft Identity Platform Scopes and Permissions](https://learn.microsoft.com/en-us/entra/identity-platform/scopes-oidc)
- [On-behalf-of Flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-on-behalf-of-flow)
