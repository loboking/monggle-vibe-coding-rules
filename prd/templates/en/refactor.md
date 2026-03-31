# Refactor PRD Template

> Template for code refactoring tasks.

---

## Front Matter

```yaml
---
refactor_id: ""               # Refactor ID (optional)
refactor_name: ""             # Refactor name (e.g., Authentication Module Refactor)
refactor_type: "refactor"     # Type: refactor (fixed)
scope: ""                    # Scope: module, function, architecture
complexity: ""                # Complexity: low, medium, high
priority: ""                  # Priority: P0, P1, P2, P3
assignee: ""                   # Assignee (optional)
estimated_hours: ""            # Estimated work hours (optional)
risk_level: ""                 # Risk level: low, medium, high
---
```

---

## Required Sections

### 1. Current Issues

Describe current code problems.

**Example:**
```
The authentication module has the following issues:
1. Violation of Single Responsibility Principle: UserService handles auth, permissions, and sessions
2. Testing difficulty: All functionality in one class makes testing hard
3. Poor extensibility: Adding new auth methods requires modifying UserService
```

### 2. Proposed Changes

Describe specific refactoring approach.

#### New Structure
- [Structure 1]
- [Structure 2]

#### Expected Benefits
- [Benefit 1]
- [Benefit 2]

#### Files to Modify
- `src/auth/service.py`: [Modification]
- `src/auth/repository.py`: [New]
- `src/auth/schema.py`: [New]

### 3. Impact

Analyze the impact on the system.

#### Compatibility
- **Existing APIs**: (e.g., Maintain existing API interfaces)
- **Database**: (e.g., No schema changes)
- **External Dependencies**: (e.g., Add new libraries)

#### Potential Risks
- [Risk 1]: (e.g., Temporary functional issues during refactoring)
- [Risk 2]: (e.g., Temporary test coverage decrease)

### 4. Testing

Describe the test plan to ensure functional equivalence.

#### Test Strategy
- [Strategy 1]
- [Strategy 2]

#### Functional Equivalence Tests
- [Test Item 1]
- [Test Item 2]

#### Performance Tests
- [Performance Test 1]
- [Performance Test 2]

---

## Optional Sections

### 5. Migration Plan

Describe the plan to safely migrate existing code to the new structure.

- **Phase 1**: [Step 1]
- **Phase 2**: [Step 2]
- **Phase 3**: [Step 3]

### 6. Rollback Plan

Describe the plan to revert to existing code if problems occur.

- (e.g., Use Git branches for rollback)

### 7. Success Criteria

Specify criteria to determine if refactoring is successful.

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

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
refactor_id: "AUTH-REFACTOR-001"
refactor_name: "Authentication Module Refactor"
refactor_type: "refactor"
scope: "module"
complexity: "high"
priority: "P1"
assignee: "john"
estimated_hours: "16"
risk_level: "medium"
---

# Authentication Module Refactor

## Current Issues

The authentication module has the following issues:
1. Violation of Single Responsibility Principle: UserService handles auth, permissions, and sessions
2. Testing difficulty: All functionality in one class makes testing hard
3. Poor extensibility: Adding new auth methods requires modifying UserService

## Proposed Changes

### New Structure
- `AuthService`: Authentication logic (login, logout)
- `PermissionService`: Permission checking
- `SessionService`: Session management
- `UserRepository`: Database access

### Expected Benefits
- Follow Single Responsibility Principle
- Test each service independently
- Add new auth methods by modifying only the relevant Service

### Files to Modify
- `src/auth/service.py`: Split into 3 classes
- `src/auth/repository.py`: Separate DB access logic
- `tests/test_auth.py`: Write tests for each service

## Impact

### Compatibility
- **Existing APIs**: Maintain API interfaces
- **Database**: No schema changes
- **External Dependencies**: None

### Potential Risks
- Temporary functional issues during refactoring
- Temporary test coverage decrease
- Possible Git merge conflicts

## Testing

### Test Strategy
- Pipeline-based incremental refactoring
- Functional equivalence tests for each Phase

### Functional Equivalence Tests
- All existing tests pass
- Add new tests (service separation tests)

### Performance Tests
- Compare before/after refactoring performance
- Target: Performance degradation within 5%
```
