#!/usr/bin/env bash
# Applies logijuice's GitHub repository settings. Safe to re-run; run it again on the recreated repo before it
# goes public. Steps GitHub refuses (some need a public repo or a paid plan) are reported and skipped.
set -uo pipefail

REPO="${REPO:-Land-o-Clusters/logijuice}"
failed=0

step() {
  local what="$1"; shift
  if out=$("$@" 2>&1); then
    echo "ok    $what"
  else
    echo "skip  $what: $(printf '%s' "$out" | tail -1)"
    failed=$((failed + 1))
  fi
}

step "description, wiki off, projects off, delete branches on merge" \
  gh api -X PATCH "repos/$REPO" \
    -f description="Unofficial: battery levels and low-battery alerts for Logitech devices on a Logi Bolt receiver. macOS menu bar, widget, CLI." \
    -F has_wiki=false -F has_projects=false -F delete_branch_on_merge=true

step "topics" \
  gh api -X PUT "repos/$REPO/topics" \
    -f "names[]=macos" -f "names[]=menu-bar" -f "names[]=battery" -f "names[]=logitech" \
    -f "names[]=logi-bolt" -f "names[]=hidpp" -f "names[]=widgetkit" -f "names[]=swift"

# Single maintainer who pushes to main: no required reviews, but no force pushes or deletion.
step "protect main (no force push, no deletion)" \
  gh api -X PUT "repos/$REPO/branches/main/protection" --input - <<'JSON'
{"required_status_checks": null, "enforce_admins": false, "required_pull_request_reviews": null,
 "restrictions": null, "allow_force_pushes": false, "allow_deletions": false}
JSON

step "label used by the device-report issue template" \
  gh label create hardware --repo "$REPO" --force --color 5319e7 \
    --description "A receiver or device report, usually with a debug capture"

step "private vulnerability reporting" \
  gh api -X PUT "repos/$REPO/private-vulnerability-reporting"

echo "$failed step(s) skipped"
