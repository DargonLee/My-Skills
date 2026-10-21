# Jenkins 打包助手

运行行为、安全约束和平台路由以 `SKILL.md` 为准。本目录当前包含 iOS 查询/触发脚本、HarmonyOS 邀请测试打包触发脚本、Android 查询脚本与每日包渠道查询；不包含 MCP 服务或 Jenkins CLI jar。

## 目录

```text
SKILL.md
README.md
回归测试清单.md
platforms/        平台现状、白名单和参数说明（*.md）+ 各平台 job 登记（*.jobs，随 skill 分发，不是凭据）
scripts/          平台入口与共用 Jenkins API
tests/            本地、禁止网络的回归测试
env/              本机凭据和渠道配置，不得分发
logs/             本机审计日志，不得分发
```

本目录的 `.gitignore` 排除 `env/` 和 `logs/`，避免本机凭据和审计记录被误提交。

## 配置

凭据放在本 skill 的 `env/`。`JENKINS_USER` 填 Jenkins 用户 id；iOS 上 API Token 的显示名不是用户名。

```bash
ROOT=/path/to/jenkins-build-assistant
mkdir -p "$ROOT/env"
chmod 700 "$ROOT/env"

cat > "$ROOT/env/ios.env" <<'EOF'
JENKINS_USER=dev
JENKINS_API_TOKEN=<API Token>
JENKINS_BASE=https://jenkins-ios.ninebot.com
EOF
chmod 600 "$ROOT/env/ios.env"

cat > "$ROOT/env/channels" <<'EOF'
IOS_CN_URL=<iOS domestic channel URL>
IOS_CN_PASSWORD=<password>
IOS_OS_URL=<iOS overseas channel URL>
IOS_OS_PASSWORD=<password>
ANDROID_CN_URL=<Android domestic channel URL>
ANDROID_CN_PASSWORD=<password>
ANDROID_OS_URL=<Android overseas channel URL>
ANDROID_OS_PASSWORD=<password>
EOF
chmod 600 "$ROOT/env/channels"
```

HarmonyOS and Android both use the main Jenkins `https://jenkins.ninebot.com` (`env/harmony.env`, `env/android.env`; same robot account / API Token). Job names live in `platforms/<platform>.jobs`, not in env files, so they ship with the skill. Do not put a personal account password in env files. Environment variables already exported by the caller take precedence over the matching values in platform env files.

## 构建完成的本机 macOS 通知（可选）

`wait-build` 等到构建结束后，可以让脚本顺手发一条系统通知（右上角横幅），不用盯着终端等 20~40 分钟。默认关闭，导出环境变量开启：

```bash
export JENKINS_NOTIFY=1
```

- 只在 `wait-build` 出最终结果时发：标题「Jenkins 打包助手」，正文 `构建 #2077 · SUCCESS · 耗时 19.6 分钟 · 6.10.13.5119`；成功音 Glass、失败音 Basso。
- 装了 `terminal-notifier` 时点击横幅会直接打开产物链接（蒲公英 / AGC 邀请测试 / Jenkins 归档产物三选一）；没装则用系统自带 `osascript`，仅展示不可点击。
- 发送失败不影响 `wait-build` 的结果输出；通知内容不含任何凭据。

### 首次使用：授权通知权限

macOS 只弹「在系统设置里被允许过」的 App 的通知，脚本无法替你完成授权，需要每台使用机做一次：

1. 先跑一次验证命令，让 App 注册到通知列表（列表里只显示发过通知的 App，刚装的机器上是找不到的）：

   ```bash
   osascript -e 'display notification "权限验证" with title "Jenkins 打包助手"'
   ```

2. 打开 **系统设置 → 通知**，在应用列表找到 **「脚本编辑器」**（`osascript` 的通知以它的名义发出），点开「允许通知」，提醒样式选「横幅」或「提醒」。

3. 再跑一次第 1 步的命令，屏幕右上角应出现横幅。

想支持点击打开链接（推荐）：`brew install terminal-notifier`（或 `gem install terminal-notifier`），然后同样三步：

```bash
terminal-notifier -title "Jenkins 打包助手" -message "权限验证"
# 系统设置 → 通知 → 「terminal-notifier」→ 允许通知
terminal-notifier -title "Jenkins 打包助手" -message "点击我" -open "https://www.pgyer.com"   # 点横幅应打开链接
```

注意：

- 通知只发给坐在这台 Mac 前的使用者；要通知群里的其他人，仍走冯宝宝的 @ 回复或飞书群机器人。
- 需在已登录的图形会话里运行（Terminal / VS Code / Codex 等都算）。SSH、无登录的守护进程里不会显示。
- 系统设置列表里找不到这两个 App 时，说明还没发过通知，先跑第 1 步再刷新列表。

## Local Regression Suite

The suite exercises local guards, channel formatting, and synthetic Jenkins responses. It checks that its `curl` and notification stubs are executable and first on `PATH` before running anything; the `curl` stub has no network fallback and rejects unhandled requests. Run it manually with:

```bash
bash tests/regression.sh
```

These checks do not replace the live Jenkins procedure recorded in `回归测试清单.md`.

## Packaging

Build a skill archive from the runtime files only. Explicit inclusion keeps local credentials, logs, and development tests out of the archive:

```bash
ROOT=/path/to/jenkins-build-assistant
cd "$ROOT"
stamp="$(date +%Y%m%d%H%M%S)"
zip -r -X "../jenkins-build-assistant-${stamp}.zip" SKILL.md platforms scripts -x '*.DS_Store'
```
