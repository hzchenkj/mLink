# mLink

`mLink` 是一个 macOS 原生 Markdown 编辑器，提供左右分栏的编辑与预览体验，适合写文档、笔记和技术说明。

## 功能

- 左侧编辑、右侧实时预览
- 分栏线可手动拖动，自动记住比例
- 基础 Markdown 语法高亮
- 文本滚动与预览滚动同步
- `关于` 菜单显示版本号、编译时间和作者信息

## 运行环境

- macOS 13.0+
- Swift 5.9+（建议使用 Xcode 自带 toolchain）

## 快速开始

```bash
swift run
```

或直接执行打包后的 App：

```bash
./scripts/package_app.sh
open dist/mLink.app
```

## 常用开发命令

构建（Debug）：

```bash
swift build
```

运行单元测试：

```bash
swift test
```

打包 macOS App（Release）：

```bash
./scripts/package_app.sh
```

脚本会在 `dist/mLink.app` 生成应用包，并自动写入：

- 版本号（`CFBundleShortVersionString` / `CFBundleVersion`）
- 编译时间（`MLinkBuildTime`）
- 应用图标（`AppIcon.icns`）

## 目录结构

- `Sources/mlink/App`: 应用入口、菜单、主窗口
- `Sources/mlink/Editor`: 编辑器组件与高亮
- `Sources/mlink/Preview`: Markdown 预览与渲染
- `Sources/mlink/Persistence`: 文档与布局持久化
- `scripts/`: 打包和图标生成脚本
- `Tests/`: 单元测试

## 作者

- 多宝（hzchenkj@gmail.com）
