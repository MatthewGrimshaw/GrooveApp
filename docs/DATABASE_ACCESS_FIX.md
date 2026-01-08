# Database Access Token Issue - Solution

## Problem
```
Login failed for user '<token-identified principal>'. (18456)
```

The Azure AD access token is being rejected by SQL Server. This means the user identity associated with the token doesn't have permission to access the database.

## Root Cause
When testing locally with `az account get-access-token`, the token represents **YOUR user account**, not a managed identity. 

**Important:** Being an Entra ID admin on the SQL **Server** gives you the ability to manage the server and connect to databases, but you still need to be added as a **user** in each **database** to actually access data.

## Solution

### Option 1: Add Your User to the Database (RECOMMENDED)

The setup script now supports creating developer access automatically.

#### Quick Setup (Recommended)

1. Get your Azure AD email:
```powershell
az ad signed-in-user show --query userPrincipalName -o tsv
```

2. Open `infra/setup-music-tables.sql` and find this line (around line 878):
```sql
DECLARE @DeveloperEmail NVARCHAR(100) = NULL; -- e.g., 'your.name@domain.com'
```

3. Replace `NULL` with your email address:
```sql
DECLARE @DeveloperEmail NVARCHAR(100) = 'your.email@domain.com';
```

4. Run the script (as Entra ID admin, you have permission to create database users):
```powershell
# Connect to your database and run the setup script
$server = "sql-grooveapp-dev-uhxg.database.windows.net"
$database = "db-grooveapp-dev"

sqlcmd -S $server -d $database -G -i infra\setup-music-tables.sql
```

The script will automatically:
- Create a database user for your account
- Grant `db_datareader`, `db_datawriter`, and `db_ddladmin` roles
- Grant `EXECUTE` permission
- Provide clear feedback about what was created

#### Manual SQL (Alternative)

If you prefer to run SQL directly:

```sql
-- Connect to the specific database (not master)
USE GrooveAppDB;
GO

-- Create user from your Azure AD account
CREATE USER [your.email@domain.com] FROM EXTERNAL PROVIDER;
GO

-- Grant necessary permissions (same as Web App)
ALTER ROLE db_datareader ADD MEMBER [your.email@domain.com];
ALTER ROLE db_datawriter ADD MEMBER [your.email@domain.com];
ALTER ROLE db_ddladmin ADD MEMBER [your.email@domain.com];
GRANT EXECUTE TO [your.email@domain.com];
GO

-- Verify
SELECT name, type_desc, authentication_type_desc 
FROM sys.database_principals 
WHERE name = 'your.email@domain.com';
GO
```

### Option 2: Use SQL Admin Credentials (Alternative)

If you don't want to use token authentication locally, you can modify the local build script to use SQL authentication with admin credentials (not recommended for production).

### Option 3: Connect to a Different Environment

If you have a dev database where you already have access, use:

```powershell
.\build-localApi.ps1 -Rebuild -Environment dev
```

## Verify Access

After granting access, test the connection:

```powershell
# Get a token and test
$token = az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv

# Use sqlcmd to test
sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d db-grooveapp-dev -G -P $token -Q "SELECT SUSER_SNAME();"
```

##  For Production (Azure Web Apps)

In production, the Web App's **managed identity** is automatically granted access by Terraform:

```hcl
# From infra/terraform/main.tf
resource "azurerm_role_assignment" "api_to_sql" {
  scope                = module.database_sql[0].server_id
  role_definition_name = "Contributor"
  principal_id         = module.api_web_app.identity_principal_id
}
```

However, this grants **Azure Resource** permissions, not **SQL Database** permissions. You also need to run this SQL in the database:

```sql
CREATE USER [app-grooveapp-dev-api] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [app-grooveapp-dev-api];
ALTER ROLE db_datawriter ADD MEMBER [app-grooveapp-dev-api];
```

Where `app-grooveapp-dev-api` is the name of your Web App.

## Quick Fix Script

Create a file `grant-db-access.sql`:

```sql
-- Add your Azure AD user
CREATE USER [your.name@domain.com] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [your.name@domain.com];
ALTER ROLE db_datawriter ADD MEMBER [your.name@domain.com];

-- Add the API Web App managed identity (for Azure deployment)
CREATE USER [app-grooveapp-dev-api] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [app-grooveapp-dev-api];
ALTER ROLE db_datawriter ADD MEMBER [app-grooveapp-dev-api];
```

Run it:
```powershell
sqlcmd -S sql-grooveapp-dev-uhxg.database.windows.net -d db-grooveapp-dev -G -i grant-db-access.sql
```

## References
- [Azure SQL Database Authentication](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview)
- [Managed Identity for Azure SQL](https://learn.microsoft.com/en-us/azure/app-service/tutorial-connect-msi-sql-database)
