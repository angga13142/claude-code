# Claude Code Architecture Guide

## System Topology

This repository contains **configuration, plugins, and workflows** for Claude Code CLI - not the CLI tool itself (distributed as `@anthropic-ai/claude-code` NPM package).

**Core Architecture:**

- `plugins/` - Plugin ecosystem with 12 official plugins
- `.claude/commands/` - Markdown command definitions (agentic workflow source code)
- `.specify/` - Speckit specification-driven development framework
- `.github/` - CI/CD, agent definitions, issue automation
- `specs/` - Feature specification implementations (e.g., `001-llm-gateway-config`)

## Plugin System Pattern

All plugins follow auto-discovery structure from `plugins/plugin-dev/skills/plugin-structure/SKILL.md`:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json          # Required: manifest with "name" field (kebab-case)
├── commands/                 # Auto-discovered: *.md files with YAML frontmatter
├── agents/                   # Auto-discovered: *.md files with "name" frontmatter
├── skills/                   # Auto-discovered: subdirs with SKILL.md
│   └── skill-name/SKILL.md  # Frontmatter: name, description, version
└── hooks/
    └── hooks.json           # Events: PreToolUse, PostToolUse, Stop, UserPromptSubmit, SessionStart
```

**Critical Path Variable:** Use `${CLAUDE_PLUGIN_ROOT}` in all hook commands for portability:

```json
{
  "type": "command",
  "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/pretooluse.py"
}
```

**Command Frontmatter Example:**

```yaml
---
description: Brief command description
argument-hint: Optional hint text
allowed-tools: ["Bash(gh pr:*)", "Write"] # Tool restrictions
agent: agent-name # Default agent to launch
---
```

Reference: `plugins/hookify/hooks/hooks.json`, `plugins/code-review/commands/code-review.md`

## Speckit Workflow (Spec-Driven Development)

Custom command-based workflow in `.claude/commands/` implementing rigorous feature development:

**Command Sequence:**

1. `/speckit.specify` → Creates `specs/{ID}/spec.md` with technical requirements
2. `/speckit.clarify` → Resolves ambiguities via structured Q&A
3. `/speckit.plan` → Generates `plan.md`, `data-model.md`, `contracts/`, executes research agents
4. `/speckit.tasks` → Breaks plan into actionable tasks in `tasks.md`
5. `/speckit.implement` → Executes tasks with test-first approach

**Constitution Enforcement:** All agents governed by `.specify/memory/constitution.md`:

- JARVIS persona (sophisticated, efficient, English-only responses)
- Code quality: SOLID principles, self-documenting code, PEP 8/Airbnb style
- Testing: Non-negotiable 80% coverage (70% unit/20% integration/10% E2E)
- Performance: <3s page load, <200KB gzipped bundles
- Accessibility: WCAG 2.1 Level AA minimum

Reference specs: `specs/001-llm-gateway-config/` shows complete implementation (quickstart, templates, scripts, tests)

## Agent Development Pattern

From `plugins/plugin-dev/agents/agent-creator.md` and `plugins/feature-dev/agents/code-architect.md`:

**Agent Markdown Structure:**

```yaml
---
name: agent-identifier
description: When to trigger this agent with examples
---
System prompt defining agent's role and output requirements
```

**Key Agents:**

- `code-explorer`: Codebase discovery, returns critical file lists
- `code-architect`: Architecture decisions with component design, data flow, implementation map
- `conversation-analyzer`: Scans user messages for patterns (used by Hookify)

**Validation:** Run `plugins/plugin-dev/skills/agent-development/scripts/validate-agent.sh <file>` before committing agents.

## Hookify Plugin Pattern

Dynamic rule engine creating hooks from conversation analysis:

**Architecture:**

- Generic hooks (`PreToolUse`, `PostToolUse`, `Stop`, `UserPromptSubmit`) in `hooks/hooks.json`
- Python hooks read `.claude/hookify.*.local.md` rule files
- Rules use `core/rule_engine.py` for pattern matching
- Commands: `/hookify` (create), `/hookify:list`, `/hookify:configure` (enable/disable)

**Rule File Format (`.claude/hookify.dangerous-rm.local.md`):**

```yaml
---
enabled: true
action: block  # or "warn"
---
Patterns:
- `rm -rf /`
- `rm -rf /*`

Message: Dangerous rm command detected
```

Reference: `plugins/hookify/README.md`, `plugins/hookify/core/rule_engine.py`

## Multi-Phase Command Pattern

Feature-dev and plugin-dev use phased workflows with TodoWrite tracking:

**Phase Structure (from `plugins/feature-dev/commands/feature-dev.md`):**

```markdown
## Phase 1: Discovery

**Goal**: Understand requirements
**Actions**: [numbered list]

## Phase 2: Codebase Understanding

**Goal**: Read existing patterns
**Actions**: Launch code-explorer agent, read returned files

## Phase N: Implementation

**Goal**: Execute with tests
```

**Critical Rule:** Always read files returned by agents before proceeding - agents provide file lists, commands must read for context.

## LLM Gateway Configuration (Spec 001)

Complete multi-provider setup in `specs/001-llm-gateway-config/`:

**Structure:**

- `examples/us{1-4}-*.md` - User story guides (quickstart, enterprise, multi-provider, proxy)
- `templates/*.yaml` - LiteLLM configs (base, complete, models, enterprise, proxy)
- `scripts/*.{sh,py}` - Validation, migration, health checks, rollback tools
- `tests/test-*.py` - End-to-end model testing, proxy integration

**Key Files:**

- `quickstart.md` - 10-15min setup for 8 Vertex AI models via LiteLLM
- `docs/configuration-reference.md` - All environment variables, model configs
- `scripts/validate-all.sh` - Run before committing gateway changes

## Development Conventions

**Runtime:** Bun for TypeScript scripts (`scripts/*.ts`), Python 3.7+ for hooks  
**Testing:** Run plugin validators before committing: `bash plugins/plugin-dev/skills/{component}/scripts/validate-*.sh`  
**Frontmatter Required:** All commands/agents/skills need YAML frontmatter with `name` and `description`  
**Handoffs in Commands:** Use handoffs array to link related commands/agents (see `speckit.plan.md`)  
**Auto-Discovery:** Place components in standard directories - no explicit registration needed beyond manifest

## Critical Files to Check Before Major Changes

- `.specify/memory/constitution.md` - Coding standards, testing requirements, persona
- `plugins/plugin-dev/skills/plugin-structure/SKILL.md` - Plugin architecture rules
- `plugins/plugin-dev/skills/hook-development/SKILL.md` - Hook event types, execution model
- `.claude/commands/speckit.*.md` - Workflow command implementations
- `specs/001-llm-gateway-config/README.md` - Gateway configuration patterns

## Common Patterns

**Reading Spec Files:** Use `${SPECS_DIR}/{feature-id}/spec.md` (set by setup scripts)  
**Branch Creation:** `git checkout -b {feature-id}` from setup scripts  
**Constitution Checks:** All specs include "Constitution Check" section validating against `.specify/memory/constitution.md`  
**Parallel Agents:** Launch independent agents together (see `code-review.md` - 5 parallel Sonnet agents with confidence scoring)
