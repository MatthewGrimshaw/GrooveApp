# Entra ID Module Migration - Terraform Native Implementation

## Overview
This module has been refactored to use pure Terraform resources instead of Azure CLI workarounds with local file dependencies.

## Changes Made

### Removed Resources
- `null_resource.api_service_principal` - Replaced with `azuread_service_principal.api`
- `null_resource.api_client_secret` - Replaced with `azuread_application_password.api`
- `data.local_file.api_secret` - No longer needed
- `null_resource.frontend_service_principal` - Replaced with `azuread_service_principal.frontend`
- `null_resource.frontend_client_secret` - Replaced with `azuread_application_password.frontend`
- `data.local_file.frontend_secret` - No longer needed

### Added Resources
- `azuread_service_principal.api` - Native Terraform resource for API service principal
- `azuread_application_password.api` - Native Terraform resource for API client secret
- `azuread_service_principal.frontend` - Native Terraform resource for frontend service principal
- `azuread_application_password.frontend` - Native Terraform resource for frontend client secret

### Benefits
✅ No dependency on local `.api_secret.txt` or `.frontend_secret.txt` files  
✅ No Azure CLI provisioners that can fail silently  
✅ Secrets managed securely in Terraform state (encrypted at rest)  
✅ Idempotent operations - can run plan/apply multiple times safely  
✅ Works with guest accounts (azuread provider handles permissions correctly)  
✅ Proper dependency tracking between resources  

## Importing Existing Resources

If you already have app registrations, service principals, and security groups deployed:

### Option 1: Using the Import Script (Recommended)
```powershell
cd infra/terraform
./import-entra-resources.ps1 -Environment dev
```

This script will:
- Find existing app registrations by name
- Import applications and service principals into Terraform state
- Import the security group
- Warn you that secrets will be regenerated

### Option 2: Manual Import Commands

```powershell
# Get resource IDs
$apiAppId = (az ad app list --display-name "appreg-app-grooveapp-dev-api" --query '[0].id' -o tsv)
$apiSpId = (az ad sp list --display-name "appreg-app-grooveapp-dev-api" --query '[0].id' -o tsv)
$frontendAppId = (az ad app list --display-name "appreg-app-grooveapp-dev-frontend" --query '[0].id' -o tsv)
$frontendSpId = (az ad sp list --display-name "appreg-app-grooveapp-dev-frontend" --query '[0].id' -o tsv)
$groupId = (az ad group list --display-name "GrooveApp-dev-Users" --query '[0].id' -o tsv)

# Import resources
terraform import "module.entra_id.azuread_application.api" $apiAppId
terraform import "module.entra_id.azuread_service_principal.api" $apiSpId
terraform import "module.entra_id.azuread_application.frontend" $frontendAppId
terraform import "module.entra_id.azuread_service_principal.frontend" $frontendSpId
terraform import "module.entra_id.azuread_group.security" $groupId
```

## Important Notes

### Secret Rotation
⚠️ **Application passwords (client secrets) cannot be imported into Terraform.**

When you run `terraform apply` after importing, Terraform will:
1. Create new client secrets for both applications
2. These secrets will replace the old ones
3. You **must** update your App Service configuration with the new secrets

The web app module will automatically update the App Service configuration if you're using Terraform to deploy everything together.

### Secret Lifecycle
- Secrets are set to expire 1 year from creation
- The `lifecycle.ignore_changes` block prevents Terraform from rotating secrets on every apply
- To manually rotate secrets, taint the resource:
  ```powershell
  terraform taint module.entra_id.azuread_application_password.api
  terraform apply
  ```

### State File Security
- Client secrets are stored in Terraform state
- Ensure your state file is:
  - Stored in Azure Storage with encryption at rest
  - Access controlled via RBAC
  - Not committed to version control

## Troubleshooting

### Guest Account Permissions
If you encounter permission errors, ensure your account has:
- `Application.ReadWrite.All` in Microsoft Graph API
- `Application Administrator` or `Cloud Application Administrator` Azure AD role

### Import Failures
If import commands fail:
1. Verify the resource exists in Azure
2. Check that display names match exactly (case-sensitive)
3. Ensure you're authenticated with `az login`

### Plan Shows Changes After Import
After importing, run `terraform plan`. You may see changes for:
- `end_date` on application passwords - This is expected, ignore with `lifecycle.ignore_changes`
- Formatting differences - Apply these changes to align state with configuration

## Migration Checklist

- [ ] Back up current Terraform state
- [ ] Run import script or manual import commands
- [ ] Run `terraform plan` to verify import
- [ ] Run `terraform apply` to create new secrets
- [ ] Update App Service configuration with new secrets (if not managed by Terraform)
- [ ] Test authentication on both API and frontend
- [ ] Delete old `.api_secret.txt` and `.frontend_secret.txt` files (if they exist)
- [ ] Update CI/CD pipelines to remove any references to secret files
