#!/bin/bash
# Ultimate AdGuard → Clash Meta payload converter (GitHub Repository Edition)
# Author: chatgpt
# GitHub: https://github.com/020204/AD_Adguard
# 使用方法: ./convert.sh

set -e
export LC_ALL=C
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"  # 脚本所在目录（仓库根目录）
# ━━━━━━━━━━━━━━━━━━━
# 新增：日志配置
# ━━━━━━━━━━━━━━━━━━━
LOG_FILE="$REPO_DIR/convert_log.txt"

# 将后续所有输出同步重定向到文件和终端
# exec 意思是执行后续命令， >(tee ...) 会开启一个进程记录输出
exec > >(tee -i "$LOG_FILE") 2>&1

echo "📝 日志将保存至: $LOG_FILE"

#━━━━━━━━━━━━━━━━━━━
# GitHub 仓库配置
#━━━━━━━━━━━━━━━━━━━
GITHUB_USER="020204"
GITHUB_REPO="AD_Adguard"
GITHUB_BRANCH="main"

#━━━━━━━━━━━━━━━━━━━
# 本地文件路径（仓库根目录）
#━━━━━━━━━━━━━━━━━━━

FILE_PAIRS=(
    "$REPO_DIR/me.txt:$REPO_DIR/me_clash.yaml"
    "$REPO_DIR/adguard.txt:$REPO_DIR/clash.yaml"
)

NOW=$(date "+%Y-%m-%d %H:%M:%S UTC+8")

echo "🚀 AdGuard → Clash Meta 转换器"
echo "📅 时间: $NOW"
echo "📁 仓库目录: $REPO_DIR"
echo "📄 需要处理 ${#FILE_PAIRS[@]} 个文件"

#━━━━━━━━━━━━━━━━━━━
# 处理函数
#━━━━━━━━━━━━━━━━━━━
process_file() {
    local IN="$1"
    local OUT="$2"
    local FILENAME=$(basename "$IN")
    local OUTPUT_FILENAME=$(basename "$OUT")
    
    # 生成对应的 GitHub Raw URL
    local GITHUB_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/$OUTPUT_FILENAME"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 输入文件: $FILENAME"
    echo "📤 输出文件: $OUTPUT_FILENAME"
    echo "🌐 GitHub URL: $GITHUB_URL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ ! -f "$IN" ]; then
        echo "❌ 错误: 输入文件不存在: $IN"
        echo "💡 提示: 请确保 $FILENAME 存在于仓库根目录"
        return 1
    fi
    
    if [ ! -s "$IN" ]; then
        echo "❌ 错误: 输入文件为空: $IN"
        return 1
    fi
    
    # 创建临时目录（在系统临时目录）
    local TMP="/tmp/clash_convert_${FILENAME}_$$"
    mkdir -p "$TMP"
    
    echo "📊 文件信息:"
    echo "   大小: $(wc -c < "$IN" | awk '{print $1}') 字节"
    echo "   行数: $(wc -l < "$IN") 行"
    
    #━━━━━━━━━━━━━━━━━━━
    # 1️⃣ 清洗 AdGuard 规则
    #━━━━━━━━━━━━━━━━━━━
    echo "🧹 清洗规则中..."
    
    grep -vE '^(#|!|/\*|\s*$|@@)' "$IN" \
    | sed -E '
      s/\r//g
      s/\$.*//
      s#https?://##
      s/^0\.0\.0\.0[[:space:]]+//
      s/^127\.0\.0\.1[[:space:]]+//
      s/^\|\|//
      s/\^$//
    ' > "$TMP/clean.txt"
    
    ORIGINAL_COUNT=$(wc -l < "$TMP/clean.txt")
    echo "📊 有效规则数: $ORIGINAL_COUNT"
    
    if [ "$ORIGINAL_COUNT" -eq 0 ]; then
        echo "⚠️  警告: 清洗后规则数为0，尝试备用方法..."
        grep -v '^\s*$' "$IN" | grep -v '^#' | grep -v '^!' | sed 's/\r//g' > "$TMP/clean.txt"
        ORIGINAL_COUNT=$(wc -l < "$TMP/clean.txt")
        echo "📊 备用清洗后: $ORIGINAL_COUNT 条"
    fi
    
    if [ "$ORIGINAL_COUNT" -eq 0 ]; then
        echo "❌ 错误: 没有有效的规则可以处理"
        rm -rf "$TMP"
        return 1
    fi
    
    #━━━━━━━━━━━━━━━━━━━
    # 2️⃣ awk 极速分类
    #━━━━━━━━━━━━━━━━━━━
    echo "🚀 规则分类中..."
    
    awk '
    BEGIN {
      dom=0; key=0; ip=0; skip=0
    }
    {
      line=$0
      if (line == "") next
    
      # 跳过路径 / 正则
      if (line ~ /\//) {
        skip++
        next
      }
    
      # IPv4
      if (line ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
        print "  - IP-CIDR," line "/32,no-resolve"
        ip++
        next
      }
    
      # 通配符
      if (line ~ /\*/) {
        gsub(/\*/, "", line)
        if (line != "") {
          print "  - DOMAIN-KEYWORD," line
          key++
        }
        next
      }
    
      # 域名
      n = split(line, a, ".")
      if (n >= 3) {
        print "  - DOMAIN," line
        dom++
      } else {
        print "  - DOMAIN-SUFFIX," line
        dom++
      }
    }
    END {
      printf "DOMAIN=%d\nKEYWORD=%d\nIP=%d\nSKIP=%d\n", dom, key, ip, skip > "'"$TMP/stats.txt"'"
    }
    ' "$TMP/clean.txt" > "$TMP/rules.txt"
    
    # 读取统计信息
    DOMAIN_COUNT=0
    KEYWORD_COUNT=0
    IP_COUNT=0
    SKIP_COUNT=0
    
    if [ -f "$TMP/stats.txt" ]; then
        while IFS='=' read -r key value; do
            case $key in
                DOMAIN) DOMAIN_COUNT=$value ;;
                KEYWORD) KEYWORD_COUNT=$value ;;
                IP) IP_COUNT=$value ;;
                SKIP) SKIP_COUNT=$value ;;
            esac
        done < "$TMP/stats.txt"
    fi
    
    DOMAIN_SUFFIX_COUNT=$(grep -c "DOMAIN-SUFFIX," "$TMP/rules.txt")
    DOMAIN_COUNT=$((DOMAIN_COUNT - DOMAIN_SUFFIX_COUNT))
    CLASSIFIED_COUNT=$(wc -l < "$TMP/rules.txt")
    
    echo "📈 分类统计:"
    echo "   🔸 DOMAIN: $DOMAIN_COUNT"
    echo "   🔹 DOMAIN-SUFFIX: $DOMAIN_SUFFIX_COUNT"
    echo "   🔠 DOMAIN-KEYWORD: $KEYWORD_COUNT"
    echo "   📡 IP-CIDR: $IP_COUNT"
    echo "   🚫 跳过路径规则: $SKIP_COUNT"
    
    #━━━━━━━━━━━━━━━━━━━
    # 3️⃣ 排序 + 去重
    #━━━━━━━━━━━━━━━━━━━
    echo "🧹 排序去重中..."
    sort -u "$TMP/rules.txt" > "$TMP/sorted.txt"
    AFTER_DEDUP=$(wc -l < "$TMP/sorted.txt")
    REMOVED_DUPLICATES=$((CLASSIFIED_COUNT - AFTER_DEDUP))
    echo "✅ 去重: 移除了 $REMOVED_DUPLICATES 条重复"
    
    #━━━━━━━━━━━━━━━━━━━
    # 4️⃣ 子域压缩
    #━━━━━━━━━━━━━━━━━━━
    echo "🔧 子域压缩中..."
    
    awk -F',' '
    {
      rule[$2] = $0
      type = $1
      if (type == "  - DOMAIN") domain_type[$2] = "DOMAIN"
      else if (type == "  - DOMAIN-SUFFIX") domain_type[$2] = "DOMAIN-SUFFIX"
      else if (type == "  - DOMAIN-KEYWORD") domain_type[$2] = "KEYWORD"
      else if (type == "  - IP-CIDR") domain_type[$2] = "IP"
    }
    END {
      for (d in rule) {
        if (domain_type[d] == "IP" || domain_type[d] == "KEYWORD") {
          print rule[d]
          continue
        }
        
        split(d, a, ".")
        keep = 1
        
        for (i = 2; i <= length(a); i++) {
          parent = ""
          for (j = i; j <= length(a); j++) {
            parent = parent (j==i?"":".") a[j]
          }
          if (parent in rule && domain_type[parent] != "IP" && domain_type[parent] != "KEYWORD") {
            if (!(domain_type[d] == "DOMAIN" && domain_type[parent] == "DOMAIN-SUFFIX")) {
              keep = 0
              break
            }
          }
        }
        if (keep) print rule[d]
      }
    }' "$TMP/sorted.txt" > "$TMP/final.txt"
    
    #━━━━━━━━━━━━━━━━━━━
    # 5️⃣ 统计最终数量
    #━━━━━━━━━━━━━━━━━━━
    FINAL_COUNT=$(wc -l < "$TMP/final.txt")
    FINAL_DOMAIN=$(grep -c "DOMAIN," "$TMP/final.txt")
    FINAL_SUFFIX=$(grep -c "DOMAIN-SUFFIX," "$TMP/final.txt")
    FINAL_KEYWORD=$(grep -c "DOMAIN-KEYWORD," "$TMP/final.txt")
    FINAL_IP=$(grep -c "IP-CIDR," "$TMP/final.txt")
    COMPRESSED_COUNT=$((AFTER_DEDUP - FINAL_COUNT))
    
    echo "📊 最终统计:"
    echo "   ✅ 总计: $FINAL_COUNT 条"
    echo "   🔸 DOMAIN: $FINAL_DOMAIN"
    echo "   🔹 DOMAIN-SUFFIX: $FINAL_SUFFIX"
    echo "   🔠 DOMAIN-KEYWORD: $FINAL_KEYWORD"
    echo "   📡 IP-CIDR: $FINAL_IP"
    echo "   🔽 压缩优化: 移除了 $COMPRESSED_COUNT 条冗余子域"
    
    #━━━━━━━━━━━━━━━━━━━
    # 6️⃣ 生成最终文件
    #━━━━━━━━━━━━━━━━━━━
    echo "📄 生成 Clash 配置文件..."
    
    cat > "$TMP/new.txt" <<EOF
#Title: ${OUTPUT_FILENAME%.*} 规则集
#Source: ${FILENAME}
#Author: 020204
#GitHub: https://github.com/$GITHUB_USER/$GITHUB_REPO
#Update URL: $GITHUB_URL
#--------------------------------------
#原始规则数: $ORIGINAL_COUNT
#最终规则数: $FINAL_COUNT
#DOMAIN: $FINAL_DOMAIN
#DOMAIN-SUFFIX: $FINAL_SUFFIX
#DOMAIN-KEYWORD: $FINAL_KEYWORD
#IP-CIDR: $FINAL_IP
#移除重复: $REMOVED_DUPLICATES
#压缩子域: $COMPRESSED_COUNT
#更新时间: $NOW

payload:
EOF
    
    cat "$TMP/final.txt" >> "$TMP/new.txt"
    
    #━━━━━━━━━━━━━━━━━━━
    # 7️⃣ 检查内容变化
    #━━━━━━━━━━━━━━━━━━━
    local NEED_UPDATE=true
    if [ -f "$OUT" ]; then
        if cmp -s "$TMP/new.txt" "$OUT"; then
            echo "🧠 规则无变化，跳过更新"
            NEED_UPDATE=false
        else
            echo "📈 规则有变化，准备更新"
        fi
    fi
    
    if [ "$NEED_UPDATE" = true ]; then
        mv "$TMP/new.txt" "$OUT"
        echo "✅ 文件已更新: $OUT"
    fi
    
    rm -rf "$TMP"
    return 0
}

#━━━━━━━━━━━━━━━━━━━
# 主循环处理所有文件
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

#━━━━━━━━━━━━━━━━━━━
# 最终报告
#━━━━━━━━━━━━━━━━━━━
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
