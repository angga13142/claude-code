# Claude Code - AI Agent Instructions

## Project Overview

This is the **Claude Code plugin repository** - a collection of official plugins that extend Claude Code's functionality through commands, agents, skills, hooks, and MCP integrations. Claude Code is an agentic coding tool that runs in terminals and IDEs.

**Key Insight**: This repository IS the plugin system itself. When working here, you're building extensibility features that shape how AI agents interact with codebases.

## Architecture: Plugin System

### Standard Plugin Structure

Every plugin follows this exact structure - **component directories MUST be at plugin root**, not nested in `.claude-plugin/`:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json          # REQUIRED: Manifest with name, version, description
├── commands/                 # Slash commands (.md with YAML frontmatter)
├── agents/                   # Specialized subagents (.md with frontmatter)
├── skills/                   # Knowledge modules (subdirs with SKILL.md)
│   └── skill-name/
│       ├── SKILL.md         # Required: skill definition
│       ├── references/      # Detailed docs
│       └── examples/        # Working code samples
├── hooks/
│   └── hooks.json           # Event handlers (PreToolUse, Stop, etc.)
├── .mcp.json                # Model Context Protocol servers (optional)
└── scripts/                 # Helper utilities
```

### Critical Path References

**Always use `${CLAUDE_PLUGIN_ROOT}`** in:
- Hook commands: `"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh"`
- Command allowed-tools: `allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh)"]`
- Any file path that needs to work across different installation locations

### Component Auto-Discovery

Claude Code automatically discovers:
- **Commands**: `commands/**/*.md` files with YAML frontmatter
- **Agents**: `agents/**/*.md` files with frontmatter
- **Skills**: `skills/*/SKILL.md` directories
- **Hooks**: `hooks/hooks.json` or inline in `plugin.json`

## Plugin Component Patterns

### Commands (Slash Commands)

Commands are markdown files with YAML frontmatter that define user-initiated actions:

```markdown
---
description: Brief command description for /help
argument-hint: [optional-arg]
allowed-tools: ["Read", "Write"]  # Restrict tool access
---

System prompt for Claude when executing this command.
Can reference $ARGUMENTS for user input.
```

**Key Pattern**: Use `allowed-tools` to restrict capabilities - commands are Claude's instructions, not executable code.

### Agents (Specialized Subagents)

Agents are autonomous subagents with specific expertise:

```markdown
---
name: agent-identifier
description: Use this agent when [trigger conditions]. Examples:

<example>
Context: [Situation]
user: "[Request]"
assistant: "[Response using agent]"
<commentary>Why trigger this agent</commentary>
</example>

model: inherit          # inherit, sonnet, opus
color: blue            # yellow, green, red, blue, magenta, cyan
tools: ["Read", "Grep", "Semantic"]
---

You are [role]. Your responsibilities:
1. [Task 1]
2. [Task 2]

**Analysis Process**: [Step-by-step workflow]
```

**Key Patterns**: 
- Strong trigger conditions with concrete examples prevent false activations
- Tool lists can be arrays `["Read"]` or space-separated `Read Write Grep`
- Model choices: `inherit` (parent's model), `sonnet` (Claude 3.5 Sonnet), `opus` (Claude Opus)
- Use parallel agent launches in commands for comprehensive analysis (see `feature-dev`)

### Skills (Knowledge Injection)

Skills provide specialized knowledge loaded on-demand via the Skill tool:

```markdown
---
name: Skill Name
description: Trigger phrases and use cases for auto-invocation
version: 0.1.0
---

# Skill Content

Core knowledge with progressive disclosure:
- Lean main content (focus on essentials)
- references/ for detailed documentation
- examples/ for working code samples
```

**Key Pattern**: Skills mentioned in commands/agents auto-load. Use clear trigger phrases in description.

### Hooks (Event Automation)

Hooks execute on specific events. **Plugin format** requires wrapper:

```json
{
  "description": "Brief explanation",
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "prompt",
        "prompt": "Validate: $TOOL_INPUT",
        "timeout": 30
      }]
    }],
    "Stop": [...]
  }
}
```

**Key Patterns**:
- **Prompt-based hooks** (type: "prompt") for LLM decisions - use for complex validation
- **Command hooks** (type: "command") for deterministic checks - use for fast validations
- Exit code 2 blocks operations, exit code 1 shows error without blocking

**Available Events**: PreToolUse, PostToolUse, Stop, SubagentStop, SessionStart, SessionEnd, UserPromptSubmit, PreCompact, Notification

**Example Use Cases**:
- PreToolUse: Validate writes to sensitive files, block dangerous bash commands
- SessionStart: Load project context, inject style preferences
- Stop: Enforce quality standards before task completion
- PostToolUse: Log operations, trigger CI/CD workflows

## Development Workflows

### Creating New Plugins

1. **Structure**: Use `plugin-dev` plugin's `/plugin-dev:create-plugin` command for guided creation
2. **Manifest**: Always create `.claude-plugin/plugin.json` with name, version, description
3. **Components**: Add directories as needed (commands/, agents/, skills/, hooks/)
4. **Testing**: Test in Claude Code with `--plugin-dir` flag before committing

### Working with Existing Plugins

**High-value plugins for reference**:
- `plugin-dev/` - Comprehensive toolkit, demonstrates all patterns (7 skills, agents, commands)
- `hookify/` - Python-based rule engine with prompt-based hooks
- `feature-dev/` - Multi-phase workflow command with parallel agent orchestration
- `pr-review-toolkit/` - Multi-agent coordination patterns

### Specs-Driven Development

Active feature branches use `/specs/{feature-id}/` for design artifacts:

```
specs/{feature-id}/
├── spec.md              # Requirements with user stories, edge cases
├── plan.md              # Implementation phases, constitution check
├── research.md          # Technical research and decisions
├── data-model.md        # Entity definitions, validation rules
├── quickstart.md        # User-facing guide
├── tasks.md             # Task breakdown by phase/story
└── contracts/           # API contracts, interaction patterns
```

**Pattern**: Comprehensive planning BEFORE implementation. Constitution check gates research phase.

### Multi-Phase Development Pattern

Commands like `/feature-dev` demonstrate the standard workflow:
1. **Discovery** - Understand requirements, create todo list
2. **Exploration** - Launch parallel agents to analyze codebase
3. **Clarification** - Resolve ambiguities BEFORE design
4. **Architecture** - Design multiple approaches, get user approval
5. **Implementation** - Execute approved plan
6. **Review** - Quality check and validation
7. **Documentation** - Update docs and examples

## Project Conventions

### Documentation Style

- **Markdown everywhere**: Commands, agents, skills, README files
- **YAML frontmatter**: All component metadata
- **Progressive disclosure**: Lean core content + references/ + examples/
- **Concrete examples**: Show don't tell - include working code snippets

### Python Code (hooks, scripts)

- **Location**: `hooks/` for event handlers, `scripts/` for utilities, `core/` for shared modules
- **Style**: PEP 8, type hints, docstrings
- **Error handling**: JSON input validation, exit codes (0=pass, 1=error, 2=block)
- **Dependencies**: Minimize external deps - use stdlib when possible

### Configuration Files

- **Settings**: `.claude/settings.json` (project) or `~/.claude/settings.json` (global)
- **Local overrides**: `.claude/*.local.md` files for user-specific rules (gitignored)
- **Environment**: `${CLAUDE_PLUGIN_ROOT}` for portable paths in all configs

## Key Files & Dependencies

**No package.json** - This is a plugin collection, not a Node project. Claude Code itself is distributed separately.

**Important globals**:
- `.github/instructions/` - Instructions for AI agents (like research.instructions.md)
- `.claude-plugin/marketplace.json` - Plugin registry for bundled plugins
- `plugins/README.md` - Master plugin documentation

## Testing & Validation

**Manual Testing**:
```bash
# Test plugin in isolation
claude --plugin-dir /path/to/plugin-name

# Test command
/your-command arg1 arg2

# Test hook (check output)
# Trigger the hooked event
```

**Validation Scripts** (in `plugin-dev/skills/*/utilities/`):
- `validate-agent.sh` - Check agent frontmatter and structure
- `validate-hook-schema.sh` - Validate hooks.json format
- `test-hook.sh` - Test hook execution

**Hook Testing Pattern**:
```python
# Hook scripts read JSON from stdin
import json
import sys

input_data = json.load(sys.stdin)
tool_name = input_data.get("tool_name", "")
tool_input = input_data.get("tool_input", {})

# Exit codes matter:
# 0 = continue, 1 = error (show to user), 2 = block (show to Claude)
sys.exit(0)
```

See `examples/hooks/bash_command_validator_example.py` for complete hook implementation.

## Common Gotchas

1. **Component Location**: Commands/agents/skills MUST be at plugin root, NOT in `.claude-plugin/`
2. **Frontmatter Format**: Commands/agents use YAML `---` delimiters, skills need `name:` field
3. **Hook Format**: Plugin hooks.json needs `"hooks": {}` wrapper, not flat event list
4. **Path References**: Always use `${CLAUDE_PLUGIN_ROOT}`, never hardcode paths
5. **Tool Restrictions**: Commands define allowed-tools, agents define tools - different syntax
6. **Skill Loading**: Skills auto-load when mentioned by name - ensure clear triggers in description

## Quick Reference

**Plugin manifest (.claude-plugin/plugin.json)**:
```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Brief description"
}
```

**Command frontmatter**:
```yaml
---
description: Show in /help
argument-hint: [args]
allowed-tools: ["Read", "Write", "Bash"]
---
```

**Agent frontmatter**:
```yaml
---
name: agent-id
description: When to use with examples
model: inherit
tools: ["Read", "Grep"]
---
```

**Hook exit codes**:
- `0`: Success, continue
- `1`: Error (show stderr to user, continue)
- `2`: Block operation (show stderr to Claude)

## Working on Current Branch (001-llm-gateway-config)

The current branch is developing an **LLM Gateway Configuration Assistant** for LiteLLM proxy with Vertex AI Model Garden integration.

**Key Artifacts** (all in `/specs/001-llm-gateway-config/`):
- `spec.md` - 4 user stories (P1-P4), 14 functional requirements, edge cases
- `research.md` - LiteLLM decisions, 8 Vertex AI models (Gemini, DeepSeek, Llama, Mistral, Qwen)
- `data-model.md` - Configuration entities, validation rules, environment variables
- `quickstart.md` - 10-15 min setup guide with verification checklist
- `tasks.md` - 143 tasks organized by phase and user story (US1-US4)
- `contracts/assistant-api.md` - TypeScript interaction patterns

**Implementation Approach**:
- Documentation/configuration feature (no Claude Code core changes)
- Provides setup templates for LiteLLM YAML config
- Guides environment variable configuration (ANTHROPIC_BASE_URL, etc.)
- Covers 4 deployment patterns: Direct, Corporate Proxy, LLM Gateway, Proxy+Gateway
- Supports authentication bypass flags (CLAUDE_CODE_SKIP_BEDROCK_AUTH, etc.)

**Success Metrics**:
- Setup completion <10 minutes (SC-001)
- First-attempt success rate >90% (SC-002)
- Configuration templates work without modification (SC-003)

**When Working on This Feature**:
1. Reference spec artifacts for requirements and design decisions
2. All new files go in `/specs/001-llm-gateway-config/` directory
3. Follow task breakdown in `tasks.md` (organized by user story)
4. Include verification steps for all configuration guidance
5. Add security warnings for API key handling (100% coverage per SC-006)
