---
name: vapp-skill
description: VApp Native Bridge Runtime 架构文档。解释 VApp 的事件驱动 Native Bridge 设计，包括 TurboModule、NotificationCenter 分发、Protocol-oriented 服务查找。当用户提及 VApp、RN Bridge、Native Bridge、TurboModule、callNative 时自动触发。
---

# VApp Native Bridge Runtime Skill

## Overview

VApp uses an event-driven Native Bridge architecture.

The JS layer never directly invokes Objective-C business classes.
Instead, all calls go through a unified TurboModule bridge + NotificationCenter dispatch system.

The architecture is designed to provide:

* Dynamic module dispatch
* Decoupled business implementations
* Protocol-oriented service lookup
* Runtime extensibility
* Cross-platform bridge consistency

---

# Core Runtime Flow

```text
JS
↓
callNative({ module, func, params })

RTNNBTurboModule.callNative()
↓
NSNotificationCenter post("RNCallNativeNotifacation")

RNCommonModule.note()
↓
dynamic selector dispatch

Concrete RN Module
↓
Business Service Lookup

NBVAppManager.service(protocol)
↓
Concrete Service Implementation

Business executes
↓
NSNotificationCenter post("RNCallBackNotifacation")

RTNNBTurboModule.callBack()
↓
resolve(result)
↓
JS Promise resolved
```

---

# Detailed Call Chain

## 1. JS Layer

JS initiates a native call through a unified bridge API:

```ts
callNative({
  module: 'ProtocolBridge',
  func: 'readValues',
  params,
})
```

Characteristics:

* module: target native module
* func: target native method
* params: serializable payload
* returns Promise

---

## 2. TurboModule Entry

```objc
RTNNBTurboModule.callNative()
```

Responsibilities:

* Receive JS invocation
* Convert payload
* Post bridge notification
* Manage callback lifecycle
* Maintain Promise resolve/reject mapping

This layer does NOT contain business logic.

---

## 3. Notification Dispatch

```objc
NSNotificationCenter
postNotificationName:@"RNCallNativeNotifacation"
```

Payload:

* module
* func
* params
* callbackId

Purpose:

* Completely decouple JS bridge from business modules
* Allow runtime dynamic module registration

---

## 4. RNCommonModule Dynamic Dispatch

All bridge modules inherit from:

```objc
RNCommonModule
```

Each module listens to:

```objc
RNCallNativeNotifacation
```

Core logic:

```objc
selector(funcName:)
```

Example:

```objc
readValues:
```

Dynamic runtime dispatch is performed using Objective-C selector reflection.

---

## 5. Glue Layer (Bridge Module)

Example:

```objc
RNProtocolBridgeModule.readValues()
```

Responsibilities:

* Parameter validation
* DTO conversion
* Bridge adaptation
* Service routing

This layer should remain thin.

It should NOT contain real business logic.

---

## 6. Service Locator

```objc
NBVAppManager.service(NBProtocolBridgeProtocol)
```

This acts as a protocol-based dependency resolver.

Characteristics:

* Protocol-oriented architecture
* Runtime service discovery
* Loose coupling
* Replaceable implementations

---

## 7. Business Implementation

Example:

```objc
ProtocolBridgeServiceImpl.readValues()
```

This is the actual business execution layer.

Responsibilities:

* Real business logic
* Data access
* Native capability invocation
* Async task orchestration

---

## 8. Callback Flow

After business execution completes:

```objc
NSNotificationCenter
postNotificationName:@"RNCallBackNotifacation"
```

Then:

```objc
RTNNBTurboModule.callBack()
```

Finally:

```objc
resolve(result)
```

Result returns back to JS Promise.

---

# Architectural Principles

## 1. Event Driven

Bridge communication is based on NotificationCenter.

Advantages:

* Loose coupling
* Dynamic extensibility
* Easier pluginization

---

## 2. Protocol-Oriented Design

Business services are resolved by protocol instead of concrete class.

```objc
service(NBProtocolBridgeProtocol)
```

Advantages:

* Better modularity
* Easier testing
* Replaceable implementations

---

## 3. Thin Bridge Layer

RN modules are glue layers only.

They should NOT:

* Contain business logic
* Access database directly
* Perform complex orchestration

---

## 4. Runtime Dynamic Dispatch

Method dispatch uses Objective-C runtime selectors.

```objc
selector("methodName:")
```

Advantages:

* Dynamic extensibility
* Configurable routing
* Low boilerplate

Tradeoffs:

* Runtime safety reduced
* Requires strict naming conventions

---

# Recommended Layer Responsibilities

| Layer              | Responsibility          |
| ------------------ | ----------------------- |
| JS                 | API invocation          |
| TurboModule        | Bridge transport        |
| NotificationCenter | Event routing           |
| RNCommonModule     | Dynamic dispatch        |
| RNxxxModule        | Glue layer              |
| Service Locator    | Dependency resolution   |
| ServiceImpl        | Business implementation |

---

# Important Conventions

## Selector Naming

All exposed methods must follow:

```objc
methodName:
```

Example:

```objc
readValues:
writeValues:
fetchConfig:
```

---

## Bridge Modules Must Be Stateless

Bridge modules should only:

* Receive payload
* Convert payload
* Forward request

Avoid storing state inside RN modules.

---

## Callback IDs

Every async bridge call should contain:

```text
callbackId
```

Used for Promise resolution mapping.

---

# Example End-to-End Flow

```text
JS
→ callNative()

TurboModule
→ post RNCallNativeNotifacation

RNProtocolBridgeModule
→ readValues:

NBVAppManager
→ resolve service

ProtocolBridgeServiceImpl
→ execute business logic

Service
→ post RNCallBackNotifacation

TurboModule
→ resolve Promise

JS
→ await result
```

---

# Recommended AI Understanding

When generating code for this architecture, AI should follow these rules:

1. Business logic belongs in ServiceImpl
2. RN Modules are glue layers only
3. Communication is notification-driven
4. Service lookup is protocol-oriented
5. JS never directly accesses business services
6. Dynamic selector dispatch is core infrastructure
7. Bridge layer should remain highly generic
8. All async operations return through callback notifications

---

# Typical Extension Flow

To add a new native capability:

1. Add JS API
2. Add RNxxxModule selector method
3. Define Protocol
4. Register ServiceImpl
5. Implement business logic
6. Return callback through notification

No TurboModule modification is required.
