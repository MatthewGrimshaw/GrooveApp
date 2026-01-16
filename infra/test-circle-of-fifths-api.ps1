# Test Circle of Fifths API endpoints
# This script tests if the Circle of Fifths API endpoints are accessible

param(
    [Parameter(Mandatory = $false)]
    [string]$Environment = "dev"
)

$apiUrl = "https://app-grooveapp-$Environment-api.azurewebsites.net"
$frontendUrl = "https://app-grooveapp-$Environment-frontend.azurewebsites.net"

Write-Host "======================================"
Write-Host "Circle of Fifths API Diagnostic Test"
Write-Host "======================================"
Write-Host ""
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "API URL: $apiUrl" -ForegroundColor Cyan
Write-Host "Frontend URL: $frontendUrl" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if API is accessible (no auth required for health)
Write-Host "Test 1: Health Check Endpoint" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$apiUrl/health" -Method Get -ErrorAction Stop
    Write-Host "✓ Health check successful" -ForegroundColor Green
    Write-Host "Response: $($health | ConvertTo-Json -Compress)" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
}
Write-Host ""

# Test 2: Check Circle of Fifths endpoint (may require auth)
Write-Host "Test 2: Circle of Fifths Keys Endpoint (Major)" -ForegroundColor Yellow
try {
    $keys = Invoke-RestMethod -Uri "$apiUrl/circle-of-fifths/keys?scale_type=1" -Method Get -ErrorAction Stop
    Write-Host "✓ Successfully retrieved major keys" -ForegroundColor Green
    Write-Host "Count: $($keys.Count)" -ForegroundColor Gray
    Write-Host "Keys: $($keys | Select-Object -First 3 | ConvertTo-Json -Compress)" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Failed to retrieve major keys" -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    # Check if it's a 401 (auth issue)
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Write-Host ""
        Write-Host "⚠️ 401 Unauthorized - This endpoint requires authentication" -ForegroundColor Yellow
        Write-Host "The frontend can access it because:" -ForegroundColor Yellow
        Write-Host "  1. It's authenticated via Easy Auth" -ForegroundColor Yellow
        Write-Host "  2. The auth interceptor adds the token to the request" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To test from PowerShell, you need to:" -ForegroundColor Yellow
        Write-Host "  1. Get an auth token from the frontend" -ForegroundColor Yellow
        Write-Host "  2. Include it in the Authorization header" -ForegroundColor Yellow
    }
}
Write-Host ""

# Test 3: Check CORS configuration
Write-Host "Test 3: CORS Configuration Check" -ForegroundColor Yellow
Write-Host "Expected CORS origin: $frontendUrl" -ForegroundColor Gray
Write-Host ""
Write-Host "To verify CORS in browser:" -ForegroundColor Cyan
Write-Host "  1. Open browser dev tools (F12)" -ForegroundColor White
Write-Host "  2. Go to Network tab" -ForegroundColor White
Write-Host "  3. Filter for 'circle-of-fifths'" -ForegroundColor White
Write-Host "  4. Check for CORS errors in console" -ForegroundColor White
Write-Host ""

# Test 4: Frontend accessibility
Write-Host "Test 4: Frontend Accessibility" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $frontendUrl -Method Get -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "✓ Frontend is accessible (200 OK)" -ForegroundColor Green
    }
    elseif ($response.StatusCode -eq 302) {
        Write-Host "✓ Frontend is accessible (302 Redirect to auth)" -ForegroundColor Green
    }
}
catch {
    if ($_.Exception.Response.StatusCode -eq 'Redirect') {
        Write-Host "✓ Frontend is accessible (redirecting to auth)" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Frontend is not accessible" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Diagnostic suggestions
Write-Host "======================================"
Write-Host "Diagnostic Steps" -ForegroundColor Cyan
Write-Host "======================================"
Write-Host ""
Write-Host "1. Check frontend browser console:" -ForegroundColor Yellow
Write-Host "   - Open $frontendUrl" -ForegroundColor White
Write-Host "   - Press F12 to open developer tools" -ForegroundColor White
Write-Host "   - Go to Console tab" -ForegroundColor White
Write-Host "   - Look for errors related to 'circle-of-fifths'" -ForegroundColor White
Write-Host ""
Write-Host "2. Check Network tab:" -ForegroundColor Yellow
Write-Host "   - Go to Network tab in dev tools" -ForegroundColor White
Write-Host "   - Reload the page" -ForegroundColor White
Write-Host "   - Filter for 'circle-of-fifths'" -ForegroundColor White
Write-Host "   - Check HTTP status codes (should be 200)" -ForegroundColor White
Write-Host "   - Check if Authorization header is present" -ForegroundColor White
Write-Host ""
Write-Host "3. Check API logs:" -ForegroundColor Yellow
Write-Host "   az webapp log tail --name app-grooveapp-$Environment-api --resource-group rg-grooveapp-$Environment" -ForegroundColor White
Write-Host ""
Write-Host "4. Check frontend logs:" -ForegroundColor Yellow
Write-Host "   az webapp log tail --name app-grooveapp-$Environment-frontend --resource-group rg-grooveapp-$Environment" -ForegroundColor White
Write-Host ""

Write-Host "Common Issues:" -ForegroundColor Cyan
Write-Host "  • CORS not configured correctly (check main.tf cors_allowed_origins)" -ForegroundColor White
Write-Host "  • API endpoint requires auth but frontend isn't sending token" -ForegroundColor White
Write-Host "  • API endpoint returning error (check API logs)" -ForegroundColor White
Write-Host "  • JavaScript error preventing API call (check browser console)" -ForegroundColor White
Write-Host "  • Config service not loading correct API URL" -ForegroundColor White
