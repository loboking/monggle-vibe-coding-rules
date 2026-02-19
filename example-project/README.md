# To-Do List Application

A simple, elegant To-Do List web application built with vanilla JavaScript.

## Features

- Create, Read, Update, Delete (CRUD) operations for tasks
- Task completion tracking
- Filter by All/Active/Completed
- Bulk delete completed tasks
- LocalStorage persistence
- Responsive design (mobile-friendly)
- Cross-browser support (Chrome, Firefox, Safari)

## Tech Stack

- HTML5
- CSS3
- Vanilla JavaScript (ES6+)
- LocalStorage API

## Quick Start

1. Open `index.html` in a web browser
2. Add a task and optionally add a description
3. Click the checkbox to mark tasks as completed
4. Use filters to view specific task types
5. Edit or delete individual tasks

## Project Structure

```
example-project/
├── index.html          # Main HTML structure
├── style.css           # Styling and responsive design
├── app.js              # Application logic
├── prd/                # PRD documents
│   └── todo-feature.md # Feature PRD
└── README.md           # This file
```

## Vibe Coding Rules Integration

This project demonstrates the Vibe Coding Rules workflow:

1. **PRD First**: `prd/todo-feature.md` defines all requirements
2. **AI Validation**: PRD includes required sections (Goal, Requirements, Edge Cases, Testing)
3. **Clean Implementation**: Code follows best practices
4. **Testable**: Each feature can be tested independently

## Testing

### Manual Testing

1. **Create Task**:
   - Enter title (required) and description (optional)
   - Click "Add" or press Enter
   - Verify task appears in list

2. **Complete Task**:
   - Click checkbox to toggle completion
   - Verify strikethrough style applied

3. **Edit Task**:
   - Click "Edit" button on a task
   - Modify title/description in modal
   - Click "Save" to update

4. **Delete Task**:
   - Click "Delete" button on a task
   - Confirm deletion in dialog

5. **Filter Tasks**:
   - Click "All", "Active", "Completed" buttons
   - Verify only matching tasks shown

6. **Persistence**:
   - Add some tasks
   - Refresh page
   - Verify tasks still present (LocalStorage)

## Browser Compatibility

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## License

MIT
