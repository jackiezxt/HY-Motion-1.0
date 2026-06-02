#!/bin/bash
# HY-Motion 1.0 快速启动脚本
# 通过懒加载和优化配置大幅减少启动时间

# 激活 conda 环境
source /AIGC_Group/miniconda3/etc/profile.d/conda.sh
conda activate hymotion

echo "=========================================="
echo "  HY-Motion 1.0 Fast Startup Mode"
echo "=========================================="
echo "  Python: $(which python3)"
echo "=========================================="

# 加载本地 .env 文件（不覆盖已有环境变量）
if [ -f "$(dirname "$0")/.env" ]; then
  set -a
  source "$(dirname "$0")/.env"
  set +a
fi

# ============ 优化配置 ============

# 1. 使用本地模型缓存（如果已下载）
#    设为 0 使用本地 ckpts/ 目录，设为 1 从 HuggingFace 在线加载
export USE_HF_MODELS=${USE_HF_MODELS:-0}

# 2. 离线模式：禁止 Transformers/HuggingFace 网络请求
#    模型已下载到本地后，开启此项可跳过网络检查，加速启动
export TRANSFORMERS_OFFLINE=1
export HF_HUB_OFFLINE=1

# 3. 启用懒加载：文本编码器在首次推理时才加载
#    这可以让 UI 快速启动，模型在用户点击生成时才加载
export LAZY_TEXT_ENCODER=1

# 4. 网络代理（服务器访问外网 API 需要）
export HTTPS_PROXY="${HTTPS_PROXY:-http://10.236.255.12:18888}"
export HTTP_PROXY="${HTTP_PROXY:-http://10.236.255.12:18888}"

# 5. 使用 Nova LLM Proxy 进行 Prompt 重写（推荐！省显存）
#    设置后将使用远程 API 代替本地 LLM，本机 0 显存占用
#    获取 API Key: https://console.tapsvc.com/nova/#/ai-gateway
export PROMPT_API_HOST="${PROMPT_API_HOST:-https://llm-proxy.tapsvc.com/v1}"
export PROMPT_API_KEY="${PROMPT_API_KEY}"  # 从 .env 或环境变量注入，禁止硬编码
export PROMPT_API_MODEL="${PROMPT_API_MODEL:-qwen/qwen3.6-plus}"

# 5. PromptRewriter 显存管理（使用 API 时可忽略）
#    设为 1：Rewrite 完成后自动卸载 PromptRewriter 模型，释放显存给动作生成
#    设为 0：保持 PromptRewriter 在显存中（适合频繁 Rewrite 的场景）
export AUTO_UNLOAD_PROMPTER=1

# 6. 禁用 Prompt Engineering（可选）
#    如果不需要自动重写 Prompt 和时长预测，取消下面的注释
# export DISABLE_PROMPT_ENGINEERING=True

# 7. 自动选择显存最空闲的 GPU
if [ -z "$CUDA_VISIBLE_DEVICES" ]; then
    BEST_GPU=$(nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits | sort -t',' -k2 -nr | head -1 | cut -d',' -f1 | tr -d ' ')
    export CUDA_VISIBLE_DEVICES=$BEST_GPU
    echo "Auto-selected GPU $BEST_GPU (most free memory)"
fi

# 8. 优化 PyTorch 显存分配
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# 9. 生成完成后自动清理 GPU 缓存
#    设为 1：每次生成完成后调用 torch.cuda.empty_cache() 释放缓存
#    设为 0：保持缓存（适合连续生成的场景）
export AUTO_CLEAN_GPU_CACHE=1

# 10. 生成完成后彻底卸载模型（激进模式，可释放全部显存）
#    设为 1：生成完成后将模型从 GPU 卸载，下次生成需重新加载（约30秒）
#    设为 0：保持模型在 GPU（推荐，连续生成更快）
#    注意：仅当需要释放显存给其他任务时才启用
export AUTO_UNLOAD_MODEL=0

# 11. 网络代理配置（服务器访问外网需要）
export HTTP_PROXY="http://172.24.12.140:18888"
export HTTPS_PROXY="http://172.24.12.140:18888"
# 确保 localhost 不走代理（Gradio 需要）
export NO_PROXY="localhost,127.0.0.1"
export no_proxy="localhost,127.0.0.1"

# ============ 启动服务 ============

echo ""
echo "Configuration:"
echo "  USE_HF_MODELS=$USE_HF_MODELS"
echo "  TRANSFORMERS_OFFLINE=$TRANSFORMERS_OFFLINE"
echo "  HF_HUB_OFFLINE=$HF_HUB_OFFLINE"
echo "  LAZY_TEXT_ENCODER=$LAZY_TEXT_ENCODER"
echo "  PROMPT_API_HOST=$PROMPT_API_HOST"
echo "  PROMPT_API_MODEL=$PROMPT_API_MODEL"
echo "  DISABLE_PROMPT_ENGINEERING=${DISABLE_PROMPT_ENGINEERING:-False}"
echo ""

# 检查 API Key 是否已设置
if [ "$PROMPT_API_KEY" = "your_api_key_here" ]; then
    echo "⚠️  警告: PROMPT_API_KEY 未设置！"
    echo "   请设置环境变量: export PROMPT_API_KEY=your_actual_key"
    echo "   或者禁用 Prompt Engineering: export DISABLE_PROMPT_ENGINEERING=True"
    echo ""
fi

# 使用 conda 环境中的 Python（确保路径正确）
/AIGC_Group/miniconda3/envs/hymotion/bin/python3 gradio_app.py "$@"
