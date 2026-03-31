# Feature PRD Template

> Template for developing new features.

---

## Front Matter

```yaml
---
feature_name: ""               # Feature name (e.g., User Authentication)
feature_type: "feature"        # Type: feature (fixed)
priority: ""                  # Priority: high, medium, low
points: []                    # Related story points (optional)
dependencies: []              # Dependency task IDs (optional)
assignee: ""                   # Assignee (optional)
estimated_hours: ""            # Estimated work hours (optional)
tags: []                      # Tags (optional)
---
```

---

## Required Sections

### 1. Goal

Describe the problem to solve and the goal to achieve.

**Example:**
```
Enable users to securely create accounts via email and social login,
and use the service with JWT token-based authentication.
```

### 2. Requirements

List functional and non-functional requirements.

#### Functional Requirements
- [Requirement 1]
- [Requirement 2]
- [Requirement 3]

#### Non-Functional Requirements
- Performance: (e.g., Login response time < 200ms)
- Security: (e.g., Passwords must be hashed)
- Compatibility: (e.g., Support Chrome, Firefox, Safari)

### 3. Tech Stack

Specify the technology stack to use.

**Frameworks/Libraries:**
- (e.g., Python 3.11, FastAPI, PostgreSQL)

**Core Dependencies:**
- (e.g., pyjwt, bcrypt, sqlalchemy)

### 4. Edge Cases

Describe expected exceptions and handling.

- **Edge Case 1**: (e.g., Duplicate email signup)
  - **Handling**: (e.g., Return "Email already exists" message)

- **Edge Case 2**: (e.g., Network error)
  - **Handling**: (e.g., Retry mechanism, up to 3 attempts)

### 5. Testing

Describe the test strategy.

#### Unit Tests
- [Test Item 1]
- [Test Item 2]

#### Integration Tests
- [Test Scenario 1]
- [Test Scenario 2]

#### E2E Tests
- [User Flow 1]
- [User Flow 2]

---

## Optional Sections

### 6. Implementation Plan

Describe the step-by-step implementation plan.

- **Phase 1**: [Step 1]
- **Phase 2**: [Step 2]
- **Phase 3**: [Step 3]

### 7. Rollback Plan

Describe the rollback strategy if problems occur.

- (e.g., Keep existing session method, new method as optional)

### 8. Success Criteria

Specify criteria to determine if the feature is successfully implemented.

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

---

## Usage Guide

1. Copy this template to the `prd/` folder.
2. Fill in the Front Matter required fields.
3. Write the required sections (1-5).
4. Write optional sections (6-8) as needed.
5. Save the file and run the Agent pipeline.

---

## Example

```yaml
---
feature_name: "User Authentication"
feature_type: "feature"
priority: "high"
points: [AUTH-1, AUTH-2]
dependencies: []
assignee: "john"
estimated_hours: "8"
tags: ["authentication", "security"]
---

# User Authentication

## Goal

Enable users to securely create accounts via email and social login,
and use the service with JWT token-based authentication.

## Requirements

### Functional Requirements
- Email signup
- Social login (Google, GitHub)
- JWT token issuance and renewal
- Logout
- Password reset

### Non-Functional Requirements
- Performance: Login response time < 200ms
- Security: Password bcrypt hashing
- Security: JWT token expiration 1 hour

## Tech Stack

**Frameworks/Libraries:**
- Python 3.11
- FastAPI
- PostgreSQL

**Core Dependencies:**
- pyjwt
- bcrypt
- sqlalchemy
- python-multipart

## Edge Cases

- **Duplicate email signup**: Return "Email already exists" message
- **Social login failure**: Error message with retry prompt

## Testing

### Unit Tests
- Email duplicate check
- Password hashing verification
- JWT token issuance and verification

### Integration Tests
- Full login flow
- Social login callback

### E2E Tests
- User signup → login → logout scenario
```
