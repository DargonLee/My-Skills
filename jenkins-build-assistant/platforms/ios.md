# iOS 打包

由主 skill 按路径读取。安全约束在主 `SKILL.md`。

## Jenkins

- 地址：`https://jenkins-ios.ninebot.com`（Remote API 已打通，2026-10-12）
- 凭据：本 skill 的 `env/ios.env`。`JENKINS_USER` 是 Jenkins 用户 id，不是 API Token 的名称。
- 构建机只有 1 台旧 Mac，队列常见

## Job（登记在 `platforms/ios.jobs`）

脚本 `scripts/ios.sh` 的白名单与别名都从登记文件读取，改名只改登记文件和本表。2026-10-13 用 Jenkins 用户 `dev` 核对过，可见 25 个 job，海外每日包的全名是 `ninebot-iOS-v6-Develop-Overseas`。

| 别名 | job | 用途 | 脚本 |
|---|---|---|---|
| `enterprise`（默认） | v6-Enterprise-2 | Enterprise 主包（参数已实测） | 可 trigger / 查询 / 取消排队 |
| `cn` / `国内` | ninebot-iOS-v6-Develop | 国内打包 job：每日 develop（定时 + 人工触发；2026-10-20 #4353 SUCCESS） | 只查询、取消排队 |
| `os` / `海外` | ninebot-iOS-v6-Develop-Overseas | 海外打包 job：每日 develop 海外（2026-10-20 最近成功 #1705） | 只查询、取消排队 |
| — | ninebot-iOS-v6-Release / -Overseas | 发版 | 拒绝 |
| — | ninebot-iOS-v6-TestFlight / -Overseas | TestFlight | 拒绝 |
| — | 其余（NimbleAI、售后 app-rn、壳 XChange 等） | 其他项目 | 拒绝 |

两个 Develop job 的参数（2026-10-20）：`Service_Key`、`main_version`（无默认，必填）、`branch=develop`、`Confusion=易盾加固`、`BuildConfiguration=Debug`、`needUpdateStringPackage=Yes`、`channel=Develop`、`watermark`、`rnEnv`、`rnBranchName`，国内多 `PgyerChannel`，海外多 `needUpload`。定时触发用 `Service_Key=test needUpload=No`。机器人目前只查询它们；要改成可触发需先定默认值并加进白名单。

每日固定渠道不要对上述 job 跑 `latest`。走 `scripts/ios.sh channels`（键：`IOS_CN_URL`、`IOS_CN_PASSWORD`、`IOS_OS_URL`、`IOS_OS_PASSWORD`）。

## 参数（v6-Enterprise-2，2026-10-12）

必填：`Service_Key`、`main_version`、`branch`。脚本默认值与本表一致。

| 参数 | 默认 | 可选值 / 说明 |
|---|---|---|
| Service_Key | test | dev / test / release / migrate_cloud / production。脚本只放行 dev、test |
| main_version | 必填 | 动态列表。错误值会导致构建失败 |
| branch | develop | develop / release / feature… |
| env | 国内 | 国内 / 海外 |
| BuildConfiguration | Debug | Debug / Release |
| channel | Release | Develop 时 RN 显示 R debug 按钮 |
| Confusion | 无 | 易盾加固 / 无 |
| Xcode | 26 | 26 / 27 / 16 |
| needUpload | No | No / Yes。此前 No 仍曾上传；当前 job 的上传步骤已移除，见下方已知问题 |
| watermark | false | true / false；水印 |
| needUpdateStringPackage | No | No / Yes；服务端没有对应文案版本时会失败 |
| ShopDebug | 0 | 商城调试按钮 |

脚本仅接受本表参数，以及这些额外参数名：`RNProjectBranch`、`rnEnv`、`rnBranchName`、`dynamicBranchName`、`team_id_info`、`PgyerChannel`、`progressTime`；额外参数的值原样传给 Jenkins。未知参数名、带换行符的值，以及 `account`、`password`、`fabuAccount`（不区分大小写）都会被脚本拒绝。

`Service_Key` 和 `main_version` 的可选项在构建机 `/Users/ninebot/ninebot/IPAPackage/Shell/jenkins_config.properties`（`app_env` / `versions`）。Remote API 不返回这些选项，传入后由 Jenkins 校验。

用户确认后的触发示例（`ROOT` 为本 skill 根目录）：

```bash
bash ROOT/scripts/ios.sh trigger 6.10.12 confirm branch=develop env=海外   # 触发成功即回执「排队号」与「本次构建：#N」
JENKINS_TRIGGER_BY=张三 bash ROOT/scripts/ios.sh trigger 6.10.12 confirm   # 挂载层透传触发人，输出回显
bash ROOT/scripts/ios.sh wait-build queue <排队号>   # 等到这次排队项对应的构建结束
bash ROOT/scripts/ios.sh wait-build 2042             # 已有构建号时，只等这一次
JOB=cn bash ROOT/scripts/ios.sh latest               # 国内每日 job（别名，等价于 JOB=ninebot-iOS-v6-Develop）
JOB=os bash ROOT/scripts/ios.sh status               # 海外每日 job
```

- 已有构建进行中/排队时，`trigger` 默认拒绝并提示，用户明确要求再打一个时才加 `force`：`trigger 6.10.12 confirm force`。
- 触发时未指定的参数全部走上表默认值，脚本会先输出「本次打包参数」完整清单再触发；用户要改默认值直接加 `key=value`，如 `trigger 6.10.12 confirm env=海外 BuildConfiguration=Release`。
- 构建完成的主动通知由冯宝宝编排：触发时记录发起者 → 经 `JENKINS_TRIGGER_BY` 透传 → 用回执里的排队号轮询 `wait-build queue <排队号>`（已有构建号则 `wait-build <构建号>`）→ 把这一次的构建版本号（#N）+状态+耗时+蒲公英地址 定向回复发起者。
- 每日包：`channels` 默认只给链接，需要密码时 `channels password`；挂载层每天定时 `daily` 推送渠道与更新说明。
- 构建失败时 `status` / `wait-build` 会附失败步骤、最多 5 条关键报错和可用的提交信息（脱敏），直接转述关键原因即可。

## 已知问题

- **蒲公英上传步骤已被移出 job（2026-10-20）**：`v6-Enterprise-2` 的 publishers 当天只剩 ArtifactArchiver + PostBuildScript（10-19 的 #2072/#2073 还有 196~206 行 `[UPLOAD TO PGYER]`；10-20 #2077 一行没有）。此前它是 `Upload to pgyer with apiV2`，10-15 起常把构建标成失败，推测因此被移除。现状：构建成功 → IPA 归档为 Jenkins 产物（`artifact/ios/ipa/Ninebot_<region>_<branch>_<Service_Key>_v6.10.13(5119)_<日期>_<时间>.ipa`，下载需 Jenkins 登录）。`latest` / `wait-build` 控制台没蒲公英时自动改给该下载链接，并从文件名解析「版本号：6.10.13.5119」（末段 5119 即 app 构建编号）。要让测试同学免登录拿包，需要 Jenkins 侧恢复蒲公英上传（或换别的分发）。
- 蒲公英上传在时输出 `[UPLOAD TO PGYER] - 版本号：6.10.13.5107` 与 `版本编号：5107`（app 的 4 位构建编号，非 Jenkins #N）；`latest` / `wait-build` 会一并提取输出「版本号：6.10.13.5107」（末段即构建编号，不再单独重复输出）。`build号：151` 是蒲公英上传序号，不输出。
- `needUpload=No` 过去仍会上传蒲公英（2026-10-12 #2024）；上传步骤恢复后需重新核对该行为。

## 待确认

渠道里「指定版本下载」的回复话术还没有定。
