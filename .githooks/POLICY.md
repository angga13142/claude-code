# Git Hooks Policy

## ⚠️ CRITICAL POLICY

**NEVER use `--no-verify` flag when committing or pushing!**

### Why This Policy Exists

Git hooks are quality gates that protect the codebase from:
- 🔒 Sensitive data leaks
- 🐛 Syntax errors
- 📝 Inconsistent commit messages
- 🔐 Security vulnerabilities
- 📊 Code quality issues

### Required Behavior

When hooks fail:

✅ **DO THIS**:
1. Read the error message carefully
2. Fix the actual issue
3. Commit/push normally without bypass

❌ **NEVER DO THIS**:
```bash
git commit --no-verify    # ❌ FORBIDDEN
git push --no-verify      # ❌ FORBIDDEN
```

### Exception Handling

If you encounter a false positive:

1. **Fix the hook** - Update the hook logic to handle the case correctly
2. **Document the fix** - Explain why the change was needed
3. **Test thoroughly** - Ensure no regression
4. **Commit the fix** - The hook fix itself can be committed normally

### Examples of Proper Fixes

#### Example 1: False Positive in Sensitive Data Detection

**Problem**: Hook detects parameter name `auth_token` as sensitive
**Wrong**: Use `--no-verify`
**Right**: Fix the hook pattern to exclude parameter names

```bash
# Before (too broad)
PATTERN="token.*="

# After (specific to actual credentials)
PATTERN='token\s*=\s*["\047][a-zA-Z0-9_-]{32,}["\047]'
```

#### Example 2: Trailing Whitespace

**Problem**: Hook detects trailing whitespace
**Wrong**: Use `--no-verify`
**Right**: Remove the whitespace

```bash
# Fix the whitespace
git diff --cached --check  # See where whitespace is
# Edit the files to remove whitespace
git add <files>
git commit  # Now it will pass
```

#### Example 3: Missing Type Hints

**Problem**: Hook warns about missing type hints
**Wrong**: Use `--no-verify`
**Right**: Add the type hints

```python
# Before
def process_data(data):
    return data

# After
def process_data(data: dict) -> dict:
    return data
```

### Hook Improvements Made

✅ **Sensitive Data Detection**
- Excludes configuration files (.toml, .yml, .yaml)
- Requires 32+ character credential strings
- Ignores parameter names
- Provides specific file locations

✅ **Type Hints Check**
- Fixed grep error with `->` operator
- Proper handling of type annotations

✅ **Flexibility**
- Warnings don't block commits (only errors do)
- Clear guidance on how to fix issues

### Verification

Test that hooks work properly:

```bash
# Test pre-commit
git commit --allow-empty -m "test(hooks): verify pre-commit"

# Test pre-push
git push origin <branch>
```

Both should show all checks running and passing.

### Enforcement

Code reviews will reject any PR that:
- Uses `--no-verify` in commit messages
- Shows evidence of bypassing hooks
- Contains issues that hooks should have caught

### Support

If you encounter hook issues:
1. Check this document first
2. Review hook documentation in `.githooks/README.md`
3. Fix the hook if it's a false positive
4. Ask team for help if needed

**Remember**: Hooks exist to help us maintain quality. If they're failing, there's usually a good reason!

---

**Last Updated**: 2025-12-01  
**Version**: 1.0
