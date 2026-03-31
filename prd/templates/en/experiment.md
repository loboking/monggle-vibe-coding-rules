# Experiment PRD Template

> Template for trying experimental features.

---

## Front Matter

```yaml
---
experiment_id: ""             # Experiment ID (optional)
experiment_name: ""           # Experiment name (e.g., AI-based Code Recommendation)
experiment_type: "experiment" # Type: experiment (fixed)
hypothesis: ""               # Hypothesis (e.g., AI-based code recommendation will improve developer productivity by 20%)
duration: ""                 # Experiment duration (optional)
success_metrics: []          # Success metrics (optional)
assignee: ""                   # Assignee (optional)
estimated_hours: ""            # Estimated work hours (optional)
---
```

---

## Required Sections

### 1. Hypothesis

Clearly state the hypothesis to test.

**Format**: If [condition], then [result] will occur.

**Example:**
```
If "AI-based code recommendations are provided during coding",
then "developer coding speed will improve by 20%".
```

### 2. Test Plan

Describe the experiment plan to verify the hypothesis.

#### Experiment Groups
- **Subjects**: (e.g., 10 developers, 2 weeks)
- **Control Group**: (e.g., Group developing without AI recommendations)

#### Experiment Design
- [Design Element 1]
- [Design Element 2]

#### Data Collection Method
- [Collection Method 1]
- [Collection Method 2]

### 3. Success Criteria

Specify criteria to determine if the hypothesis is proven.

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

### 4. Rollout Criteria

Specify criteria for deciding whether to fully deploy if experiment succeeds.

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

---

## Optional Sections

### 5. Risk Analysis

Describe potential risks and mitigation strategies.

#### Potential Risks
- [Risk 1]: (e.g., Productivity decrease)
- [Risk 2]: (e.g., Technical debt)

#### Mitigation Strategies
- [Mitigation 1]

### 6. Alternative Approaches

Describe alternatives if experiment fails.

- [Alternative 1]
- [Alternative 2]

### 7. Timeline

Plan the experiment timeline.

- **Preparation**: [Duration, Tasks]
- **Experiment**: [Duration, Tasks]
- **Analysis**: [Duration, Tasks]
- **Results Presentation**: [Duration, Tasks]

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
experiment_id: "AI-RECOMMEND-001"
experiment_name: "AI-based Code Recommendation"
experiment_type: "experiment"
hypothesis: "AI-based code recommendations will improve developer productivity by 20%."
duration: "4 weeks"
success_metrics:
  - "Coding speed: lines/hour"
  - "Code quality: bug rate"
  - "Developer satisfaction"
assignee: "research-team"
estimated_hours: "40"
---

# AI-based Code Recommendation Experiment

## Hypothesis

If "AI-based code recommendations are provided during coding",
then "developer coding speed will improve by 20%".

## Test Plan

### Experiment Groups
- **Subjects**: 10 developers
- **Duration**: 2 weeks
- **Control Group**: Group developing without AI recommendations (5 people)

### Experiment Design
- Experiment group has AI recommendation feature enabled in IDE
- Control group uses existing IDE

#### Data Collection Method
- Measure coding time
- Code review feedback
- Survey

## Success Criteria

- [ ] 20% improvement in coding speed (experiment group vs control group)
- [ ] Bug rate equal to or lower than control group
- [ ] Developer satisfaction 4.0/5.0 or higher (experiment group)

## Rollout Criteria

- [ ] All 3 success criteria met
- [ ] Technically stable
- [ ] Operational cost increase within 10%
```
