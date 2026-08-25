# Coordinate Preview

[English](README.md) | **简体中文**

![macOS 13+](https://img.shields.io/badge/macOS-13.0%2B-000000?logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![AppKit](https://img.shields.io/badge/UI-AppKit-147EFB)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**精确查看图片中的每一个原始像素。**

Coordinate Preview 是一个轻量的原生 macOS 图片查看器，适用于设计、开发和
测试场景。将鼠标移入图片即可读取原图像素坐标、查看无插值放大预览，并在大图
或长图中快速定位，同时保留完整的上下文。

## 功能亮点

- **精确的原图坐标**——坐标按解码并应用 EXIF 方向后的原图像素计算，不受
  窗口尺寸和 Retina 缩放影响。
- **内置像素放大镜**——横纵参考线、无插值预览和黄色描边让当前像素清晰可见；
  支持 `6×`、`8×`、`12×`、`16×`，默认 `12×`。
- **键盘逐像素检查**——鼠标悬停后，可用方向键让选中位置每次移动一个原图像素。
- **面向长图的缩放和平移**——支持工具栏分级缩放和触摸板连续捏合缩放。常规
  相对适窗范围为 `0.25×–20×`，超长竖图会自动生成更高倍率。
- **交互式 minimap**——图片超出画布时显示整图和当前可见范围，可点击缩略图或
  拖动黄色视口框快速定位。
- **直接跳转到指定行**——按 `⌘L` 输入原图 `y` 坐标，应用会在条件允许时将
  对应像素行移动到视图中央。
- **原生 macOS 工作流**——支持应用内打开、Finder“打开方式”和拖放；多张图片
  会分别在独立窗口中打开。
- **本地运行、无第三方依赖**——图片解码和检查均在 Mac 本机完成，使用 AppKit、
  ImageIO 和 Core Graphics 实现。

## 环境要求

- macOS 13.0 或更高版本
- 从源码构建需要 Xcode 16 或更高版本及其命令行工具

## 快速开始

克隆仓库并运行安装脚本：

```sh
git clone https://github.com/alex0811/CoordinatePreview.git
cd CoordinatePreview
./scripts/build-and-install.sh
```

脚本会构建 `Release` 配置、添加本机 ad-hoc 签名、将最新 App 安装到固定位置
`~/Applications/CoordinatePreview.app`，并刷新 Finder 的“打开方式”注册。

若希望某类图片默认由 Coordinate Preview 打开，请在 Finder 中选中一张图片，
打开“显示简介”，在“打开方式”中选择 Coordinate Preview，再点“全部更改…”。
后续重新运行脚本时，固定位置的 App 会被替换，因此文件关联可以保持不变。脚本
会清理相同 Bundle ID 的旧 Launch Services 注册记录，但不会删除其他位置的 App
文件。

构建并安装 Debug 配置：

```sh
CONFIGURATION=Debug ./scripts/build-and-install.sh
```

也可以用 Xcode 打开 `CoordinatePreview.xcodeproj`，选择共享的
`CoordinatePreview` scheme 后运行或 Archive。

## 操作方式

| 操作 | 控制方式 |
| --- | --- |
| 打开图片 | `⌘O`、Finder“打开方式”或拖放 |
| 检查像素 | 将鼠标悬停在图片上 |
| 每次移动一个原图像素 | 悬停后使用方向键 |
| 缩放 | 工具栏按钮或触摸板双指捏合 |
| 恢复适合窗口 | 点击工具栏中的当前倍率 |
| 平移已放大的图片 | 触摸板双指移动；方向遵循 macOS 设置 |
| 使用 minimap 导航 | 点击缩略图或拖动黄色视口框 |
| 跳转到原图 `y` 坐标 | 按 `⌘L`，输入像素行后按回车 |
| 取消坐标输入 | `Esc` |
| 修改放大镜倍率 | “显示 > 放大镜倍率” |

## 坐标约定

- 坐标原点是图片左上角像素 `(0, 0)`。
- `x` 向右递增，`y` 向下递增。
- 坐标对应解码并应用 EXIF 方向后的原图像素，而非显示点，因此窗口缩放和 Retina
  显示不会改变坐标。
- 只有选中位置位于图片内部时，才会显示参考线和放大镜。
- 跳转像素行时会沿用最近悬停的 `x` 坐标；没有悬停坐标时，使用当前可见图片的
  水平中心。

## 验证项目

运行几何计算测试：

```sh
swift test
```

从命令行构建 App，并关闭代码签名：

```sh
xcodebuild -project CoordinatePreview.xcodeproj \
  -scheme CoordinatePreview \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/CoordinatePreviewDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

## 项目结构

- `CoordinatePreview/`——AppKit 应用和图片交互界面
- `CoordinatePreviewCore/`——可复用的坐标与视口几何计算
- `CoordinatePreviewCoreTests/`——使用 Swift Testing 覆盖几何行为
- `scripts/build-and-install.sh`——本机构建、签名、安装及 Finder 注册脚本

## 为什么使用独立 App？

macOS 自带的“预览”没有为这类鼠标像素检查开放第三方扩展接口，因此 Coordinate
Preview 以轻量独立查看器的形式实现，并可注册为图片文件的默认打开应用。

## 开源许可

Coordinate Preview 基于 [MIT License](LICENSE) 开源。
