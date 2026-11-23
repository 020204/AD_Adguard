#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AdGuard 规则 → Clash Classical 规则集
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

OUTPUT_FILE = "merged-ads-clash-classical.yaml"

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
    block_rules = set()
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
                    block_rules.add(f"DOMAIN-SUFFIX,{domain}")

    # 例外覆盖拦截
    final_rules = set()
    removed = 0
    for rule in block_rules:
        domain = rule.split(",", 1)[1]
        if domain in exception_domains:
            removed += 1
            continue
        final_rules.add(rule)

    sorted_rules = sorted(final_rules)
    bj_time = datetime.now(timezone(timedelta(hours=8))).strftime("%Y-%m-%d %H:%M:%S")

    header = f"""# Title: Merged AdGuard Rules (me.txt + qy-Ads-Rule + Ads-Dns_Rule)
# Total rules: {len(sorted_rules)}
# Removed by exception: {removed}
# Update time: {bj_time} (UTC+8)
# Format: Clash Classical

payload:
"""

    body = "\n".join(f"  - {r}" for r in sorted_rules)
    Path(OUTPUT_FILE).write_text(header + body + "\n", encoding="utf-8")

    print(f"\n✅ Done! Final rules: {len(sorted_rules)}")
    print(f"Removed by exception: {removed}")
    print(f"Output: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()