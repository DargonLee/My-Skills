---
name: harlan-rn-architecture
description: Harlan 个人 RN 容器架构设计偏好和思想 - 协议优于继承、拒绝兼容性代码、单一职责原则
origin: custom

---

# Harlan RN 架构设计规范

## 个人设计偏好

### 1. 协议优于继承

- **偏好**：使用协议（protocol）而非继承来实现功能扩展
- **原因**：继承造成强耦合，难以控制方法暴露范围
- **应用**：`RNMethodHandler` 协议替代 `RNCommonModule` 继承

### 2. 拒绝兼容性代码

- **偏好**：不保留旧代码的兼容层，直接迁移
- **原因**：兼容性代码增加复杂度，维护成本高
- **态度**：接受迁移成本，换取干净的架构

### 3. 单一职责原则

- **偏好**：每个组件只做一件事
- **示例**：
  - `RNMethodDispatcher` 只负责分发
  - `NBVAppManager` 只负责服务管理
  - `NBPermissionCenter` 只负责权限检查
- **不允许**：Dispatcher 越权做权限检查

### 4. 显式优于隐式

- **偏好**：显式注册方法，而非自动暴露所有方法
- **旧方式问题**：`@objc` 方法全部可被调用，无法精确控制
- **新方式**：`registeredMethods()` 明确声明暴露的方法

### 5. 性能敏感

- **关注**：O(1) 字典查找 vs O(N) 遍历查找
- **选择**：用注册表字典查找替代每个模块的 responds(to:) 检查
- **理由**：通知 observers 数量从 N 降到 1

### 6. 复用现有系统

- **偏好**：优先复用已有的服务管理框架
- **示例**：调用真实服务时使用 `NBVAppManager.service(for:)`
- **不允许**：重新造轮子

### 7. 简洁的 API

- **偏好**：一行代码完成注册
- **示例**：`RNMethodDispatcher.shared.register(XXXHandler.self)`
- **避免**：冗长的配置和中间对象

---

## RN 模块设计模式

### 核心组件

```
RNMethodDispatcher (单例)
    ├── 接收 RNCallNative 通知
    ├── 字典查找 registrations[methodName] - O(1)
    └── 调用 handler.handle()

RNMethodHandler (协议)
    ├── registeredMethods() -> [String]  // 声明暴露的方法
    └── handle(method:params:completion:)  // 处理调用

NBVAppManager (外部框架)
    └── service(for:) // 获取真实服务实例
```

### 设计原则

1. **注册机制**

   - 模块实现 `RNMethodHandler` 协议
   - 在 `registeredMethods()` 中声明要暴露的方法
   - 调用 `register()` 进行注册

2. **分发流程**

   ```
   RNCallNative 通知
       ↓
   RNMethodDispatcher.handleRNCallNative()
       ↓
   字典查找 registrations[methodName]  ← O(1)
       ↓
   handler.handle(method:params:completion:)
       ↓
   NBVAppManager.service(for:) 获取服务
       ↓
   completion(.success(result))
       ↓
   RNCallBack 通知 → JS 侧
   ```

3. **错误处理**

   - 未注册方法 → `.methodNotFound`
   - 调用失败 → `.invocationFailed`
   - 不静默忽略任何错误

---

## 迁移指南

### 旧代码（继承方式）

```swift
public class RNXXXModule: RNCommonModule {
    @objc func methodA(_ userInfo: RNModel) {
        // 原有逻辑
    }
}
```

### 新代码（协议方式）

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
        // 原有逻辑，最后调用 completion()
    }
}
```

### 迁移步骤

1. 新建 Handler 类，删除继承
2. 实现 `RNMethodHandler` 协议
3. 在 `registeredMethods()` 列出所有方法名
4. `handle()` 中用 switch-case 分发
5. 原有方法改为私有，去掉 `@objc`，参数从 `RNModel` 改为 `params: [String: Any]?`
6. 最后调用 `completion()` 而非 `NotificationCenter.post`

---

## 文件清单

| 文件                         | 职责               |
| ---------------------------- | ------------------ |
| `RNMethodError.swift`        | 错误类型枚举       |
| `RNMethodHandler.swift`      | 方法处理协议       |
| `RNMethodRegistration.swift` | 注册数据结构       |
| `RNMethodDispatcher.swift`   | 核心分发器（单例） |

---

## 架构决策记录

### 决策 1：选择协议而非继承

- **日期**：2026-04-17
- **问题**：`RNCommonModule` 继承方式造成强耦合
- **方案**：实现 `RNMethodHandler` 协议
- **结果**：解耦，方法暴露可控

### 决策 2：不保留兼容性代码

- **日期**：2026-04-17
- **问题**：兼容性代码增加复杂度
- **方案**：方案 B — 纯新架构
- **结果**：迁移成本约 10 + N*5 行/模块

### 决策 3：去除权限检查功能

- **日期**：2026-04-17
- **问题**：权限检查不应在 Dispatcher 层级
- **方案**：权限由 `NBVAppManager` 负责
- **结果**：单一职责，代码更清晰

### 决策 4：复用 NBVAppManager

- **日期**：2026-04-17
- **问题**：每个模块自己调用服务增加重复代码
- **方案**：handler 内部通过 `NBVAppManager.service(for:)` 调用
- **结果**：统一服务管理，减少重复