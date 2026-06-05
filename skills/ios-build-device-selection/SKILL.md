---
name: ios-build-device-selection
description: Prefer device 00008150-001A69800138401C for xcodebuild. If that device is unavailable, fall back to an available iPhone 17 simulator.
---

# iOS Build Device Selection

Use this skill when building the RNContainer iOS app with xcodebuild.

## Goal

Always choose the build destination in this order:

1. Check whether device id 00008150-001A69800138401C exists in the current Xcode device list.
2. If it exists, use that exact device id for the build.
3. If it does not exist, choose an available simulator whose name is exactly iPhone 17.

## Workflow

### 1. Check the preferred device first

Run:

```bash
xcrun xctrace list devices
```

If the output contains 00008150-001A69800138401C, build with:

```bash
cd ios && xcodebuild -workspace RNContainer.xcworkspace -scheme RNContainer -configuration Debug -destination 'id=00008150-001A69800138401C' build
```

### 2. Fall back to an iPhone 17 simulator

If the preferred device id is missing, run:

```bash
xcrun simctl list devices available
```

Choose a simulator whose displayed name is exactly iPhone 17.

Selection rules:

- Prefer a Booted iPhone 17 simulator if present.
- Otherwise prefer the highest available iOS version.
- If multiple entries still match, prefer the arm64 destination reported by xcodebuild.

Then build with that simulator id:

```bash
cd ios && xcodebuild -workspace RNContainer.xcworkspace -scheme RNContainer -configuration Debug -sdk iphonesimulator -destination 'id=<IPHONE_17_SIMULATOR_ID>' build
```

### 3. If no iPhone 17 simulator exists

Do not silently switch to another simulator family.

Report that no iPhone 17 simulator is available and suggest creating one in Xcode or with simctl.

## Output Requirements

When reporting the build attempt, include:

- whether 00008150-001A69800138401C was found
- the final chosen destination id
- whether the build used a physical device or simulator
- the final xcodebuild exit status

## Min iOS Version Notes

If the user asks where to change the minimum iOS version, explain these control points:

1. Pod platform baseline is declared in ios/Podfile.
2. App target deployment target is declared in ios/RNContainer.xcodeproj/project.pbxproj.
3. Local pod minimum versions are declared in each podspec under ios/Frameworks.

In this repository specifically, changing only one of those locations can leave the project in an inconsistent state.