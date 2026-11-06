import SwiftUI

/// 検出したフレームワーク / ランタイム
enum Framework: String, CaseIterable, Sendable {
    case astro, vite, next, nuxt, remix, sveltekit, storybook, gatsby, angular
    case webpack, reactScripts, parcel, wrangler, vercel, firebase
    case rails, django, python, php, bun, deno, node, other

    var displayName: String {
        switch self {
        case .astro: "Astro"
        case .vite: "Vite"
        case .next: "Next.js"
        case .nuxt: "Nuxt"
        case .remix: "Remix"
        case .sveltekit: "SvelteKit"
        case .storybook: "Storybook"
        case .gatsby: "Gatsby"
        case .angular: "Angular"
        case .webpack: "webpack"
        case .reactScripts: "CRA"
        case .parcel: "Parcel"
        case .wrangler: "Wrangler"
        case .vercel: "Vercel"
        case .firebase: "Firebase"
        case .rails: "Rails"
        case .django: "Django"
        case .python: "Python"
        case .php: "PHP"
        case .bun: "Bun"
        case .deno: "Deno"
        case .node: "Node"
        case .other: "Other"
        }
    }

    var color: Color {
        switch self {
        case .astro: Color(red: 1.00, green: 0.36, blue: 0.00)
        case .vite: Color(red: 0.58, green: 0.36, blue: 1.00)
        case .next: Color.primary
        case .nuxt: Color(red: 0.00, green: 0.86, blue: 0.51)
        case .remix: Color(red: 0.20, green: 0.55, blue: 1.00)
        case .sveltekit: Color(red: 1.00, green: 0.24, blue: 0.00)
        case .storybook: Color(red: 1.00, green: 0.28, blue: 0.52)
        case .gatsby: Color(red: 0.40, green: 0.20, blue: 0.60)
        case .angular: Color(red: 0.87, green: 0.00, blue: 0.19)
        case .webpack: Color(red: 0.55, green: 0.84, blue: 0.98)
        case .reactScripts: Color(red: 0.38, green: 0.85, blue: 0.98)
        case .parcel: Color(red: 0.85, green: 0.65, blue: 0.30)
        case .wrangler: Color(red: 0.96, green: 0.51, blue: 0.13)
        case .vercel, .deno: Color.primary
        case .firebase: Color(red: 1.00, green: 0.76, blue: 0.03)
        case .rails: Color(red: 0.80, green: 0.00, blue: 0.00)
        case .django: Color(red: 0.05, green: 0.42, blue: 0.29)
        case .python: Color(red: 0.22, green: 0.46, blue: 0.69)
        case .php: Color(red: 0.47, green: 0.48, blue: 0.70)
        case .bun: Color(red: 0.98, green: 0.85, blue: 0.70)
        case .node: Color(red: 0.33, green: 0.62, blue: 0.24)
        case .other: Color.gray
        }
    }

    /// バッジに表示する短い文字
    var badge: String {
        switch self {
        case .reactScripts: "CR"
        case .sveltekit: "SK"
        case .storybook: "SB"
        case .wrangler: "CF"
        case .other: "?"
        default: String(displayName.prefix(1)).uppercased()
        }
    }

    /// コマンドラインからフレームワークを推定する（順序が重要：具体的なものから先に判定）
    static func detect(command: String, processName: String) -> Framework {
        let c = command.lowercased()
        func has(_ needles: String...) -> Bool { needles.contains { c.contains($0) } }

        if has("storybook") { return .storybook }
        if has("/astro/", "astro dev", "astro preview", "astro.js") { return .astro }
        if has("/nuxt/", "/nuxi/", "nuxt dev", "nuxi dev") { return .nuxt }
        if has("/next/", "next dev", "next start", "next-server", "next-router-worker") { return .next }
        if has("/@remix-run/", "remix dev", "remix-serve") { return .remix }
        if has("/@sveltejs/kit", "svelte-kit") { return .sveltekit }
        if has("/gatsby/", "gatsby develop") { return .gatsby }
        if has("/@angular/cli", "ng serve") { return .angular }
        if has("/vite/", "vite.js", "vite dev", "vite preview") { return .vite }
        if has("react-scripts") { return .reactScripts }
        if has("webpack") { return .webpack }
        if has("/parcel/", "parcel ") { return .parcel }
        if has("wrangler") { return .wrangler }
        if has("vercel") { return .vercel }
        if has("firebase") { return .firebase }
        if has("rails ", "puma", "/rails") { return .rails }
        if has("manage.py runserver") { return .django }
        if has("python", "uvicorn", "gunicorn", "flask") { return .python }
        if has("php") { return .php }

        let p = processName.lowercased()
        if p == "bun" || has("/bun ") { return .bun }
        if p == "deno" { return .deno }
        if p == "node" || has("/node ") { return .node }
        return .other
    }
}

/// LISTEN しているサーバープロセス 1 つ分
struct DevServer: Identifiable, Hashable, Sendable {
    let pid: Int32
    let ports: [Int]
    let processName: String
    let command: String
    let cwd: String?
    let elapsedSeconds: Int?
    let framework: Framework
    /// "dev" / "preview" / "start" など
    let mode: String?

    var id: Int32 { pid }
    var primaryPort: Int { ports.first ?? 0 }
    var url: URL { URL(string: "http://localhost:\(primaryPort)")! }

    var projectName: String {
        guard let cwd, cwd != "/" else { return processName }
        return (cwd as NSString).lastPathComponent
    }

    /// ~ 表記にした作業ディレクトリ
    var displayPath: String? {
        guard let cwd else { return nil }
        let home = NSHomeDirectory()
        return cwd.hasPrefix(home) ? "~" + cwd.dropFirst(home.count) : cwd
    }

    var elapsedText: String {
        guard let s = elapsedSeconds else { return "" }
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "\(d)日\(h)時間" }
        if h > 0 { return "\(h)時間\(m)分" }
        if m > 0 { return "\(m)分" }
        return "\(s)秒"
    }
}
