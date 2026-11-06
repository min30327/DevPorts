#!/usr/bin/env python3
"""Simple Icons (CC0) からフレームワークのロゴを取得し、Sources/DevPorts/BrandIcons.swift を生成する。

使い方:
    python3 scripts/update-brand-icons.py

ロゴを追加するときは ICONS に「Framework の case 名: Simple Icons のスラッグ」を追加して再実行する。
スラッグは https://simpleicons.org/ で確認できる。
"""
from __future__ import annotations

import re
import sys
import urllib.request
from pathlib import Path

ICONS = {
    "astro": "astro",
    "vite": "vite",
    "next": "nextdotjs",
    "nuxt": "nuxt",
    "remix": "remix",
    "sveltekit": "svelte",
    "storybook": "storybook",
    "gatsby": "gatsby",
    "angular": "angular",
    "webpack": "webpack",
    "reactScripts": "createreactapp",
    "wrangler": "cloudflare",
    "vercel": "vercel",
    "firebase": "firebase",
    "rails": "rubyonrails",
    "django": "django",
    "python": "python",
    "php": "php",
    "bun": "bun",
    "deno": "deno",
    "node": "nodedotjs",
}

BASE = "https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/{}.svg"
OUT = Path(__file__).resolve().parent.parent / "Sources/DevPorts/BrandIcons.swift"
PATH_RE = re.compile(r'<path d="([^"]+)"')
SAFE_RE = re.compile(r"^[0-9A-Za-z .,\-]+$")


def fetch(slug: str) -> str | None:
    try:
        with urllib.request.urlopen(BASE.format(slug), timeout=15) as res:
            svg = res.read().decode()
    except Exception as e:  # noqa: BLE001
        print(f"  skip {slug}: {e}", file=sys.stderr)
        return None
    m = PATH_RE.search(svg)
    if not m or not SAFE_RE.match(m.group(1)):
        print(f"  skip {slug}: unexpected SVG content", file=sys.stderr)
        return None
    return m.group(1)


def main() -> None:
    entries = []
    for case, slug in ICONS.items():
        d = fetch(slug)
        if d:
            entries.append(f'        .{case}: "{d}",')
            print(f"  ok   {case} ({slug})")

    OUT.write_text(
        "// このファイルは scripts/update-brand-icons.py で生成しています。直接編集しないでください。\n"
        "// ロゴ: Simple Icons (https://simpleicons.org/) — CC0 1.0。各ロゴは各社・各団体の商標です。\n"
        "\n"
        "import AppKit\n"
        "\n"
        "enum BrandIcons {\n"
        "    /// 24x24 viewBox の SVG パス\n"
        "    static let paths: [Framework: String] = [\n"
        + "\n".join(entries)
        + "\n    ]\n"
        "\n"
        "    private static var cache: [Framework: NSImage] = [:]\n"
        "\n"
        "    /// テンプレート画像（色は表示側で付ける）として返す\n"
        "    @MainActor\n"
        "    static func image(for framework: Framework) -> NSImage? {\n"
        "        if let cached = cache[framework] { return cached }\n"
        "        guard let d = paths[framework] else { return nil }\n"
        '        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d=""# + d + #""/></svg>"#\n'
        "        guard let image = NSImage(data: Data(svg.utf8)) else { return nil }\n"
        "        image.isTemplate = true\n"
        "        cache[framework] = image\n"
        "        return image\n"
        "    }\n"
        "}\n"
    )
    print(f"wrote {OUT.relative_to(Path.cwd()) if OUT.is_relative_to(Path.cwd()) else OUT} ({len(entries)} icons)")


if __name__ == "__main__":
    main()
