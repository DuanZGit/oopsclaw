# iFlow Oopsclaw 飞书通知配置

## 启用飞书通知

1. 创建飞书机器人 (自定义机器人)
2. 获取 Webhook URL
3. 保存到文件:

```bash
echo "https://open.feishu.cn/open-apis/bot/v2/hook/xxx" > ~/.oopsclaw/feishu_webhook.txt
```

## 通知类型

- OpenClaw 异常时自动通知
- 自动修复成功通知
- 需要人工介入时通知
