#!/bin/bash
# Setup Factory pipeline labels on the repository
# Usage: ./scripts/setup-labels.sh [owner/repo]
# Requires: gh CLI authenticated

set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

echo "Setting up Factory labels on ${REPO}..."

declare -A LABELS=(
  # Pipeline state labels
  ["factory:triage"]="0E8A16:New issue awaiting bot analysis"
  ["factory:refining"]="FBCA04:Spec refinement in progress via conversation"
  ["factory:ready"]="1D76DB:Spec finalized, awaiting human approval"
  ["factory:approved"]="0E8A16:Approved, pipeline starting"
  ["factory:executing"]="FF6B35:Workers running"
  ["factory:decision"]="E4E669:Sub-issue requiring human decision"
  ["factory:blocked"]="D93F0B:Execution blocked, needs attention"
  ["factory:completed"]="0E8A16:Pipeline completed"
  # Task labels (existing, preserved)
  ["factory:worker-task"]="FF6B35:Worker task issue"
  ["factory:retry"]="FBCA04:Retry failed worker"
  # Type labels
  ["type:new-service"]="C5DEF5:New service creation request"
  ["type:improvement"]="BFD4F2:Existing service improvement"
)

for LABEL in "${!LABELS[@]}"; do
  IFS=':' read -r COLOR DESC <<< "${LABELS[$LABEL]}"
  echo "  Creating label: ${LABEL} (${COLOR})"
  gh label create "$LABEL" \
    --repo "$REPO" \
    --color "$COLOR" \
    --description "$DESC" \
    --force 2>/dev/null || echo "    (already exists, updated)"
done

echo "Done! ${#LABELS[@]} labels configured on ${REPO}."
