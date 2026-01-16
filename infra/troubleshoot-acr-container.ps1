# Troubleshoot ACR Container Pull Issues
# Diagnoses Docker image pull failures and container startup issues

param(
    [Parameter(Mandatory = $false)]
    [string]$Environment = "dev"
)

$resourceGroupName = "rg-grooveapp-$Environment"
$apiWebAppName = "app-grooveapp-$Environment-api"
$acrName = "acrgrooveappdevuhxg"

Write-Host "======================================"
Write-Host "ACR & Container Diagnostics"
Write-Host "======================================"
Write-Host ""

# Step 1: Check what image the app is configured to use
Write-Host "Step 1: Checking configured Docker image..." -ForegroundColor Yellow
$webApp = az webapp config container show --name $apiWebAppName --resource-group $resourceGroupName | ConvertFrom-Json

$configuredImage = $webApp.linuxFxVersion -replace 'DOCKER\|', ''
Write-Host "Configured Image: $configuredImage" -ForegroundColor Cyan
Write-Host ""

# Parse image details
if ($configuredImage -match '(.+)\.azurecr\.io/(.+):(.+)') {
    $acrServer = "$($matches[1]).azurecr.io"
    $imageName = $matches[2]
    $imageTag = $matches[3]
    
    Write-Host "  ACR Server: $acrServer" -ForegroundColor Gray
    Write-Host "  Image Name: $imageName" -ForegroundColor Gray
    Write-Host "  Image Tag: $imageTag" -ForegroundColor Gray
}
else {
    Write-Host "⚠️ Could not parse image details" -ForegroundColor Yellow
}
Write-Host ""

# Step 2: Verify image exists in ACR
Write-Host "Step 2: Checking if image exists in ACR..." -ForegroundColor Yellow
try {
    $tags = az acr repository show-tags --name $acrName --repository $imageName --output json | ConvertFrom-Json
    
    if ($tags -contains $imageTag) {
        Write-Host "✓ Image tag '$imageTag' exists in ACR" -ForegroundColor Green
        Write-Host "Available tags:" -ForegroundColor Gray
        $tags | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    }
    else {
        Write-Host "✗ Image tag '$imageTag' NOT found in ACR!" -ForegroundColor Red
        Write-Host "Available tags:" -ForegroundColor Yellow
        $tags | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
        Write-Host ""
        Write-Host "SOLUTION: Push the correct image tag to ACR:" -ForegroundColor Yellow
        Write-Host "  cd api" -ForegroundColor White
        Write-Host "  docker build -t $acrServer/$imageName`:$imageTag ." -ForegroundColor White
        Write-Host "  az acr login --name $acrName" -ForegroundColor White
        Write-Host "  docker push $acrServer/$imageName`:$imageTag" -ForegroundColor White
    }
}
catch {
    Write-Host "✗ Failed to check ACR repository" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Step 3: Check ACR credentials configuration
Write-Host "Step 3: Checking ACR authentication..." -ForegroundColor Yellow
$appSettings = az webapp config appsettings list --name $apiWebAppName --resource-group $resourceGroupName | ConvertFrom-Json

$dockerRegistry = $appSettings | Where-Object { $_.name -eq 'DOCKER_REGISTRY_SERVER_URL' } | Select-Object -ExpandProperty value
$dockerUser = $appSettings | Where-Object { $_.name -eq 'DOCKER_REGISTRY_SERVER_USERNAME' } | Select-Object -ExpandProperty value
$dockerPassword = $appSettings | Where-Object { $_.name -eq 'DOCKER_REGISTRY_SERVER_PASSWORD' }

if ($dockerRegistry) {
    Write-Host "✓ DOCKER_REGISTRY_SERVER_URL: $dockerRegistry" -ForegroundColor Green
}
else {
    Write-Host "✗ DOCKER_REGISTRY_SERVER_URL not set!" -ForegroundColor Red
}

if ($dockerUser) {
    Write-Host "✓ DOCKER_REGISTRY_SERVER_USERNAME: $dockerUser" -ForegroundColor Green
}
else {
    Write-Host "✗ DOCKER_REGISTRY_SERVER_USERNAME not set!" -ForegroundColor Red
}

if ($dockerPassword) {
    Write-Host "✓ DOCKER_REGISTRY_SERVER_PASSWORD: [CONFIGURED]" -ForegroundColor Green
}
else {
    Write-Host "✗ DOCKER_REGISTRY_SERVER_PASSWORD not set!" -ForegroundColor Red
}
Write-Host ""

# Step 4: Get Docker/Container logs
Write-Host "Step 4: Fetching container logs..." -ForegroundColor Yellow
Write-Host "These logs show if the image pull succeeded/failed" -ForegroundColor Gray
Write-Host ""

# Download logs
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "container-logs-$timestamp.zip"

az webapp log download --name $apiWebAppName --resource-group $resourceGroupName --log-file $logFile 2>&1 | Out-Null

if (Test-Path $logFile) {
    Write-Host "✓ Logs downloaded: $logFile" -ForegroundColor Green
    
    # Extract and display Docker logs
    Expand-Archive -Path $logFile -DestinationPath "container-logs-$timestamp" -Force
    
    $dockerLogPath = "container-logs-$timestamp\LogFiles\*_docker.log"
    $dockerLogs = Get-ChildItem -Path $dockerLogPath -ErrorAction SilentlyContinue
    
    if ($dockerLogs) {
        Write-Host ""
        Write-Host "Recent Docker/Container logs:" -ForegroundColor Cyan
        Write-Host "======================================" -ForegroundColor Gray
        
        foreach ($log in $dockerLogs | Select-Object -Last 1) {
            Get-Content $log.FullName -Tail 50 | ForEach-Object {
                if ($_ -match 'error|Error|ERROR|failed|Failed|FAILED') {
                    Write-Host $_ -ForegroundColor Red
                }
                elseif ($_ -match 'warning|Warning|WARN') {
                    Write-Host $_ -ForegroundColor Yellow
                }
                elseif ($_ -match 'pull|Pull|PULL|pulling|Pulling') {
                    Write-Host $_ -ForegroundColor Cyan
                }
                else {
                    Write-Host $_ -ForegroundColor Gray
                }
            }
        }
        Write-Host "======================================" -ForegroundColor Gray
    }
    else {
        Write-Host "⚠️ No Docker logs found" -ForegroundColor Yellow
    }
    
    # Clean up
    Write-Host ""
    Write-Host "Full logs extracted to: container-logs-$timestamp" -ForegroundColor Gray
}
else {
    Write-Host "✗ Failed to download logs" -ForegroundColor Red
}
Write-Host ""

# Step 5: Check container state via diagnostic logs
Write-Host "Step 5: Checking App Service platform logs..." -ForegroundColor Yellow
Write-Host "Querying Log Analytics for platform errors..." -ForegroundColor Gray
Write-Host ""

$query = @"
AppServicePlatformLogs
| where TimeGenerated > ago(1h)
| where _ResourceId contains '$apiWebAppName'
| where Level == 'Error' or Level == 'Warning'
| project TimeGenerated, Level, Message
| order by TimeGenerated desc
| take 20
"@

Write-Host "Run this query in Log Analytics (Portal > Log Analytics Workspace > Logs):" -ForegroundColor Yellow
Write-Host $query -ForegroundColor White
Write-Host ""

# Step 6: Common ACR/Container issues
Write-Host "======================================"
Write-Host "Common ACR/Container Issues"
Write-Host "======================================"
Write-Host ""

Write-Host "1. Image Not Found (404):" -ForegroundColor Yellow
Write-Host "   Cause: Image tag doesn't exist in ACR" -ForegroundColor White
Write-Host "   Solution: Build and push the correct image tag" -ForegroundColor Green
Write-Host "   Check: Look for 'manifest unknown' or '404' in Docker logs" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Authentication Failed (401):" -ForegroundColor Yellow
Write-Host "   Cause: ACR credentials are incorrect or expired" -ForegroundColor White
Write-Host "   Solution: Update ACR credentials in app settings" -ForegroundColor Green
Write-Host "   Check: Look for 'unauthorized' or '401' in Docker logs" -ForegroundColor Gray
Write-Host ""

Write-Host "3. Container Exits Immediately:" -ForegroundColor Yellow
Write-Host "   Cause: Application crashes on startup (DB connection, config, etc.)" -ForegroundColor White
Write-Host "   Solution: Check application logs for startup errors" -ForegroundColor Green
Write-Host "   Check: Container starts but exits with error code" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Wrong Architecture (ARM vs x64):" -ForegroundColor Yellow
Write-Host "   Cause: Image built for wrong CPU architecture" -ForegroundColor White
Write-Host "   Solution: Rebuild image for linux/amd64" -ForegroundColor Green
Write-Host "   Check: Look for 'exec format error' in Docker logs" -ForegroundColor Gray
Write-Host ""

Write-Host "5. Image Pull Timeout:" -ForegroundColor Yellow
Write-Host "   Cause: Image is too large or network issues" -ForegroundColor White
Write-Host "   Solution: Optimize image size, use ACR Tasks" -ForegroundColor Green
Write-Host "   Check: Look for timeout errors in platform logs" -ForegroundColor Gray
Write-Host ""

# Step 7: Quick fixes
Write-Host "======================================"
Write-Host "Quick Diagnostic Commands"
Write-Host "======================================"
Write-Host ""

Write-Host "Test ACR connectivity from your machine:" -ForegroundColor Yellow
Write-Host "  az acr login --name $acrName" -ForegroundColor White
Write-Host "  docker pull $configuredImage" -ForegroundColor White
Write-Host ""

Write-Host "List all images in ACR:" -ForegroundColor Yellow
Write-Host "  az acr repository list --name $acrName --output table" -ForegroundColor White
Write-Host ""

Write-Host "Get image manifest (verify it exists):" -ForegroundColor Yellow
Write-Host "  az acr repository show --name $acrName --repository $imageName --image $imageTag" -ForegroundColor White
Write-Host ""

Write-Host "Force pull latest image:" -ForegroundColor Yellow
Write-Host "  az webapp restart --name $apiWebAppName --resource-group $resourceGroupName" -ForegroundColor White
Write-Host ""

Write-Host "View real-time container logs:" -ForegroundColor Yellow
Write-Host "  az webapp log tail --name $apiWebAppName --resource-group $resourceGroupName" -ForegroundColor White
Write-Host ""

Write-Host "======================================"
Write-Host "Azure Portal Diagnostics"
Write-Host "======================================"
Write-Host ""
Write-Host "1. Container Settings:" -ForegroundColor Cyan
Write-Host "   Portal > App Service > Deployment > Container settings" -ForegroundColor White
Write-Host "   Check: Registry, Image, Tag" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Log Stream:" -ForegroundColor Cyan
Write-Host "   Portal > App Service > Monitoring > Log stream" -ForegroundColor White
Write-Host "   Shows: Real-time container and application logs" -ForegroundColor Gray
Write-Host ""

Write-Host "3. Diagnose and Solve:" -ForegroundColor Cyan
Write-Host "   Portal > App Service > Diagnose and solve problems" -ForegroundColor White
Write-Host "   Check: 'Container Crashes' and 'Container Deployment Issues'" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Application Insights (if container started):" -ForegroundColor Cyan
Write-Host "   Portal > Application Insights > Failures" -ForegroundColor White
Write-Host "   Shows: Application exceptions and failed requests" -ForegroundColor Gray
Write-Host ""
