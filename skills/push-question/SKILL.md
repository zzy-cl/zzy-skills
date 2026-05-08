---
name: push-question
description: |
  将当前对话中的面试问答通过 API 推送到 ZZYAdmin 面试宝典系统保存。
  触发：用户说"推送这道题"、"保存到面试宝典"、"push question"、
  "保存问答"、"记录这个问题"、"这道题记下来"、"加入题库"、
  "存到面试题"、"归档这个问题"等。
  
  【智能查重机制】推送前会自动查重：
  1. 先用列表接口搜索相似题目
  2. 如果无相似题 → 直接创建新题
  3. 如果有相似题 → 获取详情对比，智能决策：
     - 当前答案更全面 → 更新原题
     - 当前答案有补充 → 合并补充后更新
     - 原题已很好 → 跳过，告知用户已有优质答案
metadata: { "openclaw": { "requires": { "bins": ["curl"], "config": ["skills.entries.push-question.env.PUSH_QUESTION_URL", "skills.entries.push-question.env.PUSH_QUESTION_API_KEY"] } } }
---

# 推送到 ZZYAdmin 面试宝典

## 智能推送流程

```
1. 提取当前问题核心关键词（技术名词）
2. 调用列表接口搜索相似题目（keyword + category 过滤）
3. 分析返回结果：
   ├── 无结果 → 创建新题 ✅
   └── 有结果 → 多维度相似度分析
        ├── 标题完全相同 → 直接获取详情对比
        ├── 技术关键词高度重叠 → 获取详情对比
        └── 弱相关 → 视为无相似题，创建新题
4. 获取详情后智能决策：
   ├── 当前答案更优 → 更新原题 📝
   ├── 可互补合并 → 合并后更新 🔄
   └── 原题已很好 → 跳过，提示用户 ⏭️
```

## API

### 1. 列表查询（查重用）

```bash
curl -s -X POST "$PUSH_QUESTION_URL/question/open/list" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $PUSH_QUESTION_API_KEY" \
  -d '{
    "keyword": "<提取的核心关键词，如 GIT、Vue、闭包等>",
    "category": "<分类code，可选>",
    "onlyFavorites": false,
    "page": 1,
    "size": 20
  }'
```

**关键词提取规则：**
- 提取问题中的技术名词（如 Git、Vue、闭包、Promise、Webpack 等）
- 去除通用词（如 "怎么"、"什么"、"如何"、"区别"等）
- 英文关键词转大写（如 git → GIT，vue → VUE）
- 多关键词时取最核心的 1-2 个

**示例：**
| 问题 | 提取关键词 |
|------|-----------|
| Git 怎么切换分支 | `GIT` |
| v-if 和 v-show 有什么区别 | `VUE` |
| JavaScript 闭包是什么 | `闭包` |
| Webpack 怎么配置多入口 | `WEBPACK` |
| TypeScript 泛型怎么用 | `TYPESCRIPT` 或 `泛型` |

**响应示例：**
```json
{
  "data": {
    "list": [
      {
        "id": "uuid",
        "question": "Vue.js中v-if和v-show的区别",
        "answer": "...",
        "category": "3",
        "difficulty": "easy"
      }
    ],
    "total": 100
  },
  "statusCode": 200
}
```

### 2. 详情查询

```bash
curl -s -X GET "$PUSH_QUESTION_URL/question/open/detail/<id>" \
  -H "X-API-Key: $PUSH_QUESTION_API_KEY"
```

### 3. 创建题目（无重复时）

```bash
curl -s -X POST "$PUSH_QUESTION_URL/question/open/create" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $PUSH_QUESTION_API_KEY" \
  -d '{
    "question": "<标题，30汉字以内>",
    "answer": "<Markdown 格式的回答>",
    "category": "<分类code>",
    "difficulty": "<easy|medium|hard>"
  }'
```

### 4. 修改题目（有重复且需要更新时）

```bash
curl -s -X PATCH "$PUSH_QUESTION_URL/question/open/update/<id>" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $PUSH_QUESTION_API_KEY" \
  -d '{
    "question": "<优化后的标题>",
    "answer": "<合并/优化后的答案>",
    "category": "<分类code>",
    "difficulty": "<easy|medium|hard>"
  }'
```

### 5. 删除题目

```bash
curl -s -X DELETE "$PUSH_QUESTION_URL/question/open/remove/<id>" \
  -H "X-API-Key: $PUSH_QUESTION_API_KEY"
```

## 查重判断逻辑

### 相似度判定（多维度）

1. **关键词搜索匹配**（优先）：
   - 列表接口用关键词搜索，只返回相关题目
   - 同分类下匹配度更高

2. **标题匹配**：
   - 完全相同 → 高度相似（直接判定重复）
   - 包含相同核心技术词 → 可能相似
   - 编辑距离 < 3 → 相似

3. **语义匹配**（辅助判断）：
   - 问题本质相同（都是问区别/用法/原理/概念）→ 相似
   - 技术栈相同但问法不同（如 "Git切换分支" vs "怎么换Git分支"）→ 相似
   - 同一技术点的不同方面（如 "Git切换分支" vs "Git合并分支"）→ 不相似

4. **分类过滤**：
   - 同分类题目优先对比
   - 跨分类题目降低相似度权重

### 决策规则

| 情况 | 操作 | 回复用户 |
|------|------|----------|
| 无相似题 | 创建新题 | "已保存到面试宝典：[标题]" |
| 有相似题，当前更优 | 更新原题 | "已优化更新面试宝典中的：[标题]" |
| 有相似题，可互补 | 合并更新 | "已补充更新面试宝典中的：[标题]" |
| 有相似题，原题更好 | 跳过 | "面试宝典中已有优质答案：[标题]，无需重复添加" |

## 答案合并策略

当需要合并两个答案时：

1. **结构对比**：保留更清晰的结构
2. **内容对比**：
   - 当前答案有独特内容 → 补充到原题
   - 原题有独特内容 → 保留
   - 重复内容 → 去重保留更优表达
3. **格式统一**：保持 Markdown 格式一致

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
| 8 | 工程化 | Webpack、Vite、CI/CD、Git |
| 9 | 性能优化 | 首屏、渲染、缓存 |
| 10 | 网络 & 浏览器 | HTTP、跨域、存储 |
| 11 | 算法 | 数据结构、排序、DP |

- **difficulty**（可选，默认 medium）：easy（基础概念）、medium（多方案/原理）、hard（底层/综合）。

## 响应处理

- 创建成功 → "已保存到面试宝典：[question 标题]"
- 更新成功 → "已优化更新面试宝典中的：[question 标题]"
- 补充成功 → "已补充更新面试宝典中的：[question 标题]"
- 跳过（已有优质答案）→ "面试宝典中已有优质答案：[question 标题]，当前答案未添加"
- 失败（如标题超长、API Key 无效、网络错误）→ 向用户说明原因，不重试

## 环境变量

| 变量 | 说明 |
|------|------|
| `PUSH_QUESTION_URL` | 后端 API 地址，如 `http://localhost:3000` |
| `PUSH_QUESTION_API_KEY` | API Key，如 `sk-...` |

配置位置：`~/.openclaw/openclaw.json` 的 `skills.entries.push-question.env`

## 示例场景

### 场景 1：无重复题
```
用户：v-if 和 v-show 有什么区别？
AI 回答后，用户：保存到面试宝典
→ 提取关键词：VUE
→ 查重：调用 /question/findAll {"keyword":"VUE","category":"3"}
→ 结果：无高度相似题（可能返回其他Vue题，但标题不匹配）
→ 操作：创建新题
→ 回复：已保存到面试宝典：Vue.js中v-if和v-show的区别
```

### 场景 2：有重复题，当前更优
```
用户：Git 怎么切换分支？
AI 回答后，用户：保存到面试宝典
→ 提取关键词：GIT
→ 查重：调用 /question/findAll {"keyword":"GIT","category":"8"}
→ 结果：发现 "Git分支切换方法"
→ 获取详情对比：当前答案包含 git switch 新命令，原题只有 git checkout
→ 操作：更新原题，补充 git switch 内容
→ 回复：已优化更新面试宝典中的：Git分支切换方法
```

### 场景 3：有重复题，原题更好
```
用户：什么是闭包？
AI 回答后，用户：保存到面试宝典
→ 提取关键词：闭包
→ 查重：调用 /question/findAll {"keyword":"闭包","category":"1"}
→ 结果：发现 "JavaScript闭包详解"
→ 获取详情对比：原题答案更全面，包含原理、应用、内存泄漏等
→ 操作：跳过
→ 回复：面试宝典中已有优质答案：JavaScript闭包详解，无需重复添加
```

### 场景 4：弱相关题目不误判
```
用户：Webpack 怎么配置多入口？
AI 回答后，用户：保存到面试宝典
→ 提取关键词：WEBPACK
→ 查重：调用 /question/findAll {"keyword":"WEBPACK","category":"8"}
→ 结果：返回 "Webpack热更新原理"、"Webpack代码分割"
→ 相似度分析：都是 Webpack 但问题本质不同（配置多入口 vs 热更新/代码分割）
→ 判定：不相似
→ 操作：创建新题
→ 回复：已保存到面试宝典：Webpack多入口配置方法
```