# molroo Service Factory

Automated service generation pipeline using Kimi Code CLI + GitHub Actions.
Each generated service is created as an independent repo under `molroo-ai/` org.

## Repository Model

```
molroo-ai/factory              ← this repo (orchestration)
molroo-ai/<service-name>       ← generated repos (one per service)
```

- **This repo**: specs, progress tracking, agents, workflows, issue-based coordination
- **Target repos**: generated app source code, each fully independent

## Architecture

```
Lead Agent ──→ Worker Agents (parallel) ──→ Integrator Agent
   │                  │                          │
   │ reads spec       │ clones target repo       │ merges PRs in
   │ creates issues   │ implements files          │ target repo
   │ (in this repo)   │ creates PRs (in target)   │ triggers next phase
```

## Conventions

- **Commits**: `feat(factory): ...` for this repo, `feat: ...` in target repos
- **Branches**: `factory/<task-id>` for workers, `integrate/<phase>` for integrator
- **Issues**: Label `factory:worker-task` in THIS repo for task tracking
- **PRs**: Created in TARGET repo. Title: `[factory] <task description>`

## SDK Patterns

Generated services MUST follow these SDK patterns:

```typescript
import { MolrooWorld, type CreateWorldInput } from '@molroo-ai/sdk';

const world = await MolrooWorld.create({
  baseUrl: import.meta.env.VITE_MOLROO_API_URL,
  apiKey: import.meta.env.VITE_MOLROO_API_KEY,
  llmConfig: {
    provider: 'openai',
    apiKey: import.meta.env.VITE_LLM_API_KEY,
  },
}, setup);

const result = await world.chat('EntityName', 'Hello!', {
  history: messages,
});
// result.response.emotion — VAD values
// result.response.text — LLM-generated response
```

## Reference Files (in molroo-ai/molroo-ai root)

- `sdk/src/world.ts` — MolrooWorld class
- `sdk/src/types.ts` — Type definitions
- `demos/game/src/setup.ts` — World setup pattern
- `web/` — Vite + React 19 + Tailwind v4 structure

## Tech Stack for Generated Services

- **Framework**: Vite 6 + React 19
- **Styling**: Tailwind CSS v4 (`@import "tailwindcss"`)
- **Language**: TypeScript 5.3+
- **Deploy**: Cloudflare Pages

## Operations Guide

### Labels

| Label | Meaning | Who sets it |
|-------|---------|-------------|
| `factory:worker-task` | Worker task issue — triggers Worker workflow | Lead agent |
| `factory:blocked` | Something failed and needs human attention | Worker / Integrator (auto) |
| `factory:retry` | Re-run a failed Worker — triggers Worker workflow | **Human** |

### Pipeline Status — Where to Look

| What | Where |
|------|-------|
| Overall progress | `progress/<service>.progress.yaml` |
| Active workers | Issues tab → filter `factory:worker-task` `is:open` |
| Blocked tasks | Issues tab → filter `factory:blocked` |
| Workflow runs | Actions tab |
| Target repo PRs | `github.com/molroo-ai/<service>/pulls` |

### When Something Fails

**Worker failed** (most common)
1. Issue gets `factory:blocked` label automatically
2. Error comment appears on the issue with a link to the Actions run log
3. To fix: review the log, then add `factory:retry` label to the issue
4. Worker re-runs automatically (cleans up stale branch/PR first)

**Integrator failed** (merge conflict, build error)
1. A new issue is created with `factory:blocked` label and recovery instructions
2. Option A — Re-run integrator:
   ```
   gh workflow run factory-recover.yml \
     --field spec="specs/<service>.spec.yaml" \
     --field phase="<phase>" \
     --field action="retry-integration"
   ```
3. Option B — Skip the phase entirely:
   ```
   gh workflow run factory-recover.yml \
     --field spec="specs/<service>.spec.yaml" \
     --field phase="<phase>" \
     --field action="skip-phase"
   ```

**Lead failed** (spec error, repo creation failed)
1. A new issue is created with `factory:blocked` label
2. Fix the cause (spec YAML, permissions, etc.)
3. Re-trigger:
   ```
   gh workflow run factory-lead.yml \
     --field spec="specs/<service>.spec.yaml" \
     --field phase="<phase>"
   ```

**Entire phase needs a do-over**
```
gh workflow run factory-recover.yml \
  --field spec="specs/<service>.spec.yaml" \
  --field phase="<phase>" \
  --field action="retry-phase"
```
This resets progress, closes old issues, and re-triggers Lead from scratch.

### Quick Reference — Recovery Commands

```bash
# Retry a single worker: just add label in GitHub UI
# Issues → find blocked issue → Add label → factory:retry

# Retry integration
gh workflow run factory-recover.yml -f spec="specs/pet-chatbot.spec.yaml" -f phase="core" -f action="retry-integration"

# Retry entire phase from scratch
gh workflow run factory-recover.yml -f spec="specs/pet-chatbot.spec.yaml" -f phase="core" -f action="retry-phase"

# Skip a phase and move on
gh workflow run factory-recover.yml -f spec="specs/pet-chatbot.spec.yaml" -f phase="core" -f action="skip-phase"

# Manual trigger from specific phase
gh workflow run factory-lead.yml -f spec="specs/pet-chatbot.spec.yaml" -f phase="core"
```

## Required Secrets

| Secret | Purpose |
|--------|---------|
| `KIMI_CONFIG` | Kimi CLI config.toml (subscription auth) |
| `KIMI_CREDENTIALS` | Kimi OAuth credentials |
| `KIMI_DEVICE_ID` | Kimi device identifier |
| `FACTORY_GH_PAT` | GitHub PAT with `repo` + `workflow` scope for cross-repo ops |
