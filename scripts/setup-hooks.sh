#!/bin/bash
# Setup script for Git hooks with high code quality standards
# This script configures Git hooks and installs required tools

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Git Hooks Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}✗ Not a git repository${NC}"
    echo "Run this script from the root of your git repository"
    exit 1
fi

echo -e "${GREEN}✓ Git repository detected${NC}"
echo ""

# Step 1: Configure Git to use .githooks
echo "📁 Configuring Git hooks path..."
git config core.hooksPath .githooks
echo -e "${GREEN}✓ Configured Git to use .githooks directory${NC}"

# Step 2: Make hooks executable
echo ""
echo "🔧 Making hooks executable..."
if [ -d ".githooks" ]; then
    chmod +x .githooks/* 2>/dev/null || true
    echo -e "${GREEN}✓ Made hooks executable${NC}"
    
    # List installed hooks
    echo ""
    echo "Installed hooks:"
    for hook in .githooks/*; do
        if [ -f "$hook" ] && [ -x "$hook" ]; then
            HOOK_NAME=$(basename "$hook")
            echo "  • $HOOK_NAME"
        fi
    done
else
    echo -e "${RED}✗ .githooks directory not found${NC}"
    exit 1
fi

# Step 3: Check Python installation
echo ""
echo "🐍 Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ Python installed: $PYTHON_VERSION${NC}"
else
    echo -e "${RED}✗ Python 3 not found${NC}"
    echo "Install Python 3: https://www.python.org/downloads/"
    exit 1
fi

# Step 4: Install Python tools
echo ""
echo "📦 Installing Python quality tools..."
TOOLS="mypy pylint bandit coverage pytest"

for tool in $TOOLS; do
    if python3 -m pip show "$tool" &> /dev/null; then
        VERSION=$(python3 -m pip show "$tool" | grep Version | awk '{print $2}')
        echo -e "${GREEN}✓ $tool ($VERSION) already installed${NC}"
    else
        echo "  Installing $tool..."
        if python3 -m pip install --quiet "$tool" 2>/dev/null; then
            echo -e "${GREEN}✓ $tool installed${NC}"
        else
            echo -e "${YELLOW}⚠ Failed to install $tool${NC}"
            echo "  Try: pip3 install --user $tool"
        fi
    fi
done

# Step 5: Check for shellcheck
echo ""
echo "🐚 Checking for shellcheck..."
if command -v shellcheck &> /dev/null; then
    SHELLCHECK_VERSION=$(shellcheck --version | head -2 | tail -1)
    echo -e "${GREEN}✓ shellcheck installed: $SHELLCHECK_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ shellcheck not found${NC}"
    echo "  Ubuntu/Debian: sudo apt-get install shellcheck"
    echo "  macOS: brew install shellcheck"
    echo "  Optional but recommended for shell script validation"
fi

# Step 6: Check for markdownlint
echo ""
echo "📝 Checking for markdownlint..."
if command -v markdownlint &> /dev/null; then
    echo -e "${GREEN}✓ markdownlint installed${NC}"
else
    echo -e "${YELLOW}⚠ markdownlint not found${NC}"
    echo "  Install: npm install -g markdownlint-cli"
    echo "  Optional but recommended for markdown validation"
fi

# Step 7: Test hook installation
echo ""
echo "🧪 Testing hook installation..."

# Test if hooks are accessible
if [ -x ".githooks/pre-commit" ]; then
    echo -e "${GREEN}✓ pre-commit hook is executable${NC}"
else
    echo -e "${RED}✗ pre-commit hook is not executable${NC}"
    chmod +x .githooks/pre-commit
fi

if [ -x ".githooks/commit-msg" ]; then
    echo -e "${GREEN}✓ commit-msg hook is executable${NC}"
else
    echo -e "${RED}✗ commit-msg hook is not executable${NC}"
    chmod +x .githooks/commit-msg
fi

if [ -x ".githooks/pre-push" ]; then
    echo -e "${GREEN}✓ pre-push hook is executable${NC}"
else
    echo -e "${RED}✗ pre-push hook is not executable${NC}"
    chmod +x .githooks/pre-push
fi

if [ -x ".githooks/post-push" ]; then
    echo -e "${GREEN}✓ post-push hook is executable${NC}"
else
    echo -e "${RED}✗ post-push hook is not executable${NC}"
    chmod +x .githooks/post-push
fi

# Step 8: Create .gitignore entries for hook-related files
echo ""
echo "📋 Updating .gitignore..."
if ! grep -q "\.pytest_cache" .gitignore 2>/dev/null; then
    echo "# Python testing" >> .gitignore
    echo ".pytest_cache/" >> .gitignore
    echo ".coverage" >> .gitignore
    echo "htmlcov/" >> .gitignore
    echo -e "${GREEN}✓ Added pytest entries to .gitignore${NC}"
fi

if ! grep -q "\.mypy_cache" .gitignore 2>/dev/null; then
    echo "# Python type checking" >> .gitignore
    echo ".mypy_cache/" >> .gitignore
    echo -e "${GREEN}✓ Added mypy entries to .gitignore${NC}"
fi

# Step 9: Summary
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}✅ Git Hooks Setup Complete!${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

echo "Hook Configuration:"
echo "  • pre-commit: Code quality checks before commit"
echo "  • commit-msg: Commit message validation"
echo "  • pre-push: Comprehensive checks before push"
echo "  • post-push: Notifications and recommendations"
echo ""

echo "Installed Tools:"
python3 -m pip list | grep -E "(mypy|pylint|bandit|coverage|pytest)" || echo "  (Check installation above)"
echo ""

echo "Next Steps:"
echo "  1. Read .githooks/README.md for detailed documentation"
echo "  2. Make a test commit to verify hooks work:"
echo "     git commit --allow-empty -m 'test(hooks): verify hook setup'"
echo "  3. Customize hook behavior by editing files in .githooks/"
echo ""

echo -e "${YELLOW}Important:${NC}"
echo "  • Hooks run automatically on commit/push"
echo "  • To bypass (not recommended): git commit --no-verify"
echo "  • Report issues or suggest improvements"
echo ""

echo -e "${GREEN}Happy coding with quality assurance! 🚀${NC}"
