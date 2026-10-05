---
name: xcode-mcp
description: >
  Interact with Xcode via mcpbridge. List windows, open files, build projects,
  or launch Claude agent with Xcode-provided config. Use when user mentions
  "xcode", "xcode windows", "open in xcode", "mcpbridge", or invokes /xcode-mcp.
---

## Overview

This skill provides interaction with Xcode through Apple's mcpbridge tool:

**mcpbridge 路径:**
```
/Applications/Xcode-26.5.0-Release.Candidate.app/Contents/Developer/usr/bin/mcpbridge
```

## mcpbridge 功能

### 1. STDIO MCP 桥接模式

无子命令运行时，作为 MCP (Model Context Protocol) 客户端与 Xcode MCP 工具服务之间的 STDIO 桥接：

```bash
xcrun mcpbridge
```

读取 stdin 的 JSON-RPC 2.0 消息，转发响应到 stdout。

### 2. run-agent 子命令

启动编码代理（如 Claude），从 Xcode 获取配置、认证令牌、环境：

```bash
# 启动 Claude 代理
xcrun mcpbridge run-agent claude

# 预览配置（不执行）
xcrun mcpbridge run-agent --dry-run claude

# 不包含 Xcode MCP 工具（避免 schema 问题）
xcrun mcpbridge run-agent --no-xcode-tools claude

# 传递额外参数
xcrun mcpbridge run-agent claude --model opus -p "fix the bug"
```

**run-agent 选项:**
- `<agent-name>` - 代理名称（如 "claude"）
- `--dry-run` - 打印解析的命令但不执行
- `--no-xcode-tools` - 不包含 Xcode MCP 工具在代理配置中

### 3. 环境变量

```bash
# 指定 Xcode 进程 PID
MCP_XCODE_PID=12345 xcrun mcpbridge

# 指定 Xcode 工具会话 UUID
MCP_XCODE_SESSION_ID=<uuid> xcrun mcpbridge
```

**自动检测逻辑（未设置 MCP_XCODE_PID 时）:**
1. 若只有一个 Xcode 进程运行，使用该进程
2. 若有多个 Xcode 进程，使用 xcode-select 确定的选中版本
3. 若无 Xcode 进程，退出报错

## 使用示例

### 列出 Xcode 窗口（AppleScript 备选方案）

```bash
bash /Users/ninebot/.codex/skills/xcode-mcp/scripts/xcode-windows.sh
```

### 打开文件

```bash
open -a Xcode <file-path>
```

### 构建项目

```bash
xcodebuild -scheme <scheme-name> build
```

### 查看 run-agent 配置

```bash
/Applications/Xcode-26.5.0-Release.Candidate.app/Contents/Developer/usr/bin/mcpbridge run-agent --dry-run claude
```

输出示例：
```
=== mcpbridge run-agent dry run ===

Executable: /Users/ninebot/Library/Developer/Xcode/CodingAssistant/Agents/XcodeVersions/17F42/claude/claude
Xcode PID:  9793
Signing:    team=Q6L2SF6YDW, identifier=com.anthropic.claude-code

Environment variables (from Xcode):
  ANTHROPIC_MODEL=best
  CLAUDE_CONFIG_DIR=/Users/ninebot/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig
  MCP_XCODE_PID=9793

Full command:
  ... --mcp-config /var/folders/.../mcp-config-XXX.json --settings '{...}'
```

## Files

- `scripts/xcode-windows.sh` - AppleScript 列出 Xcode 窗口
- `scripts/xcode_mcp_wrapper.py` - Python mcpbridge wrapper（实验性）

## 已知问题

mcpbridge 作为 MCP 服务器时返回 `inputSchema: {}` 而非 `{"type": "object"}`，
导致某些 API（如 ninebot API）schema 验证失败。解决方案：

1. 使用 `--no-xcode-tools` 避免加载 Xcode MCP 工具
2. 使用 AppleScript 备选方案列出窗口
3. 等待 Apple 更新 mcpbridge