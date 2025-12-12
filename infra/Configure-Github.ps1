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
    [String] $location
)

# Compute default value for resourceGroupName if not provided
if (-not $resourceGroupName) {
    $resourceGroupName = "rg-$($githubRepoName)-tfstate"
}

# Compute default value for storageAccountName if not provided
if (-not $storageAccountName) {
    $shortRepoName = $githubRepoName.ToLower().ToLower()[0..15] -join ''
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



# log in to Azure
Connect-AzAccount -Tenant $tenantId -Subscription $subscriptionId

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




#create a resource group, storage account and container for tfstate
New-AzResourceGroup -Name $resourceGroupName -Location $location
New-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -Location $location -SkuName "Standard_LRS" -Kind "StorageV2" -MinimumTlsVersion TLS1_2
$ctx = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount
New-AzStorageContainer -Name $containerName -Context $ctx -Permission Off

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
$environments = @("Production", "Canary", "Test", "Dev")
foreach ($env in $environments) {
    #$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $env –PublicKey $($publicKey.key)
    $Body = @"
{
}
"@
    Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/$($env)" –Headers $headers –body $Body
}

# Get Public Key for Environment
$prodPublicKey = (Invoke-RestMethod –Method get –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/Production/secrets/public-key" –Headers $headers)

#AZURE_SUBSCRIPTION_ID PROD
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $subscriptionId  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/Production/secrets/AZURE_SUBSCRIPTION_ID" –Headers $headers –body $Body

#AZURE_STORAGE_ACCOUNT_NAME
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $storageAccountName  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/Production/secrets/AZURE_STORAGE_ACCOUNT_NAME" –Headers $headers –body $Body

#AZURE_STORAGE_CONTAINER_NAME
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $containerName  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}   
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/Production/secrets/AZURE_STORAGE_CONTAINER_NAME" –Headers $headers –body $Body

#AZURE_RESOURCE_GROUP_NAME
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $resourceGroupName  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/Production/secrets/AZURE_RESOURCE_GROUP_NAME" –Headers $headers –body $Body

#AZURE_STORAGE_ACCOUNT_KEY
$encryptedSecret = ConvertTo-SodiumEncryptedString –Text $storageAccountKey  –PublicKey $($prodPublicKey.key)
$Body = @"
{
    "encrypted_value": "$encryptedSecret",
    "key_id": "$($publicKey.key_id)"
}
"@

Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/Production/secrets/AZURE_STORAGE_ACCOUNT_KEY" –Headers $headers –body $Body
    

# generate and shh key
push-location
$path = (get-location).Path
$fileName = "id_rsa.pem"
set-location "C:\Windows\System32\OpenSSH"

./ssh-keygen.exe -m PEM -t rsa -b 4096 -f $path\$fileName 

pop-location

$privateKey = Get-Content .\id_rsa.pem -Raw
$publicKey = Get-Content .\id_rsa.pem.pub -Raw

#create Key Vault to Store the SSH Keys
$kvName = "kv-$($shortRepoName.ToLower())-ssh"
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
    "key_id": "$($publicKey.key_id)"
}
"@
Invoke-RestMethod –Method Put –Uri "https://api.github.com/repos/$($githubOrgName)/$($githubRepoName)/environments/Production/secrets/AZURE_KEY_VAULT_NAME" –Headers $headers –body $Body

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