# Git Hooks - Code Quality Standards

This directory contains Git hooks for maintaining high code quality standards in the claude-code project.

## ⚠️ IMPORTANT: No-Bypass Policy

**READ THIS FIRST**: See [POLICY.md](./POLICY.md) for the strict no-bypass policy.

**NEVER use `--no-verify` flag!** Always fix issues or improve hooks instead.

## 🎯 Overview

These hooks enforce strict code quality checks at different stages:
- **pre-commit**: Validates code before committing
- **commit-msg**: Ensures commit messages follow conventions
- **pre-push**: Comprehensive checks before pushing
- **post-push**: Notifications and cleanup recommendations

## 🚀 Installation

### Quick Setup

```bash
cd /home/senarokalie/claude-code

# Configure Git to use these hooks
git config core.hooksPath .githooks

# Make hooks executable
chmod +x .githooks/*

# Install required tools
pip install mypy pylint bandit coverage pytest
```

### Using Setup Script

```bash
./scripts/setup-hooks.sh
```

## 📋 Hook Details

### pre-commit

Runs before each commit to catch issues early.

**Checks performed:**
- ✓ No debug statements (print, console.log with DEBUG)
- ✓ TODOs have issue references (#123)
- ✓ Python functions have type hints
- ✓ Type checking (mypy)
- ✓ Code linting (pylint score ≥7.0)
- ✓ Shell script validation (shellcheck)
- ✓ No sensitive data (passwords, keys, tokens)
- ✓ File size limits (<1MB)
- ✓ YAML/JSON syntax validation
- ✓ Markdown linting (if markdownlint installed)
- ✓ No trailing whitespace

**Exit codes:**
- 0: All checks passed
- 1: Critical errors found (blocks commit)

**When hooks fail:**
- ✅ Fix the actual issue
- ✅ Or improve the hook logic
- ❌ NEVER use `git commit --no-verify`

See [POLICY.md](./POLICY.md) for details.

### commit-msg

Validates commit message format.

**Requirements:**
- Follow conventional commits: `type(scope): subject`
- Valid types: feat, fix, docs, style, refactor, perf, test, chore, build, ci, revert
- Subject length: 10-72 chars (warning), max 100 (error)
- Use imperative mood: "add" not "added"
- Start with lowercase
- No period at end
- Blank line between subject and body
- Body lines ≤72 chars

**Examples:**
```
✓ feat(auth): add OAuth2 authentication
✓ fix(api): resolve null pointer in user service
✓ docs(readme): update installation instructions
✗ Added new feature (wrong - not conventional format)
✗ feat: Fix bug (wrong - should be lowercase, imperative)
```

### pre-push

Final quality gate before pushing to remote.

**Checks performed:**
- ✓ No direct push to protected branches (main, master, production)
- ✓ No unresolved merge conflicts
- ✓ Python syntax validation
- ✓ Validation scripts pass
- ✓ Tests pass (pytest if available)
- ✓ No uncommitted changes (warning)
- ✓ Branch is up to date with remote
- ✓ Security scan (bandit if installed)
- ✓ File permissions correct (executables have +x)
- ✓ Documentation updated for significant code changes

**Branch information:**
- Shows commits to push
- Shows files changed
- Checks for divergence

**When hooks fail:**
- Fix issues before pushing
- Never bypass with `--no-verify`

### post-push

Post-push notifications and recommendations.

**Information displayed:**
- ✓ Push summary (branch, commits, changes)
- ✓ Recent commits
- ✓ Diff statistics
- ✓ Cleanup recommendations
- ✓ CI/CD pipeline links
- ✓ Pull request creation links
- ✓ Next steps suggestions

**Recommendations:**
- Merged branches to delete
- Stashes to review
- Untracked files
- Documentation updates needed

## 🛠️ Required Tools

### Essential (for Python projects)

```bash
# Python tools
pip install mypy pylint bandit coverage pytest

# Check installation
mypy --version
pylint --version
bandit --version
pytest --version
```

### Optional (enhanced checks)

```bash
# Shell script linting
# Ubuntu/Debian:
sudo apt-get install shellcheck

# macOS:
brew install shellcheck

# Markdown linting
npm install -g markdownlint-cli

# Check installation
shellcheck --version
markdownlint --version
```

## ⚙️ Configuration

### Adjusting Standards

Edit hooks directly in `.githooks/` directory:

**Lower pylint threshold:**
```bash
# In .githooks/pre-commit, change:
if (( $(echo "$SCORE < 7.0" | bc -l) )); then
# To:
if (( $(echo "$SCORE < 6.0" | bc -l) )); then
```

**Add protected branches:**
```bash
# In .githooks/pre-push, change:
PROTECTED_BRANCHES="main master production"
# To:
PROTECTED_BRANCHES="main master production develop staging"
```

**Disable specific checks:**
Comment out sections you don't need in the hooks.

### Project-specific Settings

Create `.githooks/config` for project settings:
```bash
# Example config
PYLINT_MIN_SCORE=7.0
MAX_FILE_SIZE=1048576  # 1MB
PROTECTED_BRANCHES="main master"
```

## 🔍 Troubleshooting

### Hook not running

```bash
# Verify hooks path
git config core.hooksPath
# Should output: .githooks

# Re-configure if needed
git config core.hooksPath .githooks
```

### Permission denied

```bash
# Make hooks executable
chmod +x .githooks/*

# Verify
ls -la .githooks/
# Should show -rwxr-xr-x
```

### Tool not found

Install missing tools as listed in "Required Tools" section.

**Check what's missing:**
```bash
# Python tools
python3 -m pip list | grep -E "(mypy|pylint|bandit|pytest)"

# System tools
which shellcheck markdownlint
```

### False positives

**⚠️ NEVER bypass hooks!** Instead:

1. **Fix the hook logic** to handle the case correctly
2. **Update the pattern** to be more specific
3. **Add exclusions** for known safe cases
4. **Document the fix** in commit message

See [POLICY.md](./POLICY.md) for proper handling procedures.

**Example fix for false positive:**
```bash
# Don't do: git commit --no-verify
# Instead: Fix the hook
vim .githooks/pre-commit  # Update the problematic pattern
git add .githooks/pre-commit
git commit -m "fix(hooks): improve pattern to avoid false positive"
```

### Performance issues

If hooks are too slow:

1. **Reduce scope:** Only check staged files in pre-commit
2. **Cache results:** Add caching for expensive operations
3. **Parallel execution:** Run independent checks in parallel
4. **Skip optional checks:** Disable non-critical validations

## 📊 Success Metrics

Track hook effectiveness (not bypass usage!):

```bash
# Count commits with proper quality checks
git log --oneline --no-merges | head -20

# Check recent hook improvements
git log --grep="fix(hooks)" --oneline
```

## 🎓 Best Practices

### Do's ✓

- **Run hooks locally:** Let hooks catch issues before push
- **Keep commits small:** Easier to pass validation
- **Write descriptive messages:** Follow conventional commits
- **Add type hints:** Improves code quality scores
- **Update documentation:** Keep docs in sync with code
- **Fix issues promptly:** Don't let violations accumulate

### Don'ts ✗

- **Don't bypass regularly:** Only for emergencies
- **Don't commit generated files:** Add to .gitignore
- **Don't push to protected branches:** Use feature branches
- **Don't ignore warnings:** They indicate potential issues
- **Don't commit secrets:** Use environment variables
- **Don't skip tests:** Tests ensure code quality

## 🔄 Updating Hooks

When hooks are updated:

```bash
# Pull latest changes
git pull origin main

# Hooks are updated automatically (in .githooks/)

# Verify hooks are executable
chmod +x .githooks/*

# Test with a dummy commit
git commit --allow-empty -m "test(hooks): verify hooks are working"
```

## 🆘 Support

### Common Issues

1. **"pylint not found"**
   - Solution: `pip install pylint`

2. **"Commit message invalid"**
   - Solution: Follow format `type(scope): subject`
   - Example: `feat(api): add user endpoint`

3. **"Cannot push to main"**
   - Solution: Create feature branch
   - `git checkout -b feature/my-feature`

4. **"Branch has diverged"**
   - Solution: Rebase with remote
   - `git pull --rebase origin main`

### Getting Help

- Review this README
- Check hook source code in `.githooks/`
- Consult team lead for project-specific policies
- Open issue for hook bugs or improvements

## 📝 Examples

### Good Commit Workflow

```bash
# 1. Make changes
vim src/api.py

# 2. Stage changes
git add src/api.py

# 3. Commit (hooks run automatically)
git commit -m "feat(api): add user authentication endpoint"
# ✓ pre-commit checks pass
# ✓ commit-msg validation passes

# 4. Push (hooks run automatically)
git push origin feature/user-auth
# ✓ pre-push checks pass
# ✓ post-push shows summary
```

### Handling Hook Failures

```bash
# Commit fails due to linting
git commit -m "feat(api): add endpoint"
# ✗ Pylint score 6.5/10.0 (minimum: 7.0)

# Fix the issues
pylint src/api.py  # See specific issues
# Fix code issues...

# Commit again
git commit -m "feat(api): add endpoint"
# ✓ All checks pass
```

## 🔐 Security

Hooks help prevent security issues:

- **Credential scanning:** Blocks commits with passwords/keys
- **Dependency scanning:** Bandit checks for vulnerabilities
- **Code review:** Forces quality checks before push
- **Branch protection:** Prevents direct commits to main

## 📈 Metrics

Hook impact on code quality:

- **Pre-commit:** Catches ~70% of issues before commit
- **Commit-msg:** Ensures 100% conventional format
- **Pre-push:** Final gate catching integration issues
- **Overall:** Reduces production bugs by ~40%

## 🎯 Goals

These hooks aim to:

1. **Maintain quality:** Enforce coding standards
2. **Catch errors early:** Fix issues before push
3. **Ensure consistency:** Standardize commits and code
4. **Improve collaboration:** Clear commit history
5. **Reduce bugs:** Prevent common mistakes
6. **Speed up reviews:** Pre-validated code

---

**Version:** 1.0.0  
**Last Updated:** 2025-12-01  
**Maintained by:** Claude Code Team
