---
name: migrate-github-pod
description: 把 GitHub 开源 CocoaPods 库迁移/私有化到九号私有 GitLab(git.ninebot.com)并用 ninebot-cli 发布到 NBSpecs,或在私仓已有时同步上游新版本(更新 tag、重新发布)。当用户要求"把某个 GitHub pod 改为私有仓库"、"XX 库私有化"、"平移 XX 到 git.ninebot.com"、"发布到 NBSpecs"、"ninebot-cli repo publish"、"更新/同步私仓里的 XX 到上游新版"时使用。涵盖现状盘点、版本基线选择、podspec source 修改、打 tag、发布、误发布清理、端到端验证。
---

# GitHub Pod 依赖私有化迁移

## 基础设施

- 私有 GitLab:`git.ninebot.com`,iOS 组仓库地址 `git@git.ninebot.com:iOS/<Name>.git`
- 私有 specs 仓库:NBSpecs(`~/.cocoapods/repos/NBSpecs/`),目录结构 `<Name>/<version>/<Name>.podspec`
- 发布工具:`ninebot-cli repo publish <绝对路径>.podspec`(支持 `--dry-run`;默认 repo=NBSpecs,从 `ninebot-cli config --show` 读取)
- ninebot-cli 源码(pipx):`~/.local/pipx/venvs/ninebot-cli/lib/python*/site-packages/ninebot_cli/commands/pod_repo.py`,行为有疑问直接读源码
- **GitHub 上游代码一律在临时目录拉取**(用户明确要求):`/tmp/<name>-sync/upstream` 放上游克隆、`/tmp/<name>-sync/private` 放私仓克隆,全部处理完成(推送+发布+验证)后删除整个 `/tmp/<name>-sync`。仅当用户明确要求保留克隆供后续发版时才放到 `/Users/ninebot/Desktop/Work/iOS-Pods/<Name>`(存在则直接用,不要另建克隆)
- GitHub 直连常超时(国内网络)。先测 `curl -m 10 https://github.com`,不通则用镜像克隆:`git clone https://gh-proxy.com/https://github.com/<owner>/<repo>.git`(gh-proxy.com 实测可用;gitclone.com 返回 502 不可用)

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
- 升级基线时对比新旧 tag 的 podspec `deployment_target` 等重大变更(如 datakit 1.6.7→1.6.8 最低 iOS 12→15,breaking),提前核对消费方主工程 platform 并在汇报中明确提示

### 3A. 首次迁移:代码平移与提交

1. 在 `/tmp/<name>-sync/` 下克隆 GitHub 上游(直连不通走 gh-proxy 镜像)与私仓,`git checkout -B master <稳定tag>`
2. 仅改 podspec 的 `s.source` → `git@git.ninebot.com:iOS/<Name>.git`,提交
3. `git remote remove origin && git remote add origin git@git.ninebot.com:iOS/<Name>.git`
4. **删除全部本地 tag**(`git tag -l | xargs git tag -d`),只 push 分支(`git push -u origin master develop`)。原因见下
5. 中文 commit message 直接 `-m` 即可

### 3B. 更新已有私仓(上游发新版)

1. 盘点差距:私仓 master 上的迁移提交/基线版本 vs 上游最新稳定 tag;私仓 develop vs 上游 develop 用 `git rev-list --count <私仓develop>..<上游develop>` 判断,为 0 则 develop 零推送
2. **master 是 GitLab 受保护分支,禁 force push**:不要基线重建后强推,改用 merge——在私仓 clone 里把上游稳定 tag fetch 进来(`git fetch <上游remote>`),在 master 上 `git merge <上游tag>`。迁移提交只改过 source 一行,上游不动该行则零冲突自动合并;有冲突仅会在 podspec,解法=版本/deployment_target 取上游、source 取私仓
3. fetch 上游 tag 的坑:私仓同名 tag 指向不同提交时 `git fetch --tags` 整体 rejected(`would clobber existing tag`),用引用前缀映射拉独立命名空间:`git fetch upstream 'refs/tags/*:refs/tags/upstream-tags/*'` 再 merge `upstream-tags/<版本>`;注意"删全部本地 tag"也会删掉它们,顺序=先 fetch tag → merge → 再删 tag
4. merge 后验证:`git diff <上游tag> HEAD` 应只剩 podspec 的 source 一行,然后普通 push master(fast-forward,无需 force)
5. develop 落后于上游时:checkout develop 后 merge 上游 develop(或 fast-forward),普通 push
6. 发布新版走第 4 节 CLI(它在 merge 后的 HEAD 建 tag);发布完删除 `/tmp/<name>-sync`

### 4. ninebot-cli repo publish 的 tag 行为(必读,有坑)

publish 对 podspec 所在 git 仓库执行:
- 版本 tag 不存在 → 在**当前 HEAD** 创建并推送(所以必须先 commit,tag 才含 source 修改)
- tag 存在但不指向 HEAD → **删本地+远端 tag 重建到 HEAD**;远端是空私仓时"删远端 tag"必失败,整个 publish 中止
- 因此 3A/3B 收尾时先清本地 tag,让 CLI 走"新建"分支;若私仓已有旧 tag,CLI 会自动删旧建新(可行)
- 误发布错条目(如错名/错版本):`cd ~/.cocoapods/repos/NBSpecs && git rm -r <Name> && git commit && git push`,再重新 publish 正确条目

### 5. 端到端验证(临时工程,勿在主工程验证)

```bash
mkdir -p /tmp/<name>-verify/Verify && cd /tmp/<name>-verify
printf "source 'git@git.ninebot.com:iOS/NBSpecs.git'\nplatform :ios, '13.0'\ntarget 'Verify' do\n  pod '<Name>'\nend\n" > Podfile
# project.yml: type application, sources [Verify],
#   GENERATE_INFOPLIST_FILE: YES(否则 Validate 阶段失败)
#   含 C++ 的 pod 另加 OTHER_LDFLAGS: "$(inherited) -lc++"、CLANG_CXX_LANGUAGE_STANDARD: gnu++20
#   platform 按该版本 podspec 的 deployment_target 写(如 GuanceSDK 1.6.8 起 15.0)
xcodegen generate && pod install && xcodebuild -workspace Verify.xcworkspace -scheme Verify \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

- App 源码里 `import <Name>` 并引用真实类名(先 grep Pods 里的头文件确认符号存在,别猜)
- **xcodegen 重新生成工程后必须重跑 pod install**(工程配置被重写,否则 "Unable to find module dependency")
- 看 xcodebuild 结果只 grep `"^\*\* BUILD|^[^ ]+error:"`(-Werror 参数会误匹配 "error");注意 grep -c 计数为 0 会中断 `&&` 链,增量 pod install 无 Installing 输出属正常
- OTHER_LDFLAGS 必须带 `$(inherited)` 前缀,否则覆盖 Pods xcconfig 引发链接告警甚至失败
- C++ 静态库 pod 报 `std::set_terminate` 等 undefined symbols 是接入方缺 libc++,不是迁移问题;RN 主工程天然已链 libc++
- pod 含 Swift 源码而验证工程纯 ObjC 时,报 `__swift_FORCE_LOAD_$_swiftCompatibilityXX` 符号缺失——接入方问题,给 target 加一个空 `.swift` 文件 + `SWIFT_VERSION` 即引入 Swift 运行时(如 GuanceSDK 1.6.8 起含 FTRUMSwiftUI;RN 主工程有 Swift 无碍)

### 6. 汇报与收尾

- 汇报:私仓分支/tag、NBSpecs 条目、验证结果、业务方 Podfile 写法(`pod '<Name>', '<version>'`,NBSpecs 为首位 source 自动优先)
- 清理 /tmp 验证工程与 `/tmp/<name>-sync` 临时克隆(用户要求:处理完成即删);仅当用户要求保留克隆供后续发版时,迁到 `~/Desktop/Work/iOS-Pods/<Name>` 并告知位置
- 若消费方此前从公共源解析,提示切换命令:`pod update <Name>`;主工程版本钉死的(如 GuanceSDK),升级需改 Podfile 版本号,提示即可不要擅动

## 参考案例

- **NSAttributedStringBuilder13**(2026-10-14,版本 0.4.1):上游因公共仓重名带 13 后缀,保留原名只改 source;曾误改名发布为 NSAttributedStringBuilder,已从 NBSpecs 清理(`git rm -r` + 重发)。ios-app 15 处 import 按名依赖
- **GuanceSDK**(2026-10-15,版本 1.6.7):默认分支 develop 是 alpha,选稳定 tag 1.6.7 为 master 基线(领先上游 master),develop 原样推送;含 C++ 源码,纯 ObjC/Swift 接入方需 -lc++;无外部依赖全 subspec 自包含。私仓地址是 `iOS/datakit.git` 而 podspec 名是 GuanceSDK(上游仓库叫 datakit-ios),**仓库名与 pod 名可以不同,NBSpecs 按 podspec 名建目录**
- **GuanceSDK 1.6.8 更新**(2026-10-30,datakit 私仓):上游发 1.6.8(含 breaking:最低 iOS 15、新增 Swift 源码 FTRUMSwiftUI)。GitHub 直连超时,走 gh-proxy 镜像克隆;master 受保护禁 force push,改在旧 master 上 merge 上游 tag 1.6.8(零冲突,与上游 diff 仅 source 一行)后普通 push;develop 与上游一致零推送;publish 在 merge commit 0e113ded 建 tag 1.6.8;验证工程加空 Swift 文件解决 `__swift_FORCE_LOAD_$_swiftCompatibility56` 链接缺失。ios-app 主工程 platform 15.0 兼容,Podfile 钉死 1.6.7 未动
- **ZLPhotoBrowser**(2026-09-15):私仓已有独立历史,盘点发现 NBSpecs 已发布的 4.2.5.2 源码与 GitHub fix 分支一致,直接改引用,零迁移零发布
