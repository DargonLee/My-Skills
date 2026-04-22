---
name: harlan-architecture
description: |
  Harlan 的全栈架构设计 Skill — 融合通用架构哲学、iOS/RN 跨平台分层模式、SDK 设计偏好三位一体。当 Harlan 涉及任何架构级别的任务时必须参考本 Skill，包括但不限于：设计新模块/SDK/Bridge/服务层、评审或重构架构方案、规划 CocoaPods 库结构、设计原生与 JS 通信机制、模块解耦与职责拆分、协议/接口规范设计、目录结构规划、技术选型与方案对比、迁移方案制定、技术债清理。即使 Harlan 没有明确说「按我的风格」，只要涉及「怎么设计」「怎么重构」「怎么拆」「怎么迁移」，本 Skill 自动适用。
origin: custom

---

# Harlan 架构设计 Skill

> 本 Skill 融合三层知识：**通用架构哲学**（决策框架）→ **跨平台分层模式**（SDK/Bridge 设计）→ **RN 容器特化**（实现模板）。  
> 任何架构任务，从第一原则出发，沿分层模型落地，最终输出可直接使用的实现模板。

---

## 第一原则：问题驱动，不是技术驱动

每个架构决策必须先回答：**当前的具体问题是什么？**

```
❌ "用 Clean Architecture 吧，因为是最佳实践"
✅ "继承耦合导致方法暴露不可控 → 用协议注册替代继承"
```

---

## 核心设计哲学

### P1. 统一入口 + 内部分发（Facade + Dispatcher）

**对外零认知负担**：无论内部多复杂，调用者只需要一个入口。

```
NBRouter.open({ module, func, params })  ← 唯一入口
    ↓
内部自动：校验 → 检测环境 → 分发到对应平台
```

- 外部 API 越简单越好，复杂性向内收敛
- 对调用者屏蔽平台差异、版本差异、实现细节
- 环境自动检测，不让调用方传平台参数

```ts
// ✅ 自动检测平台
const result = await NBRouter.open({ module, func, params });

// ❌ 让调用方感知平台
const result = await NBRouter.open({ module, func, params, platform: 'rn' });
```

### P2. 协议驱动（Protocol-First）

先定义协议/接口，再写实现。协议即契约，实现可替换：

```swift
// ✅ 先有协议
protocol NBScannerProtocol {
    func openQRScan(_ config: [String: Any], completion: @escaping (String) -> Void)
}
// 实现可 mock、可替换、可测试
final class NBScannerService: NSObject, NBScannerProtocol { ... }

// ❌ 调用方依赖具体类
class SomeVC {
    let scanner = NBScannerService()  // 耦合实现
}
```

TypeScript 同理：`interface` 先行，永远不让调用方依赖具体类。

### P3. 标准化消息格式（Normalized Protocol）

跨层通信必须有统一的消息格式，不允许各处自定义：

```ts
// 统一请求结构
{ module: string, func: string, params?: object }

// 统一响应结构
{ success: boolean, data?: object, error?: NBRouterError }
```

建议结构化错误码，拒绝字符串错误：

```ts
interface NBRouterError {
    code: ErrorCode;   // INVALID_REQUEST / PLATFORM_NOT_SUPPORTED / NATIVE_ERROR / TIMEOUT
    message: string;
    cause?: unknown;
}
```

### P4. 显式优于隐式（Explicit over Implicit）

- 接口必须显式注册/声明，不依赖反射或命名约定
- 依赖关系在代码中可见，不藏在注解或约定里

```swift
// ✅ 显式注册
func registeredMethods() -> [String] { ["openQRScan", "closeScanner"] }

// ❌ 隐式暴露 — 所有 @objc 方法自动可被调用
```

### P5. 单一职责，严格边界（Hard Boundaries）

- Dispatcher 只分发，不做权限检查
- Service Registry 只管理实例，不含业务逻辑
- 「如果职责需要用『和』连接才能描述，就该拆分」

### P6. 清晰错误响应，拒绝静默失败（Fail Loud）

```swift
// ✅ 结构化错误枚举
enum MethodError: Error {
    case methodNotFound(method: String)
    case invocationFailed(method: String, underlying: Error?)
}

// ❌ 静默忽略
guard responds(to: selector) else { return }  // 调用方永远不知道失败
```

### P7. 性能意识，O(1) 优先

架构决策要评估性能影响，优先字典/哈希查找：

| 指标       | 旧方案               | 新方案         |
| ---------- | -------------------- | -------------- |
| 查找复杂度 | O(N) `responds(to:)` | O(1) 字典查找  |
| 未注册处理 | 静默忽略             | 返回结构化错误 |

### P8. 复用已有系统，不造轮子

先找项目中已有的框架和服务。只有在现有系统确实无法满足时才引入新依赖。

### P9. API 简洁，一行可用

```swift
// 注册一行
RNMethodDispatcher.shared.register(RNXXXHandler.self)
// 调用一行
let result = await NBRouter.open({ module: "scanner", func: "openQRScan", params })
```

---

## 标准分层模型

Harlan 的跨平台项目天然形成四层，层间通过协议通信，不跨层调用：

```
┌─────────────────────────────────────┐
│   SDK 层（npm / JS 统一入口）         │  ← 对外暴露，平台无关
├─────────────────────────────────────┤
│   Bridge 层（平台适配）               │  ← RN / H5 / Mini 各自实现
├─────────────────────────────────────┤
│   原生服务层（Protocol + Service）    │  ← Swift/ObjC 功能实现
├─────────────────────────────────────┤
│   基础设施层（AppManager / DI）       │  ← 服务注册、依赖注入
└─────────────────────────────────────┘
```

### 层间通信选型

| 场景                       | 选择                           | 原因                   |
| -------------------------- | ------------------------------ | ---------------------- |
| RN JS → 原生               | TurboModule（New Arch）        | 类型安全、同步性能好   |
| 原生内部解耦（系统级广播） | NotificationCenter             | 模块间零依赖           |
| 原生服务定位               | Protocol + DI（NBVAppManager） | 可测试、可替换         |
| H5 → 原生                  | WKScriptMessageHandler         | 官方标准方案           |
| 原生 → H5 回调             | evaluateJavaScript             | 标准回调路径           |
| 模块间常规通信             | 协议抽象直接引用               | 避免 EventBus 隐式依赖 |

> NotificationCenter 仅用于系统级广播，不用于模块间常规通信。

---

## 设计习惯与偏好

### 目录结构即架构表达

```
src/
├── core/       # 平台无关的核心逻辑（类型、校验、检测）
├── modules/    # 功能模块（对外 API）
├── bridges/    # 平台适配层（rn / h5 / mini / mock）
└── utils/      # 工具函数
```

iOS CocoaPods 库参考：

```
PackageManager/
├── RNMethodDispatcher.swift    # 核心分发器
├── RNMethodHandler.swift       # 协议 + 错误类型
└── Handlers/
    ├── RNScannerHandler.swift
    └── RNUserHandler.swift
```

- 按功能域分文件夹，不按文件类型
- 文件命名语义化（`RNMethodDispatcher.swift` 而非 `Dispatcher.swift`）
- 单文件不超过 400 行，超过即拆分

### Optional Peer Dependencies + 动态导入

```ts
// 不强制依赖，让同一 SDK 在 RN/H5/小程序三端无感安装
const { callNative } = await import('rn-callnative');
```

### 单包优于分包

| 考量     | 结论                            |
| -------- | ------------------------------- |
| 用户体验 | 一个 import，不感知平台         |
| 维护成本 | 单仓库，公共代码不重复          |
| 设计初衷 | 「平台分发」本身是 SDK 核心价值 |

参考：微信、抖音 JS SDK 均为单包。

### Mock Bridge 作为一等公民

`bridges/mock.ts` 在设计阶段就要预留，开发/测试环境无需真实原生环境也能跑通。

### 依赖管理：构造器注入优先

```swift
// ✅ 构造器注入 — 依赖关系透明
final class OrderService {
    init(repository: OrderRepository, validator: OrderValidator) { ... }
}

// ❌ 属性注入 — 依赖关系不透明，可能未赋值
final class OrderService {
    var repository: OrderRepository!
}
```

Singleton 仅用于基础设施层（Dispatcher、ServiceRegistry、Logger），业务层避免。

### 异步模式

- 新代码：async/await 优先
- 旧代码兼容：completion handler 可保留，逐步迁移
- 不引入 Combine/RxSwift 除非项目已在使用

### 新增模块标准 SOP

```
Step 1: 实现 Service（遵守 Protocol）
Step 2: 注册到 AppManager / Dispatcher
Step 3: 添加 RN 通知监听 / Bridge 分发入口
Step 4: 添加 H5 methodList 分发（如需）
```

---

## RN 桥接层特化（实现模板）

### 核心组件关系

```
RNMethodDispatcher (单例 — 基础设施层)
    ├── 接收 RNCallNative 通知
    ├── 字典查找 registrations[methodName] — O(1)
    └── 调用 handler.handle()

RNMethodHandler (协议)
    ├── registeredMethods() -> [String]
    └── handle(method:params:completion:)

NBVAppManager (外部框架)
    └── service(for:) — 获取真实服务实例
```

### 完整分发流程

```
RNCallNative 通知
    ↓
RNMethodDispatcher.handleRNCallNative()
    ↓
字典查找 registrations[methodName]   ← O(1)
    ↓
handler.handle(method:params:completion:)
    ↓
NBVAppManager.service(for:) 获取服务
    ↓
completion(.success(result))
    ↓
RNCallBack 通知 → JS 侧
```

### 迁移模板：旧（继承）→ 新（协议）

**旧代码：**

```swift
public class RNXXXModule: RNCommonModule {
    @objc func methodA(_ userInfo: RNModel) {
        // 原有逻辑
    }
}
```

**新代码：**

```swift
final class RNXXXHandler: RNMethodHandler {
    func registeredMethods() -> [String] {
        return ["methodA"]
    }

    func handle(method: String, params: [String: Any]?,
                completion: @escaping (Result<Any?, RNMethodError>) -> Void) {
        switch method {
        case "methodA":
            handleMethodA(params: params, completion: completion)
        default:
            completion(.failure(.methodNotFound(method: method)))
        }
    }

    private func handleMethodA(params: [String: Any]?,
                               completion: @escaping (Result<Any?, RNMethodError>) -> Void) {
        DispatchQueue.main.async {
            var error: NBVAppError?
            if let service = NBVAppManager.service(for: SomeProtocol.self, error: &error) {
                service.doSomething(params ?? [:]) { result in
                    completion(.success(result))
                }
            } else {
                completion(.failure(.invocationFailed(method: "methodA", underlying: error)))
            }
        }
    }
}

// 注册（一行）
RNMethodDispatcher.shared.register(RNXXXHandler.self)
```

### 迁移六步

1. 新建 Handler 类，删除继承
2. 实现 `RNMethodHandler` 协议
3. 在 `registeredMethods()` 列出所有方法名
4. `handle()` 中用 switch-case 分发
5. 原有方法改为私有，去掉 `@objc`，参数从 `RNModel` 改为 `params: [String: Any]?`
6. 末尾调用 `completion()` 而非 `NotificationCenter.post`

### 标准文件清单

| 文件                       | 职责                      |
| -------------------------- | ------------------------- |
| `RNMethodError.swift`      | 错误类型枚举              |
| `RNMethodHandler.swift`    | 方法处理协议 + 注册结构体 |
| `RNMethodDispatcher.swift` | 核心分发器（单例）        |

---

## 迁移哲学：成本驱动

| 迁移成本                  | 策略                    | 示例                             |
| ------------------------- | ----------------------- | -------------------------------- |
| **低**（< 50 行/模块）    | 一次性清理，不留兼容层  | RNMethodHandler 迁移             |
| **高**（多团队/大量模块） | Strangler Fig：新旧并行 | 新功能用新架构，旧的逐步替换     |
| **中等**                  | 定截止日期，给缓冲期    | 标记 `@deprecated`，设定删除日期 |

关键：

- 新功能必须用新架构，不往旧架构加东西
- 迁移完成后必须删除兼容层，不留死代码
- 迁移成本要量化（每模块多少行改动），不凭感觉决策

---

## 测试策略

- 重构完成后补测试：先理顺架构，再用测试锁定行为
- 协议天然支持 mock，测试替身零成本

```swift
final class MockMethodHandler: MethodHandler {
    var handledMethods: [(String, [String: Any]?)] = []
    func registeredMethods() -> [String] { ["testMethod"] }
    func handle(method: String, params: [String: Any]?,
                completion: @escaping (Result<Any?, MethodError>) -> Void) {
        handledMethods.append((method, params))
        completion(.success(nil))
    }
}
```

---

## 文档化风格

- **调用链驱动**：文档按请求路径组织（入口 → 协议解析 → 分发 → Bridge → 原生服务），不按模块平铺
- **贯穿示例**：开头声明一个 Running Example（如 `NBScanner.openQRScan`），所有片段围绕它展开
- **双视角图**：Flowchart（分发决策）+ Sequence Diagram（完整时序含异步回调）
- **对比表格**：重要决策不只写结论，写推导过程

---

## AI 输出格式（Claude 必须遵守）

### Step 1：问题识别

先列当前架构的具体问题，不跳过：

```markdown
## 当前问题
1. 继承耦合 → 所有模块必须继承 BaseModule
2. 隐式暴露 → @objc 方法全部可被调用
3. 静默失败 → 未注册方法无反馈
```

### Step 2：方案对比表（2-3 个方案）

```markdown
| 维度 | 方案 A | 方案 B | 方案 C |
|------|--------|--------|--------|
| 迁移成本 | 低 | 中 | 中 |
| 架构清洁度 | ★★☆ | ★★★ | ★★☆ |
| 性能影响 | 无改善 | O(1) 查找 | 微小开销 |
| 长期维护 | 需维护两套 | 最优 | 需维护 adapter |
```

### Step 3：等待 Harlan 确认

**不要自动选择方案。** 给出对比后等确认，再输出完整设计。

### Step 4：完整设计文档

确认后输出：

1. 核心组件（协议/类/结构体定义 + 职责说明）
2. 调用流程图（ASCII 展示数据流）
3. 性能对比表（旧 vs 新量化对比）
4. 迁移指南（模板化步骤）
5. 迁移成本估算（每模块代码行数变化）
6. 文件清单（每个文件的职责）

### Step 5：实现代码

设计确认后，输出完整可编译代码。

---

## 反模式清单

| 反模式                            | 正确做法                 |
| --------------------------------- | ------------------------ |
| 自动选方案不等确认                | 给对比表，等 Harlan 确认 |
| 过度设计                          | 按项目规模选分层         |
| 保留兼容层不删                    | 迁移完就删               |
| 静默失败                          | 返回结构化错误           |
| 用继承做扩展                      | 用协议                   |
| 隐式依赖（字符串/运行时发现）     | 显式注册或构造器注入     |
| 造轮子（项目里有的框架不用）      | 先找已有系统             |
| O(N) 遍历（能用字典的地方）       | 注册表 + O(1) 查找       |
| 职责越权（Dispatcher 做权限检查） | 拆分到独立组件           |
| 凭感觉评估迁移成本                | 量化每模块行数变化       |
| 让调用方感知平台差异              | 封装在内部自动检测       |
| 暴露可选模块的强依赖              | optional peer + 动态导入 |

---

## 快速参考卡

```
设计三问（任何新功能开始前）：
1. 调用方需要知道什么？（最小化暴露）
2. 层的边界在哪里？（协议定义边界）
3. 新人怎么扩展这个功能？（SOP 化）
```

```
标准消息结构：
Request:  { module, func, params? }
Response: { success, data?, error? }
```

```
目录模板：
src/
├── core/      # 类型、校验、检测（平台无关）
├── modules/   # 功能模块（对外 API）
├── bridges/   # 平台实现（rn/h5/mini/mock）
└── utils/     # 工具
```

---

## 与其他 Skill 的关系

- `coding-standards`：代码风格层面，本 Skill 是架构层面
- `security-review`：安全审查，与本 Skill 的错误处理原则互补
- 本 Skill 已完全替代 `harlan-architecture-philosophy`、`harlan-rn-architecture`、`harlan-rn-architecture-2`