# Development Dependencies for LLM Gateway Configuration Deployment

## Testing Framework

### Bats (Bash Automated Testing System)

**Installation**:

```bash
# Ubuntu/Debian
sudo apt-get install bats

# macOS with Homebrew
brew install bats-core

# From source (recommended for latest version)
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local

# Verify installation
bats --version
```

**Bats Helper Libraries** (optional but recommended):

```bash
# bats-support: Supporting library with common functions
git clone https://github.com/bats-core/bats-support.git tests/test_helper/bats-support

# bats-assert: Assertion library for better test readability
git clone https://github.com/bats-core/bats-assert.git tests/test_helper/bats-assert

# bats-file: File system assertions
git clone https://github.com/bats-core/bats-file.git tests/test_helper/bats-file
```

**Usage**:

```bash
# Run all tests
bats tests/deploy/

# Run specific test file
bats tests/deploy/test-deploy-basic.bats

# Run with TAP output
bats --tap tests/deploy/

# Run with timing
bats --timing tests/deploy/
```

## Linting Tools

### ShellCheck

**Installation**:

```bash
# Ubuntu/Debian
sudo apt-get install shellcheck

# macOS with Homebrew
brew install shellcheck

# From binary (latest)
scversion="stable"
wget -qO- "https://github.com/koalaman/shellcheck/releases/download/${scversion}/shellcheck-${scversion}.linux.x86_64.tar.xz" | tar -xJv
sudo cp "shellcheck-${scversion}/shellcheck" /usr/local/bin/
shellcheck --version
```

**Usage**:

```bash
# Check all bash scripts
find scripts/ -name "*.sh" -exec shellcheck {} +

# Check with configuration file
shellcheck scripts/deploy-gateway-config.sh

# Fix auto-fixable issues (with shellcheck >= 0.8.0)
shellcheck -f diff scripts/deploy-gateway-config.sh | git apply
```

## Python Tools (for validation scripts)

```bash
# Python 3.7+ required
python3 --version

# Install validation dependencies
pip3 install pyyaml jsonschema
```

## Development Environment Setup

```bash
# Clone repository
cd ~/claude-code

# Install all dependencies (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y bats shellcheck python3 python3-pip
pip3 install pyyaml jsonschema

# Verify installations
bats --version
shellcheck --version
python3 --version
```

## CI/CD Integration

### GitHub Actions

Add to `.github/workflows/test-deployment.yml`:

```yaml
name: Test Deployment Scripts

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y bats shellcheck python3-pip
          pip3 install pyyaml jsonschema
      
      - name: Run ShellCheck
        run: |
          find scripts/ -name "*.sh" -exec shellcheck {} +
      
      - name: Run Bats tests
        run: |
          bats tests/deploy/
```

## Test Coverage Tools

```bash
# bashcov (requires Ruby)
gem install bashcov

# Run with coverage
bashcov bats tests/deploy/
```

---

**Note**: This file documents development dependencies. For production deployment, only `bash` and `python3` are required.
