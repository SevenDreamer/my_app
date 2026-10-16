# AI 界面模式蓝图（AI Elements · shadcn/ui）

> Phase4（AI/MCP 基础）的界面施工图。来源：https://ui.shadcn.com/docs/ai-elements
> 21 种 agentic 界面模式，均为组件组合（web 版是 copy 进项目，无包依赖）——
> 本文件记录**模式清单与架构思想**，Flutter 移植时对照官网逐个看结构。

## 架构核心（Trace 思想）

```
Chat（对话线程）
 └── Message Scroller（流式回复时保持滚动位置不跳底）
      └── Message（一轮：用户消息 + agent 回复及其动作）
           └── Trace（agent 每一步的统一形状，步骤包括：）
                ├── Reasoning   思考流
                ├── Tool        工具调用
                ├── Plan        计划与进度
                └── ……任何步骤都长同一个样子
```

**一条设计定律**：agent 在一轮里做的每一步（思考/调工具/跑测试）都建成
**Trace 上的同构步骤**——UI 只需要认识"步骤"一种形状，无需为每类步骤写一种渲染。

## 21 个模式清单

| 模式 | 作用（官网描述/概括） |
|---|---|
| Chat | 对话线程本体 |
| Message Scroller | 流式回复时保持滚动位置 |
| Message | 一轮对话（人的消息 + agent 的回复与动作） |
| Prompt Input | 带附件与发送按钮的输入框 |
| Reasoning | agent 的思考过程流式呈现 |
| Tool | 工具调用的展示 |
| Plan | agent 计划的步骤与完成进度 |
| Queue | agent 的待办清单：已做 / 未做 |
| Chain of Thought | 摘要，可展开为 agent 走过的步骤 |
| Trace | 所有步骤的统一容器形状（见上） |
| Confirmation | 工具执行**前**的批准/拒绝提示 |
| Context | 当前对话占用上下文窗口的比例 |
| Checkpoint | 会话中可回退的存档点 |
| File Tree | agent 改动过的文件，以目录树展示 |
| Inline Citation | 句内来源引用，悬停展开 |
| Sources | agent 用到的链接列表 |
| Stack Trace | 错误堆栈的结构化展示 |
| Subagent | 子 agent 的运行状态 |
| Suggestion | 建议项 |
| Task | 任务执行状态 |
| Terminal | 终端输出 |
| Test Results | 测试结果展示 |
| Model Selector | 双菜单：选模型 + 选思考强度 |

## 对 my_app 的三个直接落点

1. **Phase4 AI 区**：chat + prompt-input + trace 是骨架，先做这三个。
2. **设备互联调试页**：Trace/Terminal/Test Results 的样式直接复用
   （"被控端执行指令"就是一次 Tool 步骤）。
3. **小七 agent（个人项目）**：同一套模式可直接照抄设计。

## 移植注意

- web 版样式依附 Tailwind/React，Flutter 侧用 shadcn_ui 的
  Typography/Separator/Badge 重建层次，布局照抄、皮毛自换。
- 滚动保持（Message Scroller）Flutter 对应 ScrollController 的
  follow-to-bottom 策略，流式场景再实现。
