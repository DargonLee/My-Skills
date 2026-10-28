# HarmonyOS 打包

由主 skill 按路径读取。安全约束在主 `SKILL.md`。脚本是 `scripts/harmony.sh`。凭据在本机状态目录的 `env/harmony.env`（见 README「配置」）。没有每日包渠道配置（无 `channels` / `daily`）。

## Jenkins

- 地址：`https://jenkins.ninebot.com`（主 Jenkins，与 Android 共用；构建机是 master 的 Mac，队列常见）
- 凭据：本机状态目录的 `env/harmony.env`（2026-10-20 已验证可查询、可触发）
- 打包入口：job `ninebot-harmony-agc`，鸿蒙邀请测试打包（AGC 邀请测试，仅内部账号）
- 内部公共测试账号：见 Jenkins 上 `ninebot-harmony-agc` 的 job 描述，不在 skill 里存放个人联系方式。

## Job（登记在 `platforms/harmony.jobs`）

脚本 `scripts/harmony.sh` 的白名单与别名都从登记文件读取，改名只改登记文件和本表。

| 别名 | job | 用途 | 脚本 |
|---|---|---|---|
| `agc`（默认）/ `鸿蒙` | ninebot-harmony-agc | 鸿蒙邀请测试打包（参数已实测，2026-10-20 由 skill 触发 #345 SUCCESS） | 可 trigger / 查询 / 取消排队 |
| — | ninebot-hap | 旧 HAP 打包（2026-08 起未用，最近 FAILURE） | 只查询、取消排队 |
| — | ninebot-hap-develop | 旧 HAP develop 打包（2026-09 起未用） | 只查询、取消排队 |
| — | ninebot-hap-signer | HAP 签名（非参数化） | 只查询、取消排队 |
| — | 其余（android-segway-orv、apk-encrypt-* 等） | 其他项目 | 拒绝 |

## 参数（ninebot-harmony-agc，2026-10-20 从 job 配置核对）

必填：`main_version`（位置参数）。脚本默认值与本表一致；`build_version`、`rn_branch_name` 不在默认清单里，用户显式传入才发送。

| 参数 | 默认 | 可选值 / 说明 |
|---|---|---|
| main_version | 必填 | 动态列表（6.10.13 / 6.10.12 / …）。错误值 Jenkins 会拒绝 |
| products | default-prod | default-prod 测试环境 / online-prod 生产环境。脚本只放行 default-prod |
| branch | develop | 鸿蒙仓库分支（develop / release / feature…） |
| kuikly_branch_name | develop | kuikly 工程分支（列表当前只有 develop） |
| build_version | （不发送） | 4 位 build 号；留空由打包机计数器递增。脚本只放行 1-4 位数字 |
| rn_branch_name | （不发送） | RN 模块分支；留空不改 DEFAULT_HARMONY_BRANCH |
| app_desc | jenkins | 邀请测试版本说明 |
| auto_submit | true | 是否自动提交邀请测试审核；可传 false 只打包不提交 |
| distribute_mode | 1 | 1 仅测试 / 2 应用市场。脚本只放行 1 |

脚本仅接受本表参数名。未知参数名、带换行/控制字符的值，以及 `account`、`password`、`fabuAccount`（不区分大小写）都会被脚本拒绝。

## 流程与产物

构建 HAP/app → 签名 → 上传 AGC → 提交邀请测试（内测群「【内部】纳恩博App测试」）→ 出分享链接。控制台同时会推企业微信/飞书群通知。构建耗时参考 15~32 分钟。`latest` / `wait-build` 成功时从控制台提取：

- `邀请测试链接：https://appgallery.huawei.com/apptest/join/…`
- `versionCode：610131377`（前 5 位是 main_version 编码，末 4 位是本次 build 号）

触发前先让开发者主动选择分支与参数：

```bash
bash ROOT/scripts/harmony.sh params          # 离线清单：每个参数的默认值与可选值
bash ROOT/scripts/harmony.sh params live     # 拉 Jenkins 实时候选版本/分支/选项（只列白名单参数）
```

`params live` 会先显示脚本本地默认值和限制，再列 Jenkins 的全部实时候选；`online-prod`、`distribute_mode=2` 即使出现在 Jenkins 候选里，仍不能由脚本触发。`main_version` 即使有 Jenkins 预设，脚本也要求显式给出。只对可触发的 AGC job 开放。

用户确认后的触发示例（`ROOT` 为本 skill 根目录）：

```bash
bash ROOT/scripts/harmony.sh trigger 6.10.13 confirm                    # 全默认：测试环境 develop 包
bash ROOT/scripts/harmony.sh trigger 6.10.13 confirm rn_branch_name=feat_v1
JENKINS_TRIGGER_BY=张三 bash ROOT/scripts/harmony.sh trigger 6.10.13 confirm
bash ROOT/scripts/harmony.sh wait-build queue <排队号>
bash ROOT/scripts/harmony.sh wait-build 345
JOB=ninebot-hap bash ROOT/scripts/harmony.sh status
```

- 已有构建进行中/排队时 `trigger` 默认拒绝并提示，用户明确要求再打一个时才加 `force`。
- 触发时未指定的参数走脚本默认值（见上表），脚本会先输出「本次打包参数」完整清单再触发。
- `wait-build`/`status`/`latest` 完成后会从 Jenkins 记录带出「本次打包参数（Jenkins 记录）」，展示这次构建实际发送的白名单参数（products、branch、main_version、auto_submit 等真实值）。
- `online-prod`（生产环境）与 `distribute_mode=2`（应用市场）由人在 Jenkins 上触发，脚本直接拒绝。
- 构建失败时 `status` / `wait-build` 附失败分析与提交信息，转述关键原因即可。

## 待确认

- 发版（应用市场正式包）是否有独立流程，接入前先问清。
- 每日包：鸿蒙暂无固定渠道，有的话再补 `channels`。
