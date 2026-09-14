# tech-doc

An [Agent Skills](https://agentskills.io)-compatible skill for writing technical documentation — 技术文档 / 技术方案 / 技术教程写作规范。

## Features

- **体裁契约**：札记 / 方案 / 教程三种体裁各有骨架、判生死标准与常见死法，一份文档只服务一个阅读时刻；体裁骨架是查漏清单，不是排版模板
- **容器优先**：读者是扫读的——分条 / 表格 / 代码 / 图按信息形状装容器，段落 ≤ 3 行，散文只负责粘合；裁剪按动作判据，压缩按容器选择
- **事实核对**：动笔前逐条对到源码（高危句 = 数字 + 全称量词），三态标注（事实 / 推断 / 示意）；核对留痕进 commit message / PR 描述，正文零元信息
- **目录设计**：目录是主线的投影，两级封顶、7±2 节、标题即检索词，标题通读即故事
- **演优于讲**：机制用流程块 / 时序 / 决策表承载，代码片段即证词且自解释（行内解释注释）
- **专业语域**：名词短语标题、禁疑问反问句、禁口语比喻
- **符号巡检**：`scripts/check_symbols.sh` 自动核对文档中 `引用` 在目标仓库是否存在

## 工作流

入口分四类：新写（完整六步）；重写 / 评审 / 压缩先读 `references/antipatterns.md` 后走对应分支。详见 `SKILL.md` 的「入口判断」与六步工作流。

## 安装

将 `tech-doc/` 目录复制到各 Agent 的技能发现路径（目录名必须与 frontmatter 的 `name` 一致）：

- Claude Code：`~/.claude/skills/tech-doc/`
- ZCode：`~/.zcode/skills/tech-doc/`（ZCode 专属全局）；`~/.agents/skills/` 为跨工具共享路径、其他 Agent 也会读取——需限定仅 ZCode 可用时安装到前者
- openClaw：在 `openclaw.json` 的 `skills.entries` 中配置
- 不支持技能发现的 Agent（Codex 等）：在其指令文件（AGENTS.md 等）中加一行——「撰写 / 重写 / 梳理 / 压缩 / 评审技术文档前，先完整阅读 `<技能目录>/SKILL.md` 并遵循其工作流；按需读取同目录 `references/`」。

## 运行环境

- `scripts/check_symbols.sh` 依赖 bash、git、grep、sed、find；Windows 下用 Git Bash 运行。
- 目录内 `.gitattributes` 强制 `*.sh` 以 LF 落盘，避免 Windows git 检出后 CRLF 导致脚本报错；zip / U 盘拷贝不受影响。

## 目录结构

```
tech-doc/
├── SKILL.md                 # 主工作流（六步 + 发文前自检）
├── references/
│   ├── genre-zhaji.md       # 札记深度指南
│   ├── genre-fangan.md      # 方案深度指南
│   ├── genre-jiaocheng.md   # 教程深度指南
│   ├── antipatterns.md      # 反模式清单与好坏对照
│   ├── doc-governance.md    # 文档经营：权威序 / 所有权 / ROI
│   └── naming.md            # 文件命名：检索键公式 / 验收测试 / 禁止项
└── scripts/
    └── check_symbols.sh     # 符号巡检（advisory）
```

## 维护

- 规则中的数字（如代码行数上限）在 SKILL.md 与 references/ 中各出现多处，修改时全局搜索保持一致。
- SKILL.md 不含具体项目事实（示例均为写法示范），无需随业务代码更新。
