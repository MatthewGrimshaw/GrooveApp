# Private Endpoint and Managed Identity Configuration

## Overview

The infrastructure now uses **private endpoints** for secure database access and **managed identities** for authentication, eliminating the need for connection strings or passwords.

## Architecture

```
┌─────────────────────┐
│  GitHub Actions     │
│  (Temporary Access) │
└──────────┬──────────┘
           │ (Firewall Rule)
           ↓
┌─────────────────────────────────────────────┐
│         Azure SQL Server                    │
│  - Private Endpoint Enabled                 │
│  - Public Access: Disabled (except deploy)  │
│  - Azure AD Authentication Only             │
└──────────┬──────────────────────────────────┘
           │ Private Link
           ↓
┌─────────────────────────────────────────────┐
│       Virtual Network (10.0.0.0/16)         │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  Private Endpoint Subnet            │   │
│  │  (10.0.2.0/24)                      │   │
│  │  - SQL Private Endpoint             │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  App Service Subnet                 │   │
│  │  (10.0.1.0/24)                      │   │
│  │  - API Web App (VNet Integrated)    │   │
│  │  - Frontend Web App (VNet Integrated)│   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

## Key Features

### 1. Private Endpoints
- **Database isolation**: SQL Server is not accessible from the public internet
- **VNet Integration**: App Services connect to database via private network
- **DNS Resolution**: Private DNS zone automatically resolves to private IP

### 2. Managed Identity Authentication
- **No connection strings**: App Services authenticate using their managed identity
- **Azure AD Integration**: All authentication through Azure AD
- **Zero secrets**: No passwords stored in app settings

### 3. Deployment Access
- **Temporary firewall rules**: GitHub Actions creates/deletes rules automatically
- **Azure AD tokens**: SQL scripts execute with federated credentials
- **No stored credentials**: Uses OIDC (OpenID Connect) for authentication

## Deployment Process

### Initial Setup

1. **Deploy Infrastructure** (with deployment access enabled):
   ```bash
   cd infra/terraform
   terraform apply -var-file=environments/dev.tfvars
   ```

2. **Deploy SQL Schema** (GitHub Actions):
   - Workflow: `.github/workflows/deploy-sql-schema.yml`
   - Automatically runs when `setup-music-tables.sql` changes
   - Or manually trigger via GitHub Actions UI

3. **Disable Deployment Access** (production only):
   ```hcl
   # environments/prod.tfvars
   allow_deployment_access = false
   ```

### How SQL Schema Deployment Works

1. **GitHub Actions authenticates** using OIDC (no secrets needed)
2. **Workflow gets public IP** of the runner
3. **Creates temporary firewall rule** for that IP
4. **Gets Azure AD access token** for SQL
5. **Executes `setup-music-tables.sql`** via sqlcmd
6. **Removes firewall rule** (even if script fails)

### App Service Database Connection

The API app connects to SQL Server using:

```python
# In your Python app (FastAPI)
import struct
from azure.identity import DefaultAzureCredential
import pyodbc

def get_db_connection():
    credential = DefaultAzureCredential()
    token = credential.get_token("https://database.windows.net/.default")
    
    # Convert token to format SQL expects
    token_bytes = token.token.encode("UTF-16-LE")
    token_struct = struct.pack(f'<I{len(token_bytes)}s', len(token_bytes), token_bytes)
    
    conn = pyodbc.connect(
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={os.environ['SQL_SERVER']};"
        f"DATABASE={os.environ['SQL_DATABASE']};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=no;",
        attrs_before={1256: token_struct}  # SQL_COPT_SS_ACCESS_TOKEN
    )
    return conn
```

## Configuration Variables

### Terraform Variables

| Variable | Description | Default | Production Value |
|----------|-------------|---------|------------------|
| `enable_private_endpoints` | Enable private endpoints | `true` | `true` |
| `allow_deployment_access` | Allow GitHub Actions | `true` (dev) | `false` |
| `deployment_ip_whitelist` | Specific IPs to allow | `[]` | `[]` |

### GitHub Secrets Required

| Secret | Description | How to Get |
|--------|-------------|------------|
| `AZURE_CLIENT_ID` | Service Principal App ID | From `Configure-Github.ps1` output |
| `AZURE_TENANT_ID` | Azure AD Tenant ID | `az account show --query tenantId` |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID | `az account show --query id` |

## Security Best Practices

### ✅ Implemented
- Private endpoints for all database access
- Managed identities (no passwords)
- VNet integration for App Services
- Azure AD authentication only
- Temporary firewall rules (auto-cleanup)
- HTTPS only for all connections

### 🔄 Recommended
- Network Security Groups (NSGs) on subnets
- Azure Policy for compliance
- Diagnostic logs to Log Analytics
- Private endpoints for Storage Account (if used)

## Troubleshooting

### Issue: App Service can't connect to database

**Symptoms**: Connection timeout or "server not found"

**Solution**:
```bash
# Check VNet integration
az webapp vnet-integration list \
  --name grooveapp-api-dev \
  --resource-group rg-grooveapp-dev

# Check private endpoint
az network private-endpoint list \
  --resource-group rg-grooveapp-dev

# Check DNS resolution (from App Service)
az webapp ssh --name grooveapp-api-dev --resource-group rg-grooveapp-dev
# Then run: nslookup <server-name>.database.windows.net
```

### Issue: GitHub Actions can't deploy schema

**Symptoms**: Firewall error or connection refused

**Solution**:
```bash
# Verify deployment access is enabled in tfvars
allow_deployment_access = true

# Check current firewall rules
az sql server firewall-rule list \
  --server <server-name> \
  --resource-group rg-grooveapp-dev

# Manually add your IP temporarily
az sql server firewall-rule create \
  --server <server-name> \
  --resource-group rg-grooveapp-dev \
  --name "MyIP" \
  --start-ip-address <your-ip> \
  --end-ip-address <your-ip>
```

### Issue: Managed identity authentication fails

**Symptoms**: "Login failed for user" or "Cannot authenticate"

**Solution**:
```bash
# Grant SQL permissions to managed identity
# Run this SQL as SQL admin:
CREATE USER [grooveapp-api-dev] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [grooveapp-api-dev];
ALTER ROLE db_datawriter ADD MEMBER [grooveapp-api-dev];
```

## Migration from Public Access

If migrating from existing public database:

1. **Enable private endpoints** (set `enable_private_endpoints = true`)
2. **Keep public access temporarily** (`allow_deployment_access = true`)
3. **Test app connectivity** via VNet integration
4. **Deploy schema** via GitHub Actions
5. **Disable public access** (`allow_deployment_access = false`)
6. **Update app code** to use managed identity

## Cost Implications

| Resource | Cost | Notes |
|----------|------|-------|
| Private Endpoint | ~$7/month per endpoint | One for SQL |
| VNet Integration | Free | Included with App Service Plan |
| Private DNS Zone | ~$0.50/month | One for SQL |
| **Total Additional** | **~$8/month** | For private network setup |

## References

- [Azure Private Link Documentation](https://learn.microsoft.com/azure/private-link/)
- [App Service VNet Integration](https://learn.microsoft.com/azure/app-service/overview-vnet-integration)
- [Managed Identity with SQL](https://learn.microsoft.com/azure/app-service/tutorial-connect-msi-sql-database)
- [GitHub OIDC with Azure](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
