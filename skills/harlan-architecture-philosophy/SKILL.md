---
name: harlan-architecture-philosophy
description: Harlan 的通用架构设计哲学 — 指导 AI 在任何架构任务中遵循 Harlan 的设计偏好、决策风格和输出格式。适用于系统设计、重构、模块拆分、API 设计等所有架构级别的任务。
origin: custom

---

# Harlan 架构设计哲学

> 本 skill 是通用架构思维模型，不绑定特定技术栈。
> 当 AI 面对架构设计、重构规划、模块拆分、技术选型等任务时，**必须遵循本 skill 的决策框架和输出格式**。

---

## 第一原则：问题驱动，不是技术驱动

每个架构决策必须回答：**当前的具体问题是什么？**

不要因为某个模式"好"就采用它。必须先识别痛点，然后匹配解法。

```
❌ "我们用 Clean Architecture 吧，因为它是最佳实践"
✅ "当前继承耦合导致方法暴露不可控 → 用协议注册替代继承"
```

---

## 核心设计偏好

### P1. 协议优于继承（Protocol over Inheritance）

- 用协议定义能力契约，不用继承传递行为
- 继承只在真正的 "is-a" 关系时使用，且层级不超过 2 层
- 协议定义接口，泛型做实现层（组合使用）

```swift
// ✅ 协议定义能力
protocol MethodHandler: AnyObject {
    func registeredMethods() -> [String]
    func handle(method: String, params: [String: Any]?, completion: @escaping (Result<Any?, MethodError>) -> Void)
}

// ❌ 继承传递行为
class BaseModule: NSObject { ... }
class ScannerModule: BaseModule { ... }
```

### P2. 显式优于隐式（Explicit over Implicit）

- 暴露的接口必须显式注册/声明，不依赖反射、运行时发现或命名约定
- 配置和依赖关系必须在代码中可见，不藏在注解或约定里
- 方法签名要表达意图，不靠文档补充

```swift
// ✅ 显式注册
func registeredMethods() -> [String] { ["openQRScan", "closeScanner"] }

// ❌ 隐式暴露
// 所有 @objc 方法自动可被调用
```

### P3. 单一职责，严格边界（Single Responsibility, Hard Boundaries）

- 每个组件只做一件事，不越权
- Dispatcher 只分发，不做权限检查
- Service Registry 只管理服务实例，不做业务逻辑
- 如果一个类的职责需要用 "和" 连接才能描述，就该拆分

### P4. 清晰错误响应，拒绝静默失败（Fail Loud, Never Swallow）

- 每个失败路径都必须有明确的错误类型和响应
- 未注册方法 → 返回 `.methodNotFound`，不是静默忽略
- 调用失败 → 返回 `.invocationFailed(underlying:)`，携带原始错误
- 错误类型用枚举建模，不用字符串

```swift
// ✅ 结构化错误
enum MethodError: Error {
    case methodNotFound(method: String)
    case invocationFailed(method: String, underlying: Error?)
}

// ❌ 静默忽略
guard responds(to: selector) else { return }  // 调用方永远不知道失败了
```

### P5. 性能意识，量化对比（Performance-Aware, Quantified）

- 架构决策必须评估性能影响，用 Big-O 标注
- 用对比表量化旧方案 vs 新方案
- 优先选择 O(1) 查找（字典/哈希表）而非 O(N) 遍历

| 指标           | 旧方案             | 新方案        |
| -------------- | ------------------ | ------------- |
| 查找复杂度     | O(N) responds(to:) | O(1) 字典查找 |
| 通知 observers | N 个               | 1 个          |
| 未注册处理     | 静默忽略           | 返回错误      |

### P6. 复用已有系统，不造轮子（Reuse, Don't Reinvent）

- 优先复用项目中已有的框架和服务
- handler 内部通过已有的 service registry 调用真实服务
- 只在现有系统确实无法满足需求时才引入新依赖

### P7. API 简洁，一行可用（Simple API Surface）

- 核心操作应该一行代码完成
- 注册：`Dispatcher.shared.register(XXXHandler.self)`
- 复杂配置用 builder 模式或默认参数，不强制使用者关心细节

---

## 依赖管理偏好

### 构造器注入优先

```swift
// ✅ 构造器注入 — 依赖关系在初始化时明确
final class OrderService {
    private let repository: OrderRepository
    private let validator: OrderValidator

    init(repository: OrderRepository, validator: OrderValidator) {
        self.repository = repository
        self.validator = validator
    }
}

// ❌ 属性注入 — 依赖关系不透明
final class OrderService {
    var repository: OrderRepository!  // 可能忘记赋值
}
```

### Singleton 使用原则

- **基础设施层可用**：Dispatcher、ServiceRegistry、Logger 等全局唯一的基础设施
- **业务层尽量避免**：业务对象不应该是单例
- **能不用就不用**：如果构造器注入能解决，就不要用单例

---

## 异步模式偏好

- **新代码**：async/await 优先
- **旧代码兼容**：completion handler 可保留，逐步迁移
- 不引入 Combine/RxSwift 除非项目已在使用

```swift
// ✅ 新接口优先 async/await
func handle(method: String, params: [String: Any]?) async throws -> Any?

// ✅ 兼容层 — 桥接旧代码
func handle(method: String, params: [String: Any]?, completion: @escaping (Result<Any?, MethodError>) -> Void)
```

---

## 模块通信偏好

采用**双轨制**：

1. **中央注册表 + 协议**：用于模块向系统注册能力（如方法处理器注册）
2. **协议抽象直接引用**：模块间通过协议直接依赖，不走事件总线

```
模块 A ──(protocol)──► 模块 B 的抽象接口
          不经过 EventBus
          不经过 NotificationCenter（除非是系统级广播）
```

- NotificationCenter 仅用于**系统级广播**（如 RN 桥接通知），不用于模块间常规通信
- EventBus 会导致隐式依赖，尽量避免

---

## 迁移哲学：成本驱动

**不教条，看迁移成本做决定：**

| 迁移成本                      | 策略                     | 示例                           |
| ----------------------------- | ------------------------ | ------------------------------ |
| **低**（<50行/模块）          | 一次性清理，不留兼容层   | RNMethodHandler 迁移           |
| **高**（涉及多团队/大量模块） | Strangler Fig：新旧并行  | 新功能用新架构，旧的逐步替换   |
| **中等**                      | 定迁移截止日期，给缓冲期 | 标记 @deprecated，设定删除日期 |

关键原则：

- **新功能必须用新架构**，不往旧架构上加东西
- 旧代码迁移完毕后，**必须删除兼容层**，不留死代码
- 迁移成本要量化（每模块多少行改动），不凭感觉决策

---

## 文件组织偏好

- **相关类型放一个文件**：协议 + 错误枚举 + 小型数据结构可以放一起
- **按职责命名**：`RNMethodDispatcher.swift`（不是 `Dispatcher.swift`，避免歧义）
- **按功能域分文件夹**：不按文件类型（Models/、Protocols/）分
- **单个文件不超过 400 行**，超过就拆分

```
PackageManager/
├── RNMethodDispatcher.swift    // 核心分发器
├── RNMethodHandler.swift       // 协议 + 错误类型 + 注册结构体
└── Handlers/
    ├── RNScannerHandler.swift
    └── RNUserHandler.swift
```

---

## 架构层级：按项目规模决定

不教条地套用某种分层架构。根据实际规模选择：

| 项目规模       | 推荐分层                           |
| -------------- | ---------------------------------- |
| 小型（单模块） | 薄接口层 + 服务层，不需要额外抽象  |
| 中型（多模块） | 接口层 → 服务层 → 数据层，协议解耦 |
| 大型（多团队） | 模块化 + 服务注册表 + 协议抽象层   |

共同原则：

- **接口层尽量薄**：Dispatcher 只做分发，不含业务逻辑
- **业务逻辑在服务层**：Handler/Service 处理真实逻辑
- **数据访问通过抽象**：不直接依赖具体存储实现

---

## 测试策略

- **重构完成后补测试**：先把架构理顺，再用测试锁定行为
- **协议天然支持 mock**：用协议定义的依赖可以轻松替换为测试替身
- **关键路径必须覆盖**：核心分发、错误处理、注册/注销流程

```swift
// 协议定义 → 自然可 mock
final class MockMethodHandler: MethodHandler {
    var handledMethods: [(String, [String: Any]?)] = []

    func registeredMethods() -> [String] { ["testMethod"] }

    func handle(method: String, params: [String: Any]?, completion: @escaping (Result<Any?, MethodError>) -> Void) {
        handledMethods.append((method, params))
        completion(.success(nil))
    }
}
```

---

## AI 输出格式要求

当 Harlan 要求进行架构设计时，AI **必须**按以下步骤输出：

### Step 1：问题识别

先列出当前架构的具体问题，不要跳过这步。

```markdown
## 当前问题
1. 继承耦合 → 所有模块必须继承 BaseModule
2. 隐式暴露 → @objc 方法全部可被调用
3. 静默失败 → 未注册方法无反馈
```

### Step 2：方案对比表

给出 2-3 个可选方案，用对比表呈现优劣：

```markdown
| 维度 | 方案 A：渐进迁移 | 方案 B：纯新架构 | 方案 C：Adapter 层 |
|------|------------------|-----------------|-------------------|
| 迁移成本 | 低 | 中 | 中 |
| 架构清洁度 | ★★☆ | ★★★ | ★★☆ |
| 性能影响 | 无改善 | O(1) 查找 | 微小开销 |
| 长期维护 | 需维护两套 | 最优 | 需维护 adapter |
```

### Step 3：等待确认

**不要自动选择方案。** 等 Harlan 确认选择后，再输出完整设计。

### Step 4：完整设计文档

确认后输出：

1. **核心组件**：协议/类/结构体定义 + 职责说明
2. **调用流程图**：ASCII 流程图展示数据流向
3. **性能对比表**：旧 vs 新的量化对比
4. **迁移指南**：模板化的迁移步骤
5. **迁移成本估算**：每模块的代码行数变化
6. **文件清单**：每个文件的职责

### Step 5：实现代码

设计文档确认后，输出完整可编译的代码。

---

## 反模式清单（AI 必须避免）

| 反模式         | 说明                        | 正确做法             |
| -------------- | --------------------------- | -------------------- |
| 自动选方案     | 不问就选了某个方案          | 给对比表，等确认     |
| 过度设计       | 小项目上 Clean Architecture | 按项目规模选分层     |
| 保留兼容层不删 | "万一以后要用"              | 迁移完就删           |
| 静默失败       | guard else return 不报错    | 返回结构化错误       |
| 用继承做扩展   | 因为"方便"                  | 用协议               |
| 隐式依赖       | 通过字符串/运行时发现       | 显式注册或构造器注入 |
| 造轮子         | 项目里有的框架不用          | 先找已有系统         |
| O(N) 遍历      | 能用字典查找的用遍历        | 注册表 + O(1) 查找   |
| 职责越权       | Dispatcher 做权限检查       | 拆分到独立组件       |
| 凭感觉决策     | "我觉得迁移不难"            | 量化迁移成本         |

---

## 触发条件

当用户的请求涉及以下关键词或意图时，本 skill 自动适用：

- 架构设计 / 系统设计 / 重构
- 模块拆分 / 解耦
- 技术选型 / 方案对比
- 迁移方案 / 技术债清理
- 协议设计 / 接口设计
- 注册机制 / 分发机制
- "怎么设计" / "怎么重构" / "怎么拆"

---

## 与其他 skill 的关系

- `harlan-rn-architecture`：本 skill 的 RN 容器特化版本，包含 RN 桥接特定的迁移模板
- `coding-standards`：代码风格层面，本 skill 是架构层面
- `security-review`：安全审查，与本 skill 的错误处理原则互补