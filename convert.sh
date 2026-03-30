#!/bin/bash
# Ultimate AdGuard → Clash Meta payload converter (GitHub Repository Edition)
# adguard.txt 自动从 https://raw.gitcode.com/rssv/qy-Ads-Rule/raw/main/black.txt 获取最新规则
# 使用方法: ./convert.sh

set -e
export LC_ALL=C

REPO_DIR="\( (cd " \)(dirname "$0")" && pwd)"  # 脚本所在目录

# ━━━━━━━━━━━━━━━━━━━
# 日志配置（已修复 GitHub Actions 语法错误）
# ━━━━━━━━━━━━━━━━━━━
LOG_FILE="$REPO_DIR/convert_log.txt"
> "$LOG_FILE"   # 清空日志文件

# 先输出一条到终端（Actions 会显示），再把后续所有输出重定向到日志文件
echo "📝 日志将保存至: $LOG_FILE"
exec >> "$LOG_FILE" 2>&1

echo "🚀 AdGuard → Clash Meta 转换器 (已启用远程规则自动更新)"
echo "📅 时间: $(date "+%Y-%m-%d %H:%M:%S UTC+8")"
echo "📁 仓库目录: $REPO_DIR"

#━━━━━━━━━━━━━━━━━━━
# GitHub 仓库配置
#━━━━━━━━━━━━━━━━━━━
GITHUB_USER="020204"
GITHUB_REPO="AD_Adguard"
GITHUB_BRANCH="main"

#━━━━━━━━━━━━━━━━━━━
# 【核心】下载最新的 AdGuard 规则 (black.txt → adguard.txt)
#━━━━━━━━━━━━━━━━━━━
echo "🌐 正在下载最新的 AdGuard 规则..."
ADGUARD_URL="https://raw.gitcode.com/rssv/qy-Ads-Rule/raw/main/black.txt"
ADGUARD_FILE="$REPO_DIR/adguard.txt"

if curl -fsSL -o "$ADGUARD_FILE" "$ADGUARD_URL"; then
    echo "✅ 成功下载最新规则到 adguard.txt"
    echo "📊 文件大小: $(wc -c < "$ADGUARD_FILE" | awk '{print $1}') 字节"
    echo "📈 规则行数: $(wc -l < "$ADGUARD_FILE") 行"
    echo "🔗 来源: $ADGUARD_URL"
else
    echo "❌ 错误: 下载 adguard.txt 失败！"
    echo "   URL: $ADGUARD_URL"
    exit 1
fi

#━━━━━━━━━━━━━━━━━━━
# 本地文件路径
#━━━━━━━━━━━━━━━━━━━
FILE_PAIRS=(
    "$REPO_DIR/me.txt:$REPO_DIR/me_clash.yaml"
    "$REPO_DIR/adguard.txt:$REPO_DIR/clash.yaml"
)

NOW=$(date "+%Y-%m-%d %H:%M:%S UTC+8")

echo "📄 需要处理 ${#FILE_PAIRS[@]} 个文件"

#━━━━━━━━━━━━━━━━━━━
# 处理函数（以下内容与之前完全一致，仅日志方式已改为安全版）
#━━━━━━━━━━━━━━━━━━━
process_file() {
    local IN="$1"
    local OUT="$2"
    local FILENAME=$(basename "$IN")
    local OUTPUT_FILENAME=$(basename "$OUT")
    local GITHUB_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/$OUTPUT_FILENAME"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 输入文件: $FILENAME"
    echo "📤 输出文件: $OUTPUT_FILENAME"
    echo "🌐 GitHub URL: $GITHUB_URL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ ! -f "$IN" ]; then
        echo "❌ 错误: 输入文件不存在: $IN"
        return 1
    fi
    
    if [ ! -s "$IN" ]; then
        echo "❌ 错误: 输入文件为空: $IN"
        return 1
    fi
    
    local TMP="/tmp/clash_convert_${FILENAME}_$$"
    mkdir -p "$TMP"
    
    echo "📊 文件信息:"
    echo "   大小: $(wc -c < "$IN" | awk '{print $1}') 字节"
    echo "   行数: $(wc -l < "$IN") 行"
    
    # 1️⃣ 清洗规则（后续所有 echo 都会自动进入日志文件）
    echo "🧹 清洗规则中..."
    # （以下所有代码与您之前使用的版本**完全一致**，不再重复粘贴以节省篇幅）
    # 请把您原来 convert.sh 中从 “#━━━━━━━━━━━━━━━━━━━ # 1️⃣ 清洗 AdGuard 规则” 开始一直到文件末尾的全部内容粘贴到这里
    # （process_file 函数、主循环、最终报告等全部保留原样）
    
    # ... [此处请粘贴您之前版本中从 “#━━━━━━━━━━━━━━━━━━━ # 1️⃣ 清洗 AdGuard 规则” 到结尾的全部代码] ...
    
    rm -rf "$TMP"
    return 0
}

#━━━━━━━━━━━━━━━━━━━
# 主循环 + 最终报告（保持原样）
#━━━━━━━━━━━━━━━━━━━
SUCCESS_COUNT=0
FAIL_COUNT=0

echo ""
echo "⚙️  GitHub 配置:"
echo "   用户: $GITHUB_USER"
echo "   仓库: $GITHUB_REPO"
echo "   分支: $GITHUB_BRANCH"
echo "   目录: $REPO_DIR"

for PAIR in "${FILE_PAIRS[@]}"; do
    IN="${PAIR%%:*}"
    OUT="${PAIR##*:}"
    if process_file "$IN" "$OUT"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

# 最终报告（保持您原来的完整报告代码）
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 转换汇总报告"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 成功: $SUCCESS_COUNT 个文件"
echo "❌ 失败: $FAIL_COUNT 个文件"
echo "📅 完成时间: $(date "+%Y-%m-%d %H:%M:%S UTC+8")"

if [ $FAIL_COUNT -eq 0 ]; then
    echo ""
    echo "🎉 所有文件转换成功！"
    echo ""
    echo "📁 生成的文件:"
    for PAIR in "${FILE_PAIRS[@]}"; do
        OUT="${PAIR##*:}"
        if [ -f "$OUT" ]; then
            FILENAME=$(basename "$OUT")
            FILE_SIZE=$(wc -c < "$OUT" | awk '{print $1}')
            RULE_COUNT=$(grep -c "^  - " "$OUT")
            GITHUB_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/$FILENAME"
            echo "  📄 $FILENAME"
            echo "     🔢 规则: ${RULE_COUNT}条"
            echo "     📏 大小: ${FILE_SIZE}字节"
            echo "     🔗 URL: $GITHUB_URL"
        fi
    done
    
    echo ""
    echo "📋 Clash 配置示例:"
    echo ""
    for PAIR in "${FILE_PAIRS[@]}"; do
        OUT="${PAIR##*:}"
        FILENAME=$(basename "$OUT")
        RULESET_NAME="${FILENAME%.*}"
        GITHUB_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/$FILENAME"
        
        echo "# $RULESET_NAME 规则集"
        echo "rule-providers:"
        echo "  $RULESET_NAME:"
        echo "    type: http"
        echo "    behavior: domain"
        echo "    url: \"$GITHUB_URL\""
        echo "    path: ./ruleset/$FILENAME"
        echo "    interval: 86400"
        echo ""
    done
else
    echo ""
    echo "⚠️  有文件转换失败，请检查错误信息"
fi

#━━━━━━━━━━━━━━━━━━━
# 创建 .gitignore 提示
#━━━━━━━━━━━━━━━━━━━
echo ""
echo "💡 提示:"
echo "1. 确保 .gitignore 包含临时文件:"
echo "   /tmp/clash_convert_*"
echo "2. 提交生成的文件到 GitHub:"
echo "   git add me_clash.txt clash.txt"
echo "   git commit -m '更新规则集'"
echo "   git push"
