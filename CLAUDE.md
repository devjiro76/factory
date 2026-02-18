# Service Factory

Issue-driven conversational pipeline for automated service generation using Claude Code CLI + GitHub Actions.
Supports both new service creation and existing service improvements.

## Repository Model

```
devjiro76/factory              <- this repo (orchestration)
<owner>/<service-name>          <- generated repos (one per service)
```

- **This repo**: issue templates, specs, progress tracking, workflows, prompt templates
- **Target repos**: generated app source code, each fully independent

## Architecture

```
Issue Created ──> Triage Bot ──> Conversation (refine spec)
                                      │
                                      v
                    Human APPROVE ──> Approve Workflow
                                      │ (extracts spec, dispatches workers)
                                      v
                    Worker Agents (parallel) ──> Integrator Agent
                       │                            │
                       │ clones target repo          │ merges PRs
                       │ implements files             │ deploys
                       │ creates PRs (in target)      │ triggers next phase
                       v                            v
                    Decision sub-issue          Parent issue updated
                    (if blocked)                (progress comments)
```

### Pipeline Flow

1. **Issue created** → `factory:triage` label (via template)
2. **Triage** (`factory-triage.yml`) → Bot analyzes, asks questions → `factory:refining`
3. **Conversation** (`factory-converse.yml`) → Bot refines spec via dialogue → generates YAML → `factory:ready`
4. **Approve** → Human comments "APPROVE" → `factory:approved` → `factory-approve.yml`
5. **Execute** → Spec extracted, workers dispatched → `factory:executing`
6. **Workers** (`factory-worker.yml`) → Implement tasks, create PRs in target repo
7. **Integrator** (`factory-integrator.yml`) → Merge PRs, deploy, trigger next phase
8. **Complete** → All phases done → `factory:completed`, parent issue closed

### Anti-Loop Strategy (5-Layer)

1. **Comment marker**: Bot comments start with `<!-- factory:bot -->` → workflow checks
2. **Author check**: `github.event.comment.user.login != 'github-actions[bot]'`
3. **Label guard**: Only `factory:refining` / `factory:decision` issues trigger conversation
4. **Concurrency group**: Per-issue `factory-converse-{issue_num}`
5. **Turn limit**: Prompt enforces 2-4 turns to spec convergence

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
- **Deploy**: Vercel / Cloudflare Pages / GitHub Pages

## Operations Guide

### Getting Started

1. **Setup labels**: `./scripts/setup-labels.sh` (run once per repo)
2. **Create an issue**: Use "New Service Request" or "Service Improvement" template
3. **Converse**: Answer the bot's questions to refine the spec
4. **Approve**: Comment `APPROVE` when the spec looks good
5. **Monitor**: Watch the parent issue for progress updates

### Label State Machine

| Label | Color | Meaning | Who sets it |
|-------|-------|---------|-------------|
| `factory:triage` | `#0E8A16` | New issue, awaiting bot analysis | Issue template |
| `factory:refining` | `#FBCA04` | Spec refinement via conversation | Bot |
| `factory:ready` | `#1D76DB` | Spec finalized, awaiting approval | Bot |
| `factory:approved` | `#0E8A16` | Approved, pipeline starting | Human |
| `factory:executing` | `#FF6B35` | Workers running | Bot |
| `factory:decision` | `#E4E669` | Sub-issue: human decision needed | Bot |
| `factory:blocked` | `#D93F0B` | Execution blocked | Bot |
| `factory:completed` | `#0E8A16` | Pipeline completed | Bot |
| `factory:worker-task` | `#FF6B35` | Worker task issue | Lead logic |
| `factory:retry` | `#FBCA04` | Retry failed worker | **Human** |
| `type:new-service` | `#C5DEF5` | New service creation | Issue template |
| `type:improvement` | `#BFD4F2` | Existing service improvement | Issue template |

Transition: `triage -> refining <-> (conversation) -> ready -> approved -> executing <-> blocked/decision -> completed`

### Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `factory-triage.yml` | `issues: [opened]` + `factory:triage` | Analyze issue, ask initial questions |
| `factory-converse.yml` | `issue_comment: [created]` + anti-loop guards | Continue conversation, detect APPROVE |
| `factory-approve.yml` | `issues: [labeled]` + `factory:approved` | Extract spec, dispatch workers |
| `factory-worker.yml` | `issues: [labeled]` + `factory:worker-task` or `factory:retry` | Implement task, create PR |
| `factory-integrator.yml` | `workflow_dispatch` | Merge PRs, deploy, trigger next phase |
| `factory-recover.yml` | `workflow_dispatch` | Recovery: retry-phase, retry-integration, skip-phase |

### Pipeline Status — Where to Look

| What | Where |
|------|-------|
| Overall progress | Parent issue comments + `progress/<service>.progress.yaml` |
| Active workers | Issues tab -> filter `factory:worker-task` `is:open` |
| Blocked tasks | Issues tab -> filter `factory:blocked` |
| Decisions needed | Issues tab -> filter `factory:decision` |
| Workflow runs | Actions tab |
| Target repo PRs | Target repo -> Pull Requests tab |

### When Something Fails

**Worker failed** (most common)
1. Issue gets `factory:blocked` label automatically
2. Error comment appears on the issue + parent issue notified
3. To fix: review the log, then add `factory:retry` label to the issue
4. Worker re-runs automatically (cleans up stale branch/PR first)

**Worker needs a decision**
1. Worker creates a sub-issue with `factory:decision` label
2. Human answers in the sub-issue comments
3. Bot resolves the decision, unblocks the parent issue

**Integrator failed** (merge conflict, build error)
1. A new issue is created with `factory:blocked` label and recovery instructions
2. Parent issue is notified
3. Option A — Re-run integrator:
   ```
   gh workflow run factory-recover.yml \
     --field spec="specs/<service>.spec.yaml" \
     --field phase="<phase>" \
     --field action="retry-integration"
   ```
4. Option B — Skip the phase entirely:
   ```
   gh workflow run factory-recover.yml \
     --field spec="specs/<service>.spec.yaml" \
     --field phase="<phase>" \
     --field action="skip-phase"
   ```

**Entire phase needs a do-over**
```
gh workflow run factory-recover.yml \
  --field spec="specs/<service>.spec.yaml" \
  --field phase="<phase>" \
  --field action="retry-phase"
```
This resets progress, closes old issues, and re-dispatches workers from scratch.

### Quick Reference — Recovery Commands

```bash
# Retry a single worker: just add label in GitHub UI
# Issues -> find blocked issue -> Add label -> factory:retry

# Retry integration
gh workflow run factory-recover.yml -f spec="specs/pet-chatbot.spec.yaml" -f phase="core" -f action="retry-integration"

# Retry entire phase from scratch
gh workflow run factory-recover.yml -f spec="specs/pet-chatbot.spec.yaml" -f phase="core" -f action="retry-phase"

# Skip a phase and move on
gh workflow run factory-recover.yml -f spec="specs/pet-chatbot.spec.yaml" -f phase="core" -f action="skip-phase"
```

## Prompt Templates

| Template | Purpose |
|----------|---------|
| `templates/prompts/triage-new.md` | Initial analysis for new service requests |
| `templates/prompts/triage-improvement.md` | Initial analysis for improvement requests |
| `templates/prompts/converse.md` | Conversation continuation + spec generation |

## Deployment

Each service spec defines a `deploy` platform. The Integrator automatically deploys after every phase merge.

### Supported Platforms

| Platform | Spec Value | Template | Auto-deploy |
|----------|-----------|----------|-------------|
| Vercel | `deploy: vercel` | `templates/deploy/vercel/` | Every merge to main |
| Cloudflare Pages | `deploy: cloudflare-pages` | `templates/deploy/cloudflare-pages/` | Every merge to main |
| GitHub Pages | `deploy: github-pages` | `templates/deploy/github-pages/` | Via workflow on push |

### Spec Format

Simple (string):
```yaml
stack:
  deploy: vercel
```

Extended (object, for future use):
```yaml
deploy:
  platform: vercel
  domain: pet-chatbot.molroo.io
  env:
    VITE_MOLROO_API_URL: https://api.molroo.io
```

### Deploy URL

After deployment, the URL is saved in the progress file:
```yaml
deployUrl: https://pet-chatbot-xxx.vercel.app
deployPlatform: vercel
```

## Required Secrets

| Secret | Purpose |
|--------|---------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code OAuth token via `claude setup-token` (subscription auth) |
| `FACTORY_GH_PAT` | GitHub PAT with `repo` + `workflow` scope for cross-repo ops |
| `VERCEL_TOKEN` | Vercel deploy token (https://vercel.com/account/tokens) |
