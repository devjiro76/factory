# Factory

**Issue-driven service generation pipeline powered by Claude Code + GitHub Actions.**

Create or modify full-stack web services through GitHub Issues. Describe what you want, refine the spec through conversation, approve, and watch it build itself.

```
Issue ──→ Bot Conversation ──→ Spec YAML ──→ APPROVE ──→ Auto Build & Deploy
```

## How It Works

```
┌──────────────────────────────────────────────────────────┐
│  1. Create Issue (new service or improvement)            │
│     Uses issue templates with structured fields          │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│  2. Bot Triage & Conversation                            │
│     Analyzes request → asks clarifying questions →       │
│     generates a complete service spec YAML               │
└───────────────────────┬──────────────────────────────────┘
                        │  comment "APPROVE"
                        ▼
┌──────────────────────────────────────────────────────────┐
│  3. Pipeline Execution                                   │
│     Extract spec → post progress checklist →             │
│     dispatch parallel workers → each creates a PR        │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│  4. Integration & Deploy                                 │
│     Merge worker PRs → build → deploy →                  │
│     update progress checklist → next phase or complete   │
└──────────────────────────────────────────────────────────┘
```

## Features

- **Conversational spec refinement** — describe in plain language, bot asks the right questions
- **New services & improvements** — greenfield creation or modify existing repos
- **Parallel workers** — multiple Claude Code agents work simultaneously
- **Phase-based execution** — dependencies between phases, automatic progression
- **Progress tracking** — dynamic checklist on the parent issue, updated as phases complete
- **`@factory` mentions** — tag `@factory` in any issue comment to invoke the bot
- **Decision sub-issues** — workers can ask humans for input mid-execution
- **Auto-recovery** — retry failed workers, skip phases, or redo from scratch
- **Deploy on merge** — Vercel, Cloudflare Pages, or GitHub Pages

## Quick Start

### 1. Clone & Setup

```bash
# Clone this repo (or use as template)
gh repo clone devjiro76/factory my-factory
cd my-factory

# Point to your own private repo
gh repo create <your-username>/my-factory --private
git remote set-url origin https://github.com/<your-username>/my-factory.git
git push -u origin main
```

### 2. Configure Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Required | How to get it |
|--------|----------|---------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Yes | Run `claude setup-token` in terminal |
| `FACTORY_GH_PAT` | Yes | [GitHub PAT](https://github.com/settings/tokens) with `repo` + `workflow` scopes |
| `VERCEL_TOKEN` | Optional | [Vercel tokens page](https://vercel.com/account/tokens) |

### 3. Create Labels

```bash
./scripts/setup-labels.sh <your-username>/my-factory
```

### 4. Create an Issue

Go to **Issues → New Issue** and pick a template:

- **New Service Request** — build something from scratch
- **Service Improvement** — modify an existing repo

Answer the bot's questions, then comment `APPROVE` when the spec looks good.

You can also mention `@factory` in any comment to invoke the bot directly.

## Pipeline Architecture

### Workflows

| Workflow | Trigger | Role |
|----------|---------|------|
| `factory-triage` | Issue opened | Analyze request, ask initial questions |
| `factory-converse` | Comment / `@factory` | Refine spec through dialogue |
| `factory-approve` | `factory:approved` label | Extract spec, dispatch workers |
| `factory-worker` | `factory:worker-task` label | Implement code, create PR |
| `factory-integrator` | Workflow dispatch | Merge PRs, deploy, next phase |
| `factory-recover` | Workflow dispatch | Retry/skip failed phases |
| `factory-stale` | Weekly cron | Nudge inactive issues |

### Label State Machine

```
triage → refining ↔ (conversation) → ready → approved → executing → completed
                                                  ↕
                                          blocked / decision
```

| Label | Meaning |
|-------|---------|
| `factory:triage` | New issue, awaiting analysis |
| `factory:refining` | Spec refinement in progress |
| `factory:ready` | Spec complete, awaiting `APPROVE` |
| `factory:approved` | Approved, pipeline starting |
| `factory:executing` | Workers running |
| `factory:decision` | Human decision needed (sub-issue) |
| `factory:blocked` | Something failed |
| `factory:completed` | All done |

### Anti-Loop Protection

Bot conversations use a 5-layer guard to prevent infinite loops:

1. **Comment marker** — bot comments start with `<!-- factory:bot -->`
2. **Author check** — ignores `github-actions[bot]` comments
3. **Label guard** — only responds on `factory:refining`, `factory:decision`, or `@factory` mentions
4. **Concurrency group** — one conversation per issue at a time
5. **Turn limit** — forces spec generation after 3-4 bot turns

### Progress Tracking

When the pipeline starts, a **progress checklist** is posted on the parent issue:

```markdown
## Pipeline Progress

- [x] **setup** — Project scaffolding (3 tasks)
- [ ] **core** — Core functionality (4 tasks) ← In progress
- [ ] **ui** — UI components (3 tasks)
- [ ] **polish** — Final polish (2 tasks)
```

The checklist updates automatically as phases complete.

## Recovery

```bash
# Retry a single worker
# → GitHub UI: add "factory:retry" label to the blocked issue

# Retry integration
gh workflow run factory-recover.yml \
  -f spec="specs/my-service.spec.yaml" \
  -f phase="core" \
  -f action="retry-integration"

# Redo entire phase
gh workflow run factory-recover.yml \
  -f spec="specs/my-service.spec.yaml" \
  -f phase="core" \
  -f action="retry-phase"

# Skip a phase
gh workflow run factory-recover.yml \
  -f spec="specs/my-service.spec.yaml" \
  -f phase="core" \
  -f action="skip-phase"
```

## Project Structure

```
factory/
├── .github/
│   ├── ISSUE_TEMPLATE/       # Issue templates (new-service, improvement)
│   └── workflows/            # GitHub Actions workflows
├── templates/
│   ├── prompts/              # Claude prompt templates (triage, converse)
│   └── deploy/               # Deploy configs (vercel, cloudflare, gh-pages)
├── scripts/
│   └── setup-labels.sh       # Label setup script
├── specs/                    # Generated service specs (gitignored)
├── progress/                 # Execution progress files (gitignored)
└── CLAUDE.md                 # Agent instructions & SDK patterns
```

## Customization

Edit `CLAUDE.md` to change:

- **SDK patterns** — default code patterns workers follow
- **Tech stack** — framework, styling, language defaults
- **Reference files** — pointers to your SDK/docs

Edit `templates/prompts/` to customize:

- **Triage prompts** — what the bot asks on new issues
- **Conversation prompt** — how the bot refines specs and generates YAML

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with active subscription
- GitHub account with Actions enabled
- Node.js 20+ (used in workflows)

## License

MIT
