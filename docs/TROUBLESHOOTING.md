# Troubleshooting Guide

## Common Issues and Solutions

### Deployment Issues

#### Issue: "Site startup probe failed after 230 seconds"

**Symptoms:**
- Frontend or API container fails to start
- Health probe timeout errors in logs

**Causes:**
1. Container not listening on correct port
2. Nginx configured for port 80 but App Service expecting 8080
3. Application crash during startup

**Solutions:**
```powershell
# 1. Check configured port
az webapp config show --name app-grooveapp-dev-frontend --resource-group rg-grooveapp-dev --query "linuxFxVersion"

# 2. Set WEBSITES_PORT to match nginx port
az webapp config appsettings set `
    --name app-grooveapp-dev-frontend `
    --resource-group rg-grooveapp-dev `
    --settings WEBSITES_PORT=8080

# 3. Check container logs
az webapp log tail --name app-grooveapp-dev-frontend --resource-group rg-grooveapp-dev
```

---

#### Issue: Build fails with "Security vulnerabilities found"

**Symptoms:**
- Docker Scout reports HIGH or CRITICAL CVEs
- Build script exits with error code 1

**Causes:**
- Vulnerable base images or dependencies
- Outdated packages

**Solutions:**
```powershell
# 1. Review vulnerabilities
docker scout cves grooveapp-api

# 2. Update base images in Dockerfile
# Change: FROM python:3.11-slim
# To:     FROM python:3.11-slim-bookworm

# 3. Update dependencies
pip list --outdated
npm outdated

# 4. Temporarily skip scan (NOT recommended for production)
.\deploy-updates.ps1 -NoSecurityScan
```

---

### Authentication Issues

#### Issue: "AADSTS700054: response_type 'id_token' is not enabled"

**Symptoms:**
- Login redirect fails with AADSTS700054 error
- Cannot sign in to frontend

**Causes:**
- Entra ID app registered as SPA instead of Web
- Implicit grant flow not enabled

**Solutions:**
```powershell
# Update app registration to web type with implicit grant
# This is done automatically by build-appInfra.ps1

# Manual fix in Azure Portal:
# 1. Go to Entra ID → App Registrations
# 2. Find frontend app registration
# 3. Authentication → Platform → Remove SPA, Add Web
# 4. Configure implicit grant: ID tokens
# 5. Add redirect URIs for staging slot
```

---

#### Issue: "Login failed for user '<token-identified principal>'"

**Symptoms:**
- API can't connect to database
- SQL authentication errors in logs

**Causes:**
- Managed identity not added as database user
- Token missing correct audience

**Solutions:**
```sql
-- Connect to database as Entra ID admin
sqlcmd -S your-server.database.windows.net -d your-database -G

-- Create user for managed identity
CREATE USER [app-grooveapp-dev-api] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [app-grooveapp-dev-api];
ALTER ROLE db_datawriter ADD MEMBER [app-grooveapp-dev-api];
GRANT EXECUTE TO [app-grooveapp-dev-api];
```

See [Database Access Fix](DATABASE_ACCESS_FIX.md) for detailed solution.

---

### CORS Issues

#### Issue: "Redirect is not allowed for a preflight request"

**Symptoms:**
- CORS errors in browser console
- API requests fail with status 0
- Error mentions preflight request

**Causes:**
- Easy Auth redirecting OPTIONS requests to login
- `unauthenticatedClientAction` set to `RedirectToLoginPage`

**Solutions:**
```powershell
# Update Easy Auth to return 401 instead of redirecting
az rest --method PUT `
    --uri "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-grooveapp-dev/providers/Microsoft.Web/sites/app-grooveapp-dev-api/config/authsettingsV2?api-version=2021-02-01" `
    --body '{
        "properties": {
            "globalValidation": {
                "requireAuthentication": true,
                "unauthenticatedClientAction": "Return401"
            }
        }
    }'
```

See [CORS Configuration](CORS_CONFIGURATION.md) for complete guide.

---

#### Issue: "CORS policy: No 'Access-Control-Allow-Origin' header"

**Symptoms:**
- Browser blocks API requests
- Missing CORS headers in response

**Causes:**
- Frontend origin not added to allowed origins
- CORS not configured on API

**Solutions:**
```powershell
# Add frontend origin to CORS
az webapp cors add `
    --name app-grooveapp-dev-api `
    --resource-group rg-grooveapp-dev `
    --allowed-origins "https://app-grooveapp-dev-frontend.azurewebsites.net"

# Enable credentials support
az rest --method PUT `
    --uri "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-grooveapp-dev/providers/Microsoft.Web/sites/app-grooveapp-dev-api/config/web?api-version=2021-02-01" `
    --body '{"properties":{"cors":{"allowedOrigins":["https://app-grooveapp-dev-frontend.azurewebsites.net"],"supportCredentials":true}}}'
```

---

### Runtime Configuration Issues

#### Issue: Frontend connecting to http://localhost:8000 instead of Azure API

**Symptoms:**
- Frontend makes requests to localhost
- API URL shows localhost in browser DevTools
- Requests fail because localhost not accessible

**Causes:**
- Environment variables baked into build at compile time
- Runtime configuration not injected properly

**Solutions:**

**Current Implementation (Runtime Injection):**
- Docker entrypoint creates `runtime-config.js` with environment variables
- Angular loads config via `window.runtimeConfig` before app startup
- ConfigService provides API URL from runtime config

**Verify:**
```powershell
# Check if API_URL environment variable is set
az webapp config appsettings list `
    --name app-grooveapp-dev-frontend `
    --resource-group rg-grooveapp-dev `
    --query "[?name=='API_URL'].value" -o tsv

# Should return: https://app-grooveapp-dev-api.azurewebsites.net
```

**Files involved:**
- `app/docker-entrypoint.sh` - Generates runtime-config.js
- `app/src/index.html` - Loads runtime-config.js
- `app/src/app/services/config.service.ts` - Reads window.runtimeConfig
- `app/src/app/interceptors/auth.interceptor.ts` - Uses ConfigService

---

### Database Issues

#### Issue: "Cannot open database requested by login"

**Symptoms:**
- API can authenticate but can't access specific database
- Error 4060 in logs

**Causes:**
- Managed identity user exists in master but not target database
- Database name mismatch

**Solutions:**
```sql
-- Connect to target database (not master!)
sqlcmd -S your-server.database.windows.net -d db-grooveapp-dev -G

-- Verify user exists in THIS database
SELECT name FROM sys.database_principals WHERE name = 'app-grooveapp-dev-api';

-- If not, create it
CREATE USER [app-grooveapp-dev-api] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [app-grooveapp-dev-api];
ALTER ROLE db_datawriter ADD MEMBER [app-grooveapp-dev-api];
GRANT EXECUTE TO [app-grooveapp-dev-api];
```

---

#### Issue: "The server was not found or was not accessible"

**Symptoms:**
- Can't connect to SQL Server
- Connection timeout errors

**Causes:**
- Firewall blocking connection
- VNet integration not configured
- Private endpoint issue

**Solutions:**
```powershell
# Add your IP to firewall temporarily
$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
az sql server firewall-rule create `
    --resource-group rg-grooveapp-dev `
    --server sql-grooveapp-dev-uhxg `
    --name "MyDevMachine" `
    --start-ip-address $myIp `
    --end-ip-address $myIp

# Or enable public access temporarily
az sql server update `
    --resource-group rg-grooveapp-dev `
    --name sql-grooveapp-dev-uhxg `
    --enable-public-network true
```

---

### Container Issues

#### Issue: "Failed to pull image from registry"

**Symptoms:**
- App Service can't pull Docker image
- 500 errors when accessing application

**Causes:**
- ACR credentials incorrect
- ACR admin user disabled
- Network connectivity issue

**Solutions:**
```powershell
# Enable ACR admin user
az acr update --name acrgrooveappdevuhxg --admin-enabled true

# Get new credentials
$acrCreds = az acr credential show --name acrgrooveappdevuhxg | ConvertFrom-Json

# Update App Service
az webapp config container set `
    --name app-grooveapp-dev-api `
    --resource-group rg-grooveapp-dev `
    --docker-custom-image-name "acrgrooveappdevuhxg.azurecr.io/grooveapp-api:latest" `
    --docker-registry-server-url "https://acrgrooveappdevuhxg.azurecr.io" `
    --docker-registry-server-user $acrCreds.username `
    --docker-registry-server-password $acrCreds.passwords[0].value
```

---

### Performance Issues

#### Issue: Slow API response times

**Symptoms:**
- Response times > 5 seconds
- Timeouts in frontend

**Diagnostic:**
```powershell
# Check Application Insights metrics
az monitor app-insights metrics show `
    --app appi-grooveapp-dev-grooveapp `
    --resource-group rg-grooveapp-dev `
    --metric "requests/duration"

# Check database performance
az sql db show `
    --resource-group rg-grooveapp-dev `
    --server sql-grooveapp-dev-uhxg `
    --name db-grooveapp-dev `
    --query "currentServiceObjectiveName"
```

**Solutions:**
1. **Scale up database:** Basic → Standard
2. **Add database indexes:** Index frequently queried columns
3. **Enable connection pooling:** Reuse database connections
4. **Scale up App Service Plan:** B1 → S1 for more CPU/memory

---

### Logging Issues

#### Issue: Logs not appearing in Application Insights

**Symptoms:**
- Empty or missing logs
- Can't find requests in App Insights

**Causes:**
- Connection string not configured
- Logging level too high (ERROR instead of DEBUG)
- Sampling enabled

**Solutions:**
```powershell
# Verify connection string
az webapp config appsettings list `
    --name app-grooveapp-dev-api `
    --resource-group rg-grooveapp-dev `
    --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING'].value" -o tsv

# Set log level to DEBUG
az webapp config appsettings set `
    --name app-grooveapp-dev-api `
    --resource-group rg-grooveapp-dev `
    --settings LOG_LEVEL=DEBUG
```

---

## Diagnostic Commands

### Check Resource Status
```powershell
# API status
az webapp show --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev --query "state"

# Frontend status
az webapp show --name app-grooveapp-dev-frontend --resource-group rg-grooveapp-dev --query "state"

# Database status
az sql db show --resource-group rg-grooveapp-dev --server sql-grooveapp-dev-uhxg --name db-grooveapp-dev --query "status"
```

### View Configuration
```powershell
# API app settings
az webapp config appsettings list --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev --output table

# CORS settings
az webapp config show --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev --query "cors"

# Easy Auth settings
az webapp auth show --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev
```

### Test Endpoints
```powershell
# Health check
curl https://app-grooveapp-dev-api.azurewebsites.net/health

# API endpoint
curl https://app-grooveapp-dev-api.azurewebsites.net/scales/C/1

# Frontend (should redirect to login)
curl -I https://app-grooveapp-dev-frontend.azurewebsites.net
```

---

## Getting Help

### Enable Detailed Logging
```powershell
# Backend
az webapp log config `
    --name app-grooveapp-dev-api `
    --resource-group rg-grooveapp-dev `
    --docker-container-logging filesystem

# Frontend
az webapp log config `
    --name app-grooveapp-dev-frontend `
    --resource-group rg-grooveapp-dev `
    --docker-container-logging filesystem
```

### Collect Diagnostic Info
```powershell
# Download all logs
az webapp log download --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev --log-file "api-logs.zip"
az webapp log download --name app-grooveapp-dev-frontend --resource-group rg-grooveapp-dev --log-file "frontend-logs.zip"

# Export configuration
az webapp config show --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev > api-config.json
az webapp config appsettings list --name app-grooveapp-dev-api --resource-group rg-grooveapp-dev > api-settings.json
```

---

**Last Updated:** January 2026  
**For additional help, see:** [Deployment Guide](DEPLOYMENT.md) | [CORS Configuration](CORS_CONFIGURATION.md) | [Database Access Fix](DATABASE_ACCESS_FIX.md)
