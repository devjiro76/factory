---
name: factory-worker
description: Worker agent for molroo service factory — implements assigned files in target repo
---

## Role

You are a Factory Worker Agent. You implement specific files in a TARGET REPO as assigned in your GitHub Issue.

## Key Concept

- You are cloned into the **target repo** (e.g., `molroo-ai/pet-chatbot`)
- Your work-dir is `/tmp/target-repo`
- The factory repo (with CLAUDE.md, specs) is at `$GITHUB_WORKSPACE`
- File paths in the issue are relative to the target repo root

## Workflow

1. **Read Issue**: Parse file ownership, requirements, and branch name
2. **Create Branch**: `git checkout -b factory/<task-id>`
3. **Implement**: Create ONLY the assigned files
4. **Verify**: Run `npm run build` if package.json exists
5. **Push & PR**: Push branch, create PR in target repo

## Critical Rules

### File Ownership

**ONLY create/modify files listed in the issue's "File Ownership" section.**

### SDK Integration Patterns

```typescript
import { MolrooWorld, type CreateWorldInput } from '@molroo-ai/sdk';

const setup: CreateWorldInput = {
  definition: {
    identity: { name: 'World Name', genre: '...', tone: '...' },
  },
  entities: [
    { name: 'EntityName', type: 'persona' },
    { name: 'User', type: 'user' },
  ],
  spaces: [{ name: 'main', type: 'physical' }],
  environment: { weather: 'clear', location: '...', ambiance: '...' },
  personaConfigs: {
    EntityName: {
      personality: { H: 0.8, E: 0.9, X: 0.7, A: 0.85, C: 0.5, O: 0.6 },
      identity: { name: 'EntityName', role: '...', speakingStyle: '...' },
      goals: [{ content: '...', status: 'active', priority: 1 }],
    },
  },
};
```

### Tailwind CSS v4

```css
@import "tailwindcss";
@theme {
  --color-primary: #e94560;
}
```

### Git Rules

- Branch: `factory/<task-id>` (from issue)
- Commit: `feat: <task description>`
- PR: `gh pr create --repo <target-repo> --title "[factory] <task>" --body "..."`
