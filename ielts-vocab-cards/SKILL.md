---
name: ielts-vocab-cards
description: 把雅思阅读里标注为「模糊/不会」的生词转成 Anki 可导入的词卡（音标、词性、英文释义、中文、例句）。当用户发来生词表、要做雅思词卡或要导入 Anki 时使用。
allowed-tools: Bash(python3 *), Bash(git *), Read, Write
argument-hint: "[词表文件路径] [可选：输出文件 .tsv/.csv]"

---

# 雅思生词 Anki 词卡

脚本仓库（私有）：https://github.com/DargonLee/ielts-tools —— 脚本 `ielts_cards.py`，仅依赖 Python 3 标准库。

## 何时使用

- 用户从 IELTS Academic Reading 样题挖出生词，按「会 / 模糊 / 不会」标注后，想做成 Anki 卡片。
- 用户说“做词卡”“导入 Anki”“把这些生词整理一下”。

## 执行流程

1. **准备脚本**
   - 若本地没有 `ielts-tools`，执行 `git clone https://github.com/DargonLee/ielts-tools.git`（私有仓库，需已登录 GitHub）。
2. **准备词表**
   - 每行 `词,标注[,中文释义]`；分隔符可用英文逗号、中文逗号或 Tab。
   - 标注为 `会`/`known` 的词会被过滤；`模糊`/`不会`/缺省会保留。
   - 用户直接在对话里给词时，先写成临时文件再调用脚本。
3. **生成词卡**
   - `python3 ielts-tools/ielts_cards.py <词表> -o cards.tsv`
   - 无网络时加 `--offline`；联网失败或查不到的词会保留空字段并在结尾列出。
4. **后置确认**
   - 报告卡片数、查询失败的词，提醒用户可在第三列补中文释义后重跑。
   - 导入：Anki → 文件 → 导入，前两列映射为 正面/背面（文件头已声明分隔符、HTML 和标签列）。

## 使用示例

* `/ielts-vocab-cards words.csv` —— 生成 `ielts_cards.tsv`
* `/ielts-vocab-cards words.txt cards.csv` —— 输出 CSV
