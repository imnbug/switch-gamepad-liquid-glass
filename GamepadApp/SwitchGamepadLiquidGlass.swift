//
//  SwitchGamepadLiquidGlass.swift
//  Switch 虚拟手柄 — SwiftUI / Liquid Glass 版
//
//  与网页原型 1:1 对应（最终版）：
//  - 双摇杆（可拖动、松手回弹）、十字键、ABXY 菱形
//  - L / ZL / R / ZR 肩键、− / ＋ 小键
//  - 无 HOME 键、无截图键
//  - 无左右玻璃底板：所有按键直接浮在画面上
//  - 三种背景：山谷 / 深夜 / 晨光
//  - 调参：控件大小、不透明度、拇指热区标注、事件日志
//
//  使用方式：
//  把本文件加入 Xcode 工程，把 SwitchGamepadView 设为根视图即可。
//  横屏使用。iOS 26+ 走原生 .glassEffect()，以下自动降级为
//  .ultraThinMaterial，布局与交互不变。
//
//  对外输出：
//  onInput 回调会给出按键按下/松开，以及摇杆归一化坐标
//  (-1...1, -1...1)，接游戏引擎时直接订阅这个回调。
//

import SwiftUI

// MARK: - 输入模型

enum GamepadInput: Equatable {
    case button(name: String, pressed: Bool)
    case stick(id: String, x: Double, y: Double) // 归一化 -1...1
}

enum GamepadBackground: String, CaseIterable, Identifiable {
    case valley = "山谷"
    case night  = "深夜"
    case dawn   = "晨光"
    var id: String { rawValue }
}

// MARK: - 原生玻璃材质（唯一的材质入口）

/// Liquid Glass 封装：iOS 26+ 用 .glassEffect()，
/// iOS 26 以下降级为 .ultraThinMaterial。
/// 规则：glassEffect 永远放在 modifier 链最后；玻璃不叠玻璃。
struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color = .clear
    var tintOpacity: Double = 0.18
    var interactive: Bool = true

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular
                    .tint(tint.opacity(tintOpacity))
                    .interactive(interactive),
                in: shape
            )
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.25), lineWidth: 1))
        }
    }
}

extension View {
    func liquidGlass<S: Shape>(
        in shape: S,
        tint: Color = .clear,
        tintOpacity: Double = 0.18,
        interactive: Bool = true
    ) -> some View {
        modifier(LiquidGlassModifier(
            shape: shape, tint: tint,
            tintOpacity: tintOpacity, interactive: interactive
        ))
    }
}

// MARK: - 背景（山谷 / 深夜 / 晨光）

struct GamepadBackdrop: View {
    let scene: GamepadBackground

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colors, startPoint: .top, endPoint: .bottom
            )
            // 远山剪影：只为让玻璃有东西可折射，正式项目换成游戏画面即可
            GeometryReader { geo in
                Path { p in
                    let w = geo.size.width, h = geo.size.height
                    p.move(to: CGPoint(x: 0, y: h * 0.72))
                    p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.48))
                    p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.66))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.44))
                    p.addLine(to: CGPoint(x: w, y: h * 0.62))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(.black.opacity(0.18))
            }
            Circle() // 太阳 / 月亮
                .fill(.white.opacity(0.55))
                .frame(width: 72, height: 72)
                .blur(radius: 2)
                .offset(x: 120, y: -110)
        }
        .ignoresSafeArea()
    }

    private var colors: [Color] {
        switch scene {
        case .valley: return [.init(red: 0.36, green: 0.62, blue: 0.86),
                              .init(red: 0.55, green: 0.78, blue: 0.62),
                              .init(red: 0.92, green: 0.80, blue: 0.55)]
        case .night:  return [.init(red: 0.05, green: 0.07, blue: 0.18),
                              .init(red: 0.13, green: 0.16, blue: 0.36),
                              .init(red: 0.28, green: 0.22, blue: 0.42)]
        case .dawn:   return [.init(red: 0.98, green: 0.62, blue: 0.45),
                              .init(red: 0.99, green: 0.78, blue: 0.58),
                              .init(red: 0.65, green: 0.72, blue: 0.88)]
        }
    }
}

// MARK: - 圆形按键（ABXY / − / ＋ 共用）

struct GlassCircleButton: View {
    let label: String
    var diameter: CGFloat = 58
    var fontSize: CGFloat = 20
    var tint: Color = .clear
    var glassOpacity: Double = 0.18
    let onChange: (Bool) -> Void

    @State private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .frame(width: diameter, height: diameter)
            .scaleEffect(pressed ? 0.90 : 1)
            .liquidGlass(in: .circle, tint: tint,
                         tintOpacity: glassOpacity)
            .animation(.spring(response: 0.22, dampingFraction: 0.6),
                       value: pressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in set(true) }
                    .onEnded { _ in set(false) }
            )
            .accessibilityLabel("按键 \(label)")
    }

    private func set(_ value: Bool) {
        guard pressed != value else { return }
        pressed = value
        if value {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        onChange(value)
    }
}

// MARK: - 肩键（L / ZL / R / ZR，胶囊形）

struct GlassShoulderButton: View {
    let label: String
    var width: CGFloat = 76
    var height: CGFloat = 36
    var glassOpacity: Double = 0.18
    let onChange: (Bool) -> Void

    @State private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .frame(width: width, height: height)
            .scaleEffect(pressed ? 0.93 : 1)
            .liquidGlass(in: .capsule, tintOpacity: glassOpacity)
            .animation(.spring(response: 0.22, dampingFraction: 0.6),
                       value: pressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in set(true) }
                    .onEnded { _ in set(false) }
            )
            .accessibilityLabel("肩键 \(label)")
    }

    private func set(_ value: Bool) {
        guard pressed != value else { return }
        pressed = value
        if value {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        onChange(value)
    }
}

// MARK: - 摇杆（可拖动，松手弹簧回弹，输出归一化坐标）

struct GlassAnalogStick: View {
    let id: String
    var baseDiameter: CGFloat = 118
    var knobDiameter: CGFloat = 56
    var glassOpacity: Double = 0.18
    let onMove: (Double, Double) -> Void

    @State private var offset: CGSize = .zero

    private var maxTravel: CGFloat {
        (baseDiameter - knobDiameter) / 2
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.06))
                .overlay(Circle().stroke(.white.opacity(0.22),
                                         lineWidth: 1))
                .frame(width: baseDiameter, height: baseDiameter)

            Circle()
                .fill(.clear)
                .frame(width: knobDiameter, height: knobDiameter)
                .overlay(
                    Circle().stroke(.white.opacity(0.15), lineWidth: 10)
                )
                .liquidGlass(in: .circle, tintOpacity: glassOpacity)
                .offset(offset)
        }
        .frame(width: baseDiameter, height: baseDiameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    var dx = value.translation.width
                    var dy = value.translation.height
                    let len = hypot(dx, dy)
                    if len > maxTravel {
                        dx *= maxTravel / len
                        dy *= maxTravel / len
                    }
                    offset = CGSize(width: dx, height: dy)
                    onMove(Double(dx / maxTravel),
                           Double(dy / maxTravel))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.28,
                                          dampingFraction: 0.55)) {
                        offset = .zero
                    }
                    onMove(0, 0)
                }
        )
        .accessibilityLabel("\(id) 摇杆")
    }
}

// MARK: - 十字键（单块玻璃十字，四向独立判定）

struct GlassDPad: View {
    var size: CGFloat = 132          // 整体边长，单臂约 size/3
    var glassOpacity: Double = 0.18
    let onChange: (String, Bool) -> Void // ("上"/"下"/"左"/"右", pressed)

    @State private var active: String?

    private var arm: CGFloat { size / 3 }

    var body: some View {
        ZStack {
            // 十字形状：竖臂 + 横臂，两块同属一个视觉整体
            RoundedRectangle(cornerRadius: 10)
                .fill(.clear)
                .frame(width: arm, height: size)
            RoundedRectangle(cornerRadius: 10)
                .fill(.clear)
                .frame(width: size, height: arm)
            // 方向箭头
            VStack {
                arrow("chevron.up", dir: "上")
                Spacer()
                arrow("chevron.down", dir: "下")
            }
            .frame(height: size - 14)
            HStack {
                arrow("chevron.left", dir: "左")
                Spacer()
                arrow("chevron.right", dir: "右")
            }
            .frame(width: size - 14)
        }
        .frame(width: size, height: size)
        // 玻璃只加在外层容器形状上，避免玻璃叠玻璃；
        // 正式项目可换成十字 Path 形状做到完全贴合。
        .liquidGlass(in: RoundedRectangle(cornerRadius: 14),
                     tintOpacity: glassOpacity * 0.7)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    set(direction(at: value.location))
                }
                .onEnded { _ in set(nil) }
        )
        .accessibilityLabel("十字键")
    }

    private func arrow(_ systemName: String, dir: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white.opacity(active == dir ? 1 : 0.75))
            .scaleEffect(active == dir ? 1.2 : 1)
    }

    private func direction(at point: CGPoint) -> String? {
        let dx = point.x - size / 2
        let dy = point.y - size / 2
        guard hypot(dx, dy) > 8 else { return nil }
        return abs(dx) > abs(dy) ? (dx > 0 ? "右" : "左")
                                 : (dy > 0 ? "下" : "上")
    }

    private func set(_ dir: String?) {
        if let old = active, old != dir { onChange(old, false) }
        if let new = dir, new != active {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onChange(new, true)
        }
        active = dir
    }
}

// MARK: - ABXY 菱形簇（Switch 布局：X 上、Y 左、A 右、B 下）

struct ABXYCluster: View {
    var buttonDiameter: CGFloat = 58
    var spacing: CGFloat = 64 // 中心到中心的距离
    var glassOpacity: Double = 0.18
    let onChange: (String, Bool) -> Void

    var body: some View {
        ZStack {
            GlassCircleButton(label: "X", diameter: buttonDiameter,
                              glassOpacity: glassOpacity) {
                onChange("X", $0)
            }
            .offset(y: -spacing)

            GlassCircleButton(label: "B", diameter: buttonDiameter,
                              glassOpacity: glassOpacity) {
                onChange("B", $0)
            }
            .offset(y: spacing)

            GlassCircleButton(label: "Y", diameter: buttonDiameter,
                              glassOpacity: glassOpacity) {
                onChange("Y", $0)
            }
            .offset(x: -spacing)

            GlassCircleButton(label: "A", diameter: buttonDiameter,
                              glassOpacity: glassOpacity) {
                onChange("A", $0)
            }
            .offset(x: spacing)
        }
        .frame(width: spacing * 2 + buttonDiameter,
               height: spacing * 2 + buttonDiameter)
    }
}

// MARK: - 拇指热区标注（设计检查用，正式版关掉）

struct ThumbZoneOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) * 0.42
            ZStack {
                Circle()
                    .stroke(.yellow.opacity(0.8),
                            style: StrokeStyle(lineWidth: 1.5,
                                               dash: [6, 5]))
                    .frame(width: r * 2, height: r * 2)
                    .position(x: 30, y: geo.size.height - 30)
                Circle()
                    .stroke(.yellow.opacity(0.8),
                            style: StrokeStyle(lineWidth: 1.5,
                                               dash: [6, 5]))
                    .frame(width: r * 2, height: r * 2)
                    .position(x: geo.size.width - 30,
                              y: geo.size.height - 30)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - 主视图（整套手柄 + 调参台 + 事件日志）

struct SwitchGamepadView: View {
    /// 游戏引擎订阅入口；不接引擎时可不传，输入只进日志。
    var onInput: (GamepadInput) -> Void = { _ in }

    @State private var scene: GamepadBackground = .valley
    @State private var controlScale: Double = 1.0   // 0.8...1.2
    @State private var glassOpacity: Double = 0.18  // 对应原型不透明度
    @State private var showThumbZones = false
    @State private var log: [String] = []

    var body: some View {
        ZStack {
            GamepadBackdrop(scene: scene)

            VStack(spacing: 0) {
                shoulderRow
                Spacer()
                mainRow
                Spacer()
                controlBar
            }
            .padding(.horizontal, 34) // 避开手势区 / 灵动岛
            .padding(.vertical, 14)

            if showThumbZones { ThumbZoneOverlay() }
        }
    }

    // 肩键行：ZL L ····· R ZR（无底板，直接浮在画面上）
    private var shoulderRow: some View {
        HStack {
            HStack(spacing: 10) {
                GlassShoulderButton(label: "ZL",
                                    glassOpacity: glassOpacity) {
                    emit("ZL", $0)
                }
                GlassShoulderButton(label: "L",
                                    glassOpacity: glassOpacity) {
                    emit("L", $0)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                GlassShoulderButton(label: "R",
                                    glassOpacity: glassOpacity) {
                    emit("R", $0)
                }
                GlassShoulderButton(label: "ZR",
                                    glassOpacity: glassOpacity) {
                    emit("ZR", $0)
                }
            }
        }
    }

    // 主行：左摇杆 + 十字键 ｜ − ＋ ｜ ABXY + 右摇杆
    private var mainRow: some View {
        HStack(alignment: .center) {
            VStack(spacing: 18) {
                GlassAnalogStick(
                    id: "左",
                    baseDiameter: 118 * controlScale,
                    knobDiameter: 56 * controlScale,
                    glassOpacity: glassOpacity
                ) { x, y in
                    onInput(.stick(id: "左摇杆", x: x, y: y))
                    appendLog("左摇杆 (\(fmt(x)), \(fmt(y)))")
                }
                GlassDPad(size: 132 * controlScale,
                          glassOpacity: glassOpacity) { dir, pressed in
                    emit("十字\(dir)", pressed)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                GlassCircleButton(label: "−", diameter: 36,
                                  fontSize: 18,
                                  glassOpacity: glassOpacity) {
                    emit("−", $0)
                }
                GlassCircleButton(label: "＋", diameter: 36,
                                  fontSize: 18,
                                  glassOpacity: glassOpacity) {
                    emit("＋", $0)
                }
            }

            Spacer()

            VStack(spacing: 18) {
                ABXYCluster(buttonDiameter: 58 * controlScale,
                            spacing: 64 * controlScale,
                            glassOpacity: glassOpacity) { name, pressed in
                    emit(name, pressed)
                }
                GlassAnalogStick(
                    id: "右",
                    baseDiameter: 118 * controlScale,
                    knobDiameter: 56 * controlScale,
                    glassOpacity: glassOpacity
                ) { x, y in
                    onInput(.stick(id: "右摇杆", x: x, y: y))
                    appendLog("右摇杆 (\(fmt(x)), \(fmt(y)))")
                }
            }
        }
    }

    // 底部调参台 + 日志（设计稿模式；正式版删掉这一行即可）
    private var controlBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 18) {
                Picker("背景", selection: $scene) {
                    ForEach(GamepadBackground.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                VStack(spacing: 2) {
                    Text("控件大小").font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                    Slider(value: $controlScale, in: 0.8...1.2)
                        .frame(width: 110)
                }
                VStack(spacing: 2) {
                    Text("玻璃不透明度").font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                    Slider(value: $glassOpacity, in: 0.05...0.45)
                        .frame(width: 110)
                }
                Toggle("拇指热区", isOn: $showThumbZones)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .fixedSize()
            }
            Text(log.suffix(2).joined(separator: "   ·   "))
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .frame(height: 14)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        // 调参台本身也是玻璃，但不与按键玻璃重叠
        .liquidGlass(in: RoundedRectangle(cornerRadius: 18),
                     tintOpacity: 0.12)
    }

    // MARK: 事件分发 / 日志

    private func emit(_ name: String, _ pressed: Bool) {
        onInput(.button(name: name, pressed: pressed))
        appendLog("\(name) \(pressed ? "按下" : "松开")")
    }

    private func appendLog(_ entry: String) {
        // 摇杆会高频触发，只保留最近 12 条，避免设计稿预览卡顿
        log.append(entry)
        if log.count > 12 { log.removeFirst(log.count - 12) }
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%.2f", v)
    }
}

// MARK: - App 入口示例

/// 独立设计稿 App 的入口；
/// 若嵌入已有工程，删掉本段、直接用 SwitchGamepadView()。
@main
struct SwitchGamepadApp: App {
    var body: some Scene {
        WindowGroup {
            SwitchGamepadView { input in
                // 在这里接游戏引擎 / 手柄映射层
                print(input)
            }
        }
    }
}

#Preview("横屏 · 山谷") {
    SwitchGamepadView()
        .previewInterfaceOrientation(.landscapeLeft)
}
