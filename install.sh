#!/bin/bash
#==============================================
# oopsclaw 一键安装脚本
#==============================================

set -e

echo "🤖 oopsclaw 安装向导"
echo "===================="

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查前置条件
check_dependencies() {
    echo -e "\n${YELLOW}[1/4] 检查前置条件...${NC}"
    
    # 检查 OpenClaw
    if command -v openclaw &> /dev/null; then
        echo -e "${GREEN}✓${NC} OpenClaw 已安装"
    else
        echo -e "${RED}✗${NC} OpenClaw 未安装"
        echo "  请先安装 OpenClaw: https://openclaw.ai"
        exit 1
    fi
    
    # 检查 iFlow
    if command -v iflow &> /dev/null; then
        echo -e "${GREEN}✓${NC} iFlow CLI 已安装"
    else
        echo -e "${YELLOW}!${NC} iFlow 未安装，正在安装..."
        install_iflow
    fi
    
    # 检查 git
    if command -v git &> /dev/null; then
        echo -e "${GREEN}✓${NC} Git 已安装"
    else
        echo -e "${RED}✗${NC} Git 未安装"
        exit 1
    fi
}

# 安装 iFlow
install_iflow() {
    if command -v npm &> /dev/null; then
        npm install -g @iflow/cli
    elif command -v pnpm &> /dev/null; then
        pnpm add -g @iflow/cli
    elif command -v bun &> /dev/null; then
        bun add -g @iflow/cli
    else
        echo -e "${RED}请先安装 npm/pnpm/bun 其中之一${NC}"
        exit 1
    fi
}

# 创建目录结构
setup_directories() {
    echo -e "\n${YELLOW}[2/4] 创建目录结构...${NC}"
    
    mkdir -p ~/.oopsclaw/{knowledge/base,logs,fixes,evolutions,scores}
    
    echo -e "${GREEN}✓${NC} 目录已创建"
}

# 复制文件
copy_files() {
    echo -e "\n${YELLOW}[3/4] 复制文件...${NC}"
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 复制守护者脚本
    cp -f "$SCRIPT_DIR/oopsclaw-event.sh" ~/.oopsclaw/
    cp -f "$SCRIPT_DIR/oopsclaw-evolve.sh" ~/.oopsclaw/
    cp -f "$SCRIPT_DIR/monitor.sh" ~/.oopsclaw/
    cp -f "$SCRIPT_DIR/ai-evolve.sh" ~/.oopsclaw/
    
    # 复制知识库
    cp -rf "$SCRIPT_DIR/knowledge/"* ~/.oopsclaw/knowledge/
    
    # 复制 systemd 服务
    mkdir -p ~/.config/systemd/user
    cp -f "$SCRIPT_DIR/openclaw-gateway.service" ~/.config/systemd/user/
    cp -f "$SCRIPT_DIR/oopsclaw-event.service" ~/.config/systemd/user/
    
    echo -e "${GREEN}✓${NC} 文件已复制"
}

# 配置服务
setup_services() {
    echo -e "\n${YELLOW}[4/4] 配置服务...${NC}"
    
    # 重新加载 systemd
    systemctl --user daemon-reload
    
    # 配置 OpenClaw Gateway 的 OnFailure (通过 drop-in)
    mkdir -p ~/.config/systemd/user/openclaw-gateway.service.d
    cat > ~/.config/systemd/user/openclaw-gateway.service.d/auto-fix.conf << 'EOF'
[Unit]
OnFailure=oopsclaw-event.service
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Restart=always
EOF
    
    echo -e "${GREEN}✓${NC} OnFailure 已配置"
    
    # 设置权限
    chmod +x ~/.oopsclaw/*.sh
    
    echo -e "${GREEN}✓${NC} 服务已配置"
}

# 主流程
main() {
    check_dependencies
    setup_directories
    copy_files
    setup_services
    
    echo -e "\n${GREEN}======================================${NC}"
    echo -e "${GREEN}🎉 oopsclaw 安装完成!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo "📖 使用说明:"
    echo "  • 故障自动修复: OnFailure 机制 (Gateway 失败时自动触发)"
    echo "  • 手动运行守护者: bash ~/.oopsclaw/oopsclaw-event.sh"
    echo "  • 查看日志: journalctl --user -u oopsclaw-event.service -f"
    echo ""
    echo "📁 文件位置: ~/.oopsclaw/"
    echo "📚 文档: https://github.com/DuanZGit/oopsclaw"
    echo ""
}

main "$@"