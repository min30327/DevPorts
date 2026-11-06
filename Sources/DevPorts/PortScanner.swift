import Foundation

/// "3000-3999, 4321, 5173-5174" のような文字列をポート範囲に変換する
enum PortRanges {
    static let defaultText = "3000-3999, 4321, 5173-5174, 6006, 8787"

    static func parse(_ text: String) -> [ClosedRange<Int>] {
        text.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .compactMap { token -> ClosedRange<Int>? in
                let parts = token.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                switch parts.count {
                case 1:
                    guard let p = Int(parts[0]), (1...65535).contains(p) else { return nil }
                    return p...p
                case 2:
                    guard let a = Int(parts[0]), let b = Int(parts[1]),
                          (1...65535).contains(a), (1...65535).contains(b) else { return nil }
                    return min(a, b)...max(a, b)
                default:
                    return nil
                }
            }
    }
}

enum Shell {
    /// コマンドを同期実行して標準出力を返す（失敗時は空文字）
    static func run(_ path: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}

enum PortScanner {
    struct Options: Sendable {
        var ranges: [ClosedRange<Int>]
        var hideSystemProcesses: Bool
    }

    static func scan(_ options: Options) -> [DevServer] {
        // 1. LISTEN 中の TCP ソケットを列挙
        let lsofOut = Shell.run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"])
        var ports: [Int32: Set<Int>] = [:]
        var names: [Int32: String] = [:]
        var currentPID: Int32?
        for line in lsofOut.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = line.dropFirst()
            switch tag {
            case "p": currentPID = Int32(value)
            case "c": if let pid = currentPID { names[pid] = String(value) }
            case "n":
                guard let pid = currentPID,
                      let colon = value.lastIndex(of: ":"),
                      let port = Int(value[value.index(after: colon)...]),
                      options.ranges.contains(where: { $0.contains(port) })
                else { continue }
                ports[pid, default: []].insert(port)
            default: break
            }
        }
        guard !ports.isEmpty else { return [] }
        let pidList = ports.keys.map(String.init).joined(separator: ",")

        // 2. 起動コマンドと経過時間
        var commands: [Int32: (elapsed: Int?, command: String)] = [:]
        let psOut = Shell.run("/bin/ps", ["-ww", "-o", "pid=,etime=,command=", "-p", pidList])
        for line in psOut.split(separator: "\n") {
            let cols = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard cols.count == 3, let pid = Int32(cols[0]) else { continue }
            commands[pid] = (parseEtime(String(cols[1])), String(cols[2]))
        }

        // 3. 作業ディレクトリ
        var cwds: [Int32: String] = [:]
        currentPID = nil
        let cwdOut = Shell.run("/usr/sbin/lsof", ["-a", "-p", pidList, "-d", "cwd", "-Fpn"])
        for line in cwdOut.split(separator: "\n") {
            if line.hasPrefix("p") { currentPID = Int32(line.dropFirst()) }
            else if line.hasPrefix("n"), let pid = currentPID { cwds[pid] = String(line.dropFirst()) }
        }

        // 4. 組み立て
        return ports.compactMap { pid, portSet -> DevServer? in
            let name = names[pid] ?? "?"
            let cmd = commands[pid]?.command ?? name
            let cwd = cwds[pid]
            if options.hideSystemProcesses && isSystemProcess(command: cmd, cwd: cwd) { return nil }
            let framework = Framework.detect(command: cmd, processName: name)
            var mode = detectMode(cmd)
            if mode == nil, [.vite, .astro, .nuxt].contains(framework) { mode = "dev" }
            return DevServer(
                pid: pid,
                ports: portSet.sorted(),
                processName: name,
                command: cmd,
                cwd: cwd,
                elapsedSeconds: commands[pid]?.elapsed,
                framework: framework,
                mode: mode
            )
        }
        .sorted { $0.primaryPort < $1.primaryPort }
    }

    /// macOS 標準のデーモン（AirPlay レシーバーなど）を除外する
    private static func isSystemProcess(command: String, cwd: String?) -> Bool {
        let systemPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/Library/Apple/"]
        if systemPrefixes.contains(where: { command.hasPrefix($0) }) { return true }
        return cwd == "/" && !command.contains("node") && !command.contains("python")
    }

    private static func detectMode(_ command: String) -> String? {
        let args = command.split(separator: " ").map { $0.lowercased() }
        for mode in ["dev", "develop", "preview", "start", "serve", "storybook"] where args.contains(mode) {
            return mode
        }
        return nil
    }

    /// ps の etime（[[dd-]hh:]mm:ss）を秒に変換
    static func parseEtime(_ s: String) -> Int? {
        var days = 0
        var rest = Substring(s)
        if let dash = rest.firstIndex(of: "-") {
            days = Int(rest[..<dash]) ?? 0
            rest = rest[rest.index(after: dash)...]
        }
        let parts = rest.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        return days * 86400 + seconds
    }
}
