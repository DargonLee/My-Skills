---
name: jenkins-build-assistant
description: 在用户要求打 iOS 测试包、打鸿蒙（HarmonyOS）邀请测试包、查询或取消 Jenkins 构建、查看构建日志，或索取 iOS / Android 每日最新包与蒲公英链接时使用。用户只说 RN、没有指明 iOS 或鸿蒙时先确认平台（Android 只查每日渠道）。
---

# Jenkins 打包助手

平台细节在 `platforms/ios.md`、`platforms/android.md`、`platforms/harmony.md`，由模型按需读取；各平台的 job 名登记在 `platforms/<平台>.jobs`（脚本白名单与别名的唯一来源，不是凭据）。分发/挂载时要与 `SKILL.md`、`scripts/` 一起保留在同一个 skill 包里，不要把平台文档拆开或提前塞进上下文。按 README 的白名单打包，不能把 `env/`、`logs/` 或其他本机数据带上。

下文 `<ROOT>` 指本 skill 根目录（本文件所在目录）。脚本在 `<ROOT>/scripts/`，调用时使用绝对路径：iOS 用 `scripts/ios.sh`，Android 用 `scripts/android.sh`，HarmonyOS 用 `scripts/harmony.sh`。共用的 HTTP 在 `scripts/common.sh`，不要直接执行。`scripts/jenkins_build.sh` 是旧入口兼容包装，新调用不要使用。当前 skill 不含 MCP 服务或 Jenkins CLI jar。

## 意图

先对上表，再读平台文件。平台不明确时先问，包括只说「RN 包」的情况。

| 用户要 | 动作 |
|---|---|
| iOS 或 Android 的每日最新包、蒲公英固定链接 | 不访问 Jenkins。执行 `bash <ROOT>/scripts/ios.sh channels` 或 `bash <ROOT>/scripts/android.sh channels`，把链接转给用户（密码默认不展示；用户明确要时执行 `channels password`）。这不是某次 Enterprise 构建。 |
| 每日包主动推送（定时） | 挂载层每天定时执行 `ios.sh daily`（或 `android.sh daily`），把渠道链接与更新说明推送到群。确认当日是否有新包需蒲公英 API Token 或确认每日构建 job。 |
| 打一个 iOS 测试包 | 读 `platforms/ios.md`。用户给版本号即可触发，其余用默认参数（`Service_Key=test`、`branch=develop`、`env=国内`、`BuildConfiguration=Debug`、`channel=Release`、`Confusion=无`、`Xcode=26`、`needUpload=No`、`watermark=false`、`needUpdateStringPackage=No`、`ShopDebug=0`），用户可指定覆盖（如 `env=海外`）。先复述 job、main_version 与本次生效参数（含被覆盖项，默认项可简述「其余用默认」）。用户明确同意后，才执行带 `confirm` 的 `trigger`。已有构建进行中/排队时 `trigger` 会拒绝；用户明确要求再打一个时，才加 `force`。 |
| 某次构建到哪了、成功没有、日志、这次包的链接、等它打完 | 读 `platforms/ios.md`。用 `status`、`log`、`latest` 或 `wait-build`。等本次触发打完时，用回执里的排队号执行 `wait-build queue <排队号>`；已经拿到构建号就执行 `wait-build <构建号>`。没给号码、当前没有进行中的排队或构建，或同时有排队与运行中的构建时，`wait-build` 会拒绝自动绑定，不会把别人的构建当成这次结果。构建完成时带上耗时。失败时输出「失败分析」（失败步骤、关键报错节点、本次构建 commit/分支；能定位到提交人则列出）。`latest` 是当前 `JOB` 最近一次成功构建。 |
| 取消排队 | 先执行 `cancel` 列出队列。用户确认 queue id 后，再执行 `cancel <id>`。 |
| 打鸿蒙（HarmonyOS）邀请测试包 | 读 `platforms/harmony.md`。入口是 `harmony.sh`，job `ninebot-harmony-agc`。用户给版本号即可触发，其余用默认参数（`products=default-prod`、`branch=develop`、`kuikly_branch_name=develop`、`app_desc=jenkins`、`auto_submit=true`、`distribute_mode=1`），用户可指定覆盖（如 `rn_branch_name=feat_v1`）。触发会提交 AGC 邀请测试审核：先复述 job、main_version 与本次生效参数，用户明确同意后才执行带 `confirm` 的 `trigger`。产物是 AGC 邀请测试分享链接（不上蒲公英）。 |
| 查鸿蒙构建、等它打完 | 读 `platforms/harmony.md`。用 `harmony.sh` 的 `status`、`log`、`latest`、`wait-build`，合同与 iOS 相同；成功时提取邀请测试链接与 versionCode。 |
| 打 Android 包 | 读 `platforms/android.md`。机器人不触发 Android（参数带发布平台账号，由人在 Jenkins 上触发），`android.sh trigger` 会拒绝；回答现状并给 Jenkins 入口。 |
| 查 Android 构建、等它打完 | 读 `platforms/android.md`。用 `android.sh` 的 `status`、`log`、`latest`、`wait-build`、`cancel`，`JOB` 默认国内（`cn`），海外用 `JOB=os`；成功时给 APK 产物名与蒲公英状态。 |

## 命令

下面的命令都是 `scripts/ios.sh` 的子命令；`scripts/harmony.sh`、`scripts/android.sh` 支持同样的 Jenkins 子命令（`trigger`〔android 无〕、`wait-build`、`status`、`latest`、`cancel`、`log`、`jobs`；android 另有 `channels` / `daily`，harmony 无），差异只在 job、参数白名单与默认值。`JOB` 环境变量可传登记文件里的 job 名或别名：iOS `enterprise`（默认，v6-Enterprise-2）/ `cn` / `os`；鸿蒙 `agc`（默认）；Android `cn`（默认）/ `os`。各平台 job 登记在 `platforms/<平台>.jobs`。凭据在本 skill 的 `env/ios.env`、`env/harmony.env`、`env/android.env`（chmod 600）。调用前已经导出的同名环境变量优先于文件（job 登记除外，登记文件值优先）。不要改各平台的 `JENKINS_BASE`（iOS `https://jenkins-ios.ninebot.com`，鸿蒙/Android `https://jenkins.ninebot.com`），不要把 env 文件贴进对话。

| 命令 | 作用 |
|---|---|
| `ios.sh channels [password]` / `android.sh channels [password]` | 每日包链接（默认不含密码；带 `password` 才输出密码） |
| `ios.sh daily` / `android.sh daily` | 每日包主动推送检查入口：固定渠道 + 更新说明（挂载层每天定时调用） |
| `ios.sh trigger <版本> confirm [force] [key=value...]` | 触发 `v6-Enterprise-2`。`main_version=6.10.12` 与位置参数等价。没有 `confirm` 会失败；已有构建进行中/排队时需 `force`。未指定参数用脚本默认值（见 `platforms/ios.md` 参数表），触发前会输出「本次打包参数」完整清单。Jenkins 返回排队地址时回执「排队号」并尽力带上「本次构建：#N」；未返回排队地址或 POST 结果不确定时先查队列和状态，不要直接重试 |
| `harmony.sh trigger <版本> confirm [force] [key=value...]` | 触发 `ninebot-harmony-agc`，合同同上（默认值见 `platforms/harmony.md`）。产物是 AGC 邀请测试分享链接 |
| `ios.sh` / `harmony.sh` / `android.sh` `wait-build queue <排队号>` / `wait-build <构建号>` | 等到这一次排队项或构建有最终结果，一次输出构建版本号 #N、状态、耗时；成功时 iOS 提取蒲公英地址与版本号（末段即 app 构建编号），鸿蒙提取邀请测试链接与 versionCode，Android 提取 APK 产物名与蒲公英状态，失败时附「失败分析」。不带号码时，仅当该 job 恰好只有一个排队项或一个正在构建且不同时存在时才等待；空闲、歧义或查询失败都会拒绝 |
| `ios.sh` / `harmony.sh` / `android.sh` `status [构建号]` | 状态。完成且有耗时时输出「耗时: X 分钟」；构建中时附排队 ETA；失败时附「失败分析」（失败步骤、关键报错节点、本次构建 commit/分支，changeSet 有 author 时列出提交人）；job 从未构建时提示「暂无构建记录」 |
| `ios.sh` / `harmony.sh` / `android.sh` `latest` | 该 job 最近成功构建，并从控制台提取本次产物信息（iOS 蒲公英 + 版本号；鸿蒙 AGC 邀请测试链接 + versionCode；Android APK 产物名 + 蒲公英状态） |
| `ios.sh` / `harmony.sh` / `android.sh` `log [构建号] [行数]` | 控制台尾部，默认 30 行 |
| `ios.sh` / `harmony.sh` / `android.sh` `cancel` / `cancel <id>` | 列出该 job 的排队项 / 取消指定 id |
| `ios.sh jobs` / `harmony.sh jobs` / `android.sh jobs` | 列出对应 Jenkins 上可见的 job |

## 完成通知

构建完成后的主动通知由冯宝宝（挂载层）编排：

1. 触发时记录发起者（群成员），经环境变量 `JENKINS_TRIGGER_BY` 传给脚本，脚本输出里回显「触发人：xxx」；Jenkins 返回排队地址时给出排队号，构建号可在开始后由 `status`/`wait-build` 显示。未取得排队号时先核对队列与状态，不要直接重试或把上一次构建视为本次结果。
2. 构建期间用触发回执里的排队号轮询 `wait-build queue <排队号>`；回执里已经有「本次构建：#N」时改用 `wait-build <构建号>`。结束后一次拿到这一次的构建版本号（#N）、状态、耗时、产物链接与版本信息。
3. 定向回复触发人，iOS 模板：`@发起者 你的包好了：#N · SUCCESS · 耗时 X 分钟 · 版本 6.10.13.5107 · 蒲公英：<主页链接>（短链 <短链接>）`；鸿蒙模板：`@发起者 你的鸿蒙包好了：#N · SUCCESS · 耗时 X 分钟 · versionCode 610131377 · 邀请测试：<分享链接>`。版本信息控制台没给时省略该段。
4. 蒲公英固定链接指向最新上传版本，通知里直接给 `wait-build` 提取到的链接，不要引用旧包。`wait-build` 给的是「Jenkins 产物下载（需登录）」时，通知里说明蒲公英本次没有上传、附产物文件名与该链接，并提示需要 Jenkins 账号。鸿蒙分享链接同样以 `wait-build` 提取到的为准。
   如果产物信息暂不可用，只报告已确认的构建状态并给构建页，不猜测分发是否成功，也不要因此重触发构建。
5. 构建失败时，`wait-build`/`status` 会附「失败分析」：失败步骤（如 `Build step '…' marked build as failure`）、关键报错节点（脱敏，最多 5 条）、本次构建 commit/分支（changeSet 提供 author 时列出提交人；日志只有 commit 时给 hash+分支+message 并说明无法定位提交人）。通知里转述失败步骤与关键报错；失败产物不会上传蒲公英/AGC。
6. 本机 macOS 通知是可选项：使用者自己导出 `JENKINS_NOTIFY=1` 后，`wait-build` 出最终结果时会发一条桌面通知（授权方法见 README「构建完成的本机 macOS 通知」）。模型不要替用户开启或代做授权，只在使用者问起时指到 README。

## 安全

这里是唯一一份安全约束。

1. 凭据只来自环境变量或本 skill 的 `env/<平台>.env`（iOS、鸿蒙、Android 各一份）。不写入群消息或日志。
2. iOS 触发只接受 `platforms/ios.md` 列出的参数名；鸿蒙触发只接受 `platforms/harmony.md` 列出的参数名。对 `account`、`password`、`fabuAccount`（不区分大小写）给出专门拒绝提示，未知参数名和含换行符的参数值也会拒绝；上传、水印、自动提交等开关只接受各自文档列出的值。
3. `Service_Key` 只放行 `dev` 和 `test`。`release`、`migrate_cloud`、`production`，以及发版 / TestFlight job，由人在 Jenkins 上触发。鸿蒙同理：`products` 只放行 `default-prod`（`online-prod` 生产环境）、`distribute_mode` 只放行 `1`（`2` 应用市场），`build_version` 只放行 1-4 位数字；越界的由人在 Jenkins 上触发。
4. 鸿蒙 `trigger` 默认 `auto_submit=true`，会提交 AGC 邀请测试审核（内测可见）。每次 `trigger` 都是对外分发，先复述参数并得到同意。iOS 蒲公英现状（2026-10-20）：`v6-Enterprise-2` 的蒲公英上传步骤当天被移出 job 配置（此前 `needUpload=No` 也会上传，且 api v2 常失败），构建成功后控制台没有蒲公英链接，`latest`/`wait-build` 会改给 Jenkins 归档 IPA 的下载链接（需 Jenkins 登录）并从文件名解析版本号；步骤恢复后自动回到蒲公英链接（见 `platforms/ios.md`）。
5. 蒲公英按包名覆盖，固定链接指向最新上传版本。用户要某个历史版本时直接说明固定链接做不到。
6. 脚本只接受各平台登记文件 `platforms/<平台>.jobs` 里的 job（别名也只解析到这些 job）；登记文件随 skill 分发，缺键会拒绝，调用方环境变量不能补写或改写它。Android 只查询不触发。`cancel` 只取消用户确认过的排队 id，不停止运行中的构建。
7. 渠道密码只放在本 skill 的 `env/channels`。`channels` 默认不输出密码，用户明确要时才用 `channels password`。不要把密码写进 `SKILL.md`、`README` 或群消息。
8. 失败时转述关键日志。`log` 会丢掉含 password、token、Authorization、crumb 的行。`tree=actions[parameters...]` 会连带密码参数被 Jenkins 拒绝，不要用来查参数。
9. 构建进行中/排队时 `trigger` 默认拒绝，需显式 `force`。无法确认是否已有构建时同样拒绝。`force` 意味着允许重复占用打包机队列，仅当用户明确要求时使用。
10. 成功 `trigger` 会把时间、触发人、job、关键参数（iOS：`Service_Key`、`main_version`、`branch`、`env`、`needUpload`；鸿蒙：`products`、`main_version`、`branch`、`distribute_mode`、`auto_submit`）追加到 `logs/audit.log`（600）。该文件与 `env/` 一样留在本机，不随 skill 分发。
