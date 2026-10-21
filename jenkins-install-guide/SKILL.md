---
name: jenkins-install-guide
description: 当用户询问「如何安装 Jenkins 打包技能」「怎么用 Jenkins 打包」「帮我安装 Jenkins 打包技能」、或要打测试包、查构建状态、取每日包却不确定技能是否已装时使用。本技能是 jenkins-build-assistant 的安装与使用向导：负责引导用户（豆包工作客户端）下载安装 jenkins-build-assistant 技能包，并说明常用用法。实际打包执行由已安装的 jenkins-build-assistant 技能承担，本技能不直接调 Jenkins。
---

# Jenkins 打包技能 · 安装与使用向导

本技能是 **jenkins-build-assistant（Jenkins 打包助手）** 的安装与使用向导。冯宝宝（云端）无法直接操作使用者的电脑，实际安装与打包在本机由豆包工作客户端完成；冯宝宝的角色是给出正确指引、链接与验证方法。

## 一、它是什么

`jenkins-build-assistant` 装在开发者的 `~/DoubaoWork/skills/jenkins-build-assistant`，提供：

- 打 iOS 测试包（`v6-Enterprise-2`，支持版本号/参数/force 重打）
- 查构建状态、日志、最近成功构建、等待构建完成
- 取 iOS / Android 每日最新包与蒲公英固定链接
- 构建失败自动输出「失败分析」（失败步骤、关键报错、提交人）
- Android、鸿蒙（HarmonyOS）平台入口（Android/Harmony 当前只读现状，不执行触发）

**凭据已内置**在技能包的 `env/ios.env`（`JENKINS_USER=dev` + API Token），开发者**无需填写 Token**。

## 二、安装（唯一方式：对话安装）

前置：使用者需先下载并安装**豆包工作客户端**，并登录公司账号（飞书 SSO 同号）。

1. 下载并安装豆包工作客户端，用公司账号登录。
2. 打开豆包工作客户端，在对话中发送：**「帮我安装 Jenkins 打包技能， https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip」**。
3. 豆包会自动从下载链接 `https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip` 下载 `jenkins-build-assistant.zip` 并解压到 `~/DoubaoWork/skills/jenkins-build-assistant`，安装即完成（凭据已内置，无其他步骤）。

## 三、验证安装

对话里让豆包/本机执行：

```
查一下 v6-Enterprise-2 最近构建状态
```

或命令行：

```bash
bash ~/DoubaoWork/skills/jenkins-build-assistant/scripts/ios.sh status
```

能返回构建号、状态、耗时（如 `构建 #2051 · FAILURE · 22.2 分钟`）即安装成功。

## 四、常用用法（给使用者的快速指引）

| 用户要 | 让豆包执行 |
|---|---|
| 打 iOS 测试包 | `trigger <版本号> confirm`（如「打一个 6.10.12 测试包」）；先复述参数再确认；已有构建在跑需加 `force` |
| 查构建状态 | `status [构建号]` |
| 等构建完成 | `wait-build <构建号>` 或 `wait-build queue <排队号>`（用触发回执里的排队号） |
| 每日最新包链接 | `channels`（iOS：`scripts/ios.sh channels`；Android：`scripts/android.sh channels`），密码默认隐藏 |
| 最近成功构建 | `latest` |
| 看构建日志 | `log [构建号] [行数]` |
| 取消排队 | 先 `cancel` 列出，确认 queue id 后 `cancel <id>` |
| 每日包主动推送 | 挂载层每天定时执行 `daily`（iOS/Android 分别用对应脚本） |

平台区分：iOS 用 `scripts/ios.sh`，Android 用 `scripts/android.sh`，鸿蒙用 `scripts/harmony.sh`。用户只说「RN 包」时先确认 iOS 还是 Android。

## 五、常见问题

| 现象 | 处理 |
|---|---|
| 对话报「缺少凭据」 | 凭据已内置在 `env/ios.env`，确认未删除或改动该文件 |
| 报「连不上 / 502」 | 确认电脑在公司内网；确认技能包已放到 `~/DoubaoWork/skills/jenkins-build-assistant`；必要时重启豆包工作客户端 |
| 每日包密码 | 联系 iOS 打包渠道管理员获取，写入 `env/channels` |
| 换电脑 / 重装系统 | 重新执行本向导的安装步骤 |
| 打包失败 | 技能会输出「失败分析」（失败步骤、关键报错、提交人），直接转述给用户并给出修复方向 |
| 蒲公英上传失败 | Jenkins 侧蒲公英 api v2 上传有已知问题（2026-10-15 未修复），构建成功也可能拿不到蒲公英链接，会回退给构建页链接 |

## 六、技能包更新

- 使用者：重新下载最新 zip（`https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip`），解压覆盖 `~/DoubaoWork/skills/jenkins-build-assistant`，**保留** `env/ios.env`（若被覆盖则重新下载一次即可），重启豆包工作客户端。
- 维护者：主技能源码位于本机 `/Users/ninebot/Desktop/Github/My-Skills/jenkins-build-assistant`；更新后重新打包（不含 env/logs/assets 等本机内容），发布到 `https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip`，并同步更新本向导技能包。

## 七、参考链接

- 技能包 zip 下载（主入口）：`https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip`
- 主技能源码（维护者本机）：`/Users/ninebot/Desktop/Github/My-Skills/jenkins-build-assistant/`（其 SKILL.md / platforms/*.md 为最终行为与安全约束）
- 使用者安装位置：`~/DoubaoWork/skills/jenkins-build-assistant/`
