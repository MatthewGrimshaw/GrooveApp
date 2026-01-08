# CORS Configuration Guide

## Overview

This document explains the Cross-Origin Resource Sharing (CORS) configuration for GrooveApp, which allows the Angular frontend to make authenticated API requests to the FastAPI backend hosted on different Azure App Service domains.

## Problem Statement

When frontend and API are hosted on different origins:
- Frontend: `https://app-grooveapp-dev-frontend.azurewebsites.net`
- API: `https://app-grooveapp-dev-api.azurewebsites.net`

The browser enforces Same-Origin Policy and blocks cross-origin requests unless CORS headers permit them.

### Additional Challenge: Easy Auth

With Easy Auth (Entra ID authentication) enabled on the API:
1. Browser sends OPTIONS preflight request to check CORS permissions
2. Easy Auth intercepts ALL requests (including OPTIONS)
3. If configured to redirect unauthenticated requests → CORS violation
4. Error: **"Redirect is not allowed for a preflight request"**

## Solution Architecture

```
┌──────────────────────────┐
│  Browser                 │
│  https://frontend...     │
└────────┬─────────────────┘
         │
         │ 1. OPTIONS (preflight)
         ↓
┌──────────────────────────┐
│  API Easy Auth           │
│  Intercepts request      │
└────────┬─────────────────┘
         │
         │ 2. Returns 401 (not redirect!)
         ↓
┌──────────────────────────┐
│  CORS Configuration      │
│  Checks allowed origin   │
│  Returns CORS headers    │
└────────┬─────────────────┘
         │
         │ 3. Browser receives CORS headers
         ↓
┌──────────────────────────┐
│  Browser                 │
│  Sends actual request    │
│  with credentials        │
└──────────────────────────┘
```

## Current Configuration

### API CORS Settings

**Allowed Origins:**
```
https://app-grooveapp-dev-frontend.azurewebsites.net
```

**Credentials Support:** Enabled (`supportCredentials: true`)

**Why credentials?** The frontend needs to include authentication cookies/tokens in cross-origin requests.

### API Easy Auth Settings

**Unauthenticated Client Action:** `Return401`

**Why Return401?** 
- Prevents redirect during CORS preflight
- Allows CORS headers to be sent
- Browser can complete preflight check
- Actual request then includes authentication

## Implementation

### Azure Portal Configuration

1. **Navigate to API App Service** → Configuration → CORS
   - Add allowed origin: `https://app-grooveapp-dev-frontend.azurewebsites.net`
   - Enable "Support Credentials"

2. **Navigate to API App Service** → Authentication
   - Click "Edit" on Entra ID provider
   - Change "Unauthenticated requests" to "HTTP 401 Unauthorized: recommended for APIs"

### Azure CLI Configuration

```powershell
# Add CORS origin
az webapp cors add `
    --name app-grooveapp-dev-api `
    --resource-group rg-grooveapp-dev `
    --allowed-origins "https://app-grooveapp-dev-frontend.azurewebsites.net"

# Update Easy Auth to return 401
az rest --method PUT `
    --uri "/subscriptions/{subscription-id}/resourceGroups/rg-grooveapp-dev/providers/Microsoft.Web/sites/app-grooveapp-dev-api/config/authsettingsV2?api-version=2021-02-01" `
    --body '{
        "properties": {
            "globalValidation": {
                "requireAuthentication": true,
                "unauthenticatedClientAction": "Return401"
            }
        }
    }'

# Enable CORS credentials support
az rest --method PUT `
    --uri "/subscriptions/{subscription-id}/resourceGroups/rg-grooveapp-dev/providers/Microsoft.Web/sites/app-grooveapp-dev-api/config/web?api-version=2021-02-01" `
    --body '{
        "properties": {
            "cors": {
                "allowedOrigins": ["https://app-grooveapp-dev-frontend.azurewebsites.net"],
                "supportCredentials": true
            }
        }
    }'
```

### Terraform Configuration

In `infra/terraform/main.tf`:

```hcl
module "api_web_app" {
  source = "./modules/web-app"
  
  # ... other configuration ...
  
  # CORS configuration
  cors_allowed_origins     = ["https://${module.naming.app_service.name}-frontend.azurewebsites.net"]
  cors_support_credentials = true
  
  # Easy Auth configuration
  enable_authentication     = var.enable_authentication
  unauthenticated_action    = "Return401"  # Critical for CORS!
  
  # ... other configuration ...
}
```

In `infra/terraform/modules/web-app/main.tf`:

```hcl
resource "azurerm_linux_web_app" "main" {
  site_config {
    # CORS configuration
    dynamic "cors" {
      for_each = length(var.cors_allowed_origins) > 0 ? [1] : []
      content {
        allowed_origins     = var.cors_allowed_origins
        support_credentials = var.cors_support_credentials
      }
    }
  }
  
  # Easy Auth configuration
  dynamic "auth_settings_v2" {
    for_each = var.enable_authentication ? [1] : []
    content {
      auth_enabled           = true
      require_authentication = true
      unauthenticated_action = var.unauthenticated_action  # "Return401" for APIs
      
      # ... provider configuration ...
    }
  }
}
```

## Frontend HTTP Interceptor

The Angular auth interceptor adds credentials to API requests:

`app/src/app/interceptors/auth.interceptor.ts`:

```typescript
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const configService = inject(ConfigService);
  
  // Get API URL from runtime configuration
  const apiUrl = configService.apiUrl || environment.apiUrl;

  // Add credentials for API requests
  if (req.url.startsWith(apiUrl) || req.url.startsWith('http')) {
    req = req.clone({
      withCredentials: true  // Include cookies/tokens in cross-origin requests
    });
  }

  return next(req);
};
```

**Why `withCredentials: true`?**
- Tells browser to include authentication cookies in request
- Required when API has `supportCredentials: true`
- Enables Easy Auth session token to be sent cross-origin

## Verification

### Check CORS Configuration

```powershell
# View CORS settings
az webapp config show `
    --name app-grooveapp-dev-api `
    --resource-group rg-grooveapp-dev `
    --query "cors"
```

**Expected output:**
```json
{
  "allowedOrigins": [
    "https://app-grooveapp-dev-frontend.azurewebsites.net"
  ],
  "supportCredentials": true
}
```

### Check Easy Auth Configuration

```powershell
# View auth settings
az rest --method GET `
    --uri "/subscriptions/{subscription-id}/resourceGroups/rg-grooveapp-dev/providers/Microsoft.Web/sites/app-grooveapp-dev-api/config/authsettingsV2?api-version=2021-02-01" `
    --query "properties.globalValidation.unauthenticatedClientAction"
```

**Expected output:** `"Return401"`

### Test in Browser

1. Open frontend: `https://app-grooveapp-dev-frontend.azurewebsites.net`
2. Open DevTools (F12) → Network tab
3. Look for API requests (e.g., `/health`, `/scales/C/1`)
4. Check request headers for:
   - `Origin: https://app-grooveapp-dev-frontend.azurewebsites.net`
5. Check response headers for:
   - `Access-Control-Allow-Origin: https://app-grooveapp-dev-frontend.azurewebsites.net`
   - `Access-Control-Allow-Credentials: true`

## Common Issues

### Issue: "Redirect is not allowed for a preflight request"

**Cause:** Easy Auth is redirecting OPTIONS requests to login page

**Solution:** Change `unauthenticatedClientAction` to `Return401`

### Issue: "CORS policy: Response to preflight request doesn't pass access control check"

**Causes:**
1. Frontend origin not in allowed origins list
2. `supportCredentials` not enabled
3. Wildcard (`*`) used with credentials (not allowed)

**Solution:** Add specific frontend origin and enable credentials

### Issue: "The value of the 'Access-Control-Allow-Origin' header must not be the wildcard '*'"

**Cause:** Using `*` for allowed origins with `supportCredentials: true`

**Solution:** Specify exact frontend origin (no wildcards with credentials)

### Issue: HTTP 401 on API requests despite authentication

**Cause:** Credentials not being sent (missing `withCredentials: true`)

**Solution:** Ensure auth interceptor sets `withCredentials: true` for API requests

## Security Considerations

✅ **Origin Restriction**: Only specific frontend origin allowed (not `*`)  
✅ **Credentials Protection**: Credentials only sent to trusted origin  
✅ **HTTPS Enforcement**: Both frontend and API use HTTPS  
✅ **Token Validation**: Easy Auth validates Entra ID tokens  
✅ **No Secrets in Frontend**: API URL is only configuration exposed  

## Environment-Specific Configuration

### Development
- Frontend: `https://app-grooveapp-dev-frontend.azurewebsites.net`
- API: `https://app-grooveapp-dev-api.azurewebsites.net`

### Staging
- Frontend: `https://app-grooveapp-staging-frontend.azurewebsites.net`
- API: `https://app-grooveapp-staging-api.azurewebsites.net`

### Production
- Frontend: `https://app-grooveapp-prod-frontend.azurewebsites.net`
- API: `https://app-grooveapp-prod-api.azurewebsites.net`

Each environment must configure CORS with its specific frontend origin.

## References

- [MDN: CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [Azure App Service CORS](https://learn.microsoft.com/en-us/azure/app-service/app-service-web-tutorial-rest-api#configure-cors)
- [Easy Auth Overview](https://learn.microsoft.com/en-us/azure/app-service/overview-authentication-authorization)
- [CORS with Credentials](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#requests_with_credentials)

---

**Last Updated:** January 2026  
**Status:** ✅ Fully Configured and Working
