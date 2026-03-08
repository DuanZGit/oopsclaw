<<<<<<< HEAD
# OppsClaw - OpenClaw 智能守护者

> 🤖 AI 驱动的 OpenClaw 故障自动修复与自主进化系统

[![GitHub](https://img.shields.io/badge/GitHub-OppsClaw-green)](https://github.com/DuanZGit/OppsClaw)
[![版本](https://img.shields.io/badge/版本-v1.0.0-blue)](https://github.com/DuanZGit/OppsClaw)
[![许可证](https://img.shields.io/badge/许可证-MIT-green)](LICENSE)

## 🌟 名字由来

**OppsClaw** = **Oops** + **OpenClaw** + **Ops**

- **Oops**: 当 OpenClaw 又双叒叕不小心把自己折腾坏的时候，OppsClaw 来救场！😄
- **Ops**: 谐音运维 (Operations)，寓意自动化运维守护者
- **Claw**: 继承 OpenClaw 的"蟹钳"精神，牢牢抓住所有故障！

> "Oops! OpenClaw 又坏了？" —— "别怕，我有 OppsClaw！"

## ✨ 特性

- **AI 故障修复** - LLM 自动诊断根因，执行修复命令
- **自主进化** - 评估修复效果，优化 Agent Prompt
- **知识积累** - 故障指纹库 + 历史经验，持续学习
- **OnFailure 触发** - systemd 故障自动触发修复
- **多渠道通知** - 飞书等实时告警
=======
# OpenClaw Guardian - 智能守护者系统

> OpenClaw/iFlow 的智能故障修复与自主进化系统

## 🌟 特性

- **自动修复**: Gateway 故障时自动诊断和修复
- **AI 驱动**: 使用 LLM 分析日志、推理根因、执行修复
- **知识积累**: 故障指纹库 + 历史经验，持续学习优化
- **自主进化**: 评估修复效果，自动优化 Agent Prompt
- **多渠道通知**: 支持飞书等渠道实时推送告警
>>>>>>> 1815a9334ba873e54be1535c8b1d8efff14b4a03

## 🏗️ 架构

```
<<<<<<< HEAD
┌─────────────────────────────────────────────────────────────┐
│                        故障检测层                            │
│              systemd OnFailure (Gateway 故障时触发)          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    守护者核心 (guardian-event.sh)            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   故障诊断   │→ │  根因分析   │→ │  自动修复   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      知识库系统                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ 故障指纹库   │  │  经验文档   │  │  评分数据   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  进化优化层 (guardian-evolve.sh)             │
│          评估修复效果 → 优化 Prompt → 自我进化              │
└─────────────────────────────────────────────────────────────┘
```

## 📦 一键安装

```bash
# 完整安装
bash -c "$(curl -fsSL https://raw.githubusercontent.com/DuanZGit/OppsClaw/main/install.sh)"
```

或手动安装：

```bash
# 1. 克隆项目
git clone https://github.com/DuanZGit/OppsClaw.git ~/.OppsClaw

# 2. 运行安装脚本
cd ~/.OppsClaw && bash install.sh
=======
┌─────────────────────────────────────────────────────────┐
│                    故障检测层                             │
│  systemd OnFailure / timer / cron                       │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│                守护者核心 (guardian-event.sh)             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  故障诊断   │→ │  根因分析   │→ │  自动修复   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│                  知识库系统                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ 故障指纹库  │  │  经验文档   │  │  评分数据   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│              进化优化层 (guardian-evolve.sh)             │
│  评估修复效果 → 优化 Prompt → 自我进化                  │
└─────────────────────────────────────────────────────────┘
```

## 📁 目录结构

```
guardian/
├── guardian-event.sh      # 事件驱动修复脚本 (核心)
├── guardian-evolve.sh     # 自主进化优化脚本
├── monitor.sh            # 定时监控脚本
├── ai-evolve.sh          # AI 进化脚本
├── knowledge/            # 知识库
│   ├── base/
│   │   ├── fingerprints.txt   # 故障指纹库
│   │   └── troubleshooting.md # 故障排查手册
│   └── learned/          # 历史经验文档
├── fixes/               # 修复方案库
├── evolutions/          # 进化版本
├── scores/              # 评分数据
├── logs/                # 运行日志
└── openclaw-gateway.service  # systemd 服务配置
>>>>>>> 1815a9334ba873e54be1535c8b1d8efff14b4a03
```

## 🚀 快速开始

### 前置要求

<<<<<<< HEAD
- [OpenClaw](https://github.com/openclaw) 已安装并运行
- [iFlow CLI](#iflow-安装) 已安装
- systemd 环境

### 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/DuanZGit/OppsClaw.git ~/.OppsClaw

# 2. 运行安装脚本
cd ~/.OppsClaw && bash install.sh
```

安装脚本会自动：
- ✅ 创建目录结构
- ✅ 复制脚本文件
- ✅ 配置 systemd 服务
- ✅ 启用 OnFailure 触发机制

### 手动运行

```bash
# 手动运行守护者
bash ~/.OppsClaw/guardian-event.sh

# 手动运行进化优化
bash ~/.OppsClaw/guardian-evolve.sh
```

## 🔧 iFlow 介绍与安装

### 什么是 iFlow?

iFlow (心流 CLI) 是一个 AI 辅助编程 CLI 工具，支持：
- 多 Agent 协作
- 代码编写、调试、修改
- 项目探索与理解
- Shell 命令执行
- Web 搜索与信息查询

### iFlow 安装

```bash
# 方法1: npm 全局安装
npm install -g @iflow/cli

# 方法2: pnpm 全局安装
pnpm add -g @iflow/cli

# 方法3: bun 全局安装
bun add -g @iflow/cli

# 验证安装
iflow --version
```

### iFlow 配置

首次运行会引导配置：

```bash
iflow
```

或手动配置 API Key：

```bash
# 编辑配置
nano ~/.iflow/settings.json
```

配置示例：

```json
{
  "apiKey": "your-api-key",
  "baseUrl": "https://apis.iflow.cn/v1",
  "modelName": "minimax-m2.5"
}
```

## 🤖 Agent Prompt

项目使用以下 Agent：

| Agent | 用途 |
|-------|------|
| `guardian` | 故障诊断、自动修复 |
| `guardian-evolve` | 评估优化、自主进化 |

详细 Prompt 位于 `~/.iflow/agents/`

## 📁 项目结构

```
OppsClaw/
├── install.sh              # 一键安装脚本
├── README.md              # 本文档
├── guardian-event.sh      # 故障修复核心脚本
├── guardian-evolve.sh     # 进化优化脚本
├── ai-evolve.sh           # AI 进化脚本
├── knowledge/             # 知识库
│   ├── base/             # 故障指纹库
│   └── learned/          # 历史经验
├── openclaw-gateway.service   # systemd 服务
└── iflow-guardian-event.service  # 故障修复服务
```

## 📊 核心功能

### 故障检测层 (OnFailure)

- **触发条件**: Gateway 服务失败时自动触发
- **配置方式**: systemd OnFailure 指令
- **无需轮询**: 事件驱动，资源占用低

### 守护者核心

- **事件驱动修复**: OnFailure 故障时自动触发
- **AI 诊断**: 分析日志，推理根因
- **自动修复**: 执行 CLI 命令修复
- **知识更新**: 记录故障模式到知识库

### 进化优化

- **效果评估**: 评分修复成功率和效率
- **Prompt 优化**: 自动改进 Agent
- **知识改进**: 优化知识库结构

## 🔍 查看日志

```bash
# 守护者日志
=======
- OpenClaw 已安装并配置
- iFlow CLI 已安装
- systemd 环境

### 安装

```bash
# 1. 复制服务配置
cp guardian/openclaw-gateway.service ~/.config/systemd/user/
cp guardian/guardian-monitor.service ~/.config/systemd/user/
cp guardian/guardian-monitor.timer ~/.config/systemd/user/

# 2. 重新加载 systemd
systemctl --user daemon-reload

# 3. 启用定时任务
systemctl --user enable --now guardian-monitor.timer

# 4. 启用故障触发 (可选)
systemctl --user enable --now openclaw-gateway.service
```

### 配置

```bash
# 设置飞书通知用户 ID (可选)
echo "ou_xxxxx" > ~/.iflow/guardian/feishu_user_id.txt
```

## 🔧 使用

### 手动运行守护者

```bash
# 事件驱动模式 (Gateway 故障时自动触发)
bash ~/.iflow/guardian/guardian-event.sh

# 定时监控模式
bash ~/.iflow/guardian/monitor.sh

# 进化优化 (评估并优化 Agent)
bash ~/.iflow/guardian/guardian-evolve.sh
```

### 查看日志

```bash
# 守护者事件日志
>>>>>>> 1815a9334ba873e54be1535c8b1d8efff14b4a03
tail -f ~/.iflow/guardian/logs/guardian-event.log

# 修复历史
cat ~/.iflow/guardian/logs/repair_history.log
<<<<<<< HEAD

# 状态记录
cat ~/.iflow/monitor/knowledge/lessons_*.md
```

## ⚠️ 故障排查

### 守护者未触发

```bash
# 检查 systemd 服务状态
systemctl --user status openclaw-gateway.service

# 检查 OnFailure 配置
cat ~/.config/systemd/user/openclaw-gateway.service
```

### iFlow 调用失败

```bash
# 检查 iFlow 是否安装
iflow --version

# 测试 iFlow
iflow -p "你好"
```

## 📝 制作人

- **第一人**: [DuanZ](https://github.com/DuanZGit) - 主要开发与维护
- **第二人**: [iFlow](https://github.com/iflow-ai) - AI 能力支持
=======
```

## 🤖 Agent Prompt

守护者使用专门的 Agent Prompt 进行故障分析：

- **guardian.md**: 故障诊断与修复专家
- **guardian-evolve.md**: 进化优化评估专家

详见 `~/.iflow/agents/guardian.md`

## 📊 评分体系

| 维度 | 权重 | 说明 |
|------|------|------|
| 修复结果 | 40% | 成功=1.0, 失败=0 |
| 修复时间 | 20% | <60s=1.0, >300s=0.2 |
| 问题类型 | 20% | 新问题=1.0, 常见=0.5 |
| 知识库利用 | 20% | 使用=1.0, 未用=0.3 |

## 🔄 进化流程

1. **检测**: 定时/事件触发故障检测
2. **修复**: guardian-agent 执行修复
3. **评估**: 记录修复结果和时间
4. **进化**: guardian-evolve-agent 评估并优化
5. **学习**: 更新知识库和 Prompt
>>>>>>> 1815a9334ba873e54be1535c8b1d8efff14b4a03

## 📝 许可证

MIT License

<<<<<<< HEAD
## 🔗 相关链接

- [OpenClaw 官网](https://openclaw.ai)
- [iFlow 官网](https://iflow.cn)
- [项目地址](https://github.com/DuanZGit/OppsClaw)
=======
## 👤 作者

OpenClaw/iFlow Community
>>>>>>> 1815a9334ba873e54be1535c8b1d8efff14b4a03
