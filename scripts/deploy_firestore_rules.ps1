# Deploy Firestore security rules from runners_saga/firestore.rules
# Usage:
#   .\scripts\deploy_firestore_rules.ps1 -ProjectId "my-project"

param(
  [Parameter(Mandatory=$false)]
  [string]$ProjectId = $env:FIREBASE_PROJECT
)

$ErrorActionPreference = "Stop"

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    Write-Error "Command '$Name' not found. Install with: npm i -g firebase-tools"
  }
}

Require-Command -Name "firebase"

if (-not $ProjectId) {
  Write-Error "Project ID not provided. Use -ProjectId or set FIREBASE_PROJECT env var."
}

$Root = (Resolve-Path "$PSScriptRoot\..\").Path
$RulesFile = Join-Path $Root "runners_saga\firestore.rules"

if (-not (Test-Path $RulesFile)) {
  Write-Error "Rules file not found at $RulesFile"
}

Write-Host "Using project: $ProjectId"
Write-Host "Rules file: $RulesFile"

firebase login | Out-Null
firebase deploy --only firestore:rules --project $ProjectId

Write-Host "Deployed Firestore rules to project: $ProjectId"

