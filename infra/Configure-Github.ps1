<#
.SYNOPSIS
Configures GitHub for Azure AD Token Exchange

.DESCRIPTION
This script will create an Azure AD application and service principal, create role assignments, add federated credentials, and create GitHub secrets for Azure AD Token Exchange.

.EXAMPLE
configure-github.ps1 -tenantId "00000000-0000-0000-0000-000000000000" -subscriptionId "00000000-0000-0000-0000-000000000000" -appName "MyApp" -githubOrgName "MyOrg" -githubRepoName "MyRepo" -githubPat "0000000"

#>
param(
    [Parameter(Mandatory = $true)]
    [String] $tenantId,
    [Parameter(Mandatory = $true)]
    [String] $subscriptionId,
    [Parameter(Mandatory = $true)]
    [String] $appName,
    [String] $githubOrgName,
    [Parameter(Mandatory = $true)]
    [String] $githubRepoName,
    [Parameter(Mandatory = $true)]
    [String] $githubPat,
    [Parameter(Mandatory = $false)]
    [String] $resourceGroupName,
    [Parameter(Mandatory = $false)] 
    [String] $storageAccountName,
    [Parameter(Mandatory = $false)]
    [String] $containerName,
    [Parameter(Mandatory = $false)]
    [String] $kvName,
    [Parameter(Mandatory = $false)]
    [String] $environment,
    [Parameter(Mandatory = $false)]
    [String] $location
)

# Compute default value for resourceGroupName if not provided
if (-not $resourceGroupName) {
    $resourceGroupName = "rg-$($githubRepoName)-tfstate"
}

if (-not $environment) {
    $environment = "Production"
}

# Compute short repo name for naming resources (used for storage account and key vault)
$shortRepoName = $githubRepoName.ToLower()[0..15] -join ''

# Compute default value for storageAccountName if not provided
if (-not $storageAccountName) {
    $storageAccountName = "st$($shortRepoName)tfstate".ToLower()[0..23] -join ''
}

# Compute default value for containerName if not provided
if (-not $containerName) {
    $containerName = "tfstate"
}
# Compute default value for location if not provided
if (-not $location) {
    $location = "Sweden Central"
}

# Validate storage account name format
if ($storageAccountName -cne $storageAccountName.ToLower()) {
    Write-Host "Storage account name must be lowercase. Converting '$storageAccountName' to lowercase." -ForegroundColor Yellow
    $storageAccountName = $storageAccountName.ToLower()
}

if ($storageAccountName.Length -lt 3 -or $storageAccountName.Length -gt 24) {
    Write-Host "Storage account name must be between 3 and 24 characters. Current length: $($storageAccountName.Length)" -ForegroundColor Red
    Write-Host "Storage account name: $storageAccountName" -ForegroundColor Red
    exit 1
}

if ($storageAccountName -notmatch '^[a-z0-9]+$') {
    Write-Host "Storage account name can only contain lowercase letters and numbers." -ForegroundColor Red
    Write-Host "Storage account name: $storageAccountName" -ForegroundColor Red
    exit 1
}

# log in to Azure
Connect-AzAccount -Tenant $tenantId -Subscription $subscriptionId

# Check if Azure AD application already exists
$existingApp = Get-AzADApplication -DisplayName $appName
if ($existingApp) {
    Write-Host "An app registration with the name '$appName' already exists." -ForegroundColor Yellow
    Write-Host "App ID: $($existingApp.AppId)" -ForegroundColor Yellow
    Write-Host "Please use a different app name or delete the existing app registration." -ForegroundColor Yellow
    exit 1
}

# Check if Key Vault already exists
if (-not $kvName) {
    $kvName = "kv-$($shortRepoName)-ssh".ToLower()
}

# Validate Key Vault name format before checking existence
if ($kvName.Length -lt 3 -or $kvName.Length -gt 24) {
    # Try to shorten it
    $kvName = "kv-$($shortRepoName[0..10] -join '')-ssh".ToLower()
}

if ($kvName -match '--') {
    Write-Host "Key Vault name would contain consecutive hyphens: $kvName" -ForegroundColor Red
    Write-Host "Please use a repository name that doesn't result in consecutive hyphens." -ForegroundColor Red
    exit 1
}

$existingKv = Get-AzKeyVault -VaultName $kvName -ErrorAction SilentlyContinue
if ($existingKv) {
    Write-Host "A Key Vault with the name '$kvName' already exists." -ForegroundColor Yellow
    Write-Host "Resource Group: $($existingKv.ResourceGroupName)" -ForegroundColor Yellow
    Write-Host "Location: $($existingKv.Location)" -ForegroundColor Yellow
    
    $response = Read-Host "`nDo you want to reuse the existing Key Vault? (Y/N)"
    
    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host "Continuing with existing Key Vault..." -ForegroundColor Green
        $keyVaultExists = $true
        # Update resource group name if Key Vault is in a different RG
        if ($existingKv.ResourceGroupName -ne $resourceGroupName) {
            Write-Host "Note: Key Vault is in resource group '$($existingKv.ResourceGroupName)'" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Script execution cancelled." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Key Vault name '$kvName' is available." -ForegroundColor Green
    $keyVaultExists = $false
}

# Create an Azure Active Directory application and service principal

New-AzADApplication -DisplayName $appName
$clientId = (Get-AzADApplication -DisplayName $appName).AppId
New-AzADServicePrincipal -ApplicationId $clientId


# create role assignments
$objectId = (Get-AzADServicePrincipal -DisplayName $appName).Id
New-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName Contributor

$clientId = (Get-AzADApplication -DisplayName $appName).Id

#Add federated credentials
New-AzADAppFederatedCredential -ApplicationObjectId $clientId -Audience api://AzureADTokenExchange -Issuer 'https://token.actions.githubusercontent.com' -Name "$($githubRepoName)-Production" -Subject "repo:$($githubOrgName)/$($githubRepoName):environment:Production"
New-AzADAppFederatedCredential -ApplicationObjectId $clientId -Audience api://AzureADTokenExchange -Issuer 'https://token.actions.githubusercontent.com' -Name "$($githubRepoName)-Canary" -Subject "repo:$($githubOrgName)/$($githubRepoName):environment:Canary"
New-AzADAppFederatedCredential -ApplicationObjectId $clientId -Audience api://AzureADTokenExchange -Issuer 'https://token.actions.githubusercontent.com' -Name "$($githubRepoName)-Test" -Subject "repo:$($githubOrgName)/$($githubRepoName):environment:Test"
New-AzADAppFederatedCredential -ApplicationObjectId $clientId -Audience api://AzureADTokenExchange -Issuer 'https://token.actions.githubusercontent.com' -Name "$($githubRepoName)-Dev" -Subject "repo:$($githubOrgName)/$($githubRepoName):environment:Dev"
New-AzADAppFederatedCredential -ApplicationObjectId $clientId -Audience api://AzureADTokenExchange -Issuer 'https://token.actions.githubusercontent.com' -Name "$($githubRepoName)-PR" -Subject "repo:$($githubOrgName)/$($githubRepoName):pull_request"
New-AzADAppFederatedCredential -ApplicationObjectId $clientId -Audience api://AzureADTokenExchange -Issuer 'https://token.actions.githubusercontent.com' -Name "$($githubRepoName)-Main" -Subject "repo:$($githubOrgName)/$($githubRepoName):ref:refs/heads/main"
New-AzADAppFederatedCredential -ApplicationObjectId $clientId -Audience api://AzureADTokenExchange -Issuer 'https://token.actions.githubusercontent.com' -Name "$($githubRepoName)-Branch" -Subject "repo:$($githubOrgName)/$($githubRepoName):ref:refs/heads/branch"


# Check if storage account name is available
$nameAvailability = Get-AzStorageAccountNameAvailability -Name $storageAccountName

if (-not $nameAvailability.NameAvailable) {
    Write-Host "Storage account name '$storageAccountName' is not available." -ForegroundColor Yellow
    Write-Host "Reason: $($nameAvailability.Reason)" -ForegroundColor Yellow
    Write-Host "Message: $($nameAvailability.Message)" -ForegroundColor Yellow
    
    # Check if the storage account exists in the current subscription
    $existingStorageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $storageAccountName }
    
    if ($existingStorageAccount) {
        Write-Host "`nA storage account with the name '$storageAccountName' already exists in this subscription." -ForegroundColor Yellow
        Write-Host "Resource Group: $($existingStorageAccount.ResourceGroupName)" -ForegroundColor Yellow
        Write-Host "Location: $($existingStorageAccount.Location)" -ForegroundColor Yellow
        
        $response = Read-Host "`nDo you want to continue with the existing storage account? (Y/N)"
        
        if ($response -eq 'Y' -or $response -eq 'y') {
            Write-Host "Continuing with existing storage account..." -ForegroundColor Green
            $storageAccountExists = $true
            $resourceGroupName = $existingStorageAccount.ResourceGroupName
        }
        else {
            Write-Host "Script execution cancelled." -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "`nThe storage account name is taken by another subscription or is invalid." -ForegroundColor Red
        Write-Host "Please choose a different storage account name." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Storage account name '$storageAccountName' is available." -ForegroundColor Green
    $storageAccountExists = $false
}

# Create resource group if it doesn't exist
$existingRg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (-not $existingRg) {
    Write-Host "Creating resource group '$resourceGroupName'..." -ForegroundColor Green
    New-AzResourceGroup -Name $resourceGroupName -Location $location
}
else {
    Write-Host "Resource group '$resourceGroupName' already exists." -ForegroundColor Yellow
}

# Create storage account only if it doesn't exist
if (-not $storageAccountExists) {
    Write-Host "Creating storage account '$storageAccountName'..." -ForegroundColor Green
    New-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -Location $location -SkuName "Standard_LRS" -Kind "StorageV2" -MinimumTlsVersion TLS1_2
}
else {
    Write-Host "Using existing storage account '$storageAccountName'." -ForegroundColor Green
}

$ctx = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount

# Check if container exists
$existingContainer = Get-AzStorageContainer -Name $containerName -Context $ctx -ErrorAction SilentlyContinue
if (-not $existingContainer) {
    Write-Host "Creating storage container '$containerName'..." -ForegroundColor Green
    New-AzStorageContainer -Name $containerName -Context $ctx -Permission Off
}
else {
    Write-Host "Storage container '$containerName' already exists." -ForegroundColor Yellow
}

# Grant Access to the Storage Account for the Service Principal
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
New-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName "Storage Blob Data Contributor" -Scope $storageAccount.Id

# Get Storage Account Key
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName)[0].Value

#install PSSodium if missing
If (!(Get-Module -ListAvailable -Name PSSodium)) {
    install-module PSSodium
}


#create GitHub Secrets
$clientAppId = (Get-AzADApplication -DisplayName $appName).AppId
$subscriptionId = (Get-AzContext).Subscription.Id
$tenantId = (Get-AzContext).Subscription.TenantId

$headers = @{Authorization = "token " + $githubPat }

Invoke-RestMethod –Method get –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/actions/secrets" –Headers $headers

$publicKey = (Invoke-RestMethod –Method get –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/actions/secrets/public-key" –Headers $headers)

#AZURE_TENANT_ID
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $tenantId –PublicKey $($publicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/actions/secrets/AZURE_TENANT_ID" –Headers $headers –body $Body

#AZURE_CLIENT_ID
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $clientAppId –PublicKey $($publicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/actions/secrets/AZURE_CLIENT_ID" –Headers $headers –body $Body

# Create Environments
$environments = @("Production", "Staging", "Canary", "Test", "Dev")
foreach ($env in $environments) {
    #$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $env –PublicKey $($publicKey.key)
    $Body = @"
{
}
"@
    Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/$($env)" –Headers $headers –body $Body
}

# Get Public Key for Environment
$prodPublicKey = (Invoke-RestMethod –Method get –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/$($environment)/secrets/public-key" –Headers $headers)

#AZURE_SUBSCRIPTION_ID PROD
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $subscriptionId  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/$($environment)/secrets/AZURE_SUBSCRIPTION_ID" –Headers $headers –body $Body

#AZURE_STORAGE_ACCOUNT_NAME
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $storageAccountName  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/$($environment)/secrets/AZURE_STORAGE_ACCOUNT_NAME" –Headers $headers –body $Body

#AZURE_STORAGE_CONTAINER_NAME
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $containerName  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}   
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/$($environment)/secrets/AZURE_STORAGE_CONTAINER_NAME" –Headers $headers –body $Body

#AZURE_RESOURCE_GROUP_NAME
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $resourceGroupName  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/$($environment)/secrets/AZURE_RESOURCE_GROUP_NAME" –Headers $headers –body $Body

#AZURE_STORAGE_ACCOUNT_KEY
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $storageAccountKey  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/$($environment)/secrets/AZURE_STORAGE_ACCOUNT_KEY" –Headers $headers –body $Body
    

# generate and shh key
push-location
$path = (get-location).Path
$fileName = "id_rsa.pem"
set-location "C:\Windows\System32\OpenSSH"

./ssh-keygen.exe -m PEM -t rsa -b 4096 -f $path\$fileName 

pop-location

$privateKey = Get-Content .\id_rsa.pem -Raw
$publicKey = Get-Content .\id_rsa.pem.pub -Raw

# Key Vault name was already validated and checked for existence at the top of the script
# Now perform additional validation before creation
if ($kvName.Length -lt 3 -or $kvName.Length -gt 24) {
    Write-Host "Key Vault name must be between 3 and 24 characters. Current length: $($kvName.Length)" -ForegroundColor Red
    Write-Host "Key Vault name: $kvName" -ForegroundColor Red
    exit 1
}

if ($kvName -notmatch '^[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9]$') {
    Write-Host "Key Vault name must start with a letter, end with a letter or digit, and contain only alphanumeric characters and hyphens." -ForegroundColor Red
    Write-Host "Key Vault name: $kvName" -ForegroundColor Red
    exit 1
}

# Create Key Vault only if it doesn't exist
if (-not $keyVaultExists) {
    Write-Host "Creating Key Vault with name: $kvName" -ForegroundColor Green

    $kv = New-AzKeyVault `
        -Name $kvName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -Sku Standard `
        -SoftDeleteRetentionInDays 90 `
        -EnablePurgeProtection `
        -EnableRbacAuthorization `
        -EnabledForDeployment 

    # Grant Access to the Key Vault for the Service Principal
    New-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName "Key Vault Secrets Officer" -Scope $kv.ResourceId

    # Grant Access to the Key Vault for the Current User
    $currentPrincipal = Get-AzADUser -Mail (Get-AzContext).Account.Id
    New-AzRoleAssignment -SignInName $currentPrincipal.UserPrincipalName -RoleDefinitionName "Key Vault Secrets Officer" -Scope $kv.ResourceId

    # Wait for RBAC role assignments to propagate
    Write-Host "Waiting for RBAC role assignments to propagate (60 seconds)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60
}
else {
    Write-Host "Using existing Key Vault '$kvName'." -ForegroundColor Green
    
    # Get the existing Key Vault object
    $kv = Get-AzKeyVault -VaultName $kvName
    
    # Ensure the current user and service principal have access
    $currentPrincipal = Get-AzADUser -Mail (Get-AzContext).Account.Id
    
    # Check if role assignments already exist
    $spRoleAssignment = Get-AzRoleAssignment -ObjectId $objectId -Scope $kv.ResourceId -RoleDefinitionName "Key Vault Secrets Officer" -ErrorAction SilentlyContinue
    if (-not $spRoleAssignment) {
        Write-Host "Granting Service Principal access to Key Vault..." -ForegroundColor Yellow
        New-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName "Key Vault Secrets Officer" -Scope $kv.ResourceId
    }
    
    $userRoleAssignment = Get-AzRoleAssignment -SignInName $currentPrincipal.UserPrincipalName -Scope $kv.ResourceId -RoleDefinitionName "Key Vault Secrets Officer" -ErrorAction SilentlyContinue
    if (-not $userRoleAssignment) {
        Write-Host "Granting current user access to Key Vault..." -ForegroundColor Yellow
        New-AzRoleAssignment -SignInName $currentPrincipal.UserPrincipalName -RoleDefinitionName "Key Vault Secrets Officer" -Scope $kv.ResourceId
        
        # Wait for RBAC role assignments to propagate if new assignments were made
        Write-Host "Waiting for RBAC role assignments to propagate (60 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 60
    }
}

# Store the SSH Keys in the Key Vault
$secret = ConvertTo-SecureString $privateKey -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $kvName -Name "sshkey" -SecretValue $secret

$publicSecret = ConvertTo-SecureString $publicKey -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $kvName -Name "sshpublickey" -SecretValue $publicSecret



#AZURE_KEY_VAULT_NAME
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $kvName  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($prodPublicKey.key_id)"
}
"@
Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/$($environment)/secrets/AZURE_KEY_VAULT_NAME" –Headers $headers –body $Body

#clean-up
Remove-Item .\id_rsa.pem
Remove-Item .\id_rsa.pem.pub


#create entraId group

$groupName = "$($githubRepoName)-cluster-admins"
$group = New-AzADGroup -DisplayName $groupName -MailEnabled:$false -SecurityEnabled:$true -MailNickname $groupName

# add current user to group
Add-AzADGroupMember -TargetGroupObjectId $group.Id -MemberObjectId $currentPrincipal.Id

#write cluster admin group id to key vault
$clusterAdminGroupId = ConvertTo-SecureString $group.Id -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $kvName -Name "clusteradmingroupid" -SecretValue $clusterAdminGroupId