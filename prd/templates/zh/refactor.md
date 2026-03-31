# 重构 PRD 模板

> 用于代码重构任务的模板。

---

## Front Matter

```yaml
---
refactor_id: ""               # 重构 ID (可选)
refactor_name: ""             # 重构名称 (例如: 认证模块重构)
refactor_type: "refactor"     # 类型: refactor (固定)
scope: ""                    # 范围: module, function, architecture
complexity: ""                # 复杂度: low, medium, high
priority: ""                  # 优先级: P0, P1, P2, P3
assignee: ""                   # 负责人 (可选)
estimated_hours: ""            # 预计工作小时 (可选)
risk_level: ""                 # 风险级别: low, medium, high
---
```

---

## 必需章节

### 1. 当前问题 (Current Issues)

描述当前代码的问题。

**示例:**
```
认证模块存在以下问题:
1. 违反单一职责原则: UserService 处理认证、权限和会话
2. 测试困难: 所有功能在一个类中，难以测试
3. 扩展性差: 添加新的认证方法需要修改 UserService
```

### 2. 提议的更改 (Proposed Changes)

描述具体的重构方法。

#### 新结构
- [结构 1]
- [结构 2]

#### 预期效果
- [效果 1]
- [效果 2]

#### 要修改的文件
- `src/auth/service.py`: [修改内容]
- `src/auth/repository.py`: [新文件]
- `src/auth/schema.py`: [新文件]

### 3. 影响 (Impact)

分析对系统的影响。

#### 兼容性
- **现有 API**: (例如: 维护现有 API 接口)
- **数据库**: (例如: 无架构更改)
- **外部依赖**: (例如: 添加新库)

#### 潜在风险
- [风险 1]: (例如: 重构期间暂时性功能问题)
- [风险 2]: (例如: 测试覆盖率暂时下降)

### 4. 测试 (Testing)

描述确保功能等效性的测试计划。

#### 测试策略
- [策略 1]
- [策略 2]

#### 功能等效性测试
- [测试项目 1]
- [测试项目 2]

#### 性能测试
- [性能测试项目 1]
- [性能测试项目 2]

---

## 可选章节

### 5. 迁移计划 (Migration Plan)

描述将现有代码安全迁移到新结构的计划。

- **阶段 1**: [步骤 1]
- **阶段 2**: [步骤 2]
- **阶段 3**: [步骤 3]

### 6. 回滚计划 (Rollback Plan)

描述如果出现问题恢复到现有代码的计划。

- (例如: 使用 Git 分支进行回滚)

### 7. 成功标准 (Success Criteria)

指定判断重构是否成功的标准。

- [ ] [标准 1]
- [ ] [标准 2]
- [ ] [标准 3]

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
refactor_id: "AUTH-REFACTOR-001"
refactor_name: "认证模块重构"
refactor_type: "refactor"
scope: "module"
complexity: "high"
priority: "P1"
assignee: "john"
estimated_hours: "16"
risk_level: "medium"
---

# 认证模块重构

## 当前问题

认证模块存在以下问题:
1. 违反单一职责原则: UserService 处理认证、权限和会话
2. 测试困难: 所有功能在一个类中，难以测试
3. 扩展性差: 添加新的认证方法需要修改 UserService

## 提议的更改

### 新结构
- `AuthService`: 认证逻辑 (登录、登出)
- `PermissionService`: 权限检查
- `SessionService`: 会话管理
- `UserRepository`: 数据库访问

### 预期效果
- 遵循单一职责原则
- 独立测试每个服务
- 添加新的认证方法只需修改相关 Service

### 要修改的文件
- `src/auth/service.py`: 分拆为 3 个类
- `src/auth/repository.py`: 分离数据库访问逻辑
- `tests/test_auth.py`: 为每个服务编写测试

## 影响

### 兼容性
- **现有 API**: 维护 API 接口
- **数据库**: 无架构更改
- **外部依赖**: 无

### 潜在风险
- 重构期间暂时性功能问题
- 测试覆盖率暂时下降
- 可能的 Git 合并冲突

## 测试

### 测试策略
- 基于流水线的增量重构
- 每个阶段的功能等效性测试

### 功能等效性测试
- 所有现有测试通过
- 添加新测试 (服务分离测试)

### 性能测试
- 比较重构前后的性能
- 目标: 性能下降在 5% 以内
```
