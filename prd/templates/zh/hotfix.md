# 紧急修复 PRD 模板

> 用于紧急错误修复的轻量级 PRD 模板。
> 一般错误修复请使用 `prd/bug.md`。

---

## Front Matter

```yaml
---
feature_name: ""               # 修复名称 (例如: 登录错误紧急修复)
feature_type: "hotfix"         # 类型: hotfix (固定)
priority: "high"               # 始终为 high
severity: ""                   # 严重程度: critical | high | medium
issue_url: ""                  # 问题跟踪器 URL (可选)
assignee: ""                   # 负责人
estimated_minutes: ""          # 预计时间 (分钟)
tags: ["hotfix", "urgent"]     # 标签
---
```

---

## 必需章节

### 1. 问题 (Issue)

简要描述需要紧急修复的问题。

**示例:**
```
生产环境在用户登录期间返回 500 错误，
阻止所有用户使用服务。
```

### 2. 快速修复 (Quick Fix)

简要描述核心修复。

**示例:**
```
缺少空引用检查导致异常。
为 user 对象添加 None 检查以防止异常。
```

**代码更改:**
```python
# 之前
def login(email):
    return user.token  # user 为 None 时出错

# 之后
def login(email):
    if not user:
        raise InvalidCredentialsError()
    return user.token
```

### 3. 测试 (Testing)

描述快速测试方法。

- **修复前**: (例如: 使用无效电子邮件登录 → 500 错误)
- **修复后**: (例如: 使用无效电子邮件登录 → 401 错误)

---

## 可选章节

### 4. 根本原因 (Root Cause)

根本原因分析 (如果需要)。

```
最近的重构更改了用户对象创建逻辑，
但登录函数没有添加 Null 检查。
```

### 5. 预防 (Prevention)

未来复发的预防措施。

```
- 在函数开始时添加参数验证
- 向单元测试添加 None 输入情况
```

---

## 使用指南

1. 将此模板复制到 `prd/` 文件夹。
2. 填写 Front Matter 的必填字段。
3. 快速编写必需章节 (1-3) (~5 分钟)。
4. 使用 `/quick` 命令运行流水线。

---

## 使用场景

**适合使用 Hotfix 的情况:**
- 生产服务中断
- 数据丢失风险
- 安全漏洞暴露
- 对用户体验的严重影响

**不适合使用 Hotfix 的情况:**
- 一般错误 (→ 使用 `prd/bug.md`)
- 新功能 (→ 使用 `prd/feature.md`)
- 重构 (→ 使用 `prd/refactor.md`)

---

## 流水线差异

**普通 PRD vs Hotfix:**

| 阶段 | 普通 PRD | Hotfix |
|-------|----------|--------|
| Gate | 完整章节验证 | 最小章节验证 |
| Scan | 完整影响分析 | 快速范围检查 |
| Fold | 可行性评估 | **跳过** (节省时间) |
| Verdict | PASS/FIX/FAIL | PASS/FIX/FAIL |
| Patch | 实施 (最多 5 次迭代) | 实施 (最多 2 次迭代) |
| Trace | 完整日志 | 仅核心日志 |

---

## 示例

```yaml
---
feature_name: "登录 500 错误紧急修复"
feature_type: "hotfix"
priority: "high"
severity: "critical"
issue_url: "https://github.com/xxx/issues/123"
assignee: "john"
estimated_minutes: "15"
tags: ["hotfix", "urgent", "production"]
---

# 登录 500 错误紧急修复

## 问题

生产环境在使用无效电子邮件尝试登录时
返回 500 内部服务器错误。
目前所有用户都受到影响。

## 快速修复

`login()` 函数缺少 `user` 对象为 None 时的处理。

**位置:** `app/auth.py:45`

**之前:**
```python
def login(email: str, password: str) -> str:
    user = db.get_user(email)
    return user.token  # None → 500 错误
```

**之后:**
```python
def login(email: str, password: str) -> str:
    user = db.get_user(email)
    if not user:
        raise InvalidCredentialsError("无效的电子邮件或密码")
    return user.token
```

**预计时间:** 15 分钟
- 代码修复: 5 分钟
- 测试: 5 分钟
- 部署: 5 分钟

## 测试

### 修复前测试
```bash
# 使用无效电子邮件登录
curl -X POST /api/login -d '{"email": "invalid@test.com", "password": "wrong"}'
# 预期: 500 内部服务器错误 (当前)
```

### 修复后测试
```bash
# 相同请求
curl -X POST /api/login -d '{"email": "invalid@test.com", "password": "wrong"}'
# 预期: 401 未授权, {"error": "无效的电子邮件或密码"}
```

### 附加测试
- 有效电子邮件/密码: 正常登录 (200 OK)
- 空电子邮件: 400 错误请求
- SQL 注入尝试: 400 错误请求
```

---

## 注意事项

1. **Hotfix 仅用于紧急情况**
2. **仅进行最小更改**
3. **测试是强制性的** (避免创建严重错误)
4. **建议 Hotfix 后编写正式 PRD** (根本原因分析和预防)
5. **可以绕过代码审查** (紧急情况)
6. **部署后监控是强制性的**
