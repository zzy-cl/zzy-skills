# zzy-skills

个人 Agent Skills 集合，适用于 Claude Code 和 openClaw。

## Skills 列表

| Skill | 说明 | 依赖 |
|-------|------|------|
| [searxng-search](skills/searxng-search/) | 通过自部署 SearXNG 元搜索引擎联网搜索，支持百度、Bing、360 搜索、Bilibili 等引擎 | SearXNG 实例 |
| [cloudreve](skills/cloudreve/) | 管理自部署 Cloudreve v4 云存储：上传、下载、列表、删除文件，查看存储容量 | Cloudreve v4 实例 |
| [push-question](skills/push-question/) | 将对话中的面试问答推送到 ZZYAdmin 面试宝典系统保存 | ZZYAdmin 后端 API |
| [tech-doc](skills/tech-doc/) | 技术文档 / 技术方案 / 技术教程写作规范：体裁选择、事实核对到源码、目录设计、专业语域与发文前自检 | bash、git（符号巡检脚本） |

## 安装

将 skill 目录复制到你的 Agent Skills 路径下，或通过 Git 引用本仓库。

### Claude Code

将 skill 目录放置于项目 `.claude/skills/` 下，或在 `settings.json` 中配置。

### openClaw

在 `openclaw.json` 中配置 `skills.entries`，参考各 skill 目录下的 `SKILL.md` 了解具体环境变量。

## 目录结构

```
zzy-skills/
├── package.json
├── README.md
└── skills/
    ├── searxng-search/    # 联网搜索
    │   ├── SKILL.md
    │   ├── scripts/
    │   └── references/
    ├── cloudreve/         # 云存储管理
    │   ├── SKILL.md
    │   ├── scripts/
    │   └── references/
    ├── push-question/     # 面试题推送
    │   └── SKILL.md
    └── tech-doc/          # 技术文档写作规范
        ├── SKILL.md
        ├── references/
        └── scripts/
```

## License

各 skill 独立许可，详见各目录下的 LICENSE 文件。
