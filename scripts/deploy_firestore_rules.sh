#!/usr/bin/env bash
set -euo pipefail

# Deploy Firestore security rules from runners_saga/firestore.rules
# Usage:
#   ./scripts/deploy_firestore_rules.sh <project-id>
# or set FIREBASE_PROJECT env var:
#   FIREBASE_PROJECT=my-project ./scripts/deploy_firestore_rules.sh

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
RULES_FILE="$ROOT_DIR/runners_saga/firestore.rules"

PROJECT_ID="${1:-${FIREBASE_PROJECT:-}}"

if ! command -v firebase >/dev/null 2>&1; then
  echo "Error: firebase-tools not found. Install with: npm i -g firebase-tools" >&2
  exit 1
fi

if [[ -z "${PROJECT_ID}" ]]; then
  echo "Error: Project ID not provided. Pass as first arg or set FIREBASE_PROJECT env var." >&2
  echo "Example: ./scripts/deploy_firestore_rules.sh my-firebase-project" >&2
  exit 1
fi

if [[ ! -f "$RULES_FILE" ]]; then
  echo "Error: Rules file not found at $RULES_FILE" >&2
  exit 1
fi

echo "Using project: $PROJECT_ID"
echo "Rules file: $RULES_FILE"

firebase login || true

firebase deploy --only firestore:rules --project "$PROJECT_ID"

echo "Deployed Firestore rules to project: $PROJECT_ID"

