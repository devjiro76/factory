#!/usr/bin/env bash
# Factory Deploy Script
# Usage: ./scripts/deploy.sh <spec-path> <target-repo-dir>
#
# Reads deploy.platform from spec and deploys accordingly.
# Outputs the deployment URL to stdout (last line).

set -euo pipefail

SPEC="$1"
TARGET_DIR="$2"

PLATFORM=$(python3 -c "
import yaml
with open('${SPEC}') as f:
    spec = yaml.safe_load(f)
deploy = spec.get('deploy', spec.get('stack', {}).get('deploy', 'none'))
if isinstance(deploy, dict):
    print(deploy.get('platform', 'none'))
else:
    print(deploy)
")

SERVICE_NAME=$(python3 -c "
import yaml
with open('${SPEC}') as f:
    spec = yaml.safe_load(f)
print(spec['service']['name'])
")

echo "=== Deploying ${SERVICE_NAME} via ${PLATFORM} ==="

case "$PLATFORM" in
  vercel)
    cd "$TARGET_DIR"

    # Copy vercel.json if not present
    if [ ! -f vercel.json ]; then
      cp "$(dirname "$0")/../templates/deploy/vercel/vercel.json" .
      git add vercel.json
      git commit -m "chore: add vercel.json" || true
      git push || true
    fi

    # Deploy to Vercel
    npm install -g vercel 2>/dev/null || true
    DEPLOY_URL=$(vercel --prod --yes --token "$VERCEL_TOKEN" 2>&1 | grep -oE 'https://[^ ]+\.vercel\.app' | tail -1)

    if [ -z "$DEPLOY_URL" ]; then
      # Fallback: try to get URL from vercel inspect
      DEPLOY_URL=$(vercel ls --token "$VERCEL_TOKEN" 2>/dev/null | grep "$SERVICE_NAME" | head -1 | awk '{print $NF}')
    fi

    echo "DEPLOY_URL=${DEPLOY_URL}"
    ;;

  cloudflare-pages)
    cd "$TARGET_DIR"

    # Copy wrangler.toml if not present
    if [ ! -f wrangler.toml ]; then
      sed "s/{{SERVICE_NAME}}/${SERVICE_NAME}/g" \
        "$(dirname "$0")/../templates/deploy/cloudflare-pages/wrangler.toml" > wrangler.toml
      git add wrangler.toml
      git commit -m "chore: add wrangler.toml" || true
      git push || true
    fi

    npm run build
    DEPLOY_URL=$(npx wrangler pages deploy dist --project-name "$SERVICE_NAME" 2>&1 | grep -oE 'https://[^ ]+' | tail -1)
    echo "DEPLOY_URL=${DEPLOY_URL}"
    ;;

  github-pages)
    cd "$TARGET_DIR"

    # Copy deploy workflow
    mkdir -p .github/workflows
    cp "$(dirname "$0")/../templates/deploy/github-pages/deploy.yml" .github/workflows/deploy.yml
    git add .github/workflows/deploy.yml
    git commit -m "chore: add GitHub Pages deploy workflow" || true
    git push || true

    REPO_NAME=$(basename "$(git remote get-url origin)" .git)
    ORG_NAME=$(git remote get-url origin | grep -oP '(?<=github\.com[:/])[^/]+')
    DEPLOY_URL="https://${ORG_NAME}.github.io/${REPO_NAME}"
    echo "DEPLOY_URL=${DEPLOY_URL}"
    ;;

  none|*)
    echo "No deploy platform configured. Skipping deployment."
    echo "DEPLOY_URL="
    ;;
esac
