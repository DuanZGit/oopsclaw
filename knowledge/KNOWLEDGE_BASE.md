# OpenClaw 运维知识库

> 本文档由自动监控系统持续更新，用于记录 OpenClaw 运行过程中的错误分析和解决方案。

## 📋 目录

- [错误分类索引](#错误分类索引)
- [解决方案库](#解决方案库)
- [配置最佳实践](#配置最佳实践)

---

## 错误分类索引

### 按严重程度

| 严重程度 | 描述 | 典型错误 |
|----------|------|----------|
| 🔴 Critical | 服务不可用 | Gateway 启动失败、端口冲突 |
| 🟡 Warning | 功能受损 | 插件加载失败、部分功能异常 |
| 🟢 Info | 正常日志 | 健康检查、常规操作 |

### 按错误类型

- **启动类**: `Cannot find module`, `spawn EINVAL`, 端口占用
- **网络类**: `ECONNREFUSED`, API 超时, DNS 解析失败
- **认证类**: `401 Unauthorized`, Token 过期, API Key 无效
- **插件类**: 依赖缺失, 版本不兼容
- **消息类**: Message ordering conflict, 发送失败

---

## 解决方案库

### 1. Gateway 启动失败

**症状**: 端口 18789 被占用 或 服务无法启动

**解决方案**:
```bash
# 检查端口占用
lsof -i :18789

# 杀死旧进程
pkill -f openclaw

# 重启服务
openclaw start
```

### 2. 插件安装失败

**症状**: `Cannot find module 'xxx'`

**解决方案**:
```bash
# 手动安装依赖
cd ~/.npm-global/lib/node_modules/openclaw
npm install <缺失的模块>
```

### 3. Message ordering conflict

**症状**: 飞书消息发送失败 "Message ordering conflict"

**原因**: 某些模型不支持 "developer" 角色

**解决方案**:
在模型配置中添加:
```json
{
  "id": "moonshotai/kimi-k2.5",
  "compat": {
    "supportsDeveloperRole": false
  }
}
```

### 4. 认证失败

**症状**: API 返回 401 Unauthorized

**检查步骤**:
1. 确认 API Key 正确
2. 检查环境变量 `OPENCLAW_*_API_KEY`
3. 验证 API Key 是否过期

---

## 配置最佳实践

### 模型配置

```json
{
  "id": "anthropic/claude-sonnet-4-20250514",
  "name": "Claude Sonnet 4.6",
  "contextWindow": 200000,
  "maxTokens": 8192,
  "thinking": {
    "enabled": true,
    "budget": 16000
  }
}
```

### 飞书配置

```json
{
  "channels": {
    "feishu": {
      "enabled": true,
      "dmPolicy": "allowlist",
      "allowFrom": ["ou_xxx"]
    }
  }
}
```

---

## 自动监控

本知识库由 `check-openclaw.sh` 脚本自动更新。

- **检查频率**: 每小时
- **分析方式**: AI 错误分析
- **存储位置**: `~/.oopsclaw/knowledge/`

---

*最后更新: $(date '+%Y-%m-%d %H:%M:%S')*
