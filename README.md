# Coordinate Preview

一个轻量的原生 macOS 图片查看器。鼠标移入图片后，会在鼠标旁显示相对于原图的像素坐标。

## 行为约定

- 坐标原点是图片左上角 `(0, 0)`。
- `x` 向右递增，`y` 向下递增。
- 坐标按解码并应用 EXIF 方向后的原图像素计算，不受窗口尺寸和 Retina 缩放影响。
- 鼠标所在位置会显示横纵虚线参考线，参考线只覆盖图片区域。
- 光标旁显示无插值像素放大预览，并用黄色边框标出当前像素；可在“显示 > 放大镜倍率”选择 `6× / 8× / 12× / 16×`，默认为 `12×`。
- 鼠标悬停在图片上时，可以使用方向键将当前像素逐次移动 1 像素；鼠标再次移动后恢复按悬停位置定位。
- 窗口顶部提供缩小、当前倍率和放大按钮；当前倍率以“适合窗口”为 `1×` 实时显示，点按倍率可恢复为适合窗口。基础范围为 `0.25×～20×`，竖版长图会自动扩展档位，最高至少可把原图 1 像素显示为 20 点。
- 图片缩放后，可用触摸板双指移动图片；移动方向与手指方向一致，并遵循 macOS 的滚动方向设置。
- 按 `⌘L` 可聚焦工具栏中的 `y` 输入框；输入原图纵坐标并回车后，当前倍率不足时会自动放大到适合宽度（不会缩小用户已有倍率），再将目标像素行尽量移动到视图中央。定位会沿用最近悬停的 `x` 坐标；没有悬停坐标时使用当前可见图片的水平中心，并把鼠标指针移动到最终像素点，显示横纵参考线、十字标记和放大镜；按 `Esc` 可取消输入。
- 支持触摸板双指捏合连续缩放，缩放中心跟随手势位置；捏合按当前倍率成比例缩放，高倍率下不会因固定增量而变迟钝。
- 鼠标位于图片外的留白区域时，不显示坐标。
- 支持通过“文件 > 打开…”、Finder 打开方式以及把图片拖入窗口来打开图片。

## 构建和使用

运行安装脚本，会构建当前代码、把最新 App 安装到固定的
`~/Applications/CoordinatePreview.app`，并刷新 Finder 的“打开方式”注册：

```sh
./scripts/build-and-install.sh
```

随后在 Finder 中右键一张图片，选择“打开方式 > Coordinate Preview”即可。
若希望图片以后都由它打开，可在图片的“显示简介 > 打开方式”中选择
`Coordinate Preview`，再点“全部更改…”。之后代码有更新时重新运行脚本，
固定安装位置就会替换为最新构建，无需重新选择打开方式。脚本还会注销同一
Bundle ID 的旧构建记录，避免右键菜单出现多个同名项；旧 App 文件不会被删除。

脚本默认构建 `Release`。需要调试包时可使用：

```sh
CONFIGURATION=Debug ./scripts/build-and-install.sh
```

也可以用 Xcode 打开 `CoordinatePreview.xcodeproj`，选择
`CoordinatePreview` scheme 后运行或 Archive。

> macOS 自带“预览”没有开放可注入这类鼠标交互的第三方插件接口，因此本项目以可注册为默认图片查看器的独立 App 实现。

## 验证

坐标换算逻辑使用 Swift Testing 覆盖：

```sh
swift test
```

命令行构建 App：

```sh
xcodebuild -project CoordinatePreview.xcodeproj \
  -scheme CoordinatePreview \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/CoordinatePreviewDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```
