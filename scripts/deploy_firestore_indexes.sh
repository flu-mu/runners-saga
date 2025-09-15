#!/usr/bin/env bash
set -euo pipefail

# Deploy Firestore composite indexes from runners_saga/firestore.indexes.json
# Usage:
#   ./scripts/deploy_firestore_indexes.sh <project-id>
# or set FIREBASE_PROJECT env var:
#   FIREBASE_PROJECT=my-project ./scripts/deploy_firestore_indexes.sh

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
INDEX_FILE="$ROOT_DIR/runners_saga/firestore.indexes.json"

PROJECT_ID="${1:-${FIREBASE_PROJECT:-}}"

if ! command -v firebase >/dev/null 2>&1; then
  echo "Error: firebase-tools not found. Install with: npm i -g firebase-tools" >&2
  exit 1
fi

if [[ -z "${PROJECT_ID}" ]]; then
  echo "Error: Project ID not provided. Pass as first arg or set FIREBASE_PROJECT env var." >&2
  echo "Example: ./scripts/deploy_firestore_indexes.sh my-firebase-project" >&2
  exit 1
fi

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "Error: Index file not found at $INDEX_FILE" >&2
  exit 1
fi

echo "Using project: $PROJECT_ID"
echo "Index file: $INDEX_FILE"

# Ensure user is logged in (will be no-op if already logged in)
firebase login || true

# Deploy only the Firestore indexes from the JSON file
firebase deploy --only firestore:indexes --project "$PROJECT_ID"

echo "Done. Firestore is building indexes in the background."
echo "Check status in Firebase Console → Firestore → Indexes for project: $PROJECT_ID"

