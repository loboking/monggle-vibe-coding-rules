---
feature_name: "Button Click Crash Fix"
feature_type: "hotfix"
priority: "high"
severity: "critical"
assignee: ""
estimated_minutes: "10"
tags: ["hotfix", "urgent", "production"]
---

# Button Click Crash Fix

## Issue

Users report that clicking the "Add Task" button causes the app to crash
with "Uncaught TypeError: Cannot read property 'value' of null".

## Quick Fix

**Root Cause:** Event listener missing null check for input element.

**Location:** `app.js:45`

**Before:**
```javascript
function addTask() {
    const input = document.getElementById('newTask');
    const task = input.value;  // Crashes if input is null
    // ...
}
```

**After:**
```javascript
function addTask() {
    const input = document.getElementById('newTask');
    if (!input) return;  // Guard clause

    const task = input.value;
    // ...
}
```

## Testing

### Reproduce Bug
1. Open app
2. Click "Add Task" button (without typing anything)
3. Expected: Should handle empty input gracefully
4. Actual: App crashes

### Verify Fix
1. Apply fix
2. Click "Add Task" button (without typing anything)
3. Expected: Shows "Please enter a task" message
4. Actual: Works correctly
