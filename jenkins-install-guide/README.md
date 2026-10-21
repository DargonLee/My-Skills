# Jenkins 打包技能 · 安装与使用向导

行为、路由以 `SKILL.md` 为准。本包是 **jenkins-build-assistant** 的安装与使用向导，供冯宝宝在对话中引导开发者完成安装与使用。

## 快速指引

1. **安装**（唯一方式）：下载并安装豆包工作客户端、登录公司账号，在对话中说「帮我安装 Jenkins 打包技能， https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip」，豆包自动从该链接下载解压到 `~/DoubaoWork/skills/jenkins-build-assistant`
2. **凭据**：已内置 `env/ios.env`，无需填写。
3. **验证**：`bash ~/DoubaoWork/skills/jenkins-build-assistant/scripts/ios.sh status` 或对话「查一下 v6-Enterprise-2 最近构建状态」。

## 常用命令（jenkins-build-assistant）

| 命令 | 作用 |
|---|---|
| `scripts/ios.sh channels [password]` | iOS 每日包蒲公英链接（密码默认隐藏） |
| `scripts/android.sh channels [password]` | Android 每日包链接 |
| `scripts/ios.sh trigger <版本> confirm [force] [key=value...]` | 触发 iOS 打包，先复述参数再 confirm |
| `scripts/ios.sh wait-build <构建号>` / `wait-build queue <排队号>` | 等构建/排队结束，输出版本号、状态、耗时、蒲公英地址 |
| `scripts/ios.sh status [构建号]` | 构建状态，失败附「失败分析」 |
| `scripts/ios.sh latest` / `log [号] [行数]` | 最近成功构建 / 控制台日志 |
| `scripts/ios.sh cancel [id]` | 列出/取消排队 |
| `scripts/ios.sh daily` | 每日包主动推送入口 |

## 分发/更新

- 主下载入口：`https://platform-doc-dev.ninebot.com/files/skills/jenkins-build-assistant.zip`；维护者源码在 `/Users/ninebot/Desktop/Github/My-Skills/jenkins-build-assistant`，更新后重新打包并发布到该直链。
- 打包时**不带** `env/`、`logs/`、`assets/`、`mcp/` 等本机内容；分发包内置凭据于 `env/ios.env`（团队共享打包账号，已确认由团队管理员维护）。
