/**
 * To-Do List Application
 * Simple CRUD application with LocalStorage persistence
 */

class TodoApp {
    constructor() {
        this.todos = this.loadTodos();
        this.currentFilter = 'all';
        this.editingId = null;
        this.init();
    }

    init() {
        this.cacheElements();
        this.bindEvents();
        this.render();
    }

    cacheElements() {
        this.todoInput = document.getElementById('todoInput');
        this.todoDesc = document.getElementById('todoDesc');
        this.addBtn = document.getElementById('addBtn');
        this.todoList = document.getElementById('todoList');
        this.emptyMessage = document.getElementById('emptyMessage');
        this.filterBtns = document.querySelectorAll('.filter-btn');
        this.clearCompletedBtn = document.getElementById('clearCompleted');

        // Edit modal elements
        this.modal = document.querySelector('.modal');
        this.modalTitle = document.querySelector('.modal-content h2');
        this.modalInput = document.querySelector('.modal-content input');
        this.modalDesc = document.querySelector('.modal-content textarea');
        this.saveBtn = document.querySelector('.save-btn');
        this.cancelBtn = document.querySelector('.cancel-btn');
    }

    bindEvents() {
        this.addBtn.addEventListener('click', () => this.addTodo());
        this.todoInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.addTodo();
        });

        this.filterBtns.forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.currentFilter = e.target.dataset.filter;
                this.updateFilterButtons();
                this.render();
            });
        });

        this.clearCompletedBtn.addEventListener('click', () => this.clearCompleted());

        // Modal events
        this.cancelBtn.addEventListener('click', () => this.closeModal());
        this.saveBtn.addEventListener('click', () => this.saveEdit());
    }

    loadTodos() {
        try {
            const stored = localStorage.getItem('todos');
            return stored ? JSON.parse(stored) : [];
        } catch (e) {
            console.error('Failed to load todos:', e);
            return [];
        }
    }

    saveTodos() {
        try {
            localStorage.setItem('todos', JSON.stringify(this.todos));
            return true;
        } catch (e) {
            console.error('Failed to save todos:', e);
            alert('저장 공간이 부족합니다.');
            return false;
        }
    }

    generateId() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    }

    addTodo() {
        const title = this.todoInput.value.trim();
        const description = this.todoDesc.value.trim();

        if (!title) {
            alert('제목을 입력해주세요.');
            this.todoInput.focus();
            return;
        }

        const todo = {
            id: this.generateId(),
            title: title.substring(0, 100),
            description: description.substring(0, 500),
            completed: false,
            createdAt: new Date().toISOString()
        };

        this.todos.unshift(todo);

        if (this.saveTodos()) {
            this.todoInput.value = '';
            this.todoDesc.value = '';
            this.render();
        }
    }

    toggleTodo(id) {
        const todo = this.todos.find(t => t.id === id);
        if (todo) {
            todo.completed = !todo.completed;
            this.saveTodos();
            this.render();
        }
    }

    deleteTodo(id) {
        if (confirm('이 할 일을 삭제하시겠습니까?')) {
            this.todos = this.todos.filter(t => t.id !== id);
            this.saveTodos();
            this.render();
        }
    }

    editTodo(id) {
        const todo = this.todos.find(t => t.id === id);
        if (todo) {
            this.editingId = id;
            this.modalInput.value = todo.title;
            this.modalDesc.value = todo.description;
            this.modal.classList.add('active');
        }
    }

    saveEdit() {
        if (!this.editingId) return;

        const title = this.modalInput.value.trim();
        const description = this.modalDesc.value.trim();

        if (!title) {
            alert('제목을 입력해주세요.');
            return;
        }

        const todo = this.todos.find(t => t.id === this.editingId);
        if (todo) {
            todo.title = title.substring(0, 100);
            todo.description = description.substring(0, 500);
            this.saveTodos();
            this.render();
        }

        this.closeModal();
    }

    closeModal() {
        this.modal.classList.remove('active');
        this.editingId = null;
    }

    clearCompleted() {
        const completedCount = this.todos.filter(t => t.completed).length;

        if (completedCount === 0) {
            alert('완료된 할 일이 없습니다.');
            return;
        }

        if (confirm(`완료된 항목 ${completedCount}개를 삭제하시겠습니까?`)) {
            this.todos = this.todos.filter(t => !t.completed);
            this.saveTodos();
            this.render();
        }
    }

    updateFilterButtons() {
        this.filterBtns.forEach(btn => {
            btn.classList.toggle('active', btn.dataset.filter === this.currentFilter);
        });
    }

    getFilteredTodos() {
        switch (this.currentFilter) {
            case 'active':
                return this.todos.filter(t => !t.completed);
            case 'completed':
                return this.todos.filter(t => t.completed);
            default:
                return this.todos;
        }
    }

    render() {
        const filtered = this.getFilteredTodos();

        // Clear list
        this.todoList.innerHTML = '';

        // Show/hide empty message
        this.emptyMessage.classList.toggle('show', filtered.length === 0);

        // Render todos
        filtered.forEach(todo => {
            const li = this.createTodoElement(todo);
            this.todoList.appendChild(li);
        });
    }

    createTodoElement(todo) {
        const li = document.createElement('li');
        li.className = `todo-item${todo.completed ? ' completed' : ''}`;
        li.dataset.id = todo.id;

        li.innerHTML = `
            <input type="checkbox" class="todo-checkbox" ${todo.completed ? 'checked' : ''}>
            <div class="todo-content">
                <div class="todo-title">${this.escapeHtml(todo.title)}</div>
                ${todo.description ? `<div class="todo-description">${this.escapeHtml(todo.description)}</div>` : ''}
            </div>
            <div class="todo-actions">
                <button class="edit-btn">수정</button>
                <button class="delete-btn">삭제</button>
            </div>
        `;

        // Bind events
        const checkbox = li.querySelector('.todo-checkbox');
        checkbox.addEventListener('change', () => this.toggleTodo(todo.id));

        const editBtn = li.querySelector('.edit-btn');
        editBtn.addEventListener('click', () => this.editTodo(todo.id));

        const deleteBtn = li.querySelector('.delete-btn');
        deleteBtn.addEventListener('click', () => this.deleteTodo(todo.id));

        return li;
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    new TodoApp();
});
