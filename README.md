# OopsClaw - OpenClaw 智能守护者

> OpenClaw/iFlow 的自动故障修复与自主进化系统

## 🌟 特性

- **自动修复**: Gateway 故障时自动诊断和修复
- **AI 驱动**: 使用 LLM 分析日志、推理根因、执行修复
- **知识积累**: 故障指纹库 + 历史经验，持续学习优化
- **自主进化**: 评估修复效果，自动优化 Agent Prompt
- **多渠道通知**: 飞书实时推送告警

## 🏗️ 架构

```
┌─────────────────────────────────────────────────────────┐
│                    故障检测层                             │
│              systemd OnFailure (Gateway 故障时触发)       │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│                守护者核心 (oopsclaw-event.sh)            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │  故障诊断   │→ │  根因分析   │→ │  自动修复   │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│                  知识库系统                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ 故障指纹库  │  │  经验文档   │  │  评分数据   │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│              进化优化层 (oopsclaw-evolve.sh)            │
│  评估修复效果 → 优化 Prompt → 自我进化                 │
└─────────────────────────────────────────────────────────┘
```

## 📁 目录结构

```
.oopsclaw/
├── oopsclaw-event.sh      # 事件驱动修复脚本 (核心)
├── oopsclaw-evolve.sh    # 自主进化优化脚本
├── monitor.sh            # 定时监控脚本
├── ai-evolve.sh          # AI 进化脚本
├── install.sh            # 一键安装脚本
├── openclaw-gateway.service  # Gateway 服务配置
├── oopsclaw-event.service    # 故障修复服务
├── oopsclaw-monitor.service # 定时监控服务
├── oopsclaw-monitor.timer    # 定时器
└── knowledge/             # 知识库
    ├── base/
    │   ├── fingerprints.txt   # 故障指纹库
    │   └── troubleshooting.md # 故障排查手册
    └── learned/          # 历史经验文档
```

## 🚀 快速开始

### 前置要求

- OpenClaw 已安装并配置
- iFlow CLI 已安装
- systemd 环境

### 安装

```bash
# 一键安装
bash ~/.oopsclaw/install.sh
```

或手动安装：

```bash
# 1. 复制服务配置
cp openclaw-gateway.service ~/.config/systemd/user/
cp oopsclaw-event.service ~/.config/systemd/user/
cp oopsclaw-monitor.service ~/.config/systemd/user/
cp oopsclaw-monitor.timer ~/.config/systemd/user/

# 2. 重新加载 systemd
systemctl --user daemon-reload

# 3. 启用服务
systemctl --user enable --now openclaw-gateway.service
systemctl --user enable --now oopsclaw-monitor.timer
```

### 手动运行

```bash
# 事件驱动模式 (Gateway 故障时自动触发)
bash ~/.oopsclaw/oopsclaw-event.sh

# 定时监控模式
bash ~/.oopsclaw/monitor.sh

# 进化优化 (评估并优化 Agent)
bash ~/.oopsclaw/oopsclaw-evolve.sh
```

### 查看日志

```bash
# 守护者事件日志
journalctl --user -u oopsclaw-event.service -f

# 或查看脚本内日志
tail -f ~/.oopsclaw/logs/oopsclaw-event.log
```

## 🤖 Agent Prompt

守护者使用专门的 Agent Prompt 进行故障分析：

- **oopsclaw**: 故障诊断与修复专家
- **oopsclaw-evolve**: 进化优化评估专家

详见 `~/.iflow/agents/oopsclaw.md`

## 📊 评分体系

| 维度 | 权重 | 说明 |
|------|------|------|
| 修复结果 | 40% | 成功=1.0, 失败=0 |
| 修复时间 | 20% | <60s=1.0, >300s=0.2 |
| 问题类型 | 20% | 新问题=1.0, 常见=0.5 |
| 知识库利用 | 20% | 使用=1.0, 未用=0.3 |

## 🔄 进化流程

1. **检测**: systemd OnFailure 触发故障检测
2. **修复**: iFlow oopsclaw-agent 执行修复
3. **评估**: 记录修复结果和时间
4. **进化**: oopsclaw-evolve-agent 评估并优化
5. **学习**: 更新知识库和 Prompt

## 📝 许可证

MIT License

## 👤 作者

DuanZ & iFlow Community