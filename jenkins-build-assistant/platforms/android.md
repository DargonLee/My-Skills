# Android 打包

由主 skill 按路径读取。安全约束在主 `SKILL.md`。脚本是 `scripts/android.sh`（只查询，不触发），凭据在 `env/android.env`，job 登记在 `platforms/android.jobs`。

每日包：用户要安卓最新包时，执行 `scripts/android.sh channels`（键：`ANDROID_CN_URL`、`ANDROID_CN_PASSWORD`、`ANDROID_OS_URL`、`ANDROID_OS_PASSWORD`）。密码默认不展示，确认需要时 `channels password`。每日包主动推送由挂载层定时执行 `android.sh daily`。

## Jenkins

- 地址：`https://jenkins.ninebot.com`（主 Jenkins，与鸿蒙共用；2026-10-20 Remote API 已打通，`env/android.env` 可查询）
- 凭据：本 skill 的 `env/android.env`（与 `env/harmony.env` 相同的机器人账号 / API Token，不是个人邮箱开机密码）
- 每日测试包由 `baseline` 分支在凌晨自动打并上传蒲公英；链接和密码在 `env/channels`

## Job（登记在 `platforms/android.jobs`）

脚本白名单与别名都从登记文件读取，改名只改登记文件和本表。

| 别名 | job | 用途 | 脚本 |
|---|---|---|---|
| `cn`（默认）/ `国内` | ninebot-android-国内-v6-copy | 国内测试包（人工触发；2026-10-20 #1277 SUCCESS，25 分钟） | 只查询、取消排队 |
| `os` / `海外` | ninebot-android-海外-v6 | 海外测试包（人工触发；2026-10-19 #1895 SUCCESS，52 分钟） | 只查询、取消排队 |
| — | 其余（ninebot-android-国内-v6、ninebot-android-海外-develop分支、*-release、apk-encrypt-* 等） | 其他 | 拒绝 |

- 2026-10-20 用户更正：海外 job 是 `ninebot-android-海外-v6`，不是 `ninebot-android-海外-develop分支`（后者没有任何构建记录，默认版本还是 5.9.0）。
- `trigger` 一律拒绝：Android 测试包参数里带发布平台账号（`fabu_user_name` / `fabu_user_password` / `fabu_teamId`）与加固开关，由人在 Jenkins 上触发。要让机器人触发需先定参数白名单与默认值。

## 参数（2026-10-20 从 job 配置核对，仅供看懂构建）

国内 `ninebot-android-国内-v6-copy`：`branch`（默认 baseline）、`main_version`（6.10.13）、`build_type`（Debug）、`nb_http_host_env_type`（test）、`bugsnagReleaseStage`、`config`、`dynamicBranchSupport` / `dynamicBranchName`、`rnBranchSupport` / `rnBranchName`、`thirdPartsDev` / `thridPartsDevPort`、`is_encrypt`（true）/ `is_encrypt_so`、`watermark_enable` / `feedback_enable` / `internal_test_tag`、`isUpload`（false）、`pgyer_channel`、`fabu_user_name` / `fabu_user_password` / `fabu_teamId`、`downloadBackupConfig`。

海外 `ninebot-android-海外-v6`：`branch`（baseline）、`main_version`（6.10.13）、`build_type`（Debug）、`nb_http_host_env_type`（test）、`test_server_address_overseas` / `new_test_server_address_overseas` / `java_test_server_address_overseas`、`bugsnagReleaseStage`、`config`、`dynamicBranchSupport` / `dynamicBranchName`、`rnBranchSupport` / `rnBranchName`、`is_encrypt` / `is_encrypt_so`、`watermark_enable`、`isUpload`（false）、`pgyer_channel`、`downloadBackupConfig`、`downloadPlatform`、`here_reroute_report_enable` / `here_reroute_record_event_enable`。

## 产物

`latest` / `wait-build` 成功时从控制台提取：

- `产物：Segway-Ninebot_v6.10.13_domestic_debug_202610201033_ddfe151186_with_so_encrypted.apk`（海外是 `…_overseas_debug_…`；文件名含版本、环境、时间戳、commit）
- 上传了蒲公英时给 `蒲公英下载：` / `短链接：`；`isUpload=false` 时提示「本次构建不上传（isUpload=false），包在打包机上」

示例（`ROOT` 为本 skill 根目录）：

```bash
bash ROOT/scripts/android.sh status            # 国内最近一次构建
JOB=os bash ROOT/scripts/android.sh status     # 海外最近一次构建
bash ROOT/scripts/android.sh latest
bash ROOT/scripts/android.sh wait-build 1277
bash ROOT/scripts/android.sh log 1277 20
```

## 待确认

- 是否需要机器人触发 Android 测试包；若需要，定参数白名单（排除 `fabu_*`）与默认值。
- 泰坦（容器化）计划在 10–11 月先试点 RN / Android。

资料：

- https://bytedance.feishu.cn/wiki/Jwqxw6OMjiHHImkyrrfcnMHQnhf
- https://bytedance.feishu.cn/wiki/YVI6wyCG2iLvvFkpCoLcbzkHnnc
- https://bytedance.feishu.cn/wiki/NWyYwejyqiZShBkrygkcu76pn8e
- https://bytedance.feishu.cn/docx/DmYRdbJTKozWPSxodWtcZvzYnGb
