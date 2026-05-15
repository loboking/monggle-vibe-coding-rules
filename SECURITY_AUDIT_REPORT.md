# Vibe Coding Rules - Security Audit Report

> **Audit Date:** 2026-05-14
> **Auditor:** Agent Judge (Claude Opus)
> **Project:** monggle-vibe-coding-rules
> **Scope:** Shell scripts, hooks, installers, secrets management

---

## Executive Summary

| Category | Status | Severity |
|----------|--------|----------|
| **Overall** | ⚠️ Needs Improvement | Medium |
| Command Injection | ⚠️ Issues Found | Medium |
| Hardcoded Secrets | ✅ Clear | None |
| Input Validation | ⚠️ Partial | Medium |
| File Permissions | ✅ Good | Low |
| Git Security | ✅ Good | Low |
| External Dependencies | ⚠️ Monitor | Low |

---

## 1. Command Injection Vulnerabilities

### 🔴 Medium Risk: Unvalidated User Input in Paths

**Location:** `install.sh:1035-1036`

```bash
if [ -n "$TARGET_DIR" ]; then
    PROJECT_ROOT="$(cd "$TARGET_DIR" && pwd)"
fi
```

**Issue:** `TARGET_DIR` comes from user input (command line argument) without validation. An attacker could provide a path containing malicious characters.

**Exploit Scenario:**
```bash
./install.sh "; rm -rf /; #"
./install.sh "../malicious-project"
```

**Recommendation:**
```bash
# Add path validation before use
if [ -n "$TARGET_DIR" ]; then
    # Resolve to absolute path
    TARGET_DIR="$(realpath "$TARGET_DIR" 2>/dev/null || echo "$TARGET_DIR")"
    
    # Check path exists and is directory
    if [ ! -d "$TARGET_DIR" ]; then
        print_error "Directory not found: $TARGET_DIR"
        exit 1
    fi
    
    # Check for suspicious characters
    if [[ "$TARGET_DIR" =~ [\;\&\|\<\>\$\(\)] ]]; then
        print_error "Invalid characters in path"
        exit 1
    fi
    
    PROJECT_ROOT="$(cd "$TARGET_DIR" && pwd)"
fi
```

---

### 🟡 Low Risk: Git Remote URL in Regex

**Location:** `install.sh:587-591`

```bash
if [[ "$GIT_REMOTE_URL" =~ github\.com ]]; then
    GIT_PLATFORM="github"
elif [[ "$GIT_REMOTE_URL" =~ gitlab\.com ]]; then
    GIT_PLATFORM="gitlab"
fi
```

**Issue:** While using `=~` for regex matching is safe, the URL is later used in file operations.

**Current Status:** ✅ Acceptable - URL is only used for pattern matching, not execution.

**Recommendation:** Add URL validation:
```bash
# Sanitize URL before use
GIT_REMOTE_URL=$(echo "$GIT_REMOTE_URL" | sed 's/[^a-zA-Z0-9\:\/\.\-_@]//g')
```

---

### 🟡 Low Risk: Variable Expansion in File Names

**Location:** `fix-skills.sh:74, 112`

```bash
local skill_dir="$SKILLS_DIR/$skill_name"
for script in "$COMMANDS_DIR"/*.sh; do
    skill_name=$(basename "$script" .sh)
```

**Issue:** `skill_name` is derived from file names without validation before being used in paths.

**Recommendation:** Add sanitization:
```bash
# Sanitize skill names
clean_name=$(echo "$skill_name" | sed 's/[^a-zA-Z0-9_-]//g')
if [ -z "$clean_name" ]; then
    log_error "Invalid skill name: $skill_name"
    continue
fi
```

---

## 2. Hardcoded Secrets

### ✅ Pass: No Hardcoded Credentials

**Finding:** No hardcoded API keys, passwords, or tokens found in source code.

**Verification:**
```bash
grep -ri "api_key\|password\|secret\|token" --include="*.sh" . | \
  grep -v "GEMINI_API_KEY\|OPENAI_API_KEY" | \
  grep -v "# " | \
  grep -v "env:"
# Result: No hardcoded secrets found
```

### ✅ Pass: API Key Storage (setup-gemini.sh)

**Location:** `.claude/commands/setup-gemini.sh:156-161`

```bash
mkdir -p "$GEMINI_CONFIG_DIR"
echo "$api_key" > "$GEMINI_CONFIG_FILE"
chmod 600 "$GEMINI_CONFIG_FILE"
```

**Status:** ✅ Proper implementation
- File permission set to 600 (owner read/write only)
- Directory created securely
- .gitignore updated to exclude `.gemini/`

---

## 3. Input Validation

### 🟡 Medium Risk: Interactive User Input

**Location:** `install.sh:989, 1024`

```bash
read -p "Enter choice [1-3] (default: 1): " lang_choice
read -p "Enter mode [1-3] (default: 1): " mode_choice
```

**Issue:** User input is used in `case` statements without range validation.

**Current Mitigation:** ✅ `case` statement provides default fallback, preventing invalid values.

**Recommendation:** Add explicit validation:
```bash
# Validate choice is 1-3
if [[ ! "$mode_choice" =~ ^[1-3]$ ]]; then
    mode_choice="1"  # Default
fi
```

---

### 🔴 Medium Risk: Heredoc with Variables

**Location:** `install.sh:244-250, 632-708`

```bash
cat > "$skill_dir/skill.json" << SKILL_EOF
{
  "name": "$skill_name",
  "description": "$description",
  "version": "1.0.0"
}
SKILL_EOF
```

**Issue:** Variables in heredocs are not escaped, allowing potential injection if variables contain malicious content.

**Exploit Scenario:**
```bash
skill_name='test","description":"malicious'
```

**Recommendation:** Use `jq` for JSON generation:
```bash
# Safe JSON generation
jq -n \
  --arg name "$skill_name" \
  --arg desc "$description" \
  '{name: $name, description: $desc, version: "1.0.0"}' > "$skill_dir/skill.json"
```

---

## 4. File Permission Issues

### ✅ Pass: Appropriate Permissions

**Finding:** All executable scripts use `chmod +x` or `chmod 600` (for secrets).

**Verification:**
```bash
# All permissions are appropriate
chmod +x          # For executables (✓)
chmod 600         # For secrets (✓)
# No 777 or overly permissive modes found
```

### 🟡 Low Risk: Silent Permission Failures

**Location:** `install.sh:480-505`

```bash
chmod +x "$SCRIPT_DIR/.claude/commands/gate.sh" 2>/dev/null || true
```

**Issue:** Permission errors are silently ignored, potentially hiding security issues.

**Recommendation:** Log warnings:
```bash
if ! chmod +x "$file" 2>/dev/null; then
    print_warning "Could not set executable permission: $file"
fi
```

---

## 5. External Dependency Security

### 🟡 Low Risk: Unvalidated Package Installations

**Location:** `install.sh:87-133` (ensure_jq function)

```bash
case "$OS_TYPE" in
    macos)
        if command -v brew &> /dev/null; then
            brew install jq
        ;;
    linux)
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
```

**Issue:** Package installations without checksum verification or version pinning.

**Recommendation:**
1. Add version pinning: `brew install jq@1.7`
2. Verify checksums after installation
3. Document required versions

---

### 🟡 Info: Python Dependencies

**Location:** `install.sh:741-746`

```bash
if command -v pip3 &> /dev/null; then
    pip3 install pyyaml openai >/dev/null 2>&1 || \
      print_warning "Failed to install dependencies"
```

**Issue:** Dependencies installed without version constraints or virtual environment.

**Recommendation:**
```bash
# Use requirements.txt with pinned versions
pip3 install -r .claude/requirements.txt --target .claude/vendor
```

**Suggested `.claude/requirements.txt`:**
```
pyyaml==6.0.1
openai==1.12.0
```

---

## 6. Git Security (.gitignore)

### ✅ Pass: Comprehensive .gitignore

**Current .gitignore:**
```gitignore
# Vibe Coding Rules
logs/*.log

# Override global .gitignore
!.claude/commands/
!.claude/hooks/
!.claude/lib/
!.claude/config/

# Python
__pycache__/
*.pyc
*.pyo
.gstack/
```

### ✅ Pass: .gemini Excluded

**Location:** `.claude/commands/setup-gemini.sh:185-196`

```bash
update_gitignore() {
    if ! grep -q "^\.gemini$" "$gitignore"; then
        echo ".gemini" >> "$gitignore"
    fi
}
```

**Status:** ✅ API key storage automatically excluded from git.

---

### 🟡 Medium: Missing Security Exclusions

**Issue:** `.gitignore` is missing common security-sensitive patterns:

**Recommended Additions:**
```gitignore
# Security - Secrets
.env
.env.*
*.key
*.pem
secrets/
.claude/config/team.yaml  # May contain sensitive config

# Security - Build artifacts
node_modules/
vendor/
*.log

# Claude specific
.claude/.upgrade/
.claude/session/
.claude/cache/
```

---

## 7. Shell Script Security Best Practices

### ✅ Pass: Safe Mode Flags

**Finding:** Most scripts use safe mode:
```bash
set -euo pipefail  # ✓ Good
set -e            # ✓ Acceptable
```

### 🟡 Low: Missing Quotes

**Issue:** Some variables used without quotes:

**Examples:**
- `install.sh:28`: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` ✅
- `fix-skills.sh:112`: `for script in "$COMMANDS_DIR"/*.sh` ✅
- Most variables are properly quoted ✅

**Status:** ✅ Good - Variables are consistently quoted.

---

### 🔴 Medium: eval Usage Detected

**Files using eval:**
- `.claude/lib/loop_detection.sh`
- `.claude/lib/git.sh`
- `.claude/brain/brain-core.sh`
- Multiple command scripts

**Risk:** `eval` can execute arbitrary code if input is not sanitized.

**Recommendation:** Audit each `eval` usage:
1. Replace with `${!var}` for indirect expansion
2. Use `declare` or `export` instead
3. Add input sanitization before eval

---

## 8. Recommendations Summary

### Critical (🔴 Fix Immediately)

| # | Issue | File | Fix |
|---|-------|------|-----|
| 1 | Unvalidated path from user input | `install.sh:1035` | Add path validation |
| 2 | Heredoc injection risk | `install.sh:244` | Use `jq` for JSON |
| 3 | `eval` usage | Multiple files | Audit and replace |

### High Priority (🟠 Fix Soon)

| # | Issue | File | Fix |
|---|-------|------|-----|
| 1 | Add version pinning | `install.sh:87` | Pin package versions |
| 2 | Input range validation | `install.sh:989` | Add numeric validation |
| 3 | Skill name sanitization | `fix-skills.sh:74` | Add name validation |

### Medium Priority (🟡 Consider)

| # | Issue | File | Fix |
|---|-------|------|-----|
| 1 | Enhanced .gitignore | `.gitignore` | Add security exclusions |
| 2 | Permission error logging | `install.sh:480` | Log chmod failures |
| 3 | Virtual env for pip | `install.sh:741` | Use requirements.txt |

---

## 9. Security Checklist

- [x] No hardcoded secrets
- [x] Proper file permissions (600 for secrets, +x for scripts)
- [x] .gitignore excludes sensitive files
- [x] Safe mode flags (`set -euo pipefail`)
- [ ] Input validation on all user input
- [ ] Path traversal protection
- [ ] Version-pinned dependencies
- [ ] `eval` usage audit needed
- [ ] Comprehensive .gitignore for security files

---

## 10. Conclusion

The Vibe Coding Rules project demonstrates **good security practices** overall, with proper secret handling, file permissions, and git security. However, there are **medium-risk vulnerabilities** related to input validation and command injection that should be addressed.

**Priority Actions:**
1. Add path validation to `install.sh`
2. Replace heredoc JSON generation with `jq`
3. Audit and minimize `eval` usage
4. Pin dependency versions

**Overall Security Rating:** 🟡 **B+ (Good with Improvements Needed)**

---

**Report Generated:** 2026-05-14
**Auditor:** Agent Judge (Claude Opus)
**Next Review:** After implementing critical fixes
