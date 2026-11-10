# Switch 手柄 GitHub Actions 编译验证

把这套文件推到一个 GitHub 仓库，Actions 就会在云端 Mac 上编译一次，
验证那份 601 行 SwiftUI 代码能不能过 Xcode——不用租 Mac、不用花钱。

## 里面有什么

- `GamepadApp/SwitchGamepadLiquidGlass.swift` — 就是已交付的那份 601 行代码（原样，未改）
- `GamepadApp.xcodeproj/project.pbxproj` — 最小 Xcode 工程，只引用上面那一个文件
- `.github/workflows/build.yml` — 编译 workflow：`xcodebuild build`，目标 iOS 模拟器，不签名

工程设定：部署目标 iOS 17.0（代码里 iOS 26 以下自动降级到 `.ultraThinMaterial`，
所以不用非得 26 才能编）；横屏方向已写进配置；Bundle ID 是占位用的
`com.example.SwitchGamepad`，真要打包上机再改成自己的。

## 怎么用（3 步）

1. 在 GitHub 新建一个仓库（公开免费无限额度；私有仓库每月约 200 分钟 macOS 免费额度，
   一次编译约 2–5 分钟，够用）
2. 把这个文件夹里的全部内容推到仓库根目录（`.github` 是隐藏文件夹，别漏了）
3. 打开仓库的 Actions 页看结果：绿勾 = 编译通过；红叉 = 点进 log 看报错发回来

## 这一步能证明什么、不能证明什么

- 能证明：代码没有语法/类型错误、`.glassEffect` 的 `#available` 写法没问题、
  `UIImpactFeedbackGenerator` 这些调用能过编译。
- 不能证明：在真机上跑起来什么样、Liquid Glass 在 iOS 27 上的实际效果、
  摇杆手感——那些要装到手机上才知道。真机安装仍需 Apple ID 签名（7 天重签），
  这一步不涉及签名。

## 如果不想走 Actions

租一台云 Mac 也行，2026-11-09 刚对价格复核过（各家官网价，与之前说的没变）：

- MacRent：M4 / 16GB，$15/天、$89/周、$159/月（美国月付 10 月 26 日时显示售罄）
- My Remote Mac：同配置 $14/天、$85/月
- Scaleway M4-S：€0.22/小时，但 24 小时起租（一次最少 €5.28）
- AWS EC2 Mac M4：$1.23/小时，同样 24 小时起租（一次最少 $29.52）

只为验这一次编译，Actions 是零成本的那条路；要长期在 Mac 上折腾再考虑租。
