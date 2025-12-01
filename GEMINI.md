# Project Context: Claude Code Repository

## Overview
This repository hosts the ecosystem for **Claude Code**, an agentic coding tool. It serves as the central hub for:
1.  **Official Plugins**: Extensions that add commands, agents, and skills to Claude Code.
2.  **Speckit Workflow**: A specification-driven development methodology implemented via customized Claude commands.
3.  **Agent Configuration**: Prompts, instructions, and configurations for AI agents.
4.  **Automation**: Maintenance scripts and GitHub Actions workflows.

**Note**: This repository contains the *configuration, plugins, and workflows* for Claude Code. The CLI tool itself is distributed as an NPM package (`@anthropic-ai/claude-code`).

## Directory Structure

### Core Directories
*   **`plugins/`**: Contains official plugins (e.g., `agent-sdk-dev`, `feature-dev`, `pr-review-toolkit`). Each plugin follows a standard structure with `commands/`, `agents/`, and `plugin.json`.
*   **`.claude/`**: Configuration for the Claude Code CLI.
    *   `commands/`: Markdown files defining custom commands (e.g., `speckit.plan.md`). These files act as the "source code" for the agentic workflow, containing prompts and logic.
*   **`.specify/`**: Core resources for the specification workflow.
    *   `memory/constitution.md`: The "Constitution" defining the rules, persona, and coding standards that AI agents must follow.
    *   `templates/`: Markdown templates for plans (`plan-template.md`), specs (`spec-template.md`), and checklists.
    *   `scripts/`: Helper scripts for the workflow.
*   **`.github/`**: GitHub-specific configuration.
    *   `agents/`: Agent definitions corresponding to the Speckit workflow (e.g., `speckit.plan.agent.md`).
    *   `workflows/`: CI/CD pipelines.
    *   `prompts/`: Underlying prompts for the GitHub-based agents.
*   **`scripts/`**: TypeScript automation scripts (e.g., for issue triage) executed via Bun.

## The Speckit Workflow
The repository implements a rigorous "Spec-Driven Development" workflow (Speckit), driven by custom commands:
1.  **Plan** (`speckit.plan`): Analyzes user input and generates an implementation plan.
2.  **Specify** (`speckit.specify`): Creates detailed technical specifications and data models.
3.  **Tasks** (`speckit.tasks`): Breaks down specs into actionable tasks.
4.  **Implement** (`speckit.implement`): Executes the code changes.

### Governance: The Constitution
All agent operations are governed by **`.specify/memory/constitution.md`**. This document mandates:
*   **Persona**: JARVIS-like (Sophisticated, Efficient, Professional).
*   **Code Quality**: Strict adherence to SOLID principles, readability, and self-documentation.
*   **Testing**: Non-negotiable 80% code coverage target (70% unit, 20% integration, 10% E2E).
*   **UX/UI**: Accessibility standards (WCAG 2.1 AA) and responsive design.

## Development & Usage

### Running Scripts
This project uses **Bun** as the runtime for its maintenance scripts.
*   **Example**: `bun run scripts/auto-close-duplicates.ts`

### Plugin Development
Plugins are located in `plugins/`. To develop or understand them:
*   See `plugins/README.md` for the general plugin architecture.
*   Each plugin defines `commands` (slash commands), `agents` (specialized AI workers), and `skills` (functions agents can call).

### Environment
*   **Dev Container**: A `.devcontainer` configuration is provided to set up a Dockerized development environment with all necessary tools (Node.js, Bun, etc.).
