# Jenkins 打包助手

运行行为、安全约束和平台路由以 `SKILL.md` 为准。本目录包含 iOS 查询/触发脚本、HarmonyOS 邀请测试打包触发脚本、Android 查询脚本与每日包渠道查询。

## 目录

```text
SKILL.md           skill 入口：意图路由、打包流程、通知与安全规则
README.md          面向维护者：配置、通知授权、回归测试、打包
回归测试清单.md      人工线上验证记录
platforms/         平台现状、白名单和参数说明（*.md）+ 各平台 job 登记（*.jobs，随 skill 分发，不是凭据）
scripts/           平台入口与共用 Jenkins API
tests/             本地、禁止网络的回归测试
evals/             模型行为测试（触发与流程），格式见 skill-creator
```

凭据、渠道密码和审计日志不在这个目录里，见下一节。

## 配置

本机状态默认放在 skill 目录之外的 `~/.config/jenkins-build-assistant/`，这样无论怎么打包或复制 skill，都不会带出凭据。脚本按这个顺序定位状态目录：

1. 环境变量 `JENKINS_SKILL_HOME`
2. `~/.config/jenkins-build-assistant/`（存在时）
3. skill 根目录（旧位置，仅作兼容；新装请不要用）

状态目录的结构：

```text
env/ios.env  env/harmony.env  env/android.env   Jenkins 凭据
env/channels                                    每日包渠道链接与密码
logs/audit.log                                  触发审计日志
```

`JENKINS_USER` 填 Jenkins 用户 id；iOS 上 API Token 的显示名不是用户名。

```bash
STATE="$HOME/.config/jenkins-build-assistant"
mkdir -p "$STATE/env"
chmod 700 "$STATE" "$STATE/env"

cat > "$STATE/env/ios.env" <<'EOF'
JENKINS_USER=dev
JENKINS_API_TOKEN=<API Token>
JENKINS_BASE=https://jenkins-ios.ninebot.com
EOF
chmod 600 "$STATE/env/ios.env"

cat > "$STATE/env/channels" <<'EOF'
IOS_CN_URL=<iOS 国内渠道链接>
IOS_CN_PASSWORD=<密码>
IOS_OS_URL=<iOS 海外渠道链接>
IOS_OS_PASSWORD=<密码>
ANDROID_CN_URL=<Android 国内渠道链接>
ANDROID_CN_PASSWORD=<密码>
ANDROID_OS_URL=<Android 海外渠道链接>
ANDROID_OS_PASSWORD=<密码>
EOF
chmod 600 "$STATE/env/channels"
```

鸿蒙和 Android 使用主 Jenkins `https://jenkins.ninebot.com`（`env/harmony.env`、`env/android.env`，同一个机器人账号和 API Token）。job 名登记在 `platforms/<平台>.jobs`，不在 env 里，所以随 skill 分发。不要把个人账号密码写进 env 文件。调用方已经导出的环境变量优先于 env 文件里的同名值。

另有 `JENKINS_ENV`，可直接指定某个平台的单个 env 文件（回归测试用它指向假凭据）。

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

## 本地回归测试

套件用假凭据、假渠道数据和本地 `curl` stub 检查本地门禁、渠道输出格式和模拟的 Jenkins 响应。运行前它会确认 `curl` 与通知桩是可执行文件且在 `PATH` 最前，`curl` 桩没有联网回退，遇到未处理的请求直接失败。测试把状态目录指向临时目录，不会读写真实凭据和审计日志。手动运行：

```bash
bash tests/regression.sh
```

这些检查不能替代 `回归测试清单.md` 里记录的线上联调流程。

## 模型行为测试

`evals/` 里的每个文件夹是一个用例（提示词 + 期望结果 + 评分项），检查模型在这个 skill 下是否按流程走：平台不明确先问、不跳过 `params` 和确认直接触发、越界参数拒绝等。格式见 skill-creator 的 `references/schemas.md`。

## 打包

用显式白名单打包运行时文件。`env/`、`logs/`、`tests/`、`evals/` 都不进包：

```bash
ROOT=/path/to/jenkins-build-assistant
cd "$ROOT"
stamp="$(date +%Y%m%d%H%M%S)"
zip -r -X "../jenkins-build-assistant-${stamp}.zip" SKILL.md platforms scripts -x '*.DS_Store'
```

用 skill-creator 的 `package_skill.py` 也可以，但它会按目录打包，先确认目录里没有本机数据。
