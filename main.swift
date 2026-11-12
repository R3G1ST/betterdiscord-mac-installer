import Cocoa
import SwiftUI
import Combine
import Darwin

// MARK: - Ошибки

struct BDError: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

// MARK: - Пути и окружение

let fm = FileManager.default
let home = fm.homeDirectoryForCurrentUser
let supportRoot = home.appendingPathComponent("Library/Application Support", isDirectory: true)

let bdRoot = supportRoot.appendingPathComponent("BetterDiscord", isDirectory: true)
let bdData = bdRoot.appendingPathComponent("data", isDirectory: true)
let bdAsar = bdData.appendingPathComponent("betterdiscord.asar")

let channelNames = ["Discord", "Discord PTB", "Discord Canary"]
let supportNames = ["discord", "discordptb", "discordcanary"]

var logger: (String) -> Void = { print($0) }
func log(_ s: String) { logger(s) }

func discordAppURLs() -> [URL] {
    var out: [URL] = []
    for name in channelNames {
        let candidates = [
            URL(fileURLWithPath: "/Applications/\(name).app"),
            home.appendingPathComponent("Applications/\(name).app")
        ]
        for c in candidates where fm.fileExists(atPath: c.path) {
            out.append(c)
        }
    }
    return out
}

func supportDirs() -> [URL] {
    supportNames
        .map { supportRoot.appendingPathComponent($0, isDirectory: true) }
        .filter { fm.fileExists(atPath: $0.path) }
}

func isPermissionError(_ error: Error) -> Bool {
    let error = error as NSError
    if error.domain == NSCocoaErrorDomain {
        return error.code == NSFileReadNoPermissionError
    }
    if error.domain == NSPOSIXErrorDomain {
        return error.code == Int(EPERM) || error.code == Int(EACCES)
    }
    return false
}

enum DiscordDataAccess {
    static var lastError: Error?
    static var denied: Bool { lastError.map(isPermissionError) ?? false }
}

func coreIndexFiles() -> [URL] {
    var result: [URL] = []
    DiscordDataAccess.lastError = nil

    // Не фильтруем через fileExists: macOS 26 App Data может запрещать даже stat,
    // а нам нужно отличить «папки нет» от «нет доступа».
    let dirs = supportNames.map { supportRoot.appendingPathComponent($0, isDirectory: true) }

    for dir in dirs {
        do {
            let versions = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            for v in versions where v.lastPathComponent.hasPrefix("app-") {
                let modsDir = v.appendingPathComponent("modules", isDirectory: true)
                do {
                    let mods = try fm.contentsOfDirectory(at: modsDir, includingPropertiesForKeys: nil)
                    for m in mods where m.lastPathComponent.hasPrefix("discord_desktop_core") {
                        let idx = m
                            .appendingPathComponent("discord_desktop_core", isDirectory: true)
                            .appendingPathComponent("index.js")
                        if fm.fileExists(atPath: idx.path) { result.append(idx) }
                    }
                } catch {
                    if isPermissionError(error) { DiscordDataAccess.lastError = error }
                }
            }
        } catch {
            if isPermissionError(error) { DiscordDataAccess.lastError = error }
        }
    }
    return result
}

func isPatched(_ idx: URL) -> Bool {
    (try? String(contentsOf: idx, encoding: .utf8))?
        .contains("BetterDiscord/data/betterdiscord.asar") ?? false
}

func jsEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
}

func discordVersion() -> String {
    for dir in supportDirs() {
        if let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil),
           let v = items.first(where: { $0.lastPathComponent.hasPrefix("app-") }) {
            return String(v.lastPathComponent.dropFirst(4))
        }
    }
    return "?"
}

func statusText() -> String {
    let idxs = coreIndexFiles()
    if DiscordDataAccess.denied {
        return "Нет доступа к папке Discord. Нужен Full Disk Access для BetterDiscord Installer."
    }
    if idxs.isEmpty {
        return "Discord ещё не запускался. Запустите его один раз и закройте — потом нажмите «Установить»."
    }
    if idxs.contains(where: isPatched) {
        return "BetterDiscord подключён."
    }
    return "BetterDiscord не подключён."
}

// MARK: - Процессы Discord

func runningDiscordBundles() -> [URL] {
    let known = Set(discordAppURLs().map { $0.standardizedFileURL.path })
    var out: [URL] = []
    for app in NSWorkspace.shared.runningApplications {
        guard let url = app.bundleURL?.standardizedFileURL else { continue }
        if known.contains(url.path), !out.contains(where: { $0.path == url.path }) {
            out.append(url)
        }
    }
    return out
}

@discardableResult
func quitDiscord() -> [URL] {
    let running = runningDiscordBundles()
    guard !running.isEmpty else {
        log("Discord не запущен")
        return []
    }

    log("Закрываю Discord…")
    let known = Set(running.map { $0.standardizedFileURL.path })
    let apps = NSWorkspace.shared.runningApplications.filter { app in
        guard let url = app.bundleURL?.standardizedFileURL else { return false }
        return known.contains(url.path)
    }

    for app in apps { app.terminate() }

    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline {
        if apps.allSatisfy({ $0.isTerminated }) { break }
        usleep(200_000)
    }

    for app in apps where !app.isTerminated {
        app.forceTerminate()
    }
    usleep(500_000)

    log("Discord закрыт")
    return running
}

func relaunchDiscord(_ urls: [URL]) {
    var targets = urls
    if targets.isEmpty {
        targets = Array(discordAppURLs().prefix(1))
    }
    guard !targets.isEmpty else { return }

    log("Запускаю Discord…")
    for url in targets {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = [url.path]
        try? p.run()
        p.waitUntilExit()
    }
}

// MARK: - Установка / удаление

func ensureBDAsar() throws {
    try fm.createDirectory(at: bdData, withIntermediateDirectories: true)
    try fm.createDirectory(at: bdRoot.appendingPathComponent("plugins", isDirectory: true), withIntermediateDirectories: true)
    try fm.createDirectory(at: bdRoot.appendingPathComponent("themes", isDirectory: true), withIntermediateDirectories: true)

    // BetterDiscord 1.14.5 (stable) не инициализируется на Discord 0.0.421.
    // Canary 1.14.6+ это исправляет, поэтому сначала пробуем development-сборку.
    let urls = [
        "https://github.com/BetterDiscord/BetterDiscord/releases/download/canary/betterdiscord.asar",
        "https://github.com/BetterDiscord/BetterDiscord/releases/latest/download/betterdiscord.asar"
    ]
    let tmp = bdData.appendingPathComponent("betterdiscord.asar.tmp")
    var lastError = ""

    for url in urls {
        try? fm.removeItem(at: tmp)
        log("Скачиваю BetterDiscord…")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-fL", "--retry", "3", "--max-time", "120", "-o", tmp.path, url]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            lastError = error.localizedDescription
            continue
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus == 0,
           let attrs = try? fm.attributesOfItem(atPath: tmp.path),
           let size = attrs[.size] as? NSNumber,
           size.intValue > 100_000 {
            try? fm.removeItem(at: bdAsar)
            try fm.moveItem(at: tmp, to: bdAsar)
            log("BetterDiscord обновлён (\(size.intValue) байт)")
            return
        }

        lastError = String(data: data, encoding: .utf8) ?? "curl exit \(process.terminationStatus)"
    }

    if fm.fileExists(atPath: bdAsar.path) {
        log("Не удалось обновить BetterDiscord, использую текущую версию")
        return
    }

    throw BDError("Не удалось скачать betterdiscord.asar.\n\(lastError)")
}

struct InstallResult {
    let patched: Int
    let already: Int
    let total: Int
}

func installBD() throws -> InstallResult {
    guard !discordAppURLs().isEmpty else {
        throw BDError("Discord не найден в /Applications.")
    }

    let running = quitDiscord()
    try ensureBDAsar()

    let idxs = coreIndexFiles()
    guard !idxs.isEmpty else {
        if DiscordDataAccess.denied {
            throw BDError("Нет доступа к папке Discord.\nВыдайте Full Disk Access приложению BetterDiscord Installer и перезапустите его.")
        }
        throw BDError("Не найден core-модуль Discord.\nЗапустите Discord один раз, закройте и повторите.")
    }

    var patched = 0
    var already = 0

    for idx in idxs {
        if isPatched(idx) {
            already += 1
            log("Уже подключено: \(idx.deletingLastPathComponent().path)")
            continue
        }

        let orig = idx.appendingPathExtension("orig")
        if !fm.fileExists(atPath: orig.path) {
            try fm.copyItem(at: idx, to: orig)
        }

        let js = "require(\"\(jsEscape(bdAsar.path))\");\n" +
                 "module.exports = require(\"./core.asar\");\n"
        try js.write(to: idx, atomically: true, encoding: .utf8)
        patched += 1
        log("Подключено: \(idx.deletingLastPathComponent().path)")
    }

    relaunchDiscord(running)
    return InstallResult(patched: patched, already: already, total: idxs.count)
}

func uninstallBD() throws -> Int {
    let running = quitDiscord()
    let idxs = coreIndexFiles()
    guard !idxs.isEmpty else {
        if DiscordDataAccess.denied {
            throw BDError("Нет доступа к папке Discord.\nВыдайте Full Disk Access приложению BetterDiscord Installer и перезапустите его.")
        }
        throw BDError("Не найден core-модуль Discord.")
    }

    var restored = 0
    for idx in idxs {
        let orig = idx.appendingPathExtension("orig")
        if fm.fileExists(atPath: orig.path) {
            try? fm.removeItem(at: idx)
            try fm.copyItem(at: orig, to: idx)
            restored += 1
            log("Отключено: \(idx.deletingLastPathComponent().path)")
        } else if isPatched(idx) {
            try "module.exports = require('./core.asar');\n"
                .write(to: idx, atomically: true, encoding: .utf8)
            restored += 1
            log("Отключено: \(idx.deletingLastPathComponent().path)")
        }
    }

    relaunchDiscord(running)
    return restored
}

// MARK: - Автовосстановление (LaunchAgent)

@discardableResult
func runProcess(_ path: String, _ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    p.standardOutput = Pipe()
    p.standardError = Pipe()
    do { try p.run() } catch { return -1 }
    p.waitUntilExit()
    return p.terminationStatus
}

enum AutoRepair {
    static let label = "app.betterdiscord.installer.autorepair"

    static var launchAgentURL: URL {
        home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    static var scriptURL: URL {
        bdRoot.appendingPathComponent("auto-repair.sh")
    }
    static var logURL: URL {
        bdRoot.appendingPathComponent("auto-repair.log")
    }

    static var isEnabled: Bool {
        fm.fileExists(atPath: launchAgentURL.path)
    }

    static let script = #"""
#!/bin/bash
# Автовосстановление BetterDiscord после обновлений Discord.
# 1) Раз в 6 часов обновляет BetterDiscord Canary (1.14.6+) — стабильный 1.14.5
#    не инициализируется на Discord 0.0.421.
# 2) Передаёт работу приложению: у него есть Full Disk Access для папки Discord.
set -u

APP="/Applications/BetterDiscord Installer.app"
BD="$HOME/Library/Application Support/BetterDiscord"
ASAR="$BD/data/betterdiscord.asar"
LOG="$BD/auto-repair.log"
STAMP="$BD/.canary-check"
NOW="$(/bin/date +%s)"
LAST=0
CHANGED=0

[ -f "$STAMP" ] && LAST="$(/usr/bin/stat -f %m "$STAMP" 2>/dev/null || echo 0)"

if [ $((NOW - LAST)) -gt 1800 ]; then
  /usr/bin/touch "$STAMP"
  REMOTE="$(/usr/bin/curl -fsIL --max-time 20 \
    "https://github.com/BetterDiscord/BetterDiscord/releases/download/canary/betterdiscord.asar" \
    | /usr/bin/awk 'tolower($1)=="content-length:" {v=$2} END {gsub("\r","",v); print v}')"
  LOCAL="$(/usr/bin/stat -f %z "$ASAR" 2>/dev/null || echo 0)"

  if [ -n "$REMOTE" ] && [ "$REMOTE" != "$LOCAL" ]; then
    if /usr/bin/curl -fL --retry 3 --max-time 120 -o "$ASAR.tmp" \
      "https://github.com/BetterDiscord/BetterDiscord/releases/download/canary/betterdiscord.asar"; then
      /bin/mv "$ASAR.tmp" "$ASAR"
      CHANGED=1
      echo "$(/bin/date '+%Y-%m-%d %H:%M:%S') canary-asar updated $LOCAL -> $REMOTE" >> "$LOG"
    else
      /bin/rm -f "$ASAR.tmp"
    fi
  fi
fi

if [ -d "$APP" ]; then
  /usr/bin/open -g -j -n -a "$APP" --args --auto-repair
else
  echo "$(/bin/date '+%Y-%m-%d %H:%M:%S') app-not-found: $APP" >> "$LOG"
fi

# Если обновился asar — перезапускаем Discord, чтобы он подхватил новую версию.
if [ "$CHANGED" -eq 1 ] && /usr/bin/pgrep -x Discord >/dev/null 2>&1; then
  /bin/sleep 3
  /usr/bin/pkill -x Discord 2>/dev/null
  /bin/sleep 2
  /usr/bin/open "/Applications/Discord.app" 2>/dev/null
fi
"""#

    static func enable() throws {
        try fm.createDirectory(at: bdRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: launchAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/bin/bash", scriptURL.path],
            "RunAtLoad": true,
            "StartInterval": 120,
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path,
            "ProcessType": "Background"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: launchAgentURL)

        let uid = getuid()
        _ = runProcess("/bin/launchctl", ["bootout", "gui/\(uid)/\(label)"])
        let r = runProcess("/bin/launchctl", ["bootstrap", "gui/\(uid)", launchAgentURL.path])
        if r != 0 {
            _ = runProcess("/bin/launchctl", ["load", "-w", launchAgentURL.path])
        }
    }

    static func disable() {
        let uid = getuid()
        _ = runProcess("/bin/launchctl", ["bootout", "gui/\(uid)/\(label)"])
        try? fm.removeItem(at: launchAgentURL)
        try? fm.removeItem(at: scriptURL)
    }
}

// MARK: - Автовосстановление (выполняется приложением с Full Disk Access)

func autoRepairLog(_ line: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let text = "\(formatter.string(from: Date())) \(line)\n"
    try? fm.createDirectory(at: bdRoot, withIntermediateDirectories: true)
    let url = bdRoot.appendingPathComponent("auto-repair.log")
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(text.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

func autoRepairIfNeeded() throws -> Int {
    let idxs = coreIndexFiles()

    if idxs.isEmpty {
        if DiscordDataAccess.denied {
            autoRepairLog("no-access: Full Disk Access required")
        } else {
            autoRepairLog("no-core: Discord is not launched")
        }
        return 0
    }

    if idxs.allSatisfy(isPatched) {
        autoRepairLog("ok: already patched")
        return 0
    }

    let result = try installBD()
    autoRepairLog("patched=\(result.patched) already=\(result.already)")
    return result.patched
}

// MARK: - CLI-режим (для тестов)

let arguments = CommandLine.arguments

if arguments.contains("--cli-status") {
    print(statusText())
    exit(0)
}

if arguments.contains("--cli-install") {
    do {
        let r = try installBD()
        print("OK patched=\(r.patched) already=\(r.already) total=\(r.total)")
        exit(0)
    } catch {
        print("ERROR: \(error.localizedDescription)")
        exit(1)
    }
}

if arguments.contains("--cli-remove") {
    do {
        let n = try uninstallBD()
        print("OK restored=\(n)")
        exit(0)
    } catch {
        print("ERROR: \(error.localizedDescription)")
        exit(1)
    }
}

if arguments.contains("--auto-repair") {
    do {
        let n = try autoRepairIfNeeded()
        print("OK patched=\(n)")
        exit(0)
    } catch {
        autoRepairLog("error: \(error.localizedDescription)")
        print("ERROR: \(error.localizedDescription)")
        exit(1)
    }
}

if arguments.contains("--cli-enable-autorepair") {
    do {
        try AutoRepair.enable()
        print("OK auto-repair enabled")
        exit(0)
    } catch {
        print("ERROR: \(error.localizedDescription)")
        exit(1)
    }
}

if arguments.contains("--cli-disable-autorepair") {
    AutoRepair.disable()
    print("OK auto-repair disabled")
    exit(0)
}

// MARK: - Модель

final class AppModel: ObservableObject {
    enum Kind: Equatable {
        case ok, idle, error, busy
    }

    @Published var kind: Kind = .idle
    @Published var title = "Проверяю…"
    @Published var detail = ""
    @Published var busy = false
    @Published var showLog = false
    @Published var logText = ""
    @Published var autoRepair = true
    @Published var success = false
    @Published var appeared = false
    @Published var needsPermission = false

    func start() {
        logger = { [weak self] line in
            self?.appendLog(line)
        }

        let pref = UserDefaults.standard.object(forKey: "autoRepair") as? Bool ?? true
        autoRepair = pref || AutoRepair.isEnabled
        refresh()

        if autoRepair && coreIndexFiles().contains(where: isPatched) && !AutoRepair.isEnabled {
            try? AutoRepair.enable()
            autoRepair = AutoRepair.isEnabled
            if kind == .ok { refreshDetail() }
        }
    }

    func refresh() {
        if discordAppURLs().isEmpty {
            kind = .error
            title = "Discord не найден"
            detail = "Установите Discord в /Applications"
            return
        }

        let idxs = coreIndexFiles()
        if DiscordDataAccess.denied {
            kind = .error
            title = "Нет доступа к папке Discord"
            detail = "Выдайте Full Disk Access приложению BetterDiscord Installer, затем перезапустите его"
            needsPermission = true
            return
        }
        needsPermission = false

        if idxs.isEmpty {
            kind = .error
            title = "Discord ещё не запускался"
            detail = "Запустите Discord один раз, закройте и откройте это приложение снова"
            return
        }

        if idxs.contains(where: isPatched) {
            kind = .ok
            title = "BetterDiscord подключён"
            refreshDetail()
        } else {
            kind = .idle
            title = "BetterDiscord не подключён"
            detail = "Нажмите «Установить» — и всё будет готово"
        }
    }

    func refreshDetail() {
        detail = "Discord \(discordVersion()) · автовосстановление \(autoRepair ? "включено" : "выключено")"
    }

    func appendLog(_ line: String) {
        let action = { [weak self] in
            guard let self else { return }
            self.logText += (self.logText.isEmpty ? "" : "\n") + line
            if self.logText.count > 20_000 {
                self.logText = String(self.logText.suffix(20_000))
            }
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    func install() {
        guard !busy, !needsPermission else { return }
        let auto = true

        busy = true
        kind = .busy
        title = "Устанавливаю BetterDiscord…"
        detail = "Discord будет перезапущен"
        logText = ""
        success = false

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let r = try installBD()
                if auto { try? AutoRepair.enable() }
                DispatchQueue.main.async {
                    self.busy = false
                    self.needsPermission = false
                    self.autoRepair = AutoRepair.isEnabled
                    self.kind = .ok
                    self.title = r.patched > 0
                        ? "Готово — BetterDiscord подключён"
                        : "BetterDiscord уже был подключён"
                    self.refreshDetail()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                        self.success = true
                    }
                    self.appendLog("Готово: patched=\(r.patched), already=\(r.already)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.busy = false
                    self.kind = .error
                    if DiscordDataAccess.denied {
                        self.needsPermission = true
                        self.title = "Нужен Full Disk Access"
                        self.detail = "Разрешите доступ приложению BetterDiscord Installer и перезапустите его"
                    } else {
                        self.title = "Ошибка установки"
                        self.detail = error.localizedDescription
                    }
                    self.appendLog("Ошибка: \(error.localizedDescription)")
                }
            }
        }
    }

    func remove() {
        guard !busy else { return }
        let wasAuto = autoRepair

        busy = true
        kind = .busy
        title = "Отключаю BetterDiscord…"
        detail = "Discord будет перезапущен"
        logText = ""

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let n = try uninstallBD()
                if wasAuto {
                    AutoRepair.disable()
                    UserDefaults.standard.set(false, forKey: "autoRepair")
                }
                DispatchQueue.main.async {
                    self.busy = false
                    self.kind = .idle
                    self.success = false
                    self.autoRepair = false
                    self.title = n > 0 ? "BetterDiscord отключён" : "BetterDiscord не был подключён"
                    self.detail = "Плагины и темы сохранены · автовосстановление выключено"
                    self.appendLog("Отключено модулей: \(n)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.busy = false
                    self.kind = .error
                    if DiscordDataAccess.denied {
                        self.needsPermission = true
                        self.title = "Нужен Full Disk Access"
                        self.detail = "Разрешите доступ приложению BetterDiscord Installer и перезапустите его"
                    } else {
                        self.title = "Ошибка"
                        self.detail = error.localizedDescription
                    }
                    self.appendLog("Ошибка: \(error.localizedDescription)")
                }
            }
        }
    }

    func setAutoRepair(_ on: Bool) {
        autoRepair = on
        UserDefaults.standard.set(on, forKey: "autoRepair")

        if on {
            do {
                try AutoRepair.enable()
                appendLog("Автовосстановление включено")
            } catch {
                appendLog("Автовосстановление: \(error.localizedDescription)")
                autoRepair = false
                UserDefaults.standard.set(false, forKey: "autoRepair")
            }
        } else {
            AutoRepair.disable()
            appendLog("Автовосстановление выключено")
        }

        if kind == .ok { refreshDetail() }
    }

    func openFullDiskAccess() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func restartApp() {
        let path = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", path]
        try? process.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NSApp.terminate(nil)
        }
    }

    func recheckAccess() {
        refresh()
    }
}

// MARK: - Цвета

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Компоненты

struct AnimatedBackground: View {
    @State private var phase = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x070A16), Color(hex: 0x111632), Color(hex: 0x070A16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0x2563EB).opacity(0.34), .clear],
                    center: .center, startRadius: 0, endRadius: 260
                ))
                .frame(width: 540, height: 540)
                .blur(radius: 70)
                .offset(x: phase ? -180 : -120, y: phase ? -200 : -150)

            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0x7C3AED).opacity(0.26), .clear],
                    center: .center, startRadius: 0, endRadius: 240
                ))
                .frame(width: 500, height: 500)
                .blur(radius: 80)
                .offset(x: phase ? 210 : 160, y: phase ? 210 : 160)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }
}

struct LogoView: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0x6FA8FF), Color(hex: 0x1D4ED8)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color(hex: 0x3B82F6).opacity(glow ? 0.65 : 0.3),
                        radius: glow ? 22 : 12, y: 8)

            Text("BD")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 74, height: 74)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

struct StatusDot: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: 20, height: 20)
                .scaleEffect(pulse ? 1.5 : 0.7)
                .opacity(pulse ? 0 : 0.9)
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .shadow(color: color.opacity(0.8), radius: 6)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(hover ? .white : .white.opacity(0.72))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(hover ? 0.12 : 0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(hover ? 0.18 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { value in
            withAnimation(.easeOut(duration: 0.15)) { hover = value }
        }
    }
}

struct FeaturePill: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.62))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

struct ContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Интерфейс

struct ContentView: View {
    @ObservedObject var model: AppModel
    var onMeasure: ((CGSize) -> Void)? = nil

    @State private var installHover = false

    private var statusColor: Color {
        switch model.kind {
        case .ok: return Color(hex: 0x34D399)
        case .idle: return Color(hex: 0x60A5FA)
        case .busy: return Color(hex: 0xFBBF24)
        case .error: return Color(hex: 0xF87171)
        }
    }

    private var isInstalled: Bool { model.kind == .ok }

    var body: some View {
        ZStack(alignment: .top) {
            AnimatedBackground()

            VStack(alignment: .leading, spacing: 16) {
                header
                statusCard
                if model.needsPermission {
                    permissionCard
                        .transition(.opacity)
                }
                installButton
                secondaryRow
                autoRepairCard

                if model.showLog {
                    logCard
                        .transition(.opacity)
                } else {
                    featuresRow
                        .transition(.opacity)
                }

                footer
                    .padding(.top, 6)
            }
            .padding(.horizontal, 30)
            .padding(.top, 46)
            .padding(.bottom, 22)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ContentSizeKey.self, value: proxy.size)
                        .onAppear { onMeasure?(proxy.size) }
                }
            )
            .onPreferenceChange(ContentSizeKey.self) { size in
                onMeasure?(size)
            }
        }
        .frame(width: 680)
        .environment(\.colorScheme, .dark)
        .opacity(model.appeared ? 1 : 0)
        .offset(y: model.appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { model.appeared = true }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            LogoView()

            VStack(alignment: .leading, spacing: 3) {
                Text("BetterDiscord")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Темы, плагины и тонкая настройка Discord")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            if model.success && !model.busy {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: 0x34D399))
                    .shadow(color: Color(hex: 0x34D399).opacity(0.6), radius: 12)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .padding(.bottom, 4)
    }

    private var statusCard: some View {
        HStack(alignment: .center, spacing: 14) {
            StatusDot(color: statusColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                if !model.detail.isEmpty {
                    Text(model.detail)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if model.busy {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: model.kind)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: 0xFBBF24))
                Text("Нужен Full Disk Access")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            Text("macOS 26 защищает папку Discord. Включите BetterDiscord Installer в Full Disk Access, затем перезапустите приложение.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Открыть настройки") {
                    model.openFullDiskAccess()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0x2563EB)))

                Button("Перезапустить приложение") {
                    model.restartApp()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.08)))

                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0xF59E0B).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0xF59E0B).opacity(0.30), lineWidth: 1)
        )
    }

    private var installButton: some View {
        Button(action: { model.install() }) {
            HStack(spacing: 10) {
                Image(systemName: isInstalled ? "arrow.triangle.2.circlepath" : "arrow.down.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(isInstalled ? "Переустановить" : "Установить BetterDiscord")
                    .font(.system(size: 15, weight: .semibold))
                if model.busy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .padding(.leading, 2)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: model.busy
                            ? [Color(hex: 0x334155), Color(hex: 0x1E293B)]
                            : [Color(hex: 0x4F8DF7), Color(hex: 0x1D4ED8)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(
                        color: Color(hex: 0x2563EB).opacity(model.busy ? 0.15 : 0.45),
                        radius: installHover ? 22 : 16,
                        y: 8
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(model.busy || model.needsPermission)
        .opacity(model.busy || model.needsPermission ? 0.55 : 1)
        .scaleEffect(installHover && !model.busy && !model.needsPermission ? 1.012 : 1)
        .onHover { value in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                installHover = value
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.busy)
    }

    private var secondaryRow: some View {
        HStack(spacing: 12) {
            SecondaryButton(title: "Удалить", icon: "trash") {
                model.remove()
            }
            .disabled(model.busy)
            .opacity(model.busy ? 0.55 : 1)

            SecondaryButton(
                title: model.showLog ? "Скрыть детали" : "Подробности",
                icon: "terminal"
            ) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    model.showLog.toggle()
                }
            }

            Spacer()
        }
    }

    private var autoRepairCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 38, height: 38)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: 0x8AB4FF))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Автовосстановление")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("Проверять после обновлений Discord и подключать BetterDiscord автоматически")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { model.autoRepair },
                set: { model.setAutoRepair($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Color(hex: 0x3B82F6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var featuresRow: some View {
        HStack(spacing: 10) {
            FeaturePill(icon: "paintpalette.fill", title: "Темы", color: Color(hex: 0xC084FC))
            FeaturePill(icon: "puzzlepiece.extension.fill", title: "Плагины", color: Color(hex: 0x60A5FA))
            FeaturePill(icon: "chevron.left.forwardslash.chevron.right", title: "CSS-редактор", color: Color(hex: 0x34D399))
            Spacer(minLength: 0)
        }
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ЖУРНАЛ")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }

            ScrollView {
                Text(model.logText.isEmpty ? "Пока пусто" : model.logText)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 112)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield")
                .font(.system(size: 10))
            Text("Не изменяет /Applications/Discord.app · macOS 12+")
                .font(.system(size: 10.5))
        }
        .foregroundColor(.white.opacity(0.35))
    }
}

// MARK: - Приложение

final class NoIntrinsicHostingView<Content: View>: NSHostingView<Content> {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let model = AppModel()
    var measuredHeight: CGFloat = 0
    var hasRevealed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        model.start()

        if CommandLine.arguments.contains("--show-log") {
            model.showLog = true
        }

        let host = NoIntrinsicHostingView(rootView: ContentView(model: model, onMeasure: { [weak self] size in
            guard let self else { return }
            self.measuredHeight = size.height
            self.fitWindow(height: size.height)
        }))
        host.frame = NSRect(x: 0, y: 0, width: 680, height: 420)
        host.autoresizingMask = [.width, .height]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 420))
        container.autoresizingMask = [.width, .height]
        container.addSubview(host)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "BetterDiscord Installer"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isRestorable = false
        window.contentMinSize = NSSize(width: 0, height: 0)
        window.minSize = NSSize(width: 0, height: 0)
        window.backgroundColor = NSColor(calibratedRed: 0.027, green: 0.039, blue: 0.086, alpha: 1)
        window.contentView = container
        window.center()
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reveal() {
        guard !hasRevealed, let window = window else { return }
        hasRevealed = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    func fitWindow(height: CGFloat) {
        guard height > 100, let window = window else { return }
        let target = max(320, ceil(height) + 6)
        let current = window.frame.height

        if abs(current - target) < 1 {
            reveal()
            return
        }

        var frame = window.frame
        let top = frame.origin.y + frame.size.height
        frame.size.height = target
        frame.origin.y = top - target

        if hasRevealed {
            window.setFrame(frame, display: true, animate: true)
        } else {
            window.setFrame(frame, display: true)
            window.center()
            reveal()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func buildMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)

        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "О программе BetterDiscord Installer",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Завершить",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }
}

// Отрисовка превью интерфейса в PNG (для проверки дизайна без экрана).
if let index = arguments.firstIndex(of: "--render-preview"),
   let out = arguments[(index + 1)...].first(where: { !$0.hasPrefix("--") }) {
    _ = NSApplication.shared

    let preview = AppModel()
    preview.appeared = true
    preview.kind = .ok
    preview.title = "BetterDiscord подключён"
    preview.detail = "Discord \(discordVersion()) · автовосстановление включено"
    preview.autoRepair = true
    preview.success = true

    if arguments.contains("--with-log") {
        preview.showLog = true
        preview.logText = """
        Discord: /Applications/Discord.app
        betterdiscord.asar уже на месте
        Подключено: ~/Library/Application Support/discord/app-\(discordVersion())/modules/discord_desktop_core-1/discord_desktop_core
        Готово: patched=1, already=0
        """
    }

    let height: CGFloat = preview.showLog ? 642 : 519
    let view = NSHostingView(rootView: ContentView(model: preview))
    view.frame = NSRect(x: 0, y: 0, width: 680, height: height)
    view.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        fputs("preview: cannot create bitmap\n", stderr)
        exit(1)
    }
    view.cacheDisplay(in: view.bounds, to: rep)

    guard let png = rep.representation(using: .png, properties: [:]) else {
        fputs("preview: cannot encode png\n", stderr)
        exit(1)
    }

    try? png.write(to: URL(fileURLWithPath: out))
    print("preview: \(out)")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
