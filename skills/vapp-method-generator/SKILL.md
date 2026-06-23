---
name: vapp-method-generator
description: Generate or update Ninebot iOS VApp native methods and services. Use when adding a Swift VApp API, creating a VApp-backed pod under ios/Modules, exposing native methods through NBVAppManager/NBUnifiedAPIRegistry, wiring registrations in RootVCService+vapp.swift, or converting RN/callnative methods to the VApp service pattern.
---

# VApp Method Generator

## Overview

Add VApp methods with the same shape as the Ninebot iOS modules: protocol-oriented service, singleton service implementation, `NBVAppManager` registration, `NBUnifiedAPIRegistry` method registration, pod integration only when needed, and a real build check.

## Workflow

1. State assumptions before editing.
   Include the target module or pod, method names, parameter shape, callback payload, and whether this is a new pod or an existing VApp service.

2. Read local patterns first.
   Inspect nearby services and podspecs with `rg`, `find`, and `sed`. Prefer examples such as:
   - `ios/Modules/NBDynamicModule/NBDynamicModule/Classes/NBDynamicModuleService.swift`
   - `ios/Modules/NBScanner/NBScanner/Classes/NBScannerService.swift`
   - `ios/Modules/SettingSearch/Classes/NBSettingSearchService.swift`
   - `ios/Ninebot/RootVCService+vapp.swift`

3. Implement the smallest compatible shape.
   First decide whether the target pod already exists:
   - No pod exists for this capability: create the pod directory, podspec, protocol file, service file, and `Classes` folder.
   - A pod/service already exists: do not create another pod; add only the requested protocol method, service method, and registry handler.

4. Wire the service.
   Add the pod to `Podfile` only when creating a new pod. Import the module and call `NB...Reg.register()` in `RootVCService+vapp.swift` only when the service is new or not already registered.

5. Verify.
   Run syntax/spec checks first, then `pod install` if pod wiring changed, then build the narrowest target available.

## Code Shape

For a complete new-pod example, inspect or copy from `assets/NBSystemDevice`. It shows a minimal pod with:

- `NBSystemDevice.podspec`
- `Classes/NBSystemDeviceProtocol.swift`
- `Classes/NBSystemDeviceService.swift`

Use this direct service shape by default unless the local module has a stronger pattern. `NBUnifiedAPIRegistry.shared.register` already provides a completion block for the JS bridge, so do not add another block to the service method unless the native work really needs it:

```swift
import Foundation
import NBVAppManager
import NBVAppProtocol

@objc public final class NBExampleService: NSObject, NBExampleProtocol {
    public static let shared: NSObject = NBExampleService()
    @objc public static let serviceName: String = "NBExampleService"

    private override init() {
        super.init()
    }

    public func methodName(_ value: String) -> String {
        return value
    }
}

public enum NBExampleReg: NBServiceRegistrable {
    public static func register() {
        NBVAppManager.shared.register(NBExampleService.self, as: NBExampleProtocol.self)

        NBUnifiedAPIRegistry.shared.register("methodName", ownerServiceName: NBExampleService.serviceName) { params, completion in
            guard let service = NBExampleService.shared as? NBExampleProtocol else {
                completion(["code": "-1", "message": "example service unavailable"])
                return
            }

            guard let value = params?["value"] as? String else {
                completion(["code": "-1", "message": "invalid value"])
                return
            }

            completion(["result": service.methodName(value)])
        }
    }
}
```

Use this protocol shape for a new service protocol:

```swift
import Foundation
import NBVAppProtocol

@objc public protocol NBExampleProtocol: NBBaseServiceProtocol {
    func methodName(_ value: String) -> String
}

extension NBExampleProtocol {
    public static var registrarName: String? {
        return "NBExampleReg"
    }
}
```

Only use a completion/block in the service method when the underlying work is naturally asynchronous or an existing protocol already requires it, such as network requests, BLE command response callbacks, scanner UI callbacks, album writes, authorization flows, or file IO that reports later. For local reads/writes such as clipboard, theme mode, local flags, or cached values, return the value directly and let the unified API handler wrap it for JS.

Use this minimal podspec shape for a new local pod:

```ruby
Pod::Spec.new do |s|
  s.name             = 'NBExample'
  s.version          = '1.0.0'
  s.summary          = 'NBExample module'
  s.description      = 'NBExample module provides VApp APIs.'
  s.homepage         = 'https://git.ninebot.com/iOS/ninebot_6'
  s.license          = 'MIT'
  s.author           = 'MIT'
  s.source           = { :path => '.' }
  s.ios.deployment_target = '11.0'
  s.swift_versions = '5.0'
  s.source_files = 'Classes/**/*.{swift,h,m}'
  s.dependency 'NBVAppProtocol'
  s.dependency 'NBVAppManager'
end
```

## Conventions

- Keep changes surgical. Do not modify bridge runtime, permission center, generated Pods files, or unrelated RN code unless the request requires it.
- Keep service APIs simple. Since `NBUnifiedAPIRegistry.shared.register` already has a completion block, do not add a service-level block for synchronous work.
- Prefer the local module's existing return keys. Common keys are `result`, `success`, `text`, or the domain field name.
- For lightweight native reads/writes such as clipboard, theme mode, local flags, or cached values, return directly from the service method.
- Keep UIKit and pasteboard APIs on the simplest safe path. Do not add a queue hop unless the API truly requires it.
- Return dictionaries from `NBUnifiedAPIRegistry` handlers; use `["code": "-1", "message": "..."]` for validation/service errors.
- Preserve user changes in dirty worktrees. Mention unrelated dirty files instead of reverting them.
- Do not edit `Pods/NBVAppProtocol` directly unless the user explicitly asks to patch installed pods. Prefer adding protocols in local module source or the appropriate protocol source package.

## Verification Commands

Run the checks that match the change:

```bash
pod ipc spec ios/Modules/NBExample/NBExample.podspec >/tmp/NBExample.podspec.json
ruby -c ios/Podfile
pod install
xcodebuild -quiet -workspace ios/Ninebot.xcworkspace -scheme NBExample -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

If no dedicated pod scheme exists, run `xcodebuild -list -workspace ios/Ninebot.xcworkspace` and choose the narrowest relevant scheme before considering a full app build.
