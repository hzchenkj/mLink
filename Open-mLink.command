#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$ROOT_DIR/dist/mLink.app"

if [[ ! -d "$APP_PATH" ]]; then
  osascript -e 'display alert "mLink.app not found" message "Please run scripts/package_app.sh first." as critical'
  exit 1
fi

open -n "$APP_PATH"
