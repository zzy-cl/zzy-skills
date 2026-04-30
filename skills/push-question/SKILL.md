---
name: push-question
description: |
  将当前对话中的面试问答通过 API 推送到 ZZYAdmin 面试宝典系统保存。
  触发：用户说"推送这道题"、"保存到面试宝典"、"push question"、
  "保存问答"、"记录这个问题"、"这道题记下来"、"加入题库"、
  "存到面试题"、"归档这个问题"等。
metadata:
  openclaw:
    requires:
      bins:
        - curl
      config:
        - skills.entries.push-question.env.PUSH_QUESTION_URL
        - skills.entries.push-question.env.PUSH_QUESTION_API_KEY
---

# 推送到 ZZYAdmin 面试宝典

## API

```bash
curl -s -X POST "$PUSH_QUESTION_URL/question/push" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $PUSH_QUESTION_API_KEY" \
  -d '{
    "question": "<标题，30汉字以内>",
    "answer": "<Markdown 格式的回答>",
    "category": "<分类code>",
    "difficulty": "<easy|medium|hard>"
  }'
```

## 参数

- **question**（必填）：标题最多 30 个汉字（两个英文字符算一个汉字）。从对话中提炼核心问题，不要照搬用户原始长句。
- **answer**（可选）：Markdown 格式。提取最近一轮 Assistant 的完整回答。
- **category**（可选，默认 1）：

| code | 分类 | 典型内容 |
|------|------|----------|
| 1 | JavaScript | JS 语法、ES6+、异步 |
| 2 | TypeScript | 类型、泛型、装饰器 |
| 3 | Vue | Vue 2/3、Composition API |
| 4 | React | Hooks、状态管理、JSX |
| 5 | CSS & HTML | 布局、动画、响应式 |
| 6 | AI Agent | LLM、Prompt、RAG |
| 7 | Node.js | Express、NestJS、文件系统 |
| 8 | 工程化 | Webpack、Vite、CI/CD |
| 9 | 性能优化 | 首屏、渲染、缓存 |
| 10 | 网络 & 浏览器 | HTTP、跨域、存储 |
| 11 | 算法 | 数据结构、排序、DP |

- **difficulty**（可选，默认 medium）：easy（基础概念）、medium（多方案/原理）、hard（底层/综合）。

## 响应处理

- 成功 → 回复用户："已保存到面试宝典：[question 标题]"
- 失败（如标题超长、API Key 无效、网络错误）→ 向用户说明原因，不重试

## 环境变量

| 变量 | 说明 |
|------|------|
| `PUSH_QUESTION_URL` | 后端 API 地址，如 `http://localhost:3000` |
| `PUSH_QUESTION_API_KEY` | API Key，如 `sk-...` |

配置位置：`~/.openclaw/openclaw.json` 的 `skills.entries.push-question.env`
