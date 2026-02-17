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

## Required Secrets

| Secret | Purpose |
|--------|---------|
| `KIMI_CONFIG` | Kimi CLI config.toml (subscription auth) |
| `KIMI_CREDENTIALS` | Kimi OAuth credentials |
| `KIMI_DEVICE_ID` | Kimi device identifier |
| `FACTORY_GH_PAT` | GitHub PAT with `repo` + `workflow` scope for cross-repo ops |
