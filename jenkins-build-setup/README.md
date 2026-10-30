# Jenkins 打包技能 · 安装与使用向导

行为、路由以 `SKILL.md` 为准。本包是 **jenkins-build-assistant** 的安装与使用向导，供冯宝宝在对话中引导开发者完成安装与使用。

## 快速指引

1. **安装**（唯一方式）：下载并安装豆包工作客户端、登录公司账号，在对话中说「帮我安装 Jenkins 打包技能， https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip」，豆包自动下载解压到 `~/DoubaoWork/skills/jenkins-build-assistant` 并初始化本机状态目录凭据。
2. **凭据**：本机状态目录 `~/.config/jenkins-build-assistant/env/`（ios/harmony/android/channels），安装向导自动配置，无需手工填写。
3. **验证**：`bash ~/DoubaoWork/skills/jenkins-build-assistant/scripts/ios.sh status`（或对话「查一下 v6-Enterprise-2 最近构建状态」）。

## 平台速览

| 平台 | 脚本 | job | 能力 |
|---|---|---|---|
| iOS | `scripts/ios.sh` | `v6-Enterprise-2`（enterprise/cn/os） | 触发 + 查询 |
| 鸿蒙 | `scripts/harmony.sh` | `ninebot-harmony-agc`（agc/鸿蒙） | 触发 + 查询（AGC 邀请测试） |
| Android | `scripts/android.sh` | 国内 `ninebot-android-国内-v6-copy`、海外 `ninebot-android-海外-v6`（cn/os） | 只查询 |

## 常用命令（jenkins-build-assistant）

| 命令 | 作用 |
|---|---|
| `<平台>.sh params [live]` | 触发前参数清单（live 拉 Jenkins 实时候选） |
| `ios.sh trigger <版本> confirm [force] [key=value...]` | 触发 iOS 打包；先复述参数再 confirm |
| `harmony.sh trigger <版本> confirm [force] [key=value...]` | 触发鸿蒙 AGC 邀请测试打包 |
| `<平台>.sh wait-build <构建号>` / `wait-build queue <排队号>` | 等构建/排队结束，输出版本号、状态、耗时、产物链接、本次打包参数 |
| `<平台>.sh status [构建号]` | 构建状态，失败附「失败分析」 |
| `<平台>.sh latest` / `log [号] [行数]` | 最近成功构建 / 控制台日志 |
| `<平台>.sh cancel [id]` | 列出/取消排队（只取消排队项） |
| `ios.sh` / `android.sh` `channels [password]`、`daily` | 每日包渠道（鸿蒙没有） |

## 打包流程（iOS / 鸿蒙）

1. `<平台>.sh params`（或 `params live`）列出参数与默认值，由开发者选择。
2. `main_version` 必填（如 6.10.13）。
3. 复述 job、main_version 与生效参数，开发者确认后 `trigger <版本> confirm`。
4. 已有构建在跑时 trigger 拒绝，需显式 `force` 才重复触发。
5. 用回执排队号 `wait-build queue <排队号>` 等结果，完成后回显版本号/耗时/产物链接/本次打包参数。

## 产物形态

- iOS：蒲公英（历史上传时）或 Jenkins 归档 IPA 下载链接（蒲公英上传步骤 2026-10-20 起已移除，需 Jenkins 登录），版本号从文件名解析
- 鸿蒙：华为 AGC 邀请测试链接（`appgallery.huawei.com/apptest/join/…`）+ versionCode；默认 `auto_submit=true`
- Android：APK 产物名（`Segway-Ninebot_v6.10.13_domestic_debug_…apk`），`isUpload=false` 时包在打包机上

## 分发/更新

- 主下载入口：`https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip`；维护者源码在 `/Users/ninebot/Desktop/Github/My-Skills/jenkins-build-assistant`，更新后按 README「打包」白名单打包（SKILL.md platforms scripts）发布到该直链，并同步更新本向导。
- 凭据在本机状态目录 `~/.config/jenkins-build-assistant/`，不随分发包扩散；更新技能包不影响状态目录。
