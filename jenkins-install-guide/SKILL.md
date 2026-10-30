---
name: jenkins-install-guide
description: 当用户询问「如何安装 Jenkins 打包技能」「怎么用 Jenkins 打包」「帮我安装 Jenkins 打包技能」、或要打测试包、查构建状态、取每日包却不确定技能是否已装时使用。本技能是 jenkins-build-assistant 的安装与使用向导：负责引导用户（豆包工作客户端）下载安装 jenkins-build-assistant 技能包，并说明三平台（iOS / 鸿蒙 / Android）的常用用法。实际打包执行由已安装的 jenkins-build-assistant 技能承担，本技能不直接调 Jenkins。
---

# Jenkins 打包技能 · 安装与使用向导

本技能是 **jenkins-build-assistant（Jenkins 打包助手）** 的安装与使用向导。冯宝宝（云端）无法直接操作使用者的电脑，实际安装与打包在本机由豆包工作客户端完成；冯宝宝的角色是给出正确指引、链接与验证方法。

## 一、它是什么

`jenkins-build-assistant` 装在开发者的 `~/DoubaoWork/skills/jenkins-build-assistant`，提供三平台能力：

| 平台 | 能力 | 说明 |
|---|---|---|
| iOS | 触发 + 查询 | `v6-Enterprise-2` 企业签测试包（`enterprise` 默认；`cn`/`os` 每日 job 只查询） |
| 鸿蒙 HarmonyOS | 触发 + 查询 | `ninebot-harmony-agc` AGC 邀请测试包（`agc` 默认），产物是华为邀请测试链接 |
| Android | 只查询 | 机器人不触发（参数含发布平台账号，由人在 Jenkins 上操作）；可查状态/产物/每日包 |

公共能力：查构建状态/日志/最近成功构建、等待构建完成（`wait-build`）、取消排队、`params` 触发前参数清单、失败自动输出「失败分析」（失败步骤/关键报错/提交人）、iOS / Android 每日包渠道（`channels` / `daily`）。

**凭据**：Jenkins 凭据在本机状态目录 `~/.config/jenkins-build-assistant/env/`（`ios.env` / `harmony.env` / `android.env` / `channels`），不在技能包内、不随分发包扩散；安装向导自动完成配置，**开发者无需手动填写 Token**。

## 二、安装（唯一方式：对话安装）

前置：使用者需先下载并安装**豆包工作客户端**，用公司账号登录（飞书 SSO 同号）。

1. 下载并安装豆包工作客户端，用公司账号登录。
2. 打开豆包工作客户端，在对话中发送：**「帮我安装 Jenkins 打包技能， https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip」**。
3. 豆包自动完成：下载 zip → 解压到 `~/DoubaoWork/skills/jenkins-build-assistant` → 检查/初始化本机状态目录 `~/.config/jenkins-build-assistant/env/`（凭据已内置，无手工步骤）。
4. 完成。

## 三、验证安装

对话里让豆包/本机执行（任一即可）：

```
查一下 v6-Enterprise-2 最近构建状态        # iOS
查一下鸿蒙 AGC 最近构建状态                # 鸿蒙
查一下 Android 国内最近构建状态            # Android
```

或命令行：

```bash
bash ~/DoubaoWork/skills/jenkins-build-assistant/scripts/ios.sh status
bash ~/DoubaoWork/skills/jenkins-build-assistant/scripts/harmony.sh status
bash ~/DoubaoWork/skills/jenkins-build-assistant/scripts/android.sh status
```

能返回构建号、状态、耗时（如 `构建 #2085 · SUCCESS · 28.5 分钟`）即安装成功。三平台命令速查：

| 平台 | 脚本 |
|---|---|
| iOS | `scripts/ios.sh`（job：`v6-Enterprise-2`，别名 enterprise / cn / os） |
| 鸿蒙 | `scripts/harmony.sh`（job：`ninebot-harmony-agc`，别名 agc / 鸿蒙） |
| Android | `scripts/android.sh`（job：国内 `ninebot-android-国内-v6-copy`、海外 `ninebot-android-海外-v6`，别名 cn / os） |

用户只说「RN 包」时先确认是 iOS 还是鸿蒙（Android 不能由机器人触发）。

## 四、常用用法（给使用者的快速指引）

### 打包（iOS / 鸿蒙）

1. 先让豆包运行 `<平台>.sh params`（要 Jenkins 实时候选分支/版本时加 `params live`），把可选参数与默认值列给你，由你逐项选择或直接用默认。
2. `main_version` 必须明确给出（如 `6.10.13`）。
3. 豆包复述 job、main_version 和本次生效参数，你确认后执行：`trigger <版本> confirm [key=value...]`（如 `trigger 6.10.13 confirm env=海外`）。
4. 已有构建进行中/排队时 trigger 会拒绝；你明确要再打一个时才加 `force`。
5. 触发成功回执「排队号」与「本次构建：#N」；用排队号等结果：`wait-build queue <排队号>`，已有构建号则 `wait-build <构建号>`。

### 查询与等待（三平台通用）

| 用户要 | 让豆包执行 |
|---|---|
| 查构建状态 | `status [构建号]` |
| 等构建完成 | `wait-build <构建号>` 或 `wait-build queue <排队号>` |
| 最近成功构建 | `latest`（含产物链接/版本号/本次打包参数） |
| 看构建日志 | `log [构建号] [行数]` |
| 取消排队 | 先 `cancel` 列出，确认 queue id 后 `cancel <id>`（只取消排队，不停运行中的构建） |
| 列出可见 job | `jobs` |

### 每日包（iOS / Android）

| 用户要 | 让豆包执行 |
|---|---|
| 每日最新包链接 | `scripts/ios.sh channels` 或 `scripts/android.sh channels`（密码默认隐藏，明确要时 `channels password`） |
| 每日包主动推送 | 挂载层每天定时执行 `ios.sh daily` / `android.sh daily` |

### 完成通知模板（冯宝宝编排）

- iOS：`@发起者 你的包好了：#N · SUCCESS · 耗时 X 分钟 · 版本 6.10.13.5107 · 蒲公英/归档链接 · 参数：branch=… Service_Key=… main_version=…`
- 鸿蒙：`@发起者 你的鸿蒙包好了：#N · SUCCESS · 耗时 X 分钟 · versionCode 610131377 · 邀请测试：<链接> · 参数：branch=… products=… main_version=…`
- 失败：转述失败步骤与关键报错（失败分析），失败包不会上传蒲公英/AGC。

## 五、常见问题

| 现象 | 处理 |
|---|---|
| 对话报「连不上 / 502」 | 确认电脑在公司内网（Jenkins 是内网地址）；确认技能已装到 `~/DoubaoWork/skills/jenkins-build-assistant`；必要时重启豆包工作客户端 |
| 报「缺少凭据」 | 确认本机状态目录 `~/.config/jenkins-build-assistant/env/` 存在且含对应平台的 env 文件；无则重新执行安装或联系技能维护者补齐 |
| 打 Android 包 | 机器人不触发 Android（参数含发布平台账号），由人在 Jenkins 上操作；豆包只查询和给每日包链接 |
| 每日包密码 | 渠道密码在本机 `env/channels`，默认不展示；需要时让豆包执行 `channels password` |
| iOS 没有蒲公英链接 | 已知问题：蒲公英上传步骤已从 job 移除（2026-10-20），构建成功给 Jenkins 归档 IPA 下载链接（需 Jenkins 登录），版本号从文件名解析 |
| 鸿蒙打包产物 | 产物是华为 AGC 邀请测试链接（`appgallery.huawei.com/apptest/join/…`）+ versionCode；默认 `auto_submit=true` 会提交邀请测试审核 |
| 换电脑 / 重装系统 | 重新执行本向导的安装步骤 |
| 打包失败 | 技能输出「失败分析」（失败步骤、关键报错、提交人），直接转述并给修复方向；失败包不上传 |

## 六、技能包更新

- 使用者：重新下载最新 zip（同一链接 `https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip`，维护者覆盖发布后链接不变），解压覆盖 `~/DoubaoWork/skills/jenkins-build-assistant`，重启豆包工作客户端；本机状态目录 `~/.config/jenkins-build-assistant/` 不受更新影响。
- 维护者：主技能源码在 `/Users/ninebot/Desktop/Github/My-Skills/jenkins-build-assistant`；更新后按 README「打包」用白名单打包（只收 `SKILL.md platforms scripts`，不含 env/logs/tests），发布到上述直链，并同步更新本向导技能包。

## 七、参考链接

- 技能包 zip 下载（主入口）：`https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip`
- 主技能源码（维护者本机）：`/Users/ninebot/Desktop/Github/My-Skills/jenkins-build-assistant/`（其 SKILL.md / platforms/*.md 为最终行为与安全约束）
- 使用者安装位置：`~/DoubaoWork/skills/jenkins-build-assistant/`
- 本机状态目录（凭据/渠道/审计）：`~/.config/jenkins-build-assistant/`
