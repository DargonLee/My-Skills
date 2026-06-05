---
name: harlan-rn-architecture-2
description: Harlan 的 iOS/React Native 架构设计风格指南与 Skill。当 Harlan 需要设计新的 SDK、模块、Bridge、原生服务层、CocoaPods 库、或任何跨平台调用链时，使用此 Skill 确保产出符合他一贯的架构思维和设计偏好。
  
  触发场景：设计新模块、评审架构方案、规划 SDK 结构、设计 Bridge 层、拆分子系统职责、设计协议/接口规范、规划目录结构、设计原生与 JS 通信机制、CocoaPods podspec 设计、服务注册与依赖注入设计。即使 Harlan 没有明确说"按我的风格"，只要涉及上述话题，也应主动参考本 Skill。

---

# Harlan 架构设计风格 Skill

> 本 Skill 从 `@ninebot/open-sdk` 的 `NBRouter` 设计文档中提炼，不局限于该功能本身，而是对 Harlan 设计思维的系统性总结。

---

## 一、核心设计哲学

### 1.1 统一入口 + 内部分发（Facade + Dispatcher）

Harlan 极其强调**对外零认知负担**。无论内部多复杂，调用者只需要一个入口、一套接口：

```
NBRouter.open({ module, func, params })  ← 唯一入口
    ↓
内部自动：校验 → 检测环境 → 分发到对应平台
```

**设计原则**：外部 API 越简单越好，复杂性向内收敛。对调用者屏蔽平台差异、版本差异、实现细节。

**推广到其他场景**：

- CocoaPods 库设计：对外暴露最小化 API，内部 subspec 或实现细节不泄露
- 原生服务层：统一通过 `NBVAppManager.shared.resolve(Protocol.self)` 访问，调用者不 import 实现类
- TurboModule：JS 侧只看到 `callNative(params)` 这一个方法

### 1.2 协议驱动（Protocol-First Design）

先定义协议，再写实现。协议即契约，实现可替换：

```swift
// 先有协议
protocol NBScannerProtocol {
    func openQRScan(_ config: [String: Any], completion: @escaping (String) -> Void)
}

// 再有实现（可测试、可 mock、可替换）
final class NBScannerService: NSObject, NBScannerProtocol { ... }
```

**推广**：TypeScript 接口先行、Swift Protocol 先行，永远不让调用方依赖具体类。

### 1.3 标准化消息格式（Normalized Protocol）

跨层通信必须有标准化的消息格式，不允许各处自定义：

```ts
// 统一请求结构
{ module: string, func: string, params?: object }

// 统一响应结构  
{ success: boolean, data?: object, error?: string }
```

这个思想贯穿 RN Bridge、H5 Bridge、原生分发全链路。格式标准化是可扩展性的基础。

---

## 二、分层架构模式

### 2.1 标准四层模型

Harlan 的跨平台项目天然形成四层：

```
┌─────────────────────────────────┐
│   SDK 层（npm / JS 统一入口）     │  ← 对外暴露，平台无关
├─────────────────────────────────┤
│   Bridge 层（平台适配）           │  ← RN/H5/Mini 各自实现
├─────────────────────────────────┤
│   原生服务层（Protocol + Service） │  ← Swift/ObjC 功能实现
├─────────────────────────────────┤
│   基础设施层（AppManager/DI）     │  ← 服务注册、依赖注入
└─────────────────────────────────┘
```

每层职责单一，层间通过协议/接口通信，不跨层调用。

### 2.2 层间通信机制选型

| 场景           | Harlan 的选择                  | 原因                     |
| -------------- | ------------------------------ | ------------------------ |
| RN JS → 原生   | TurboModule（New Arch）        | 类型安全、同步性能好     |
| 原生内部解耦   | NotificationCenter             | 模块间零依赖、广播式解耦 |
| 原生服务定位   | Protocol + DI（NBVAppManager） | 可测试、可替换实现       |
| H5 → 原生      | WKScriptMessageHandler         | 官方 WebView 标准方案    |
| 原生 → H5 回调 | evaluateJavaScript             | 同上，标准回调路径       |

---

## 三、设计习惯与偏好

### 3.1 环境自动检测，不让调用方传平台参数

```ts
// ✅ Harlan 的风格：自动检测
const result = await NBRouter.open({ module, func, params });

// ❌ 反模式：让调用方传平台
const result = await NBRouter.open({ module, func, params, platform: 'rn' });
```

detectPlatform() 封装在内部，运行时自动判断，SDK 对调用方透明。

### 3.2 Optional Peer Dependencies + 动态导入

Harlan 不强制依赖，而是用 optional peerDependencies + 动态 import 处理可选依赖：

```ts
// 动态导入，不在非 RN 环境报错
const { callNative } = await import('rn-callnative');
```

这让同一个 SDK 可以在 RN、H5、小程序三端无感安装。

### 3.3 单包优于分包

行业对比后 Harlan 选择单包：

| 考量           | 结论                              |
| -------------- | --------------------------------- |
| 用户体验       | 一个 import，不需要感知平台       |
| 维护成本       | 单仓库，公共代码不重复            |
| 设计初衷符合度 | "平台分发"本身就是 SDK 的核心价值 |

参考：微信、抖音 JS SDK 都是单包。

### 3.4 新增模块有标准 SOP

Harlan 会将扩展路径标准化，降低团队协作成本：

```
Step 1: 实现 Service（遵守 Protocol）
Step 2: 注册到 AppManager
Step 3: 添加 RN 通知监听
Step 4: 添加 H5 methodList 分发
```

这说明他有**流程文档化**的习惯，模块扩展是可以 copy-paste 的 SOP，不是靠口头约定。

### 3.5 目录结构即架构表达

Harlan 的目录结构本身就是架构的外在表达：

```
src/
├── core/       # 平台无关的核心逻辑（类型、校验、检测）
├── modules/    # 功能模块（NBRouter、Device、Ble...）
├── bridges/    # 平台适配层（rn、h5、mini、mock）
└── utils/      # 工具函数
```

**目录命名语义化，职责边界清晰**。看目录结构就能理解架构意图。

### 3.6 Mock Bridge 作为一等公民

在 bridges/ 里预留了 `mock.ts`，说明 Harlan 在设计阶段就考虑了**可测试性**，开发/测试环境不需要真实原生环境也能跑通。

---

## 四、文档化风格

### 4.1 调用链驱动的文档结构

Harlan 的文档**按调用链顺序组织**，不按模块组织：

```
1. SDK 入口 → 2. 协议解析 → 3. 平台分发 → 4. Bridge → 5. 原生服务 → 6. 完整调用链
```

这让读者能沿着一次请求的完整路径理解系统，比"模块 A"、"模块 B"平铺更直观。

### 4.2 贯穿示例（Running Example）

文档开头就声明贯穿示例：`NBScanner.openQRScan`，之后所有代码片段都围绕这个例子展开。读者不会在"抽象概念"和"具体代码"之间来回跳跃。

### 4.3 Mermaid 流程图 + Sequence Diagram 双视角

- Flowchart：展示分发决策流程
- Sequence Diagram：展示完整时序（包括异步回调路径）

两种图配合，覆盖"做什么"和"怎么做"两个维度。

### 4.4 对比表格辅助决策

重要的架构决策（单包 vs 分包）都有对比表格，不只写结论，还写推导过程。

---

## 五、Claude 在为 Harlan 设计时应遵守的规则

### 5.1 必须做

- **先定义接口/协议，再写实现**：TypeScript interface 或 Swift protocol 先行
- **标准化消息格式**：输入输出统一结构，不允许各处自定义
- **分层清晰**：明确每层职责，层间通过协议通信
- **统一入口**：无论内部多复杂，对外暴露最少 API
- **SOP 化扩展路径**：新增模块/功能的步骤要能被 copy-paste 复用
- **文档按调用链组织**：从入口到出口，沿请求路径展开

### 5.2 不应该做

- 让调用方感知平台差异（不要 `if platform === 'rn'` 暴露在外部）
- 强制依赖可选模块（应用 optional peer + 动态导入）
- 跨层直接调用（不能 SDK 层直接 import 原生 Service）
- 文档只写结论不写推导（重要决策要有对比分析）
- 模块扩展靠口头约定（必须有文档化 SOP）

### 5.3 推荐补充（Harlan 风格的延伸）

以下是在 Harlan 现有风格基础上，值得加入的增强点：

**① 错误分类与错误码体系**

现有 `NBRouterResult.error` 只是字符串，建议：

```ts
interface NBRouterError {
  code: ErrorCode;   // 枚举：INVALID_REQUEST / PLATFORM_NOT_SUPPORTED / NATIVE_ERROR / TIMEOUT
  message: string;
  cause?: unknown;
}
```

统一错误码让调用方能精确处理，也方便日志分析。

**② 中间件/拦截器机制**

在 dispatch 前后可以插入 middleware，比如：

```ts
NBRouter.use(loggingMiddleware);
NBRouter.use(authMiddleware);
NBRouter.use(metricsMiddleware);
```

不改动核心分发逻辑，就能扩展能力（日志、鉴权、埋点）。

**③ 超时与重试策略**

Promise 默认不超时，原生调用可能 hang 住。建议在 Bridge 层加超时：

```ts
const result = await withTimeout(callNative(request), 5000);
```

**④ 请求队列 / 并发控制**

某些原生能力（如摄像头）不支持并发，可在 Bridge 层加队列：

```ts
class QueuedBridge {
  private queue = new PQueue({ concurrency: 1 });
  call(req) { return this.queue.add(() => callNative(req)); }
}
```

**⑤ 版本协商机制**

跨 App 版本调用时，原生能力可能不存在。可在 module/func 注册时加 minVersion：

```ts
{ module: 'scanner', func: 'openQRScan', minAppVersion: '6.6.9' }
```

SDK 在分发前校验，给出友好降级而非 crash。

---

## 六、快速参考卡片

```
Harlan 设计三问（设计任何新功能时先问）：

1. 调用方需要知道什么？（最小化暴露）
2. 层的边界在哪里？（协议定义边界）
3. 新人怎么扩展这个功能？（SOP 化）
```

```
标准消息结构（任何跨层通信都用这套）：

Request:  { module, func, params? }
Response: { success, data?, error? }
```

```
目录结构模板：

src/
├── core/      # 类型、校验、检测（平台无关）
├── modules/   # 功能模块（对外 API）
├── bridges/   # 平台实现（rn/h5/mini/mock）
└── utils/     # 工具
```