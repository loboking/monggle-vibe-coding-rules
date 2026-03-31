# Bug PRD 模板

> 用于错误修复任务的模板。

---

## Front Matter

```yaml
---
bug_id: ""                    # Bug ID (可选)
bug_name: ""                 # Bug 名称 (例如: 登录 500 错误)
bug_type: ""                 # 类型: bugfix (固定)
severity: ""                  # 严重程度: critical, high, medium, low
priority: ""                  # 优先级: P0, P1, P2, P3
affected_version: ""           # 受影响的版本 (可选)
environment: ""                # 环境 (可选)
reporter: ""                   # 报告人 (可选)
assignee: ""                   # 负责人 (可选)
estimated_hours: ""            # 预计工作小时 (可选)
---
```

---

## 必需章节

### 1. 问题描述 (Issue Description)

详细描述问题。

**示例:**
```
当用户点击登录按钮时，
发生 HTTP 500 内部服务器错误，无法登录。
错误日志显示 "AttributeError: 'NoneType' object has no attribute 'user'"。
```

### 2. 根本原因 (Root Cause)

分析问题的根本原因。

**示例:**
```
用户模型在数据库中有电子邮件字段为 NULL 的用户。
登录逻辑引用 `user.email` 导致 NoneType 错误。
原因: 注册期间缺少电子邮件验证逻辑，允许 NULL 值。
```

### 3. 修复计划 (Fix Plan)

描述具体的修复方法。

#### 解决方案
- [解决方案 1]
- [解决方案 2]

#### 要修改的文件
- `src/auth/login.py`: [修改内容]
- `src/models/user.py`: [修改内容]
- `tests/test_auth.py`: [测试添加]

### 4. 测试 (Testing)

描述防止复发的测试计划。

#### 复发预防测试
- [测试项目 1]
- [测试项目 2]

#### 回归测试
- [现有功能测试 1]
- [现有功能测试 2]

---

## 可选章节

### 5. 影响分析 (Impact Analysis)

分析对系统其他部分的影响。

- **受影响的模块**: (例如: 认证模块、会话管理)
- **数据更改**: (例如: 需要用户数据迁移)
- **API 更改**: (例如: 登录 API 响应更改)

### 6. 临时变通方法 (Temporary Workaround)

描述永久修复之前的临时变通方法。

- (例如: 添加错误日志并手动修复 NULL 电子邮件)

### 7. 预防 (Prevention)

描述避免复发的预防措施。

- [预防措施 1]
- [预防措施 2]

---

## 使用指南

1. 将此模板复制到 `prd/` 文件夹。
2. 填写 Front Matter 的必填字段。
3. 编写必需章节 (1-4)。
4. 根据需要编写可选章节 (5-7)。
5. 保存文件并运行 Agent 流水线。

---

## 示例

```yaml
---
bug_id: "AUTH-500"
bug_name: "登录 500 错误"
bug_type: "bugfix"
severity: "high"
priority: "P1"
affected_version: "v1.2.0"
environment: "production"
reporter: "jane"
assignee: "john"
estimated_hours: "4"
---

# 登录 500 错误

## 问题描述

当用户点击登录按钮时，
发生 HTTP 500 内部服务器错误，无法登录。
错误日志显示 "AttributeError: 'NoneType' object has no attribute 'user'"。

## 根本原因

用户模型在数据库中有电子邮件字段为 NULL 的用户。
登录逻辑引用 `user.email` 导致 NoneType 错误。
原因: 注册期间缺少电子邮件验证逻辑，允许 NULL 值。

## 修复计划

### 解决方案
1. 注册期间添加电子邮件验证逻辑
2. 编写脚本从数据库中删除 NULL 电子邮件用户
3. 在登录逻辑中添加 NULL 检查

### 要修改的文件
- `src/auth/register.py`: 添加电子邮件重复检查逻辑
- `scripts/clean_null_users.py`: NULL 电子邮件用户清理脚本
- `src/auth/login.py`: 添加 NULL 检查
- `tests/test_auth.py`: 添加 NULL 用户登录尝试测试

## 测试

### 复发预防测试
- NULL 电子邮件注册尝试
- 重复电子邮件注册尝试

### 回归测试
- 有效电子邮件登录
- 社交登录
```
