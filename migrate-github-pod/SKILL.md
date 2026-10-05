---
name: migrate-github-pod
description: 把 Podfile 中依赖的 GitHub 仓库(含公司 fork)迁移/平移到九号私有 GitLab(git.ninebot.com)并按 tag 正规发布。当用户要求"把某个 GitHub pod 改为私有仓库"、"XX 库私有化"、"平移 XX 到 git.ninebot.com"、"发布到 NBSpecs/ninebot-cli"时使用。涵盖现状盘点、代码平移、podspec source 修改、打 tag、ninebot-cli repo publish、Podfile 改为版本号引用。
---

# GitHub Pod 依赖私有化迁移

## 基础设施

- 私有 GitLab:`git.ninebot.com`,iOS 组仓库地址 `git@git.ninebot.com:iOS/<Name>.git`
- 私有 specs 仓库:NBSpecs,本地缓存 `~/.cocoapods/repos/NBSpecs/<Name>/<version>/`
- 发布工具:`ninebot-cli repo publish <Name>.podspec`(支持 `--dry-run`,只复制 podspec 到 NBSpecs 并推送)
- 用户的私有仓库本地克隆惯例放在 `/Users/ninebot/Desktop/Work/iOS-Pods/<Name>`(已存在则直接用它操作,不要另建克隆)

## 环境限制(权限沙箱)

- 禁止写项目目录以外的路径(/tmp 的 Edit/Write/cp/mv/rm 均被拦):临时克隆放项目目录下隐藏目录,用完删除
- git 命令拆成单条执行,`&&` 链式易被拦
- 含中文的 `git commit -m` 易被拦:先用 Write 写消息文件,再 `git commit -F <file>`

## 工作流程

### 1. 定位依赖与现状盘点(先查再动,避免重复劳动)

1. 从 Podfile 找到目标 pod 的引用形式(`:git` URL、`:branch`、`:commit`、`:tag`)
2. `git ls-remote git@git.ninebot.com:iOS/<Name>.git` — 私有仓库是否存在、已有分支/tag
3. `ls ~/.cocoapods/repos/NBSpecs/<Name>/` — 哪些版本已发布、spec 的 s.source 指向
4. **私有仓库可能已有同名库但历史独立**(网页上传/二进制化重做,与 GitHub 无共同提交):先 fetch 对比,严禁 mirror 全量覆盖已有 main

### 2. 判断是否真的需要平移代码(关键捷径)

对比"要迁移的代码"与私有仓库已有 tag:

```
git diff --stat <已有tag> <GitHub分支>        # 整体差异
git diff <GitHub分支> <已有tag> -- Sources/   # 源码目录逐一确认
```

- 只关注源码目录(Sources/、Classes/ 等)与 podspec;忽略 .DS_Store、.github、.travis.yml 等元文件
- **若已有 tag 源码一致 → 代码早已发布过,直接跳到第 4 步引用该版本,不打新 tag 不重复发布**
- 不一致才继续第 3 步

### 3. 代码平移与发布

1. 克隆 GitHub 仓库,推送所需分支:`git push private origin/<branch>:refs/heads/<branch>`
2. 在该分支上把 podspec 的 `s.source` 改为 `git@git.ninebot.com:iOS/<Name>.git`,提交推送
3. 升 podspec 版本号(沿用仓库已有版本规律,如 4.2.5.x 递增;必须大于 NBSpecs 已发布版本),提交
4. 打同名 tag 并推送(podspec 的 source 用 `:tag => s.version`,tag 必须真实存在,否则该版本无法安装)
5. `ninebot-cli repo publish --dry-run <Name>.podspec` 预览无误后正式执行

### 4. 更新 Podfile

- 目标写法:`pod '<Name>', '<version>'`,经 NBSpecs 正常解析(与其他三方库一致)
- **避免** `:git => ... :branch => ... :commit => ...` 锁死写法(用户明确不喜欢)
- 若其他模块 podspec 里有 `s.dependency '<Name>'`(无版本约束),Podfile 的显式版本号会统一锁定解析结果,无需改动那些 podspec

### 5. 验证与汇报

- `pod install` 验证解析(大工程耗时长,可留给用户执行)
- 汇报:私有仓库分支/tag 状态、NBSpecs 发布状态、Podfile 最终引用方式
- 清理临时克隆;提醒用户可删除不再需要的迁移分支

## 参考案例

ZLPhotoBrowser(2026-09-15):Podfile 原引用 fork `ninebot-9/ZLPhotoBrowser` 的 fix 分支 + commit。盘点发现私有仓库已有独立 main(二进制化 4.7.3)且 NBSpecs 已发布 4.2.5.1/4.2.5.2;将 fix 分支推送到私有仓库后 diff 发现 tag 4.2.5.2 的 Sources 与 fix 分支字节级一致(iOS18 修复早已包含),最终直接 `pod 'ZLPhotoBrowser', '4.2.5.2'`,未打新 tag、未重新发布。
