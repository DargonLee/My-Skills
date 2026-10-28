---
name: jenkins-build-assistant
description: 通过 Jenkins 打包与查询构建：触发 iOS 企业签测试包、鸿蒙（HarmonyOS）AGC 邀请测试包；查询、等待、取消 iOS / 鸿蒙 / Android 的构建，查看构建状态、日志、失败原因、最近成功的包和产物链接；索取 iOS / Android 每日最新包与蒲公英固定链接。只要用户提到打包、出包、提测、测试包、Jenkins、构建进度、构建日志、蒲公英、AGC 邀请测试，就使用本 skill，即使没有明确说"Jenkins"。用户只说"RN 包"而没有指明平台时，先确认是 iOS 还是鸿蒙。Android 不能由机器人触发，只能查询。
---

# Jenkins 打包助手

用 `scripts/` 下的平台脚本操作 Jenkins。`<ROOT>` 指本 skill 根目录（本文件所在目录），调用时用绝对路径：`bash <ROOT>/scripts/ios.sh`、`harmony.sh`、`android.sh`。`common.sh` 是共用代码，不要直接执行；`jenkins_build.sh` 是旧入口，新调用不要用。

先按下面的意图表判断要做什么，再读对应的 `platforms/<平台>.md`（job、参数、已知问题）。只在需要时读，不要提前把三个平台的文档都塞进上下文。凭据和审计日志在本机状态目录，不在 skill 包里，不要读取或转述 `env/` 下的文件。

## 意图

| 用户要 | 做法 |
|---|---|
| iOS / Android 每日最新包、蒲公英固定链接 | 不访问 Jenkins。运行 `ios.sh channels` 或 `android.sh channels`，把链接给用户。密码默认不展示，用户明确要时才加 `password`。这不是某次 Enterprise 构建，不要对每日 job 跑 `latest`。 |
| 每日包定时推送 | 由宿主编排层每天调用 `ios.sh daily` / `android.sh daily`（渠道链接 + 更新说明）。要确认当日是否真有新包，需要蒲公英 API Token 或每日构建 job，这里不做判断。 |
| 打 iOS 测试包、打鸿蒙邀请测试包 | 见「打包流程」。 |
| 打 Android 包 | 机器人不触发 Android（参数里带发布平台账号，由人在 Jenkins 上操作，`android.sh trigger` 会拒绝）。说明现状并给 Jenkins 入口。 |
| 构建到哪了、成功没有、日志、这次包的链接、等它打完、取消排队 | 见「查询与等待」。 |

## 打包流程（iOS、鸿蒙）

1. 读 `platforms/<平台>.md`，运行 `<平台>.sh params`（要 Jenkins 当前实时候选的分支和开关时加 `live`）。把还没指定的选项连同默认值列给开发者，由开发者自己选。没选的项用脚本默认值（`params` 输出里有），开发者也可以覆盖，如 `env=海外`。
2. `main_version` 必须由开发者明确给出，Jenkins API 不返回候选列表。iOS 的 job 是 `v6-Enterprise-2`；鸿蒙的 job 是 `ninebot-harmony-agc`，产物是 AGC 邀请测试分享链接，不上蒲公英。
3. 复述 job、`main_version` 和本次生效参数（被覆盖的项写清楚，默认项可以说"其余用默认"）。
4. 用户明确同意后，才运行 `<平台>.sh trigger <版本> confirm [key=value...]`。

为什么要先确认：每次 trigger 都是对外分发（鸿蒙默认 `auto_submit=true`，会提交 AGC 邀请测试审核，内测群可见），而且 iOS 打包机只有一台旧 Mac，队列很紧。已有构建进行中或排队时 trigger 会拒绝；只有用户明确要再打一个时才加 `force`。

trigger 成功后回执里有「排队号」，并尽力给出「本次构建：#N」。如果没有排队地址，或 POST 结果不确定，先查队列和 `status`，不要直接重试，否则可能打出重复的包。

## 查询与等待

- `status [构建号]`、`log [构建号] [行数]`、`latest`（该 job 最近一次成功构建）、`wait-build`。
- 等本次触发的结果：`wait-build queue <排队号>`；已有构建号就用 `wait-build <构建号>`。没给号码，且当前没有或有多个候选时，脚本会拒绝自动绑定。这是有意为之：不能把别人的构建当成这次结果。
- 完成后带上耗时。失败时给「失败分析」：失败步骤、关键报错、本次构建的 commit / 分支，能定位提交人就列出。
- 成功时：iOS 给蒲公英（或 Jenkins 归档下载）链接与版本号；鸿蒙给邀请测试链接与 versionCode；Android 给 APK 产物名与蒲公英状态。
- 取消排队：先运行 `cancel` 列出队列，用户确认 queue id 后再 `cancel <id>`。它只取消排队项，不会停止运行中的构建。
- `JOB` 环境变量可传登记文件里的 job 名或别名：iOS `enterprise`（默认）/ `cn` / `os`，鸿蒙 `agc`（默认），Android `cn`（默认）/ `os`。iOS 的 `cn` / `os` 和 Android 只能查询、取消排队。

## 命令速查

| 命令 | 说明 |
|---|---|
| `ios.sh` / `harmony.sh` `params [live]` | 触发前的可选参数清单。默认离线列脚本默认值与可选值，`live` 追加 Jenkins 实时候选。`android.sh params` 只说明人工触发 |
| `ios.sh` / `harmony.sh` `trigger <版本> confirm [force] [key=value...]` | 触发。没有 `confirm` 会失败 |
| 三个脚本都有 `wait-build [queue <排队号> \| <构建号>]` | 等到最终结果 |
| 三个脚本都有 `status [构建号]` / `latest` / `log [构建号] [行数]` / `cancel [id]` / `jobs` | 查询与取消排队 |
| `ios.sh` / `android.sh` `channels [password]`、`daily` | 每日包（鸿蒙没有） |

## 完成通知

构建完成后的主动通知由宿主编排层（冯宝宝机器人）负责，本 skill 只提供数据：

1. 触发时把发起者经环境变量 `JENKINS_TRIGGER_BY` 传给脚本，输出会回显「触发人：xxx」。
2. 用回执里的排队号轮询 `wait-build queue <排队号>`，已有构建号则 `wait-build <构建号>`。结果里有构建号、状态、耗时、产物链接、版本信息，以及「本次打包参数（Jenkins 记录）」，即这次构建实际发送的白名单参数。原样转述给触发人，让他知道包用了哪些参数；没取到就省略，不要编造。
3. @ 发起者回复。iOS 模板：`@发起者 你的包好了：#N · SUCCESS · 耗时 X 分钟 · 版本 6.10.13.5107 · 蒲公英：<主页链接>（短链 <短链接>）· 参数：branch=… Service_Key=… main_version=…`。鸿蒙模板：`@发起者 你的鸿蒙包好了：#N · SUCCESS · 耗时 X 分钟 · versionCode 610131377 · 邀请测试：<分享链接> · 参数：branch=… products=… main_version=…`。版本信息没给就省略该段。
4. 链接以 `wait-build` 提取到的为准，不要引用旧包（蒲公英固定链接指向最新上传版本）。iOS 构建成功后控制台可能没有蒲公英链接，这时脚本给的是「Jenkins 产物下载（需登录）」：通知里说明本次没上传蒲公英，附产物文件名和链接，并提示需要 Jenkins 账号（背景见 `platforms/ios.md` 的已知问题）。产物信息暂不可用时，只报告已确认的构建状态并给构建页，不猜测分发是否成功，也不要因此重新触发。
5. 构建失败时转述「失败分析」里的失败步骤与关键报错。失败的包不会上传蒲公英或 AGC。
6. 本机 macOS 桌面通知是可选的：用户自己 `export JENKINS_NOTIFY=1` 才会开启。不要替用户开启或代做授权，用户问起时指到 README。

## 安全

1. 凭据只来自环境变量或本机状态目录的 `env/<平台>.env`。不要把凭据和渠道密码写进群消息、日志、SKILL.md 或 README，也不要把 env 文件内容贴进对话。
2. 触发只接受 `platforms/<平台>.md` 参数表里的参数。`account`、`password`、`fabuAccount` 等凭据类参数、未知参数名、含换行的值，脚本都会拒绝。上传、水印、自动提交等开关只接受文档列出的值。
3. 越界的请求由人在 Jenkins 上触发，不要想办法绕过。iOS 的 `Service_Key` 只放行 `dev` 和 `test`（`release`、`migrate_cloud`、`production` 以及发版 / TestFlight job 由人触发）。鸿蒙的 `products` 只放行 `default-prod`，`distribute_mode` 只放行 `1`（生产环境 `online-prod` 和应用市场 `2` 由人触发），`build_version` 只放行 1 到 4 位数字。
4. 脚本只认 `platforms/<平台>.jobs` 里登记的 job，别名也只解析到这些 job。Android 只查询不触发。
5. 蒲公英固定链接指向最新上传的版本。用户要某个历史版本时，直接说明固定链接做不到。
6. `log` 会丢掉含 password、token、Authorization、crumb 的行。回显的「本次打包参数」只含白名单内的参数，凭据类名字一律过滤（Android 白名单为空，不回显任何参数）。转述时以脚本输出为准。
7. 成功的 trigger 会往本机审计日志追加一行（时间、触发人、job、关键参数）。日志只留在本机，不随 skill 分发。

## 示例

**平台不明确**
用户：帮我打个 RN 包
→ 先问是 iOS 还是鸿蒙，并说明 Android 包由人在 Jenkins 上触发。

**iOS 打包**
用户：打个 iOS 6.10.13 的海外包
→ 读 `platforms/ios.md`，运行 `ios.sh params`，把其余选项和默认值列出来。用户选完后复述「`v6-Enterprise-2` · main_version=6.10.13 · env=海外 · 其余用默认」。得到明确同意再运行 `ios.sh trigger 6.10.13 confirm env=海外`。

**越界请求**
用户：Service_Key 用 release 打一个
→ 说明脚本只放行 `dev` / `test`，`release` 由人在 Jenkins 上触发，可以改用 `test` 先打。
