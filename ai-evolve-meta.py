#!/usr/bin/env python3
"""
iFlow Oopsclaw Meta-Evolution System
进化的进化 - 评分选择器 + 精简优化

功能：
1. 评分系统 - 对每次进化进行评分
2. 版本管理 - 保留多个进化版本
3. 权重选择 - 根据评分自动选择最佳策略
4. 精简优化 - 目标是减少 token 消耗，提高效率
"""

import json
import os
import time
from datetime import datetime
from typing import Dict, List, Optional

# 路径配置
OOPSCLAW_DIR = os.path.expanduser("~/.oopsclaw")
EVOLUTIONS_DIR = f"{OOPSCLAW_DIR}/evolutions"
SCORES_DIR = f"{OOPSCLAW_DIR}/scores"
LEARNED_DIR = f"{OOPSCLAW_DIR}/knowledge/learned"
LOG_DIR = f"{OOPSCLAW_DIR}/logs"

# 评分配置文件
SCORES_FILE = f"{SCORES_DIR}/evolution_scores.json"
WEIGHTS_FILE = f"{SCORES_FILE}.weights"

# 评分指标及权重
DEFAULT_WEIGHTS = {
    'token_efficiency': 0.25,      # Token 效率 (越少越好)
    'fix_success': 0.25,            # 修复成功率
    'response_time': 0.20,           # 响应时间
    'code_simplity': 0.15,          # 代码精简度
    'learning_gain': 0.15           # 学习增益
}

class EvolutionScorer:
    """进化评分器"""
    
    def __init__(self):
        self.weights = self.load_weights()
        self.scores = self.load_scores()
    
    def load_weights(self) -> Dict:
        """加载权重配置"""
        try:
            with open(WEIGHTS_FILE, 'r') as f:
                return json.load(f)
        except:
            return DEFAULT_WEIGHTS.copy()
    
    def save_weights(self):
        """保存权重配置"""
        with open(WEIGHTS_FILE, 'w') as f:
            json.dump(self.weights, f, indent=2)
    
    def load_scores(self) -> Dict:
        """加载历史评分"""
        try:
            with open(SCORES_FILE, 'r') as f:
                return json.load(f)
        except:
            return {'evolutions': {}, 'runs': []}
    
    def save_scores(self):
        """保存评分"""
        with open(SCORES_FILE, 'w') as f:
            json.dump(self.scores, f, indent=2)
    
    def calculate_score(self, evolution_name: str, metrics: Dict) -> float:
        """
        计算综合评分
        
        metrics 包含:
        - tokens_used: 消耗的 token 数量
        - fix_success: 是否成功修复 (0/1)
        - response_time: 响应时间(秒)
        - code_lines: 代码行数变化
        - new_knowledge: 新学到知识数量
        """
        score = 0.0
        
        # 1. Token 效率 (越少越好，反向计算)
        if 'tokens_used' in metrics:
            tokens = metrics['tokens_used']
            # 假设 1000 tokens 为基准，越少越好
            token_score = max(0, 100 - (tokens / 10))
            score += token_score * self.weights['token_efficiency']
        
        # 2. 修复成功率
        if 'fix_success' in metrics:
            score += metrics['fix_success'] * 100 * self.weights['fix_success']
        
        # 3. 响应时间 (越快越好)
        if 'response_time' in metrics:
            # 假设 30 秒为基准
            time_score = max(0, 100 - (metrics['response_time'] * 3.3))
            score += time_score * self.weights['response_time']
        
        # 4. 代码精简度 (行数减少为正)
        if 'code_lines_delta' in metrics:
            delta = metrics['code_lines_delta']
            if delta < 0:  # 代码减少了
                simplicity_score = min(100, abs(delta) * 10)
            else:  # 代码增加了
                simplicity_score = max(0, 100 - delta * 5)
            score += simplicity_score * self.weights['code_simplity']
        
        # 5. 学习增益
        if 'new_knowledge' in metrics:
            score += min(50, metrics['new_knowledge'] * 10) * self.weights['learning_gain']
        
        return round(score, 2)
    
    def record_run(self, evolution_name: str, metrics: Dict) -> float:
        """记录一次运行并返回评分"""
        score = self.calculate_score(evolution_name, metrics)
        
        # 更新进化版本评分
        if evolution_name not in self.scores['evolutions']:
            self.scores['evolutions'][evolution_name] = {
                'runs': 0,
                'total_score': 0,
                'avg_score': 0,
                'success_rate': 0
            }
        
        evo = self.scores['evolutions'][evolution_name]
        evo['runs'] += 1
        evo['total_score'] += score
        evo['avg_score'] = evo['total_score'] / evo['runs']
        
        if metrics.get('fix_success', 0) == 1:
            evo['success_rate'] = evo.get('success_rate', 0) * 0.9 + 10
        else:
            evo['success_rate'] = evo.get('success_rate', 0) * 0.9
        
        # 记录运行历史
        self.scores['runs'].append({
            'timestamp': datetime.now().isoformat(),
            'evolution': evolution_name,
            'score': score,
            'metrics': metrics
        })
        
        # 只保留最近 100 条记录
        self.scores['runs'] = self.scores['runs'][-100:]
        
        self.save_scores()
        return score
    
    def get_best_evolution(self) -> str:
        """获取最佳进化版本"""
        best = 'ai-evolve-v1.0'
        best_score = 0
        
        for name, data in self.scores['evolutions'].items():
            if data['avg_score'] > best_score:
                best_score = data['avg_score']
                best = name
        
        return best
    
    def adjust_weights(self, feedback: str):
        """根据反馈调整权重"""
        # 简单的权重调整逻辑
        if 'too_slow' in feedback.lower():
            self.weights['response_time'] += 0.1
            self.weights['token_efficiency'] -= 0.05
        
        if 'too_many_tokens' in feedback.lower():
            self.weights['token_efficiency'] += 0.1
            self.weights['code_simplity'] -= 0.05
        
        if 'fix_failed' in feedback.lower():
            self.weights['fix_success'] += 0.1
            self.weights['token_efficiency'] -= 0.05
        
        # 归一化权重
        total = sum(self.weights.values())
        for k in self.weights:
            self.weights[k] = round(self.weights[k] / total, 2)
        
        self.save_weights()
    
    def get_report(self) -> str:
        """生成评分报告"""
        report = []
        report.append("=" * 50)
        report.append("📊 iFlow Oopsclaw 进化评分报告")
        report.append("=" * 50)
        report.append(f"\n当前权重配置:")
        for k, v in self.weights.items():
            report.append(f"  {k}: {v*100:.0f}%")
        
        report.append(f"\n最佳进化版本: {self.get_best_evolution()}")
        
        report.append(f"\n各版本评分:")
        for name, data in sorted(self.scores['evolutions'].items(), 
                                  key=lambda x: x[1]['avg_score'], reverse=True):
            report.append(f"  {name}:")
            report.append(f"    - 运行次数: {data['runs']}")
            report.append(f"    - 平均评分: {data['avg_score']:.2f}")
            report.append(f"    - 成功率: {data['success_rate']:.1f}%")
        
        return "\n".join(report)

def create_evolution_v2() -> str:
    """创建精简版进化器 (v2.0 - 减少 token)"""
    v2_content = '''#!/usr/bin/env python3
"""
iFlow Oopsclaw AI 进化模块 - v2.0 精简版
优化目标: 减少 token 消耗，提高效率
"""

import json
import sys
import os

OOPSCLAW_DIR = os.path.expanduser("~/.oopsclaw")
IFLOW_CONFIG = os.path.expanduser("~/.iflow/settings.json")

def get_iflow_config():
    try:
        with open(IFLOW_CONFIG, 'r') as f:
            return json.load(f)
    except:
        return None

def evolve(problem: str, context: str = "") -> dict:
    """精简版进化 - 只输出关键信息"""
    config = get_iflow_config()
    if not config:
        return {'error': '配置错误'}
    
    # 精简 Prompt - 只包含必要信息
    prompt = f"""你是系统自愈专家。问题: {problem}

要求输出(精简):
1. 根因 (1句)
2. 命令 (如有)
3. 指纹更新 (如有)
4. 经验 (1句)

格式:
## 分析
[1句]
## 命令
[命令]
## 指纹
[指纹]
## 经验
[1句]
"""
    
    try:
        from iflow_sdk import query_sync, IFlowOptions
        options = IFlowOptions(timeout=30.0)  # 减少超时
        response = query_sync(prompt, options=options)
        return {'response': response, 'tokens_estimate': len(prompt) // 4}
    except Exception as e:
        return {'error': str(e)}

def main():
    if len(sys.argv) < 2:
        print("用法: ai-evolve-v2.0.py <问题>")
        sys.exit(1)
    
    result = evolve(sys.argv[1])
    if 'error' in result:
        print(result['error'])
    else:
        print(result['response'])
        print(f"\\n[Token消耗估算: ~{result.get('tokens_estimate', '?')}]")

if __name__ == "__main__":
    main()
'''
    
    v2_path = f"{EVOLUTIONS_DIR}/ai-evolve-v2.0.py"
    with open(v2_path, 'w') as f:
        f.write(v2_content)
    os.chmod(v2_path, 0o755)
    return v2_path

def main():
    import argparse
    parser = argparse.ArgumentParser(description='iFlow Oopsclaw Meta-Evolution')
    parser.add_argument('--score', help='记录评分', nargs='+')
    parser.add_argument('--best', action='store_true', help='获取最佳版本')
    parser.add_argument('--report', action='store_true', help='生成评分报告')
    parser.add_argument('--create-v2', action='store_true', help='创建精简版v2')
    parser.add_argument('--adjust', help='根据反馈调整权重')
    
    args = parser.parse_args()
    
    scorer = EvolutionScorer()
    
    if args.best:
        print(scorer.get_best_evolution())
    
    elif args.report:
        print(scorer.get_report())
    
    elif args.create_v2:
        path = create_evolution_v2()
        print(f"✅ 已创建精简版: {path}")
    
    elif args.score:
        # 格式: --score evolution_name tokens time success lines knowledge
        if len(args.score) >= 7:
            name = args.score[0]
            metrics = {
                'tokens_used': int(args.score[1]),
                'response_time': float(args.score[2]),
                'fix_success': int(args.score[3]),
                'code_lines_delta': int(args.score[4]),
                'new_knowledge': int(args.score[5])
            }
            score = scorer.record_run(name, metrics)
            print(f"评分: {score}")
    
    elif args.adjust:
        scorer.adjust_weights(args.adjust)
        print("✅ 权重已调整")
    
    else:
        print(scorer.get_report())

if __name__ == "__main__":
    main()
