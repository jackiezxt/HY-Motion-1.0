#!/bin/bash
# HY-Motion 1.0 快速启动脚本

# 激活 conda 环境
source /AIGC_Group/miniconda3/etc/profile.d/conda.sh
conda activate hymotion

echo "=========================================="
echo "  HY-Motion 1.0 Fast Startup Mode"
echo "=========================================="
echo "  Python: $(which python3)"
echo "=========================================="

# 加载 .env（不覆盖已有环境变量）
if [ -f "$(dirname "$0")/.env" ]; then
  set -a
  source "$(dirname "$0")/.env"
  set +a
fi

# 自动选择显存最空闲的 GPU
if [ -z "$CUDA_VISIBLE_DEVICES" ]; then
    BEST_GPU=$(nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits | sort -t',' -k2 -nr | head -1 | cut -d',' -f1 | tr -d ' ')
    export CUDA_VISIBLE_DEVICES=$BEST_GPU
    echo "Auto-selected GPU $BEST_GPU (most free memory)"
fi

echo ""
echo "Configuration:"
echo "  PROMPT_API_HOST=$PROMPT_API_HOST"
echo "  PROMPT_API_MODEL=$PROMPT_API_MODEL"
echo "  DISABLE_PROMPT_ENGINEERING=${DISABLE_PROMPT_ENGINEERING:-False}"
echo ""

if [ -z "$PROMPT_API_KEY" ]; then
    echo "⚠️  警告: PROMPT_API_KEY 未设置！请在 .env 中配置。"
    echo ""
fi

/AIGC_Group/miniconda3/envs/hymotion/bin/python3 gradio_app.py "$@"
