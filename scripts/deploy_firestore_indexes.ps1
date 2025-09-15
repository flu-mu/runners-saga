# Deploy Firestore composite indexes from runners_saga/firestore.indexes.json
# Usage:
#   .\scripts\deploy_firestore_indexes.ps1 -ProjectId "my-project"

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
$IndexFile = Join-Path $Root "runners_saga\firestore.indexes.json"

if (-not (Test-Path $IndexFile)) {
  Write-Error "Index file not found at $IndexFile"
}

Write-Host "Using project: $ProjectId"
Write-Host "Index file: $IndexFile"

# Ensure user is logged in (no-op if already)
firebase login | Out-Null

# Deploy only Firestore indexes
firebase deploy --only firestore:indexes --project $ProjectId

Write-Host "Done. Firestore will build indexes in the background."
Write-Host "Check Firebase Console → Firestore → Indexes for project: $ProjectId"

