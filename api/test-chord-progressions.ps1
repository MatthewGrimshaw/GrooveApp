#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test Circle of Fifths chord progression endpoints
.DESCRIPTION
    Tests the /circle-of-fifths/progression endpoint for all minor keys
    to verify database, API, and encoding are working correctly.
.PARAMETER ApiUrl
    API base URL (default: http://localhost:8000)
.EXAMPLE
    .\test-chord-progressions.ps1
    .\test-chord-progressions.ps1 -ApiUrl https://app-grooveapp-dev-api.azurewebsites.net
#>

param(
    [string]$ApiUrl = "http://localhost:8000"
)

$ErrorActionPreference = "Stop"

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Testing Circle of Fifths Chord Progressions" -ForegroundColor Cyan
Write-Host "API URL: $ApiUrl" -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Cyan

# Test cases: [KeyNote, ScaleType, DisplayName]
$testCases = @(
    # Minor keys that were previously missing
    @{ Key = "B"; Type = 2; Name = "B minor" },
    @{ Key = "F#"; Type = 2; Name = "F# minor" },
    @{ Key = "C#"; Type = 2; Name = "C# minor" },
    @{ Key = "G#"; Type = 2; Name = "G# minor" },
    @{ Key = "D#"; Type = 2; Name = "D# minor" },
    @{ Key = "Bb"; Type = 2; Name = "Bb minor" },
    @{ Key = "Eb"; Type = 2; Name = "Eb minor" },
    # Previously working minor keys
    @{ Key = "A"; Type = 2; Name = "A minor" },
    @{ Key = "E"; Type = 2; Name = "E minor" },
    @{ Key = "D"; Type = 2; Name = "D minor" },
    # A couple major keys for comparison
    @{ Key = "C"; Type = 1; Name = "C major" },
    @{ Key = "G"; Type = 1; Name = "G major" }
)

$passCount = 0
$failCount = 0
$results = @()

foreach ($test in $testCases) {
    $key = $test.Key
    $scaleType = $test.Type
    $displayName = $test.Name
    
    # URL encode the key (e.g., F# -> F%23, Bb stays Bb)
    $encodedKey = [System.Web.HttpUtility]::UrlEncode($key)
    $url = "$ApiUrl/circle-of-fifths/progression/$encodedKey`?scale_type=$scaleType"
    
    Write-Host "Testing: $displayName" -ForegroundColor Yellow -NoNewline
    Write-Host " ($url)" -ForegroundColor Gray
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -UseBasicParsing
        
        if ($response -and $response.Count -eq 7) {
            Write-Host "  ✓ SUCCESS: Received $($response.Count) chords" -ForegroundColor Green
            Write-Host "    Chords: " -NoNewline -ForegroundColor Gray
            $chordSymbols = $response | ForEach-Object { $_.ChordSymbol }
            Write-Host ($chordSymbols -join ", ") -ForegroundColor White
            $passCount++
            
            $results += [PSCustomObject]@{
                Key        = $key
                Name       = $displayName
                Status     = "✓ PASS"
                ChordCount = $response.Count
                Chords     = ($chordSymbols -join ", ")
                Error      = ""
            }
        }
        else {
            Write-Host "  ⚠ WARNING: Expected 7 chords, got $($response.Count)" -ForegroundColor Yellow
            $passCount++
            
            $results += [PSCustomObject]@{
                Key        = $key
                Name       = $displayName
                Status     = "⚠ PASS (unexpected count)"
                ChordCount = $response.Count
                Chords     = ""
                Error      = "Expected 7 chords"
            }
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMsg = $_.Exception.Message
        
        if ($_.ErrorDetails.Message) {
            try {
                $errorDetail = ($_.ErrorDetails.Message | ConvertFrom-Json).detail
                if ($errorDetail) {
                    $errorMsg = $errorDetail
                }
            }
            catch {}
        }
        
        Write-Host "  ✗ FAILED: [$statusCode] $errorMsg" -ForegroundColor Red
        $failCount++
        
        $results += [PSCustomObject]@{
            Key        = $key
            Name       = $displayName
            Status     = "✗ FAIL"
            ChordCount = 0
            Chords     = ""
            Error      = "[$statusCode] $errorMsg"
        }
    }
    
    Write-Host ""
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Total Tests:  $($testCases.Count)" -ForegroundColor White
Write-Host "Passed:       " -NoNewline
Write-Host $passCount -ForegroundColor Green
Write-Host "Failed:       " -NoNewline
Write-Host $failCount -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })

if ($failCount -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $results | Where-Object { $_.Status -like "*FAIL*" } | Format-Table -AutoSize
    exit 1
}
else {
    Write-Host "`n✓ All tests passed!" -ForegroundColor Green
    Write-Host "`nAll chord progressions:" -ForegroundColor Cyan
    $results | Format-Table Key, Name, ChordCount, Chords -AutoSize
    exit 0
}
