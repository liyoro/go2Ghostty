# 用 Codex + 提示词生成一个快速打开 Ghostty 的 macOS 小工具

## 前言

日常在 Finder 里翻项目目录时，经常会有一个小需求：  
**我想在当前 Finder 文件夹里快速打开终端。**

以前很多人会用 Go2Shell 这类工具，把 App 拖到 Finder 工具栏，点击一下就能在当前目录打开终端。

这篇文章记录一次完整实操：用 **Codex + 提示词** 快速生成一个类似 Go2Shell 的 macOS 小工具，不过目标终端换成 **Ghostty**。

最终效果：

- App 名称：`go2Ghostty`
- 可拖到 Finder toolbar
- 点击后读取 Finder 当前目录
- 打开 Ghostty 并定位到该目录
- Ghostty 已打开时，尽量新建 tab 并进入当前目录
- App 不显示在 Dock
- 自动打包到 `Release/go2Ghostty.app`
- 自带一个 Ghostty 风格的原创图标

---

## 环境说明

本次环境：

```text
macOS
Xcode / Command Line Tools
Swift
Ghostty.app
Codex
```

项目目录约定：

```text
go2Ghostty/
  code/
  Release/
```

其中：

```text
code/
```

用于存放源码、脚本和 README。

```text
Release/
```

用于存放最终生成的 macOS App：

```text
Release/go2Ghostty.app
```

Ghostty 默认安装路径：

```text
/Applications/Ghostty.app
```

如果你的 Ghostty 不在这个路径，需要后面手动改一下常量配置。

---

## 整体思路

我们要做的不是一个带窗口的完整 GUI App，而是一个极小的 macOS helper app。

整体流程如下：

1. 用户把 `go2Ghostty.app` 拖到 Finder 工具栏。
2. 点击 App。
3. App 启动后读取 Finder 当前路径。
4. 判断 Ghostty 是否已经运行。
5. 如果未运行：
   - 通过 `/usr/bin/open` 打开 `/Applications/Ghostty.app`
   - 传入 `--working-directory`
6. 如果已运行：
   - 激活 Ghostty
   - 发送 `Cmd + T`
   - 粘贴 `cd '<当前目录>'; clear`
   - 回车执行
7. App 自动退出。

关键技术点：

```text
Swift + AppKit
NSAppleScript 读取 Finder 路径
NSWorkspace 判断 Ghostty 是否运行
Process 调用 /usr/bin/open
AXIsProcessTrustedWithOptions 检测辅助功能权限
System Events 发送快捷键
LSUIElement 隐藏 Dock 图标
CoreGraphics 生成 App 图标
swiftc + lipo 打包 universal binary
codesign 做 ad-hoc 签名
```

---

## 分步提示词

下面是核心：如何一步一步让 Codex 生成这个 App。

### 第一步：初始化需求

先给 Codex 一个完整需求描述。

```text
我需要开发一个 macOS 小工具 App，名字叫 go2Ghostty，类似 Go2Shell。

功能要求：
1. 可以拖到 Finder toolbar。
2. 点击后读取 Finder 当前窗口目录。
3. 打开 Ghostty 到当前目录。
4. 如果 Ghostty 已经打开，则在 Ghostty 中新建一个 tab，并 cd 到当前目录。
5. App 不显示在 Dock。
6. 所有代码放到当前目录的 code 文件夹。
7. 打包产物放到当前目录的 Release 文件夹，路径为 Release/go2Ghostty.app。
8. 使用 Swift + AppKit 实现。
9. 提供一键构建脚本。
10. 直接实现完整项目，不要只给方案。
```

这一步的目标是让 Codex 明确：

- 做什么 App
- 放在哪
- 如何打包
- 不要停留在设计方案

---

### 第二步：补充系统适配规则

macOS 上打开 Ghostty 有个坑：  
`open -a Ghostty` 在部分机器上可能找不到应用。

所以继续补一段提示词：

```text
系统适配要求：
1. Ghostty 默认路径为 /Applications/Ghostty.app。
2. 不要使用 open -a Ghostty。
3. 使用固定路径打开：
   /usr/bin/open -n /Applications/Ghostty.app --args --working-directory=<目录>
4. 使用 bundle id 判断 Ghostty 是否运行：
   com.mitchellh.ghostty
5. 目标系统 macOS 13+。
6. App bundle id 使用 dev.local.go2Ghostty。
```

关键点是这句：

```bash
/usr/bin/open -n /Applications/Ghostty.app --args --working-directory=<目录>
```

比 `open -a Ghostty` 更稳。

---

### 第三步：要求隐藏 Dock

这个 App 是工具栏小工具，不应该在 Dock 里出现。

提示词：

```text
App 不需要显示在 Dock。请在 Info.plist 中设置：

LSUIElement = true

并且 App 启动时设置：

app.setActivationPolicy(.accessory)
```

对应配置：

```xml
<key>LSUIElement</key>
<true/>
```

Swift 入口里也要有：

```swift
app.setActivationPolicy(.accessory)
```

---

### 第四步：要求本地日志

调试这种无窗口 App 时，最怕“点击没反应”。

所以提前要求 Codex 加日志：

```text
请添加本地调试日志，路径为：

/tmp/go2Ghostty.log

关键步骤都写日志，包括：
1. main
2. applicationDidFinishLaunching
3. resolved directory
4. ghostty is running
5. open new window success
6. AppleScript error
7. did open

如果用户反馈点击无反应，可以通过 tail -n 40 /tmp/go2Ghostty.log 排查。
```

这样后面排错会非常省事。

---

### 第五步：要求生成图标

最后给 App 加一个类似 Ghostty 气质的原创图标。

提示词：

```text
请给 App 创建一个类似 Ghostty.app 气质但不直接复制的图标。

要求：
1. macOS 圆角方形图标。
2. 深色终端窗口。
3. 青绿色 / 薄荷绿色高亮。
4. 有终端提示符 >_。
5. 有一个浅绿色小幽灵元素。
6. 使用 CoreGraphics 生成图标，不依赖外部图片服务。
7. 生成完整 AppIcon.iconset 和 AppIcon.icns。
8. 打包时写入 CFBundleIconFile = AppIcon。
```

---

## 代码生成

经过上面的提示词，Codex 会生成类似下面的项目结构：

```text
code/
  Package.swift
  README.md
  .gitignore
  Sources/
    go2Ghostty/
      main.swift
  Resources/
    AppIcon.iconset/
    AppIcon.icns
  script/
    build_release.sh
    generate_icon.swift
Release/
  go2Ghostty.app
```

### 主程序关键代码

核心入口应该是显式 AppKit 启动，而不是依赖隐式行为：

```swift
@main
enum Main {
    static func main() {
        DebugLog.write("main")

        let app = NSApplication.shared
        let delegate = AppDelegate()

        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
```

AppDelegate 负责启动后执行逻辑：

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        DispatchQueue.main.async {
            self.openGhosttyAtFinderLocation()
        }
    }

    private func openGhosttyAtFinderLocation() {
        DebugLog.write("applicationDidFinishLaunching")

        let directory = FinderLocationResolver.currentDirectory()
            ?? FileManager.default.homeDirectoryForCurrentUser.path

        DebugLog.write("resolved directory: \(directory)")

        let ghosttyIsRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.mitchellh.ghostty"
        }

        DebugLog.write("ghostty is running: \(ghosttyIsRunning)")

        let didOpen = ghosttyIsRunning
            ? GhosttyLauncher.openNewTab(at: directory)
            : GhosttyLauncher.openNewWindow(at: directory)

        DebugLog.write("did open: \(didOpen)")

        NSApp.terminate(nil)
    }
}
```

读取 Finder 当前目录：

```swift
private enum FinderLocationResolver {
    static func currentDirectory() -> String? {
        let script = """
        tell application "Finder"
            if (count of Finder windows) is greater than 0 then
                set finderTarget to target of front Finder window as alias
                return POSIX path of finderTarget
            else if (count of selection) is greater than 0 then
                set selectedItem to item 1 of selection
                if class of selectedItem is folder then
                    return POSIX path of (selectedItem as alias)
                else
                    return POSIX path of ((container of selectedItem) as alias)
                end if
            else
                return POSIX path of (path to home folder)
            end if
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        let result = appleScript.executeAndReturnError(&error)
        return error == nil ? result.stringValue : nil
    }
}
```

打开 Ghostty：

```swift
static func openNewWindow(at directory: String) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [
        "-n",
        "/Applications/Ghostty.app",
        "--args",
        "--working-directory=\(directory)"
    ]

    return process.runAndWait()
}
```

---

## 调试运行

### 直接打包

进入 `code` 目录：

```bash
cd code
./script/build_release.sh
```

成功后输出：

```text
/当前项目/Release/go2Ghostty.app
```

### 检查 App 是否存在

```bash
find Release/go2Ghostty.app/Contents -maxdepth 3 -type f | sort
```

应该看到：

```text
Release/go2Ghostty.app/Contents/Info.plist
Release/go2Ghostty.app/Contents/MacOS/go2Ghostty
Release/go2Ghostty.app/Contents/Resources/AppIcon.icns
Release/go2Ghostty.app/Contents/_CodeSignature/CodeResources
```

### 手动启动测试

```bash
/usr/bin/open -n Release/go2Ghostty.app
```

如果没反应，看日志：

```bash
tail -n 40 /tmp/go2Ghostty.log
```

日志示例：

```text
main
applicationDidFinishLaunching
resolved directory: /Users/xxx/Project/
ghostty is running: false
open new window success: true
did open: true
```

看到 `open new window success: true`，说明 App 已经把打开请求交给系统。

---

## 打包发布

### build_release.sh 关键逻辑

打包脚本主要做这些事：

1. 编译图标生成器
2. 生成 `AppIcon.iconset`
3. 生成 `AppIcon.icns`
4. 编译 arm64 主程序
5. 编译 x86_64 主程序
6. 用 `lipo` 合并 universal binary
7. 组装 `.app`
8. 写入 `Info.plist`
9. 复制图标
10. ad-hoc 签名
11. 复制到 `Release`

核心命令类似：

```bash
swiftc -parse-as-library -O \
  -target arm64-apple-macos13 \
  -sdk "$SDK_PATH" \
  -framework AppKit \
  -framework ApplicationServices \
  Sources/go2Ghostty/main.swift \
  -o .build-direct/go2Ghostty-arm64
```

x86_64 版本：

```bash
swiftc -parse-as-library -O \
  -target x86_64-apple-macos13 \
  -sdk "$SDK_PATH" \
  -framework AppKit \
  -framework ApplicationServices \
  Sources/go2Ghostty/main.swift \
  -o .build-direct/go2Ghostty-x86_64
```

合并：

```bash
lipo -create \
  .build-direct/go2Ghostty-arm64 \
  .build-direct/go2Ghostty-x86_64 \
  -output .build-direct/go2Ghostty
```

签名：

```bash
codesign --force --sign - code/dist/go2Ghostty.app
```

复制发布：

```bash
cp -R code/dist/go2Ghostty.app Release/go2Ghostty.app
```

---

## 关键配置

### Info.plist

必须包含：

```xml
<key>CFBundleExecutable</key>
<string>go2Ghostty</string>

<key>CFBundleIdentifier</key>
<string>dev.local.go2Ghostty</string>

<key>CFBundleIconFile</key>
<string>AppIcon</string>

<key>CFBundleName</key>
<string>go2Ghostty</string>

<key>CFBundlePackageType</key>
<string>APPL</string>

<key>LSMinimumSystemVersion</key>
<string>13.0</string>

<key>LSUIElement</key>
<true/>

<key>NSAppleEventsUsageDescription</key>
<string>go2Ghostty reads the front Finder folder and opens Ghostty at that location.</string>

<key>NSPrincipalClass</key>
<string>NSApplication</string>
```

### 校验签名

```bash
codesign --verify --deep --strict --verbose=2 Release/go2Ghostty.app
```

期望输出：

```text
Release/go2Ghostty.app: valid on disk
Release/go2Ghostty.app: satisfies its Designated Requirement
```

### 校验架构

```bash
file Release/go2Ghostty.app/Contents/MacOS/go2Ghostty
```

期望包含：

```text
Mach-O universal binary with 2 architectures
x86_64
arm64
```

### 校验 Dock 隐藏

```bash
/usr/libexec/PlistBuddy -c 'Print LSUIElement' Release/go2Ghostty.app/Contents/Info.plist
```

期望：

```text
true
```

### 校验图标

```bash
/usr/libexec/PlistBuddy -c 'Print CFBundleIconFile' Release/go2Ghostty.app/Contents/Info.plist
```

期望：

```text
AppIcon
```

---

## 使用方式

打包完成后，找到：

```text
Release/go2Ghostty.app
```

把它拖到 Finder toolbar。

之后在任意 Finder 文件夹里点击它，就会打开 Ghostty 到当前目录。

如果你之前拖过旧版本到 Finder toolbar，需要：

1. 从 Finder toolbar 移除旧图标。
2. 重新拖入新的 `Release/go2Ghostty.app`。

否则 toolbar 可能还指向旧包或失效路径。

---

## 权限说明

首次运行时，macOS 可能会弹权限：

### Automation 权限

用于读取 Finder 当前目录。

一般会出现类似：

```text
go2Ghostty wants to control Finder
```

允许即可。

### Accessibility 权限

用于 Ghostty 已运行时发送 `Cmd + T` 新建 tab。

如果不授权，App 会 fallback 到打开新的 Ghostty 窗口。

可以在这里手动授权：

```text
系统设置 -> 隐私与安全性 -> 辅助功能
```

---

## 总结要点

这次用 Codex 生成 Mac 小工具，有几个经验很关键：

1. **需求要写清楚目录结构和产物路径**  
   否则生成结果容易散。

2. **macOS helper app 建议显式 AppKit 启动**  
   使用 `NSApplication.shared`、`AppDelegate`、`app.run()` 更稳。

3. **不要依赖 `open -a Ghostty`**  
   某些机器上 LaunchServices 找不到 Ghostty 名称，固定路径更可靠。

4. **无窗口 App 必须加日志**  
   `/tmp/go2Ghostty.log` 对排查“点击没反应”非常有用。

5. **Finder toolbar 旧图标可能指向旧包**  
   重新打包后，最好移除旧 toolbar 图标再拖入新 App。

6. **打包时保留 universal binary**  
   `arm64 + x86_64` 覆盖 Apple Silicon 和 Intel Mac。

7. **图标可以用 CoreGraphics 程序化生成**  
   不依赖外部图片，也方便复现。

最终，这个小工具就是一个很典型的 AI 生成原生效率工具案例：  
用一组清晰的提示词，把需求、实现、调试、打包、图标全部串起来，十几分钟就能做出一个可用的 macOS 小 App。
