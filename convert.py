#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AdGuard 规则 → Clash Classical + AdGuard 合并规则
三源合并 + 去重 + 例外规则（@@）覆盖拦截规则
"""

import re
from datetime import datetime, timezone, timedelta
from pathlib import Path
import requests

SOURCES = [
    "https://ghfast.top/https://raw.githubusercontent.com/020204/AD_Adguard/main/me.txt",
    "https://raw.githubusercontent.com/rssvcn/qy-Ads-Rule/main/black.txt",
    "https://raw.githubusercontent.com/rssvcn/Ads-Root_Rule/main/Ads-Dns_Rule.txt",
]

CLASH_OUTPUT = "merged-ads-clash-classical.yaml"
ADG_OUTPUT = "merged-ads-adguard.txt"

def fetch(url: str) -> str:
    headers = {
        "User-Agent": "Mozilla/5.0 (compatible; Clash-Rule-Updater/1.0)"
    }
    print(f"Fetching: {url}")
    try:
        r = requests.get(url, headers=headers, timeout=30)
        r.raise_for_status()
        r.encoding = "utf-8"
        print(f"  → {r.status_code}, length={len(r.text)}")
        return r.text
    except Exception as e:
        print(f"  Failed: {e}")
        return ""

def extract_domain(line: str) -> str | None:
    line = line.strip()
    m = re.match(r"^(?:@@)?\|\|([a-zA-Z0-9.*_-]+\.[a-zA-Z0-9.*_-]+)", line)
    if m:
        domain = m.group(1).lower()
        if domain.startswith("*."):
            domain = domain[2:]
        if "*" in domain:
            return None
        if domain and "." in domain:
            return domain
    return None

def main():
    block_domains = set()
    exception_domains = set()

    for url in SOURCES:
        content = fetch(url)
        if not content:
            continue

        for line in content.splitlines():
            line = line.strip()
            if not line or line.startswith(("!", "#")):
                continue

            domain = extract_domain(line)
            if not domain:
                continue

            if line.startswith("@@"):
                exception_domains.add(domain)
            else:
                if "$" not in line:
                    block_domains.add(domain)

    # 例外覆盖拦截
    final_domains = set()
    removed = 0
    for domain in block_domains:
        if domain in exception_domains:
            removed += 1
            continue
        final_domains.add(domain)

    sorted_domains = sorted(final_domains)
    bj_time = datetime.now(timezone(timedelta(hours=8))).strftime("%Y-%m-%d %H:%M:%S")

    # ==================== 生成 Clash Classical ====================
    clash_header = f"""# Title: Merged AdGuard Rules (me.txt + qy-Ads-Rule + Ads-Dns_Rule)
# Total rules: {len(sorted_domains)}
# Removed by exception: {removed}
# Update time: {bj_time} (UTC+8)
# Format: Clash Classical

payload:
"""
    clash_body = "\n".join(f"  - DOMAIN-SUFFIX,{d}" for d in sorted_domains)
    Path(CLASH_OUTPUT).write_text(clash_header + clash_body + "\n", encoding="utf-8")

    # ==================== 生成 AdGuard 格式 ====================
    adg_header = f"""[Adblock Plus 2.0]
! Title: Merged AdGuard Rules (me.txt + qy-Ads-Rule + Ads-Dns_Rule)
! Total rules: {len(sorted_domains)}
! Removed by exception: {removed}
! Update time: {bj_time} (UTC+8)
! Homepage: https://github.com/你的用户名/你的仓库名
! Expires: 2 hours

"""
    adg_body = "\n".join(f"||{d}^" for d in sorted_domains)
    Path(ADG_OUTPUT).write_text(adg_header + adg_body + "\n", encoding="utf-8")

    print(f"\n✅ Done!")
    print(f"Final rules: {len(sorted_domains)}")
    print(f"Removed by exception: {removed}")
    print(f"Clash 输出: {CLASH_OUTPUT}")
    print(f"AdGuard 输出: {ADG_OUTPUT}")

if __name__ == "__main__":
    main()