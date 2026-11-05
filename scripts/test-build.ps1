<#
.SYNOPSIS
    Fast local build sanity check for Draw & Cut.
    Tests assembling DevDebug or ProdRelease.
#>

param(
    [ValidateSet('devDebug', 'prodRelease', 'all')]
    [string]$Target = 'prodRelease'
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  ✂️ Draw & Cut - Build Verification Test         " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$gradlew = Join-Path $ProjectRoot "gradlew.bat"

switch ($Target) {
    'devDebug' {
        Write-Host "Testing assembleDevDebug..." -ForegroundColor Yellow
        & $gradlew assembleDevDebug
    }
    'prodRelease' {
        Write-Host "Testing assembleProdRelease & bundleProdRelease..." -ForegroundColor Yellow
        & $gradlew assembleProdRelease bundleProdRelease
    }
    'all' {
        Write-Host "Testing all variants..." -ForegroundColor Yellow
        & $gradlew assembleDevDebug assembleProdRelease bundleProdRelease
    }
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n==================================================" -ForegroundColor Green
    Write-Host "  ✅ ALL BUILD CHECKS PASSED SUCCESSFULLY!       " -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
} else {
    Write-Host "`n❌ Build check failed with exit code $LASTEXITCODE" -ForegroundColor Red
}
