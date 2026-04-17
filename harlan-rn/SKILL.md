---
name: harlan-rn-architecture
description: Harlan RN 容器架构特化规范 — 基于 harlan-architecture-philosophy 的 RN 桥接层具体实现模板。
extends: harlan-architecture-philosophy
origin: custom
---

# Harlan RN 架构设计规范

> 本 skill 是 `harlan-architecture-philosophy` 在 RN 容器项目上的特化。
> 通用设计原则见父级 skill，本文件仅包含 RN 桥接层的具体约定和迁移模板。

---

## RN 模块设计模式

### 核心组件

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

### 分发流程

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

---

## 迁移模板

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

// 注册
RNMethodDispatcher.shared.register(RNXXXHandler.self)
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

| 文件 | 职责 |
|------|------|
| `RNMethodError.swift` | 错误类型枚举 |
| `RNMethodHandler.swift` | 方法处理协议 + 注册结构体 |
| `RNMethodDispatcher.swift` | 核心分发器（单例） |
