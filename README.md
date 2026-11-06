# DevPorts

ローカルで起動している開発サーバー（Astro / Vite / Next.js など）をメニューバーから一覧・停止できる macOS アプリです。

「どのターミナルで `npm run dev` したか分からないサーバーが 3000 番台に溜まっている」を解消するための小さなツールです。

## 機能

- **一覧表示** — 指定したポート範囲で LISTEN しているプロセスを数秒ごとに検出
  - フレームワーク判定（Astro / Vite / Next.js / Nuxt / Remix / SvelteKit / Storybook / Gatsby / Angular / webpack / Wrangler / Rails / Django / Python / Node など）
  - プロジェクト名（作業ディレクトリ名）、ポート、PID、稼働時間、`dev` / `preview` などのモード
- **操作**
  - ポートをクリックして `http://localhost:<port>` をブラウザで開く
  - Finder で表示 / ターミナルで開く
  - 停止（SIGTERM → 3 秒以内に終了しなければ SIGKILL）
  - 右クリックで URL・パス・コマンド・PID のコピー、強制終了
  - すべて停止（誤操作防止のため 2 回クリック）
- **設定**
  - 監視するポート（例: `3000-3999, 4321, 5173-5174, 6006, 8787`）
  - 更新間隔（1 / 3 / 5 / 10 秒）
  - macOS のシステムプロセス（AirPlay レシーバーなど）を隠す
  - ログイン時に起動

## 動作環境

- macOS 14 Sonoma 以降
- Apple Silicon / Intel

## インストール

1. [Releases](https://github.com/min30327/DevPorts/releases) から `DevPorts-x.y.z.zip` をダウンロードして展開
2. `DevPorts.app` を `/Applications`（または `~/Applications`）に移動
3. 初回起動時の Gatekeeper 対応（後述）を行って起動

### 初回起動時の「開発元を確認できません」について

DevPorts は Apple の Developer ID 署名・公証を行っていないため、初回起動時にブロックされます。以下のどちらかで許可してください。

**方法 A: システム設定から許可**

1. `DevPorts.app` をダブルクリック（ブロックのダイアログが出たら「完了」で閉じる）
2. 「システム設定」→「プライバシーとセキュリティ」を開く
3. 下の方に表示される「"DevPorts" は開発元を確認できないため…」の **「このまま開く」** をクリック

**方法 B: ターミナルで隔離属性を外す**

```bash
xattr -dr com.apple.quarantine /Applications/DevPorts.app
```

## 使い方

起動するとメニューバーにアイコンと起動中サーバー数が表示されます。クリックで一覧を開きます。

| 操作 | 内容 |
|---|---|
| `:3000` などのポート表示をクリック | ブラウザで開く |
| 🧭 / 📁 ボタン | ブラウザで開く / Finder で表示 |
| 赤い停止ボタン | プロセスを停止 |
| 行を右クリック | コピー・ターミナルで開く・強制終了など |
| ⚙️ ボタン | 設定パネルを開閉 |
| `⌘Q` | アプリを終了 |

## ソースからビルド

Xcode または Command Line Tools（Swift 5.10 以降）が必要です。

```bash
git clone https://github.com/min30327/DevPorts.git
cd DevPorts

./build.sh            # build/DevPorts.app を作成
./build.sh --install  # ~/Applications にコピーして起動
./build.sh --dist     # Apple Silicon / Intel 両対応でビルドして build/DevPorts-<version>.zip を作成
```

検出結果をターミナルで確認するデバッグモードもあります。

```bash
build/DevPorts.app/Contents/MacOS/DevPorts --dump
```

## リリース手順

1. `VERSION` を更新してコミット
2. `./build.sh --dist`
3. GitHub で `v<version>` のリリースを作成し、`build/DevPorts-<version>.zip` を添付

## 仕組み

macOS 標準のコマンドだけを使っています。

| 目的 | コマンド |
|---|---|
| LISTEN 中のソケット列挙 | `lsof -nP -iTCP -sTCP:LISTEN` |
| 起動コマンド・経過時間 | `ps -ww -o pid=,etime=,command=` |
| 作業ディレクトリ | `lsof -a -p <pid> -d cwd` |
| 停止 | `kill(2)`（SIGTERM / SIGKILL） |

自分のユーザーで起動したプロセスのみ停止できます。プロセスを操作する性質上、App Sandbox 下では動作しないため Mac App Store では配布していません。

## ファイル構成

```
Sources/DevPorts/
├── DevPortsApp.swift   # エントリポイント、メニューバー（NSStatusItem / NSPopover）
├── ContentView.swift   # ポップオーバーの UI
├── PortMonitor.swift   # 定期スキャン・停止などの状態管理
├── PortScanner.swift   # lsof / ps の実行と解析
└── Models.swift        # DevServer モデル、フレームワーク判定
```
