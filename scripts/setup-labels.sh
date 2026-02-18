#!/bin/bash
# Setup Factory pipeline labels on the repository
# Usage: ./scripts/setup-labels.sh [owner/repo]
# Requires: gh CLI authenticated

set -eo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

echo "Setting up Factory labels on ${REPO}..."

create_label() {
  local name="$1" color="$2" desc="$3"
  echo "  Creating label: ${name} (${color})"
  gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force 2>/dev/null \
    || echo "    (already exists, updated)"
}

# Pipeline state labels
create_label "factory:triage"      "0E8A16" "New issue awaiting bot analysis"
create_label "factory:refining"    "FBCA04" "Spec refinement in progress via conversation"
create_label "factory:ready"       "1D76DB" "Spec finalized, awaiting human approval"
create_label "factory:approved"    "0E8A16" "Approved, pipeline starting"
create_label "factory:executing"   "FF6B35" "Workers running"
create_label "factory:decision"    "E4E669" "Sub-issue requiring human decision"
create_label "factory:blocked"     "D93F0B" "Execution blocked, needs attention"
create_label "factory:completed"   "0E8A16" "Pipeline completed"

# Task labels
create_label "factory:worker-task" "FF6B35" "Worker task issue"
create_label "factory:retry"       "FBCA04" "Retry failed worker"

# Type labels
create_label "type:new-service"    "C5DEF5" "New service creation request"
create_label "type:improvement"    "BFD4F2" "Existing service improvement"

echo "Done! 12 labels configured on ${REPO}."
