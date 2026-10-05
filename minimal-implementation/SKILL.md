---
name: minimal-implementation
description: Use when implementing a feature, adding an API or compatibility layer, writing parsers, or finishing newly written code—before calling the work done.
---

# Minimal implementation

写功能只覆盖**当前真实合同**。跑通之后删掉没用上的分支、包装和 API。各项目都遵守。

## Do

- 按调用方实际传入的数据形态实现，不要预留「以后可能还有」的类型。
- 已有通道能完成读写，就不要再加一层服务 / 协议 / Unified API。
- 兼容只处理**线上已经存在**的旧 key / 旧格式；命中后再回写新格式即可。
- 同一件事只留一条解析或写入路径。
- 写完对照合同自查：每一段新代码都能指到一个当前需求。指不到就删。

## Don't

- 为假想输入加 `if`（多种 JSON 形态、逗号分隔、空协议、空注册）。
- 调用链已经在目标线程，再包一层 `async` / 队列。
- 把内部 key 拼装做成对外 API。
- 用「完善一点更稳」留下死代码。稳来自合同对齐，不是来自分支数量。
