<#
.SYNOPSIS
    Automated Release Script for Draw & Cut Android App.
    Builds APK and AAB, tags version, and publishes release locally and to GitHub.

.PARAMETER Bump
    Type of version bump: 'patch' (e.g. 1.1 -> 1.1.1 or 1.2), 'minor' (1.1 -> 1.2), 'major' (1.1 -> 2.0), or 'none'.

.PARAMETER NewVersion
    Explicit new version name (e.g. "1.2").

.PARAMETER SkipPush
    If specified, builds and packages locally without committing or pushing to GitHub.

.EXAMPLE
    .\scripts\release.ps1
    .\scripts\release.ps1 -Bump minor
    .\scripts\release.ps1 -NewVersion "1.2"
    .\scripts\release.ps1 -SkipPush
#>

[CmdletBinding()]
param (
    [ValidateSet('patch', 'minor', 'major', 'none', '')]
    [string]$Bump = '',

    [string]$NewVersion = '',

    [switch]$SkipPush
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  ✂️ Draw & Cut - Automated Build & Release     " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Read current version from app/build.gradle
$GradleFile = Join-Path $ProjectRoot "app\build.gradle"
if (-not (Test-Path $GradleFile)) {
    Write-Error "Could not find app/build.gradle at $GradleFile"
    exit 1
}

$gradleContent = Get-Content $GradleFile -Raw

if ($gradleContent -match 'versionCode\s+(\d+)') {
    $currentCode = [int]$matches[1]
} else {
    $currentCode = 1
}

if ($gradleContent -match 'versionName\s+"([^"]+)"') {
    $currentVersion = $matches[1]
} else {
    $currentVersion = "1.0"
}

Write-Host "Current Version Name : " -NoNewline
Write-Host "$currentVersion" -ForegroundColor Yellow
Write-Host "Current Version Code : " -NoNewline
Write-Host "$currentCode" -ForegroundColor Yellow

# 2. Determine target version
$targetVersion = $currentVersion
$targetCode = $currentCode

if ($NewVersion) {
    $targetVersion = $NewVersion
    $targetCode = $currentCode + 1
} elseif ($Bump -ne '') {
    $parts = $currentVersion.Split('.')
    $major = if ($parts.Length -gt 0) { [int]$parts[0] } else { 1 }
    $minor = if ($parts.Length -gt 1) { [int]$parts[1] } else { 0 }
    $patch = if ($parts.Length -gt 2) { [int]$parts[2] } else { 0 }

    switch ($Bump) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
            $targetVersion = "$major.$minor"
        }
        'minor' {
            $minor++
            $patch = 0
            $targetVersion = "$major.$minor"
        }
        'patch' {
            if ($parts.Length -ge 3) {
                $patch++
                $targetVersion = "$major.$minor.$patch"
            } else {
                $minor++
                $targetVersion = "$major.$minor"
            }
        }
        'none' {
            # Keep same version name
        }
    }
    $targetCode = $currentCode + 1
} else {
    # Interactive prompt if running interactively
    Write-Host "`nChoose an action:" -ForegroundColor Green
    Write-Host "  [1] Bump Minor Version (Recommended: $currentVersion -> " -NoNewline
    $parts = $currentVersion.Split('.')
    $m = if ($parts.Length -gt 1) { [int]$parts[1] + 1 } else { 1 }
    $suggested = "$($parts[0]).$m"
    Write-Host "$suggested, Code: $($currentCode + 1)" -ForegroundColor Yellow -NoNewline
    Write-Host ")"
    Write-Host "  [2] Keep Current Version ($currentVersion, Build Code: $($currentCode + 1))"
    Write-Host "  [3] Custom Version Name"
    
    $choice = Read-Host "Select option [1-3] (Default: 1)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

    switch ($choice) {
        "1" {
            $targetVersion = $suggested
            $targetCode = $currentCode + 1
        }
        "2" {
            $targetVersion = $currentVersion
            $targetCode = $currentCode + 1
        }
        "3" {
            $custom = Read-Host "Enter new version name (e.g. 1.2)"
            if (-not [string]::IsNullOrWhiteSpace($custom)) {
                $targetVersion = $custom
            }
            $targetCode = $currentCode + 1
        }
        default {
            $targetVersion = $suggested
            $targetCode = $currentCode + 1
        }
    }
}

Write-Host "`nTarget Release:" -ForegroundColor Cyan
Write-Host "  Version Name: $targetVersion" -ForegroundColor Green
Write-Host "  Version Code: $targetCode" -ForegroundColor Green

# 3. Update app/build.gradle if version changed
if ($targetCode -ne $currentCode -or $targetVersion -ne $currentVersion) {
    Write-Host "`nUpdating app/build.gradle..." -ForegroundColor Yellow
    $updatedContent = $gradleContent -replace 'versionCode\s+\d+', "versionCode $targetCode"
    $updatedContent = $updatedContent -replace 'versionName\s+"[^"]+"', "versionName `"$targetVersion`""
    Set-Content -Path $GradleFile -Value $updatedContent -NoNewline
    Write-Host "Updated version successfully." -ForegroundColor Green
}

# 4. Run Build
Write-Host "`nStarting Build: assembleProdRelease & bundleProdRelease..." -ForegroundColor Cyan
$gradlewCmd = Join-Path $ProjectRoot "gradlew.bat"

& $gradlewCmd assembleProdRelease bundleProdRelease
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

# 5. Collect and Package Outputs
$outputDir = Join-Path $ProjectRoot "release-outputs\v$targetVersion"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$apkSource = Join-Path $ProjectRoot "app\build\outputs\apk\prod\release\app-prod-release.apk"
$aabSource = Join-Path $ProjectRoot "app\build\outputs\bundle\prodRelease\app-prod-release.aab"

$apkDestName = "DrawAndCut-v$targetVersion-build$targetCode.apk"
$aabDestName = "DrawAndCut-v$targetVersion-build$targetCode.aab"

$apkDest = Join-Path $outputDir $apkDestName
$aabDest = Join-Path $outputDir $aabDestName

if (Test-Path $apkSource) {
    Copy-Item $apkSource $apkDest -Force
    $apkSize = [math]::Round(((Get-Item $apkDest).Length / 1MB), 2)
    Write-Host "  [APK] $apkDestName ($apkSize MB)" -ForegroundColor Green
} else {
    Write-Warning "APK output not found at $apkSource"
}

if (Test-Path $aabSource) {
    Copy-Item $aabSource $aabDest -Force
    $aabSize = [math]::Round(((Get-Item $aabDest).Length / 1MB), 2)
    Write-Host "  [AAB] $aabDestName ($aabSize MB)" -ForegroundColor Green
} else {
    Write-Warning "AAB output not found at $aabSource"
}

# Generate SHA256 Checksums
$checksumFile = Join-Path $outputDir "checksums.txt"
$shaList = @()
Get-ChildItem -Path $outputDir -File | Where-Object { $_.Name -ne "checksums.txt" } | ForEach-Object {
    $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToLower()
    $shaList += "$hash  $($_.Name)"
}
$shaList | Set-Content -Path $checksumFile -Encoding UTF8
Write-Host "  [CHECKSUM] checksums.txt created" -ForegroundColor Gray

Write-Host "`nArtifacts saved in: $outputDir" -ForegroundColor Cyan

# 5.5 Optional Direct Google Play Upload
$playKeyCandidates = @(
    "D:\htmlgames\TangledLine\play-key.json.json",
    (Join-Path $ProjectRoot "service-account.json")
)
$playKey = $null
foreach ($pk in $playKeyCandidates) {
    if (Test-Path $pk) { $playKey = $pk; break }
}
if ($playKey -and (Test-Path $aabDest)) {
    Write-Host "`n🚀 Direct Uploading to Google Play Console..." -ForegroundColor Cyan
    try {
        $uploadScript = Join-Path $ScriptDir "upload-playstore.py"
        python $uploadScript --aab $aabDest --key $playKey --track production
    } catch {
        Write-Warning "Direct Play Store upload encountered an error: $_"
    }
}

# 6. Git Commit & Push & Tag
if (-not $SkipPush) {
    Write-Host "`nGit Status & Publishing..." -ForegroundColor Cyan
    
    # Check if there are changes to commit
    git add app/
    $staged = git diff --cached --name-only
    
    if ($staged) {
        $commitMsg = "chore(release): bump version to v$targetVersion (build $targetCode)"
        Write-Host "Committing: $commitMsg" -ForegroundColor Yellow
        git commit -m $commitMsg
    }

    $tagName = "v$targetVersion"
    $existingTag = git tag -l $tagName
    if ($existingTag) {
        Write-Host "Tag $tagName already exists. Skipping local tag creation." -ForegroundColor DarkYellow
    } else {
        Write-Host "Creating Git tag: $tagName" -ForegroundColor Yellow
        git tag -a $tagName -m "Release $tagName"
    }

    Write-Host "Pushing to GitHub (origin main and tags)..." -ForegroundColor Yellow
    git push origin main
    git push origin --tags

    Write-Host "`n==================================================" -ForegroundColor Green
    Write-Host "  SUCCESS! Release $tagName Pushed to GitHub!  " -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "GitHub Actions will automatically build & publish the official Release online."
    Write-Host "Check status at: https://github.com/ssilu07/Draw-and-Cut/actions" -ForegroundColor Cyan
} else {
    Write-Host "`nSkipPush was specified. Local build completed successfully." -ForegroundColor Yellow
}
