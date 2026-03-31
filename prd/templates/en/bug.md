# Bug PRD Template

> Template for bug fix tasks.

---

## Front Matter

```yaml
---
bug_id: ""                    # Bug ID (optional)
bug_name: ""                 # Bug name (e.g., Login 500 Error)
bug_type: ""                 # Type: bugfix (fixed)
severity: ""                  # Severity: critical, high, medium, low
priority: ""                  # Priority: P0, P1, P2, P3
affected_version: ""           # Affected version (optional)
environment: ""                # Environment (optional)
reporter: ""                   # Reporter (optional)
assignee: ""                   # Assignee (optional)
estimated_hours: ""            # Estimated work hours (optional)
---
```

---

## Required Sections

### 1. Issue Description

Describe the problem in detail.

**Example:**
```
When users click the login button,
HTTP 500 Internal Server Error occurs and login fails.
The error log shows "AttributeError: 'NoneType' object has no attribute 'user'".
```

### 2. Root Cause

Analyze the root cause of the problem.

**Example:**
```
User model has users with NULL email field in the database.
Login logic references `user.email` causing NoneType error.
Cause: Email validation logic was missing during signup, allowing NULL values.
```

### 3. Fix Plan

Describe the specific fix approach.

#### Solution
- [Solution 1]
- [Solution 2]

#### Files to Modify
- `src/auth/login.py`: [Modification]
- `src/models/user.py`: [Modification]
- `tests/test_auth.py`: [Test addition]

### 4. Testing

Describe the test plan to prevent recurrence.

#### Regression Prevention Tests
- [Test Item 1]
- [Test Item 2]

#### Regression Tests
- [Existing Feature Test 1]
- [Existing Feature Test 2]

---

## Optional Sections

### 5. Impact Analysis

Analyze the impact on other system parts.

- **Affected Modules**: (e.g., Authentication module, Session management)
- **Data Changes**: (e.g., User data migration needed)
- **API Changes**: (e.g., Login API response change)

### 6. Temporary Workaround

Describe any temporary workaround before permanent fix.

- (e.g., Add error logging and manually fix NULL emails)

### 7. Prevention

Describe prevention measures to avoid recurrence.

- [Prevention 1]
- [Prevention 2]

---

## Usage Guide

1. Copy this template to the `prd/` folder.
2. Fill in the Front Matter required fields.
3. Write the required sections (1-4).
4. Write optional sections (5-7) as needed.
5. Save the file and run the Agent pipeline.

---

## Example

```yaml
---
bug_id: "AUTH-500"
bug_name: "Login 500 Error"
bug_type: "bugfix"
severity: "high"
priority: "P1"
affected_version: "v1.2.0"
environment: "production"
reporter: "jane"
assignee: "john"
estimated_hours: "4"
---

# Login 500 Error

## Issue Description

When users click the login button,
HTTP 500 Internal Server Error occurs and login fails.
The error log shows "AttributeError: 'NoneType' object has no attribute 'user'".

## Root Cause

User model has users with NULL email field in the database.
Login logic references `user.email` causing NoneType error.
Cause: Email validation logic was missing during signup, allowing NULL values.

## Fix Plan

### Solution
1. Add email validation logic during signup
2. Write script to remove users with NULL emails from database
3. Add NULL check in login logic

### Files to Modify
- `src/auth/register.py`: Add email duplicate check logic
- `scripts/clean_null_users.py`: NULL email user cleanup script
- `src/auth/login.py`: Add NULL check
- `tests/test_auth.py`: Add test for NULL user login attempt

## Testing

### Regression Prevention Tests
- Signup attempt with NULL email
- Signup attempt with duplicate email

### Regression Tests
- Login with valid email
- Social login
```
