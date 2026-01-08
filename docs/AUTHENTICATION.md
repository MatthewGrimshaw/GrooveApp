# 100% Automated Authentication with Terraform

## Overview

This Terraform configuration now provides **complete end-to-end automation** for Azure AD authentication, matching the same approach used in `build-appInfra.ps1`.

## How It Works

### The Permission Workaround

The Terraform `azuread_application_password` resource requires elevated Azure AD permissions, **BUT** the Azure CLI command `az ad app credential reset` works with your current permissions! 

### Implementation

We use Terraform's `null_resource` with `local-exec` provisioner to run the same Azure CLI commands that work in PowerShell:

```hcl
resource "null_resource" "api_client_secret" {
  provisioner "local-exec" {
    command     = "az ad app credential reset --id ${azuread_application.api.id} --append --display-name 'Terraform-Generated' --query password -o tsv > ${path.module}/.api_secret.txt"
    interpreter = ["pwsh", "-Command"]
  }
}
```

## What Gets Created

✅ **App Registrations** (API + Frontend)  
✅ **Service Principals** (automatically)  
✅ **Client Secrets** (via Azure CLI)  
✅ **Easy Auth Configuration** (on both web apps)  
✅ **Security Group** (for access control)  

## Zero Manual Steps Required!

Just run:
```powershell
terraform apply -var-file="environments\prod.tfvars" -auto-approve
```

## Secret Management

- Secrets are generated via Azure CLI and stored temporarily in:
  - `modules/entra-id/.api_secret.txt`
  - `modules/entra-id/.frontend_secret.txt`
- These files are read back into Terraform for outputs
- Files are in `.gitignore` - never committed to source control
- Secrets are automatically applied to App Service configuration

## Advantages Over Manual Approach

1. **Fully reproducible** - destroy and recreate infrastructure at will
2. **Version controlled** - all configuration in code
3. **Consistent** - same result every time
4. **Automated** - no Portal clicking required
5. **Secure** - secrets handled programmatically

## Credits

This approach mirrors the proven pattern from `build-appInfra.ps1` which successfully creates app registrations and secrets without elevated permissions.
