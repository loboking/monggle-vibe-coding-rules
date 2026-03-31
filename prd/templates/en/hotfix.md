# Hotfix PRD Template

> Lightweight PRD template for urgent bug fixes.
> Use `prd/bug.md` for general bug fixes.

---

## Front Matter

```yaml
---
feature_name: ""               # Fix name (e.g., Login Error Emergency Fix)
feature_type: "hotfix"         # Type: hotfix (fixed)
priority: "high"               # Always high
severity: ""                   # Severity: critical | high | medium
issue_url: ""                  # Issue tracker URL (optional)
assignee: ""                   # Assignee
estimated_minutes: ""          # Estimated time (minutes)
tags: ["hotfix", "urgent"]     # Tags
---
```

---

## Required Sections

### 1. Issue

Briefly describe the problem requiring urgent fix.

**Example:**
```
Production environment returns 500 error during user login,
preventing all users from using the service.
```

### 2. Quick Fix

Briefly describe the core fix.

**Example:**
```
Missing null reference check causing exception.
Add None check for user object to prevent exception.
```

**Code Change:**
```python
# Before
def login(email):
    return user.token  # Error if user is None

# After
def login(email):
    if not user:
        raise InvalidCredentialsError()
    return user.token
```

### 3. Testing

Describe quick test method.

- **Before Fix**: (e.g., Login with invalid email → 500 error)
- **After Fix**: (e.g., Login with invalid email → 401 error)

---

## Optional Sections

### 4. Root Cause

Root cause analysis (if needed).

```
Recent refactoring changed user object creation logic,
but login function didn't add Null check.
```

### 5. Prevention

Prevention measures for future recurrence.

```
- Add argument validation at function start
- Add None input case to unit tests
```

---

## Usage Guide

1. Copy this template to the `prd/` folder.
2. Fill in the Front Matter required fields.
3. Quickly write required sections (1-3) (~5 minutes).
4. Run pipeline with `/quick` command.

---

## Usage Scenarios

**Hotfix is appropriate when:**
- Production service outage
- Data loss risk
- Security vulnerability exposure
- Critical impact on user experience

**Hotfix is NOT appropriate when:**
- General bugs (→ use `prd/bug.md`)
- New features (→ use `prd/feature.md`)
- Refactoring (→ use `prd/refactor.md`)

---

## Pipeline Differences

**Normal PRD vs Hotfix:**

| Stage | Normal PRD | Hotfix |
|-------|-----------|--------|
| Gate | Full section validation | Minimal section validation |
| Scan | Full impact analysis | Quick scope check |
| Fold | Feasibility evaluation | **SKIP** (time saving) |
| Verdict | PASS/FIX/FAIL | PASS/FIX/FAIL |
| Patch | Implementation (max 5 iterations) | Implementation (max 2 iterations) |
| Trace | Full log | Core log only |

---

## Example

```yaml
---
feature_name: "Login 500 Error Emergency Fix"
feature_type: "hotfix"
priority: "high"
severity: "critical"
issue_url: "https://github.com/xxx/issues/123"
assignee: "john"
estimated_minutes: "15"
tags: ["hotfix", "urgent", "production"]
---

# Login 500 Error Emergency Fix

## Issue

Production environment returns 500 Internal Server Error
when attempting login with invalid email.
All users are currently affected.

## Quick Fix

`login()` function missing handling for when `user` object is None.

**Location:** `app/auth.py:45`

**Before:**
```python
def login(email: str, password: str) -> str:
    user = db.get_user(email)
    return user.token  # None → 500 Error
```

**After:**
```python
def login(email: str, password: str) -> str:
    user = db.get_user(email)
    if not user:
        raise InvalidCredentialsError("Invalid email or password")
    return user.token
```

**Estimated Time:** 15 minutes
- Code fix: 5 minutes
- Testing: 5 minutes
- Deployment: 5 minutes

## Testing

### Pre-Test
```bash
# Login with invalid email
curl -X POST /api/login -d '{"email": "invalid@test.com", "password": "wrong"}'
# Expected: 500 Internal Server Error (current)
```

### Post-Test
```bash
# Same request
curl -X POST /api/login -d '{"email": "invalid@test.com", "password": "wrong"}'
# Expected: 401 Unauthorized, {"error": "Invalid email or password"}
```

### Additional Tests
- Valid email/password: Normal login (200 OK)
- Empty email: 400 Bad Request
- SQL Injection attempt: 400 Bad Request
```

---

## Notes

1. **Hotfix is for emergency situations only**
2. **Make minimal changes only**
3. **Testing is mandatory** (to avoid creating serious bugs)
4. **Formal PRD recommended after hotfix** (root cause analysis and prevention)
5. **Code review can be bypassed** (emergency situation)
6. **Post-deployment monitoring is mandatory**
