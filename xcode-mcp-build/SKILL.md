---
name: xcode-mcp-build
description: 通过 Xcode 官方 MCP bridge（xcrun mcpbridge）在 Xcode 里编译 iOS 项目：XcodeListWindows → 选择目标设备（优先已连接真机，无真机时用 Any iOS Device (arm64)）→ BuildProject → GetBuildLog 验证。凡用户要求"用 Xcode 编译"、"build 一下项目"、"用 mcpbridge 编译"、"编译到真机 / Any iOS Device / arm64"，或编译失败后要取 Xcode 构建日志排障时，都使用本技能。
---

# Xcode MCP Bridge 编译（优先真机）

用 Xcode 26.3+ 自带的官方 MCP 服务（`xcrun mcpbridge`，MCP server 名通常为 `xcode`）在真实 Xcode 中触发编译。**优先使用真机编译**，目标设备按以下优先级选择，绝不落到模拟器：

1. **已连接的物理 iPhone**；
2. 没有真机连接时，用 **Any iOS Device (arm64)**（通用真机目标，同样产出真机 arm64 产物）。

**不要**改用 `xcodebuild` 命令行，除非用户明确要求。

## 前置条件（工具连不上时先查这里）

- Xcode ≥ 26.3：`xcrun --find mcpbridge` 能输出路径即满足。
- `xcode-select -p` 指向的 Xcode 必须就是正在运行的那个。机器上装了多个 Xcode（正式版 / beta）时两者不一致，`XcodeListWindows` 会看不到窗口。
- Xcode 需允许外部 agent 使用 Xcode Tools（Settings → Intelligence 里开启）；首次连接会弹授权框，需用户在 Xcode 里点允许。
- 第 2 步的 AppleScript 需要运行它的终端 / 客户端拥有「辅助功能」权限（System Settings → Privacy & Security → Accessibility），否则报 `-1719` 或 `-1743`。

## 关键事实（先读懂再动手）

- `BuildProject` **没有 scheme/destination 参数**：它编译该 Xcode 窗口当前选中的 scheme 和 run destination，并阻塞到编译结束。
- MCP **无法读取**当前选中的 destination。编译前可用第 2 步脚本从 Xcode 菜单的 `✓` 勾选回读；编译后以构建日志为准（见第 4 步验证）。
- mcpbridge 依赖 Xcode 进程存活：Xcode 没开时所有工具都会失败，先 `open <workspace>` 再轮询。
- 部分客户端里 mcpbridge 返回的 inputSchema 是空 `{}`，属已知兼容性问题；照常按下面的参数传，`tabIdentifier` 必填。

## 使用的工具（裸名，客户端可能加 `mcp__xcode__` 前缀）

| 工具 | 参数 | 用途 |
|------|------|------|
| `XcodeListWindows` | 无 | 列出 Xcode 窗口，拿 tabIdentifier |
| `BuildProject` | `tabIdentifier` | 触发编译并等待完成 |
| `GetBuildLog` | `tabIdentifier`，可选 `severity` / `pattern` / `glob` | 取构建日志；响应自带"是否仍在编译中"标志 |

## 标准流程

### 1. 确认工作区已打开，拿到 tabIdentifier

调用 `XcodeListWindows`，输出形如：

```
* tabIdentifier: windowtab1, workspacePath: /Users/.../Ninebot.xcworkspace
```

- 按 workspacePath 匹配目标工作区，取对应 `tabIdentifier`；多个窗口匹配时向用户确认用哪个。
- 目标工作区未打开：`open /path/to/xxx.xcworkspace`，然后每隔几秒重试 `XcodeListWindows`（首次打开要等索引，上限约 60 秒）。
- 工具调用本身报连接失败：按「前置条件」排查，不要反复重试。

### 2. 选择 run destination：优先真机

**可跳过本步**：用户已说明 destination 已选好，或本会话内同一 scheme 已通过第 4 步验证过是真机 / Any iOS Device。

先查有没有连着的真机（用 JSON 解析，别解析文本表格——设备名可能含空格、中文，且可能与模拟器同前缀，如设备就叫 `iPhone`）：

```bash
xcrun devicectl list devices --json-output /tmp/devices.json >/dev/null 2>&1
python3 - <<'PY'
import json
for d in json.load(open('/tmp/devices.json'))['result']['devices']:
    if d['connectionProperties'].get('tunnelState') == 'connected' \
       and d['hardwareProperties'].get('reality') == 'physical':
        print(d['deviceProperties']['name'])
PY
```

每行输出是一台已连接真机的名字（含无线已连接的）；多台时让用户选；无输出表示没有真机。`tunnelState=unavailable` 是配对过但未连接，`reality=simulated` 是模拟器，都不能选。

然后按顺序切换 destination，任一成功即进入第 3 步：

**a. AppleScript 点菜单**（Product → Destination，已在 Xcode 26.3 实测）。要点：

- 按菜单名取（Xcode 菜单为英文；若遇本地化版本找不到会返回 `NOT_FOUND`，走 b）。**不要**按菜单栏位置取：Xcode 菜单栏有 `Find`、`Integrate` 等项，位置会随版本变。
- 设备名**精确匹配**，避免设备名是 `iPhone` 之类时前缀误中；`Any iOS Device` 用前缀匹配（实际条目名为 `Any iOS Device (arm64)`，不会误中 `Any iOS Simulator Device`）。
- 已选中则不点击、不抢焦点；点击后菜单会重排，脚本会按名字重新取条目、轮询回读 `✓`（`AXMenuItemMarkChar`），所以**编译前**就能确认 destination 是否真的切过去了。

```bash
# 参数：真机名（精确匹配）；无真机时传 "Any iOS Device"
osascript - "<设备名 或 Any iOS Device>" <<'AppleScript'
on run argv
  set target to item 1 of argv
  tell application "System Events"
    tell process "Xcode"
      set n to my findName(target)
      if n is missing value then return "NOT_FOUND"
      if my isMarkedByName(n) then return "already: " & n
      tell application "Xcode" to activate
      delay 0.5
      click (first menu item of (my destMenu()) whose name is n)
      -- 切换后菜单会重排且需要时间：按名字重新取条目，轮询最多约 3 秒回读
      repeat 6 times
        delay 0.5
        if my isMarkedByName(n) then return "selected: " & n
      end repeat
      return "CLICKED_BUT_UNVERIFIED: " & n
    end tell
  end tell
end run

on destMenu()
  tell application "System Events" to tell process "Xcode"
    return menu 1 of menu item "Destination" of menu "Product" of menu bar item "Product" of menu bar 1
  end tell
end destMenu

on findName(target)
  tell application "System Events" to tell process "Xcode"
    repeat with sub in menu items of (my destMenu())
      set n to name of sub
      if n is not missing value then
        if n is target or (target is "Any iOS Device" and n starts with "Any iOS Device") then return n
      end if
    end repeat
  end tell
  return missing value
end findName

on isMarkedByName(n)
  tell application "System Events" to tell process "Xcode"
    try
      set mk to value of attribute "AXMenuItemMarkChar" of (first menu item of (my destMenu()) whose name is n)
      return (mk is not missing value) and (mk is not "")
    on error
      return false
    end try
  end tell
end isMarkedByName
AppleScript
```

返回值：

- `already: ...` / `selected: ...`：destination 已确认（回读到 ✓），进入第 3 步；
- `CLICKED_BUT_UNVERIFIED: ...`：点了但 3 秒内没读到 ✓，不能确定，按 c 处理（靠第 4 步日志兜底）；
- `NOT_FOUND`：菜单里没有该条目（设备刚拔掉 / 菜单被本地化 / Xcode 没有打开工作区），走 b。

**b. 报 `-1719` / `-1743`（无辅助功能 / 自动化权限）或返回 `NOT_FOUND`**：明确请用户在 Xcode 工具栏手动选 run destination——**有真机就选自己的 iPhone，没有就选 Any iOS Device (arm64)**——等用户确认。Xcode 会按 scheme 记住该选择，之后同一 scheme 无需重复切换。

**c. 无法当场确认**（如 `CLICKED_BUT_UNVERIFIED`）：可以先编译，靠第 4 步的日志验证兜底——但这可能白跑一次完整编译；发现编译到模拟器时必须回到本步重来。

补充：真机编译需要可用的签名证书。若构建因签名失败（日志出现 code signing / No signing certificate / provisioning profile 类错误），如实告知用户。Any iOS Device 同样需要签名配置，退回它重试未必能过；**不要**自行修改工程的签名设置。

### 3. 触发编译

调用 `BuildProject(tabIdentifier=...)`。

- 大项目编译可能超过 MCP 客户端超时。**客户端超时 ≠ 编译失败**：Xcode 里的构建仍在继续，改用 `GetBuildLog` 轮询（间隔 15–30 秒，别过密）。
- 等待期间**不要**再次调用 `BuildProject`（会再排一次构建）。
- 构建长时间无进展时，多半是 Xcode 弹了窗（签名、pod 变更确认等）卡住，提醒用户看一眼 Xcode 窗口。

### 4. 读结果，并验证是设备编译而非模拟器

`GetBuildLog(tabIdentifier, severity="error")` 拿错误列表；若响应显示仍在编译中，等待后重查。

**验证 destination**：用 `GetBuildLog(tabIdentifier, pattern="iphonesimulator|iphoneos|destination")` 检查命令行/路径（若 `|` 不被当作正则、无命中，拆成单关键词分别查）：

- 命中 `iphoneos`，且 destination 为 `generic/platform=iOS`（Any iOS Device）或 `platform=iOS,id=...`（连接的真机）→ 真机 arm64 编译，符合要求。
- 只有 `iphonesimulator` → 编译到了模拟器，destination 不对：回第 2 步切换后重新编译。

### 5. 汇报

- 成功：说明"编译通过"，并注明实际使用的 destination（真机设备名或 Any iOS Device arm64）以及 scheme/workspace。
- 失败：按文件归类列出首条关键 error（可用 `pattern`/`glob` 过滤定位），给出下一步修复建议；**不要**整段粘贴构建日志。

## 常见问题速查

| 现象 | 多半原因 | 处理 |
|------|----------|------|
| `XcodeListWindows` 连接失败 / 无窗口 | Xcode 未开；`xcode-select` 与运行中的 Xcode 不一致；未授权 | 见「前置条件」 |
| osascript 报 `-1719` / `-1743` | 终端 / 客户端无辅助功能权限 | 授权后重试；不便授权则走第 2 步 b，让用户手动选 |
| 日志里只有 `iphonesimulator` | destination 是模拟器 | 回第 2 步重选并重编 |
| MCP 调用超时但 Xcode 还在编 | 客户端超时，非构建失败 | 用 `GetBuildLog` 轮询，勿重发 `BuildProject` |
| 构建一直不动 | Xcode 弹窗等待确认 | 提醒用户查看 Xcode 窗口 |
