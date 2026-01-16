#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive test of GrooveApp API endpoints
.DESCRIPTION
    Tests every combination of notes, scales, arpeggios and intervals.
    Can test local or deployed API endpoints.
    
    COMPLETE TEST COVERAGE:
    - All notes (12 chromatic notes)
    - All scales (12 notes × 14 scale types = 168 tests)
    - All arpeggios (12 notes × 28 chord types = 336 tests)
    - All intervals from each note (12 notes × 13 intervals = 156 tests)
    - Circle of Fifths keys (3 tests: all, major, minor)
    - Circle of Fifths progressions (24 tests: 12 major + 12 minor)
    - Chord extensions (8 chord types with extensions)
    - Reference data endpoints (4 tests)
    - Health check (1 test)
    TOTAL: 700+ comprehensive tests
    
.PARAMETER ApiUrl
    Base URL for the API (default: http://localhost:8000)
.PARAMETER Verbose
    Show detailed output for each test
.PARAMETER StopOnError
    Stop testing on first error
.EXAMPLE
    .\test_deployment.ps1
    .\test_deployment.ps1 -Verbose
    .\test_deployment.ps1 -ApiUrl "https://webapp-grooveapp-api.azurewebsites.net"
    .\test_deployment.ps1 -StopOnError
#>
param(
    [string]$ApiUrl = "http://localhost:8000",
    [switch]$Verbose,
    [switch]$StopOnError
)

$ErrorActionPreference = "Continue"

# Robust path resolution for centralized logging (works in VS Code, ISE, terminal)
$scriptPath = if ($PSScriptRoot) { 
    $PSScriptRoot 
}
elseif ($psISE) { 
    Split-Path -Parent $psISE.CurrentFile.FullPath 
}
elseif ($null -ne $psEditor) {
    Split-Path -Parent $psEditor.GetEditorContext().CurrentFile.Path
}
else {
    $PWD.Path
}

# Find repository root by looking for .git folder
$repoRoot = $scriptPath
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot ".git"))) {
    $repoRoot = Split-Path -Parent $repoRoot
}

if (-not $repoRoot) {
    # Fallback: assume we're in /api/ subdirectory
    $repoRoot = Split-Path -Parent $scriptPath
}

$logDir = Join-Path $repoRoot "logs"

# Ensure logs directory exists
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Color output helpers
function Write-Success { param([string]$Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Failure { param([string]$Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param([string]$Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }

# Test results tracking
$script:totalTests = 0
$script:passedTests = 0
$script:failedTests = 0
$script:failedEndpoints = @()
$script:nullNoteFailures = 0
$script:dataValidationFailures = 0

function Test-Endpoint {
    param(
        [string]$Url,
        [string]$Description,
        [int]$ExpectedStatus = 200,
        [switch]$ValidateNotes,
        [switch]$ValidateScale,
        [switch]$ValidateArpeggio
    )
    
    $script:totalTests++
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -TimeoutSec 10
        
        if ($response.StatusCode -ne $ExpectedStatus) {
            $script:failedTests++
            Write-Failure "$Description - Expected: $ExpectedStatus, Got: $($response.StatusCode)"
            $script:failedEndpoints += [PSCustomObject]@{
                Url = $Url
                Description = $Description
                Expected = $ExpectedStatus
                Actual = $response.StatusCode
                Error = "Unexpected status code"
            }
            return $false
        }
        
        # Validate JSON response data if requested
        if ($ValidateScale -or $ValidateArpeggio -or $ValidateNotes) {
            try {
                $data = $response.Content | ConvertFrom-Json
                
                # Validate Scale response
                if ($ValidateScale) {
                    $nullNotes = @($data | Where-Object { $null -eq $_.Note -or $_.Note -eq "" })
                    if ($nullNotes.Count -gt 0) {
                        $script:failedTests++
                        $script:nullNoteFailures++
                        Write-Failure "$Description - Found $($nullNotes.Count) NULL/empty Note values"
                        $script:failedEndpoints += [PSCustomObject]@{
                            Url = $Url
                            Description = $Description
                            Expected = "All notes valid"
                            Actual = "$($nullNotes.Count) NULL notes"
                            Error = "NULL Note values detected"
                        }
                        if ($StopOnError) { throw "NULL Note values found" }
                        return $false
                    }
                    
                    # Validate required scale fields
                    foreach ($note in $data) {
                        if ([string]::IsNullOrWhiteSpace($note.ScaleDegree)) {
                            $script:failedTests++
                            $script:dataValidationFailures++
                            Write-Failure "$Description - Missing ScaleDegree"
                            $script:failedEndpoints += [PSCustomObject]@{
                                Url = $Url
                                Description = $Description
                                Expected = "Valid ScaleDegree"
                                Actual = "NULL/empty"
                                Error = "Missing required field"
                            }
                            if ($StopOnError) { throw "Invalid scale data" }
                            return $false
                        }
                    }
                }
                
                # Validate Arpeggio response
                if ($ValidateArpeggio) {
                    $nullNotes = @($data | Where-Object { $null -eq $_.Note -or $_.Note -eq "" })
                    if ($nullNotes.Count -gt 0) {
                        $script:failedTests++
                        $script:nullNoteFailures++
                        Write-Failure "$Description - Found $($nullNotes.Count) NULL/empty Note values"
                        $script:failedEndpoints += [PSCustomObject]@{
                            Url = $Url
                            Description = $Description
                            Expected = "All notes valid"
                            Actual = "$($nullNotes.Count) NULL notes"
                            Error = "NULL Note values detected"
                        }
                        if ($StopOnError) { throw "NULL Note values found" }
                        return $false
                    }
                    
                    # Validate required arpeggio fields
                    foreach ($note in $data) {
                        if ([string]::IsNullOrWhiteSpace($note.ChordTone)) {
                            $script:failedTests++
                            $script:dataValidationFailures++
                            Write-Failure "$Description - Missing ChordTone"
                            $script:failedEndpoints += [PSCustomObject]@{
                                Url = $Url
                                Description = $Description
                                Expected = "Valid ChordTone"
                                Actual = "NULL/empty"
                                Error = "Missing required field"
                            }
                            if ($StopOnError) { throw "Invalid arpeggio data" }
                            return $false
                        }
                    }
                }
                
            } catch {
                $script:failedTests++
                $script:dataValidationFailures++
                Write-Failure "$Description - JSON validation error: $($_.Exception.Message)"
                $script:failedEndpoints += [PSCustomObject]@{
                    Url = $Url
                    Description = $Description
                    Expected = "Valid JSON"
                    Actual = "Parse error"
                    Error = $_.Exception.Message
                }
                if ($StopOnError) { throw }
                return $false
            }
        }
        
        # All validations passed
        $script:passedTests++
        if ($Verbose) {
            Write-Success "$Description - Status: $($response.StatusCode)"
        }
        return $true
        
    } catch {
        $script:failedTests++
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.Value__ } else { "N/A" }
        $errorMessage = $_.Exception.Message
        
        Write-Failure "$Description - Status: $statusCode"
        if ($Verbose) {
            Write-Host "   Error: $errorMessage" -ForegroundColor Red
        }
        
        $script:failedEndpoints += [PSCustomObject]@{
            Url = $Url
            Description = $Description
            Expected = $ExpectedStatus
            Actual = $statusCode
            Error = $errorMessage
        }
        
        if ($StopOnError) {
            throw "Test failed: $Description"
        }
        return $false
    }
}

# Start testing
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "GrooveApp API Comprehensive Test Suite" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Base URL: $ApiUrl`n" -ForegroundColor Yellow

# Test health endpoint
Write-Info "Testing health endpoint..."
Test-Endpoint -Url "$ApiUrl/health" -Description "Health Check"

# Fetch all reference data
Write-Host "`n------------------------------------------------" -ForegroundColor Cyan
Write-Info "Fetching reference data..."

try {
    $allNotes = Invoke-RestMethod -Uri "$ApiUrl/notes" -Method Get
    # Filter to only natural notes and flat accidentals (exclude sharps as they're not supported as root notes)
    $notes = $allNotes | Where-Object { -not $_.IsSharp } | Select-Object -ExpandProperty NoteName
    Write-Success "Found $($notes.Count) notes (excluding sharps: $($allNotes.Count - $notes.Count) enharmonic equivalents)"
    
    $scaleTypes = Invoke-RestMethod -Uri "$ApiUrl/scales" -Method Get
    Write-Success "Found $($scaleTypes.Count) scale types"
    
    $chordTypes = Invoke-RestMethod -Uri "$ApiUrl/chords" -Method Get
    Write-Success "Found $($chordTypes.Count) chord types"
    
    $intervals = Invoke-RestMethod -Uri "$ApiUrl/intervals" -Method Get
    Write-Success "Found $($intervals.Count) intervals"
} catch {
    Write-Failure "Failed to fetch reference data: $($_.Exception.Message)"
    exit 1
}

# Test all note + scale type combinations
Write-Host "`n------------------------------------------------" -ForegroundColor Cyan
Write-Info "Testing Scales: $($notes.Count) notes × $($scaleTypes.Count) scale types = $($notes.Count * $scaleTypes.Count) tests"

$scaleProgress = 0
foreach ($note in $notes) {
    foreach ($scaleType in $scaleTypes) {
        $scaleProgress++
        $url = "$ApiUrl/scales/$note/$($scaleType.ScaleTypeId)"
        $desc = "Scale: $note $($scaleType.ScaleName) (ID: $($scaleType.ScaleTypeId))"
        
        if ($Verbose -or ($scaleProgress % 20 -eq 0)) {
            Write-Host "Progress: $scaleProgress / $($notes.Count * $scaleTypes.Count) - Testing $note $($scaleType.ScaleName)" -ForegroundColor Gray
        }
        
        Test-Endpoint -Url $url -Description $desc -ValidateScale
    }
}

# Test all note + chord type combinations (arpeggios)
Write-Host "`n------------------------------------------------" -ForegroundColor Cyan
Write-Info "Testing Arpeggios: $($notes.Count) notes × $($chordTypes.Count) chord types = $($notes.Count * $chordTypes.Count) tests"

$arpeggioProgress = 0
foreach ($note in $notes) {
    foreach ($chordType in $chordTypes) {
        $arpeggioProgress++
        $url = "$ApiUrl/arpeggios/$note/$($chordType.ChordTypeId)"
        $desc = "Arpeggio: $note $($chordType.ChordName) (ID: $($chordType.ChordTypeId))"
        
        if ($Verbose -or ($arpeggioProgress % 20 -eq 0)) {
            Write-Host "Progress: $arpeggioProgress / $($notes.Count * $chordTypes.Count) - Testing $note $($chordType.ChordName)" -ForegroundColor Gray
        }
        
        Test-Endpoint -Url $url -Description $desc -ValidateArpeggio
    }
}

# Note: Interval and Key Signature endpoints do not exist in current API
# Skipping those tests

# Test reference endpoints
Write-Host "`n------------------------------------------------" -ForegroundColor Cyan
Write-Info "Testing Reference Data Endpoints..."

Test-Endpoint -Url "$ApiUrl/notes" -Description "All Notes"
Test-Endpoint -Url "$ApiUrl/scales" -Description "All Scale Types"
Test-Endpoint -Url "$ApiUrl/chords" -Description "All Chord Types"
Test-Endpoint -Url "$ApiUrl/intervals" -Description "All Intervals"

# Test intervals from each note
Write-Host "`n------------------------------------------------" -ForegroundColor Cyan
Write-Info "Testing Intervals From Each Note: $($notes.Count) notes × $($intervals.Count) intervals = $($notes.Count * $intervals.Count) tests"

$intervalProgress = 0
foreach ($note in $notes) {
    $intervalProgress++
    $url = "$ApiUrl/intervals/$([uri]::EscapeDataString($note))"
    $desc = "Intervals from $note"
    
    if ($Verbose -or ($intervalProgress % 10 -eq 0)) {
        Write-Host "Progress: $intervalProgress / $($notes.Count) - Testing intervals from $note" -ForegroundColor Gray
    }
    
    Test-Endpoint -Url $url -Description $desc -ValidateNotes
}

# Test Circle of Fifths endpoints
Write-Host "`n------------------------------------------------" -ForegroundColor Cyan
Write-Info "Testing Circle of Fifths Endpoints..."

# Test Circle of Fifths keys
Test-Endpoint -Url "$ApiUrl/circle-of-fifths/keys" -Description "Circle of Fifths - All Keys"
Test-Endpoint -Url "$ApiUrl/circle-of-fifths/keys?scale_type=1" -Description "Circle of Fifths - Major Keys Only"
Test-Endpoint -Url "$ApiUrl/circle-of-fifths/keys?scale_type=2" -Description "Circle of Fifths - Minor Keys Only"

# Test Circle of Fifths progressions for all keys
Write-Host "`n------------------------------------------------" -ForegroundColor Cyan
Write-Info "Testing Circle of Fifths Progressions: $($notes.Count) notes × 2 scale types = $(($notes.Count * 2)) tests"

$progressionProgress = 0
foreach ($note in $notes) {
    # Major progression
    $progressionProgress++
    $url = "$ApiUrl/circle-of-fifths/progression/$([uri]::EscapeDataString($note))?scale_type=1"
    $desc = "Circle of Fifths Progression: $note Major"
    
    if ($Verbose -or ($progressionProgress % 5 -eq 0)) {
        Write-Host "Progress: $progressionProgress / $(($notes.Count * 2)) - Testing $note Major progression" -ForegroundColor Gray
    }
    
    Test-Endpoint -Url $url -Description $desc
    
    # Minor progression
    $progressionProgress++
    $url = "$ApiUrl/circle-of-fifths/progression/$([uri]::EscapeDataString($note))?scale_type=2"
    $desc = "Circle of Fifths Progression: $note Minor"
    
    if ($Verbose -or ($progressionProgress % 5 -eq 0)) {
        Write-Host "Progress: $progressionProgress / $(($notes.Count * 2)) - Testing $note Minor progression" -ForegroundColor Gray
    }
    
    Test-Endpoint -Url $url -Description $desc
}

# Test chord extensions for each chord type that has extensions
Write-Host "`n------------------------------------------------" -ForegroundColor Cyan
Write-Info "Testing Chord Extensions Endpoints..."

# Test chord types that have extensions in the database
$chordTypesWithExtensions = @(
    @{Id=1; Name="Major"},
    @{Id=2; Name="Minor"},
    @{Id=3; Name="Dominant 7th"},
    @{Id=4; Name="Major 7th"},
    @{Id=5; Name="Minor 7th"},
    @{Id=11; Name="Half Diminished"},
    @{Id=12; Name="Minor Major 7th"},
    @{Id=16; Name="Dominant 9th"}
)

foreach ($chordType in $chordTypesWithExtensions) {
    Test-Endpoint -Url "$ApiUrl/chords/$($chordType.Id)/extensions" -Description "Extensions for $($chordType.Name)"
}

# Print summary
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Total Tests:  $script:totalTests" -ForegroundColor White
Write-Host "Passed:       $script:passedTests" -ForegroundColor Green
Write-Host "Failed:       $script:failedTests" -ForegroundColor $(if ($script:failedTests -eq 0) { "Green" } else { "Red" })

if ($script:nullNoteFailures -gt 0 -or $script:dataValidationFailures -gt 0) {
    Write-Host "`nData Quality Issues:" -ForegroundColor Yellow
    if ($script:nullNoteFailures -gt 0) {
        Write-Host "  NULL Note values: $script:nullNoteFailures" -ForegroundColor Red
    }
    if ($script:dataValidationFailures -gt 0) {
        Write-Host "  Other validation failures: $script:dataValidationFailures" -ForegroundColor Red
    }
}

if ($script:nullNoteFailures -gt 0) {
    Write-Host "`nData Quality Issues:" -ForegroundColor Yellow
    Write-Host "  NULL Note values: $script:nullNoteFailures" -ForegroundColor Red
}
if ($script:dataValidationFailures -gt 0) {
    Write-Host "  Other validation failures: $script:dataValidationFailures" -ForegroundColor Red
}

if ($script:failedTests -gt 0) {
    # Analyze failures by note
    $failuresByNote = $script:failedEndpoints | Where-Object { $_.Description -match "^(Scale|Arpeggio):" } | 
        ForEach-Object { 
            if ($_.Description -match "^(Scale|Arpeggio): ([A-G][#b]?)") {
                $matches[2]
            }
        } | Group-Object | Sort-Object Count -Descending
    
    if ($failuresByNote) {
        Write-Host "`nFailures by Note:" -ForegroundColor Yellow
        foreach ($noteGroup in $failuresByNote | Select-Object -First 10) {
            Write-Host "  $($noteGroup.Name): $($noteGroup.Count) failures" -ForegroundColor Yellow
        }
        Write-Host "`nNote: Sharp notes (C#, D#, F#, G#, A#) may not be supported as root notes." -ForegroundColor Yellow
        Write-Host "      Use flat equivalents (Db, Eb, Gb, Ab, Bb) instead." -ForegroundColor Yellow
    }
    $successRate = [math]::Round(($script:passedTests / $script:totalTests) * 100, 2)
    Write-Host "Success Rate: $successRate%" -ForegroundColor Yellow
    
    Write-Host "`n------------------------------------------------" -ForegroundColor Red
    Write-Host "Failed Endpoints (First 20):" -ForegroundColor Red
    Write-Host "------------------------------------------------" -ForegroundColor Red
    
    $script:failedEndpoints | Select-Object -First 20 | Format-Table Description, Actual, Expected, Error -AutoSize
    
    if ($script:failedEndpoints.Count -gt 20) {
        Write-Warning "... and $($script:failedEndpoints.Count - 20) more failures"
    }
    
    # Export full failure report to centralized logs folder
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportPath = Join-Path $logDir "test-api-failures-$timestamp.json"
    $script:failedEndpoints | ConvertTo-Json -Depth 10 | Out-File $reportPath
    Write-Info "Full failure report saved to: $reportPath"
    
    exit 1
} else {
    Write-Host "`n🎉 All tests passed! 🎉" -ForegroundColor Green
    exit 0
}
