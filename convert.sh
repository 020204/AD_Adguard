#!/system/bin/sh
# Ultimate AdGuard → Clash Meta payload converter (Final Turbo Edition)
# Author: chatgpt
# Android / KernelSU / Magisk / GitHub Actions Friendly

set -e
export LC_ALL=C

IN="/storage/emulated/0/Download/adguard.txt"
OUT="/storage/emulated/0/Download/clash.txt"

if [ ! -f "$IN" ]; then
  echo "❌ 未找到规则文件：$IN"
  exit 1
fi

TMP="/data/local/tmp/clash_convert_$$"
mkdir -p "$TMP"

echo "📥 读取规则: $IN"
echo "📤 输出文件: $OUT"
echo "⚡ 启用高性能模式"

#━━━━━━━━━━━━━━━━━━━
# 1️⃣ 清洗 AdGuard 规则
#━━━━━━━━━━━━━━━━━━━
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
NOW=$(date "+%Y-%m-%d %H:%M:%S UTC+8")

echo "📊 原始规则数: $ORIGINAL_COUNT"

#━━━━━━━━━━━━━━━━━━━
# 2️⃣ awk 极速分类（核心加速）
#━━━━━━━━━━━━━━━━━━━
echo "🚀 规则分类中（awk 高速模式）..."

awk '
BEGIN {
  dom=0; key=0; ip=0
}
{
  line=$0
  if (line == "") next

  # 跳过路径 / 正则
  if (line ~ /\//) next

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
  } else {
    print "  - DOMAIN-SUFFIX," line
  }
  dom++
}
' "$TMP/clean.txt" > "$TMP/rules.txt"

# 暂时统计原始分类数量（处理前）
DOMAIN_COUNT=$(grep -c "DOMAIN," "$TMP/rules.txt")
DOMAIN_SUFFIX_COUNT=$(grep -c "DOMAIN-SUFFIX," "$TMP/rules.txt")
KEYWORD_COUNT=$(grep -c "DOMAIN-KEYWORD," "$TMP/rules.txt")
IP_COUNT=$(grep -c "IP-CIDR," "$TMP/rules.txt")
CLASSIFIED_COUNT=$(wc -l < "$TMP/rules.txt")
SKIP_COUNT=$((ORIGINAL_COUNT - CLASSIFIED_COUNT))

echo "📈 分类统计:"
echo "   DOMAIN: $DOMAIN_COUNT"
echo "   DOMAIN-SUFFIX: $DOMAIN_SUFFIX_COUNT"
echo "   DOMAIN-KEYWORD: $KEYWORD_COUNT"
echo "   IP-CIDR: $IP_COUNT"
echo "   🚫 已跳过: $SKIP_COUNT (含路径规则)"

#━━━━━━━━━━━━━━━━━━━
# 3️⃣ 排序 + 去重
#━━━━━━━━━━━━━━━━━━━
sort -u "$TMP/rules.txt" > "$TMP/sorted.txt"
AFTER_DEDUP=$(wc -l < "$TMP/sorted.txt")
REMOVED_DUPLICATES=$((CLASSIFIED_COUNT - AFTER_DEDUP))

echo "🧹 去重: 移除了 $REMOVED_DUPLICATES 条重复规则"

#━━━━━━━━━━━━━━━━━━━
# 4️⃣ 子域压缩
#━━━━━━━━━━━━━━━━━━━
echo "🔧 子域压缩优化中..."

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
    
    # 只处理 DOMAIN 和 DOMAIN-SUFFIX
    split(d, a, ".")
    keep = 1
    
    # 检查是否有父域存在
    for (i = 2; i <= length(a); i++) {
      parent = ""
      for (j = i; j <= length(a); j++) {
        parent = parent (j==i?"":".") a[j]
      }
      if (parent in rule && domain_type[parent] != "IP" && domain_type[parent] != "KEYWORD") {
        # 如果父域是 DOMAIN-SUFFIX，子域是 DOMAIN，可以保留
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
# 6️⃣ 生成新文件（临时）
#━━━━━━━━━━━━━━━━━━━
cat > "$TMP/new.txt" <<EOF
#Title: 安妮
#--------------------------------------
#Source: AdGuard Rules
#Original rules: $ORIGINAL_COUNT
#Final rules: $FINAL_COUNT
#DOMAIN: $FINAL_DOMAIN
#DOMAIN-SUFFIX: $FINAL_SUFFIX
#DOMAIN-KEYWORD: $FINAL_KEYWORD
#IP-CIDR: $FINAL_IP
#Duplicates removed: $REMOVED_DUPLICATES
#Subdomains compressed: $COMPRESSED_COUNT
#Update time: $NOW
#Homepage: https://github.com/020204/AD_Adguard
#Update url: https://raw.githubusercontent.com/020204/AD_Adguard/main/clash.txt

payload:
EOF

cat "$TMP/final.txt" >> "$TMP/new.txt"

#━━━━━━━━━━━━━━━━━━━
# 7️⃣ 内容无变化 → 不更新
#━━━━━━━━━━━━━━━━━━━
if [ -f "$OUT" ]; then
  OLD_HASH=$(sha256sum "$OUT" | awk '{print $1}')
  NEW_HASH=$(sha256sum "$TMP/new.txt" | awk '{print $1}')
  if [ "$OLD_HASH" = "$NEW_HASH" ]; then
    echo "🧠 规则无变化，跳过更新"
    rm -rf "$TMP"
    exit 0
  fi
fi

mv "$TMP/new.txt" "$OUT"
rm -rf "$TMP"

echo "✅ 转换完成"
echo "📄 Clash Meta 规则已生成："
echo "👉 $OUT"
echo "🎯 总计 $FINAL_COUNT 条规则"