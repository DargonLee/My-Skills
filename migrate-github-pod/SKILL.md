---
name: migrate-github-pod
description: 把 GitHub 开源 CocoaPods 库迁移/私有化到九号私有 GitLab(git.ninebot.com)并用 ninebot-cli 发布到 NBSpecs。当用户要求"把某个 GitHub pod 改为私有仓库"、"XX 库私有化"、"平移 XX 到 git.ninebot.com"、"发布到 NBSpecs"、"ninebot-cli repo publish"时使用。涵盖现状盘点、版本基线选择、podspec source 修改、打 tag、发布、误发布清理、端到端验证。
---

# GitHub Pod 依赖私有化迁移

## 基础设施

- 私有 GitLab:`git.ninebot.com`,iOS 组仓库地址 `git@git.ninebot.com:iOS/<Name>.git`
- 私有 specs 仓库:NBSpecs(`~/.cocoapods/repos/NBSpecs/`),目录结构 `<Name>/<version>/<Name>.podspec`
- 发布工具:`ninebot-cli repo publish <绝对路径>.podspec`(支持 `--dry-run`;默认 repo=NBSpecs,从 `ninebot-cli config --show` 读取)
- ninebot-cli 源码(pipx):`~/.local/pipx/venvs/ninebot-cli/lib/python*/site-packages/ninebot_cli/commands/pod_repo.py`,行为有疑问直接读源码
- 用户已有的私有仓库本地克隆惯例放 `/Users/ninebot/Desktop/Work/iOS-Pods/<Name>`(存在则直接用,不要另建克隆)

## 铁律(用户明确要求过)

- **podspec 文件名和 `s.name` 绝不改,内容只改 `s.source` 的 git 地址**。改名会波及消费方:主工程 ios-app(`/Users/ninebot/Desktop/Work/ninebot-rn/ios-app`)Podfile.lock 按名依赖、业务代码按名 import(曾见 15 处)。原名即使带历史后缀(如 NSAttributedStringBuilder13 的 "13" 是公共仓重名产物)也保留
- README 至多补安装说明(加私有 source 行),其余上游文件一律不动

## 工作流程

### 1. 现状盘点(先查再动)

1. 消费方检查:grep ios-app 的 Podfile/Podfile.lock 确认依赖名与当前解析源(NBSpecs 首位 source 优先于公共镜像)
2. `git ls-remote git@git.ninebot.com:iOS/<Name>.git` — 私仓是否存在、是否为空(exit 0 无输出=存在且空)
3. `ls ~/.cocoapods/repos/NBSpecs/<Name>/` — 是否已发布过版本
4. 私仓已有同名库但历史独立(网页上传/二进制化重做)时,先 fetch 对比,**严禁 mirror 全量覆盖已有分支**;若已有 tag 源码与要迁移的一致(`git diff <tag> <分支> -- Sources/`),直接引用该版本,不打新 tag 不重复发布

### 2. 选版本基线(不要盲用默认分支 HEAD)

- 找**最新稳定 tag**:`git tag -l | grep -E '^[0-9]' | grep -vE 'alpha|beta'`,再与默认分支 podspec 的 s.version 对照
- 默认分支可能是 develop/alpha 线(如 GuanceSDK 默认分支是 1.6.7-alpha.2,而最新稳定 tag 是 1.6.7 且领先 master);用 `git show <tag>:<Name>.podspec | grep version` 确认 tag 与版本对应
- 私仓分支惯例:**master = 最新稳定 tag + 迁移提交**;上游 develop 等分支原样推送便于后续同步
- 版本号沿用上游,不发明新版本

### 3. 代码平移与提交

1. 克隆 GitHub 仓库,`git checkout -B master <稳定tag>`
2. 仅改 podspec 的 `s.source` → `git@git.ninebot.com:iOS/<Name>.git`,提交
3. `git remote remove origin && git remote add origin git@git.ninebot.com:iOS/<Name>.git`
4. **删除全部本地 tag**(`git tag -l | xargs git tag -d`),只 push 分支(`git push -u origin master develop`)。原因见下
5. 中文 commit message 直接 `-m` 即可

### 4. ninebot-cli repo publish 的 tag 行为(必读,有坑)

publish 对 podspec 所在 git 仓库执行:
- 版本 tag 不存在 → 在**当前 HEAD** 创建并推送(所以必须先 commit,tag 才含 source 修改)
- tag 存在但不指向 HEAD → **删本地+远端 tag 重建到 HEAD**;远端是空私仓时"删远端 tag"必失败,整个 publish 中止
- 因此第 3 步先清本地 tag,让 CLI 走"新建"分支;若私仓已有旧 tag,CLI 会自动删旧建新(可行)
- 误发布错条目(如错名/错版本):`cd ~/.cocoapods/repos/NBSpecs && git rm -r <Name> && git commit && git push`,再重新 publish 正确条目

### 5. 端到端验证(临时工程,勿在主工程验证)

```bash
mkdir -p /tmp/<name>-verify/Verify && cd /tmp/<name>-verify
printf "source 'git@git.ninebot.com:iOS/NBSpecs.git'\nplatform :ios, '13.0'\ntarget 'Verify' do\n  pod '<Name>'\nend\n" > Podfile
# project.yml: type application, sources [Verify],
#   GENERATE_INFOPLIST_FILE: YES(否则 Validate 阶段失败)
#   含 C++ 的 pod 另加 OTHER_LDFLAGS: -lc++、CLANG_CXX_LANGUAGE_STANDARD: gnu++20
xcodegen generate && pod install && xcodebuild -workspace Verify.xcworkspace -scheme Verify \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

- App 源码里 `import <Name>` 并引用真实类名(先 grep Pods 里的头文件确认符号存在,别猜)
- **xcodegen 重新生成工程后必须重跑 pod install**(工程配置被重写,否则 "Unable to find module dependency")
- 看 xcodebuild 结果只 grep `"^\*\* BUILD|^[^ ]+error:"`(-Werror 参数会误匹配 "error")
- C++ 静态库 pod 报 `std::set_terminate` 等 undefined symbols 是接入方缺 libc++,不是迁移问题;RN 主工程天然已链 libc++

### 6. 汇报与收尾

- 汇报:私仓分支/tag、NBSpecs 条目、验证结果、业务方 Podfile 写法(`pod '<Name>', '<version>'`,NBSpecs 为首位 source 自动优先)
- 清理 /tmp 验证工程;已迁移的本地克隆(如 ~/Downloads/003 下)告知用户位置供后续发版
- 若消费方此前从公共源解析,提示切换命令:`pod update <Name>`

## 参考案例

- **NSAttributedStringBuilder13**(2026-10-14,版本 0.4.1):上游因公共仓重名带 13 后缀,保留原名只改 source;曾误改名发布为 NSAttributedStringBuilder,已从 NBSpecs 清理(`git rm -r` + 重发)。ios-app 15 处 import 按名依赖
- **GuanceSDK**(2026-10-15,版本 1.6.7):默认分支 develop 是 alpha,选稳定 tag 1.6.7 为 master 基线(领先上游 master),develop 原样推送;含 C++ 源码,纯 ObjC/Swift 接入方需 -lc++;无外部依赖全 subspec 自包含
- **ZLPhotoBrowser**(2026-09-15):私仓已有独立历史,盘点发现 NBSpecs 已发布的 4.2.5.2 源码与 GitHub fix 分支一致,直接改引用,零迁移零发布
