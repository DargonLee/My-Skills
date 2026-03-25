---
name: my-swift-skill
description: Swift 代码风格规范
---

# Swift 代码风格规范（SKILL）

> 本规范从实际项目代码中提炼，适用于所有 Swift 模块的编写与维护。
> 目标是让代码**可读、可测、线程安全、行为可预期**。

---

## 一、类型设计

### 1.1 值类型 vs 引用类型

| 场景 | 类型 |
|------|------|
| 输入参数、配置、快照等不可变数据 | `struct` |
| 有状态、需要引用语义（`===` 比较）的运行时对象 | `final class` |
| 有限集合的状态/类型枚举 | `enum` |
| 能力边界抽象 | `protocol` |

```swift
// ✅ 输入参数用 struct
struct RegisterPagePayload {
    let pageId: String
    let config: PageConfig
}

// ✅ 运行时对象用 final class
final class CompiledPage {
    let pageId: String
    var lastSnapshot: PageSnapshot?
}

// ✅ 输出快照用 struct（不可变，跨层传递）
struct PageSnapshot {
    let nodeValues: [[String: Any]]
    let nodeStates: [[String: Any]]
}

// ✅ 错误/状态/类型 用 enum
enum NavigationDestination {
    case webView(url: String)
    case custom(url: String)
}
```

### 1.2 所有具体类标注 final

```swift
// ✅ 不打算被继承的类一律加 final
final class PageRegistry { ... }

// ❌ 缺少 final，暗示可被继承，造成误导
class PageRegistry { ... }
```

### 1.3 访问控制最小化原则

- 对外暴露的 API 加 `public`
- 模块内部跨文件共享保持默认 `internal`（可不写）
- 仅在本文件使用加 `private` 或 `fileprivate`
- **能收窄就收窄，不确定时先用 `private`**

```swift
public final class BridgeCenter {        // 对外 API 入口
    public static let shared = BridgeCenter()
    private init() {}

    public func refresh() { ... }        // 对外方法
    private func internalSetup() { ... } // 内部实现
}
```

---

## 二、单例

### 2.1 标准写法

```swift
final class PageRegistry {
    static let shared = PageRegistry()
    private init() {}
}

// NSObject 子类同理
final class HostProvider: NSObject {
    static let shared = HostProvider()
    private override init() {}
}
```

- `static let` 保证线程安全的懒加载（Swift 语言保证）。
- `private init()` 封闭构造路径，禁止外部创建实例。
- **不使用 `dispatch_once` 或手动加锁**，`static let` 已足够。

### 2.2 单例不承担依赖注入

单例只持有实例，具体依赖通过显式方法注入，不在 `init` 里互相引用：

```swift
// ✅ 通过 configure 注入依赖
final class PageRegistry {
    static let shared = PageRegistry()
    var context: RuntimeContext?

    func configure(with context: RuntimeContext) {
        self.context = context
    }
}

// ❌ 在 init 里访问其他单例，产生隐式耦合
final class PageRegistry {
    static let shared = PageRegistry()
    private init() {
        self.context = RuntimeContext.shared  // 不推荐
    }
}
```

---

## 三、协议设计

### 3.1 能力协议加 AnyObject 约束

```swift
// ✅ 限制为引用类型，防止值类型实现时生命周期混乱、weak 引用无法使用
public protocol CacheProvider: AnyObject {
    func value(for key: String) -> Any?
    func setValue(_ value: Any?, for key: String)
}

// ❌ 缺少 AnyObject，值类型也能实现，weak 将无法使用
public protocol CacheProvider {
    func value(for key: String) -> Any?
}
```

### 3.2 协议方法写 /// 文档注释

```swift
public protocol BluetoothProvider: AnyObject {
    /// 当前是否已连接
    var isConnected: Bool { get }

    /// 创建命令模型
    /// - Parameters:
    ///   - name: 命令名称
    ///   - value: 命令值，nil 表示只读
    /// - Returns: 命令模型，创建失败返回 nil
    func createCommand(_ name: String, value: Int?) -> CommandModel?
}
```

### 3.3 写操作协议加 @discardableResult

返回值代表操作是否成功，但调用方不一定需要处理时加 `@discardableResult`：

```swift
public protocol LogicProvider: AnyObject {
    func value(for id: String) -> Any?

    @discardableResult
    func setValue(_ value: Any?, for id: String) -> Bool
}
```

### 3.4 协议只定义能力边界，不包含默认实现

实现细节放在具体类里，避免 `protocol extension` 隐藏行为、干扰阅读。

---

## 四、依赖注入与生命周期

### 4.1 强引用 vs 弱引用的选择原则

| 场景 | 选择 | 理由 |
|------|------|------|
| 父对象持有子对象 | `strong`（默认） | 父对象负责子对象生命周期 |
| 子对象引用父对象（避免循环引用） | `weak` | 父对象不由子对象延长生命周期 |
| 注入的依赖，两者生命周期独立 | 视情况，并在注释里说明 | 防止意外释放或循环引用 |

注入的依赖如果持有强引用，**必须在注释里说明为什么不会循环**：

```swift
/// 运行时上下文（由外部注入）
/// 持有强引用：注入方（Host）与本类均为单例，不存在循环引用风险。
var context: RuntimeContext?
```

### 4.2 闭包捕获列表

- 闭包持有 `self` 时根据需要选择 `weak` 或 `unowned`
- **优先用 `weak`，避免 `unowned` 带来的崩溃风险**
- 同时捕获多个对象时，一并列在捕获列表里

```swift
// ✅ 同时 weak 捕获 self 和相关业务对象
executor.refresh { [weak self, weak page] in
    guard let self, let page else { return }
    self.handleResult(page: page)
}

// ❌ 不加捕获列表，可能循环引用或野指针
executor.refresh {
    self.handleResult()
}
```

---

## 五、线程安全

### 5.1 并发读写用并发队列 + barrier

```swift
private let queue = DispatchQueue(
    label: "com.example.module.state",
    attributes: .concurrent
)
private var data: [String: Any] = [:]

// 读：并发 sync（允许多个读者同时进入）
func value(for key: String) -> Any? {
    queue.sync { data[key] }
}

// 写（无需返回值）：异步 barrier（不阻塞调用线程）
func setValue(_ value: Any?, for key: String) {
    queue.async(flags: .barrier) {
        self.data[key] = value
    }
}

// 写（需要返回值）：同步 barrier
@discardableResult
func removeValue(for key: String) -> Any? {
    var removed: Any?
    queue.sync(flags: .barrier) {
        removed = self.data.removeValue(forKey: key)
    }
    return removed
}
```

**禁止**：在串行队列里对同一队列调用 `sync`（必然死锁）。

### 5.2 主线程操作必须显式保证

涉及 UI、Timer、RunLoop 的操作必须在主线程执行，非主线程时主动切换：

```swift
func startTimer(for item: TimerItem) {
    // 非主线程时切换后重试，不直接在当前线程执行
    guard Thread.isMainThread else {
        DispatchQueue.main.async { [weak self, weak item] in
            guard let self, let item else { return }
            self.startTimer(for: item)
        }
        return
    }
    // 在主线程安全创建 Timer
    let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in ... }
    RunLoop.main.add(timer, forMode: .common)
}
```

### 5.3 只在固定线程访问的变量，注释说明

```swift
// lastFired 仅在主线程（Timer 回调）中访问，无需额外加锁。
var lastFired = [Int: TimeInterval]()
```

### 5.4 RCTEventEmitter / ObjC 桥接初始化

init 可能不在主线程时，静态状态赋值需要主线程保护：

```swift
override init() {
    super.init()
    // init 可能不在主线程，静态属性赋值需保证在主线程执行以与后续访问保持一致。
    if Thread.isMainThread {
        Self.currentInstance = self
    } else {
        DispatchQueue.main.async { Self.currentInstance = self }
    }
}
```

---

## 六、异步与回调

### 6.1 保证回调只调用一次：CompletionBox 模式

所有"可能从多个路径触发"的回调（如超时 + 正常响应双路径），用加锁的 Box 封装：

```swift
private final class CompletionBox<T> {
    private var isCompleted = false
    private let lock = NSLock()
    private let completion: (T) -> Void

    init(_ completion: @escaping (T) -> Void) {
        self.completion = completion
    }

    func resolve(_ value: T) {
        lock.lock()
        guard !isCompleted else { lock.unlock(); return }
        isCompleted = true
        lock.unlock()
        completion(value)
    }
}

// 使用
let box = CompletionBox<Result<Void, Error>>(completion)
model.onSuccess = { box.resolve(.success(())) }
model.onFailure = { box.resolve(.failure(someError)) }
// 超时路径同样调用 box.resolve，CompletionBox 保证只有第一次生效
```

**不允许**裸调 completion 后，还有其他路径也能触发它。

### 6.2 超时用可取消的 DispatchWorkItem

```swift
// ✅ 成功时取消超时，避免多余执行
var timeoutWork: DispatchWorkItem?

model.onSuccess = { [weak box] in
    timeoutWork?.cancel()
    box?.resolve(.success(()))
}
model.onFailure = { [weak box] in
    timeoutWork?.cancel()
    box?.resolve(.failure(TimeoutError()))
}
model.send()

let work = DispatchWorkItem { [weak box] in
    box?.resolve(.failure(TimeoutError()))
}
timeoutWork = work
DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)

// ❌ asyncAfter 不可取消，成功后超时仍会触发一次
DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
    box.resolve(.failure(TimeoutError()))
}
```

### 6.3 异步回调里检查对象是否仍然有效

```swift
someAsyncOperation { [weak self, weak target] result in
    guard let self, let target else { return }
    // 用 === 检查对象身份，防止 id 相同但对象已被替换
    guard self.isActive(target) else { return }
    self.handleResult(result)
}

// isActive 用 === 比较，不是 id 比较
func isActive(_ page: CompiledPage) -> Bool {
    return pages[page.pageId] === page
}
```

---

## 七、错误处理

### 7.1 错误类型用 LocalizedError 枚举

```swift
enum ModuleError: LocalizedError {
    case notFound(String)
    case invalidInput(String)
    case timeout(String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):       return "[MyModule] not found: \(id)"
        case .invalidInput(let msg):  return "[MyModule] invalid input: \(msg)"
        case .timeout(let cmd):       return "[MyModule] timed out: \(cmd)"
        case .operationFailed(let m): return "[MyModule] failed: \(m)"
        }
    }
}
```

- 错误信息加模块名前缀，方便日志过滤。
- 不使用 `NSError`，不 `throw` 裸字符串。
- 每个 case 携带上下文信息（id、command、message 等）。

### 7.2 用 Result 类型表达异步操作结果

```swift
// ✅ 用 Result，语义清晰，调用方强制处理成功/失败两条路径
func loadData(completion: @escaping (Result<Data, Error>) -> Void) { ... }

// ❌ 双可选参数，调用方需手动判断哪个有值
func loadData(completion: @escaping (Data?, Error?) -> Void) { ... }
```

### 7.3 提前返回（Early Return）处理错误路径

```swift
// ✅ 先处理异常路径，主逻辑保持平坦
func process(payload: Payload, completion: @escaping (Result<Void, Error>) -> Void) {
    guard !payload.id.isEmpty else {
        completion(.failure(ModuleError.invalidInput("id is empty")))
        return
    }
    guard let page = pages[payload.id] else {
        completion(.failure(ModuleError.notFound(payload.id)))
        return
    }
    doMainWork(page: page, completion: completion)
}

// ❌ 嵌套 if-else，主逻辑被埋在深处
func process(payload: Payload, completion: @escaping (Result<Void, Error>) -> Void) {
    if !payload.id.isEmpty {
        if let page = pages[payload.id] {
            doMainWork(page: page, completion: completion)
        } else { completion(.failure(...)) }
    } else { completion(.failure(...)) }
}
```

---

## 八、数据解码

### 8.1 解码逻辑放在 Payload 的 static func 里

输入参数的解码和校验放在对应结构体的静态方法里，调用方只负责传参和处理结果：

```swift
struct RegisterPayload {
    let pageId: String
    let config: PageConfig

    static func decode(from params: [String: Any]) throws -> RegisterPayload {
        // 必填字段：错误信息携带方法名和字段名
        guard let pageId = params["pageId"] as? String, !pageId.isEmpty else {
            throw ModuleError.invalidInput("RegisterPayload missing pageId")
        }
        guard let configDict = params["config"] as? [String: Any] else {
            throw ModuleError.invalidInput("RegisterPayload missing config")
        }
        let config = try PageConfig.decode(from: configDict)
        return RegisterPayload(pageId: pageId, config: config)
    }
}

// 调用方
func handleRegister(_ params: [String: Any]) {
    do {
        let payload = try RegisterPayload.decode(from: params)
        doRegister(payload: payload)
    } catch {
        handleError(error)
    }
}
```

### 8.2 可选字符串用 nilIfEmpty 扩展处理

```swift
private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// ✅ 简洁
let logicId = (params["logicId"] as? String)?.nilIfEmpty

// ❌ 冗长的三目表达式
let logicId: String?
if let s = params["logicId"] as? String, !s.isEmpty { logicId = s } else { logicId = nil }
```

### 8.3 Decodable 解码错误携带字段路径

```swift
private func describeDecodingError(_ error: DecodingError) -> String {
    switch error {
    case .keyNotFound(let key, let ctx):
        let path = (ctx.codingPath + [key]).map(\.stringValue).joined(separator: ".")
        return "missing key: \(path)"
    case .typeMismatch(_, let ctx):
        let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
        return "type mismatch at: \(path) — \(ctx.debugDescription)"
    case .valueNotFound(_, let ctx):
        let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
        return "missing value at: \(path)"
    case .dataCorrupted(let ctx):
        return "corrupted data: \(ctx.debugDescription)"
    @unknown default:
        return "unknown decoding error"
    }
}
```

---

## 九、文件组织

### 9.1 MARK 分区顺序

每个文件用 `// MARK: -` 划分逻辑分区，推荐顺序：

```swift
// MARK: - 属性
// MARK: - 初始化
// MARK: - 对外 API
// MARK: - 内部方法
// MARK: - Private
```

### 9.2 大类拆分为 extension 文件

单文件超过约 300 行时，按功能拆分为多个 extension 文件，命名格式：`类名+功能.swift`：

```
PageRegistry.swift              // 核心属性 + 初始化 + 主要入口
PageRegistry+Actions.swift      // 写操作、跳转等动作处理
PageRegistry+Lifecycle.swift    // 生命周期（Timer、前后台）
PageRegistry+Refresh.swift      // 刷新流水线
```

### 9.3 类/协议顶部写 /// 职责注释

第一行说"是什么"，第二行说"设计约束"（可选）：

```swift
/// 页面注册中心
/// 管理所有页面的生命周期，负责节点状态刷新和事件分发。
final class PageRegistry { ... }

/// 缓存数据提供者协议
/// 抽象全局缓存和网络缓存的读写操作，解耦对具体缓存 SDK 的依赖。
public protocol CacheProvider: AnyObject { ... }
```

---

## 十、注释规范

### 10.1 注释解释"为什么"，不重复"是什么"

```swift
// ❌ 废话注释（代码本身已经够清晰）
// 将 value 赋值给 pages[pageId]
pages[pageId] = value

// ✅ 说明非显而易见的原因
// 必须用 sync(flags: .barrier) 而非 async，因为调用方需要同步获取返回值。
stateQueue.sync(flags: .barrier) {
    removed = pages.removeValue(forKey: pageId)
}
```

### 10.2 重要设计决策写内联注释

影响正确性的决策（线程要求、优先级顺序、生命周期约定等）必须注释：

```swift
// String 必须优先于 Bool 转换：
// 防止 toBool 对 "0"/"on" 等字符串提前返回非 nil，
// 导致本该输出字符串的节点被错误转成布尔值。
if let stringValue = transform.toString(descriptor) { return stringValue }
if let boolValue   = transform.toBool(descriptor)   { return boolValue }
```

### 10.3 TODO / FIXME 格式统一

```swift
// TODO: 描述待做事项及影响范围
// TODO: hashValue 不稳定，跨进程持久化场景需改为确定性 hash（FNV-32）

// FIXME: 描述已知问题及触发条件
// FIXME: 未注册 contextProvider 时此处会兜底，应在文档中说明依赖关系
```

---

## 十一、日志规范

### 11.1 统一格式

```swift
NSLog("[模块名] 事件名 key1=%@ key2=%ld", value1, value2)

// 示例
NSLog("[MyModule] registerPage pageId=%@ nodeCount=%ld", pageId, nodes.count)
NSLog("[MyModule] refresh skipped reason=bluetooth_disconnected")
NSLog("[MyModule] write timed out after %.0fms command=%@", timeout * 1000, cmd)
```

- 前缀固定：`[模块名]`，方便 Console 过滤
- 事件名小驼峰
- 参数用 `key=value` 格式，多参数空格分隔

### 11.2 高频路径加 Debug 开关

Timer 回调、数据接收等高频路径的日志加编译条件，避免 Release 包性能损耗：

```swift
private func log(_ format: String, _ args: CVarArg...) {
    #if DEBUG
    NSLog("[MyModule] " + format, args)
    #endif
}
```

---

## 十二、编译期索引优化

对于"根据某个 key 快速查找关联对象"的场景，在初始化时构建反向索引，避免运行时遍历：

```swift
final class CompiledPage {
    // 编译期构建：BLE command → 依赖该 command 的节点 ID 集合
    let commandToNodeIds: [String: Set<String>]
    // 编译期构建：context key → 节点 ID 集合
    let contextKeyToNodeIds: [String: Set<String>]

    init(nodes: [ResolvedNode]) {
        self.commandToNodeIds    = Self.buildCommandIndex(from: nodes)
        self.contextKeyToNodeIds = Self.buildContextKeyIndex(from: nodes)
    }

    private static func buildCommandIndex(from nodes: [ResolvedNode]) -> [String: Set<String>] {
        nodes.reduce(into: [:]) { index, node in
            guard let cmd = node.valueCommand, !cmd.isEmpty else { return }
            index[cmd, default: []].insert(node.id)
        }
    }

    // 查询时 O(1)，不再每次遍历所有节点
    func affectedNodes(forCommand cmd: String) -> Set<String> {
        commandToNodeIds[cmd] ?? []
    }
}
```

新增属性时，如果影响"哪些节点需要刷新"的判断，必须同步更新对应的 `build*Index` 方法。

---

## 十三、新增代码 Checklist

每次新增功能时，依次核查：

- [ ] 新类是否标注了 `final`？
- [ ] 访问控制是否最小化（能 `private` 就不用 `internal`）？
- [ ] 协议是否加了 `: AnyObject` 约束？
- [ ] 闭包是否有正确的捕获列表（`[weak self]` 等）？
- [ ] 持有强引用的注入依赖是否在注释里说明了不循环引用的理由？
- [ ] 多路径可触发的回调是否用 `CompletionBox` 保证幂等？
- [ ] 超时是否用可取消的 `DispatchWorkItem`？
- [ ] Timer 创建是否确保在主线程？
- [ ] 共享状态的读写是否用并发队列 + barrier？
- [ ] 异步回调里是否有对象活跃性检查（`===` 身份比较）？
- [ ] 错误信息是否携带了足够的上下文（id、command、message 等）？
- [ ] 高频路径的日志是否加了 `#if DEBUG` 开关？
- [ ] 重要的设计决策是否有内联注释说明原因？
