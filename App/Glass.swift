import AppKit
import SwiftUI

// Liquid Glass on macOS 26+, translucent materials on 14–25. One look, two implementations.

extension View {
  /// A glass panel with continuous corners.
  @ViewBuilder func glassPanel(cornerRadius: CGFloat = 18) -> some View {
    if #available(macOS 26.0, *) {
      glassEffect(.regular, in: .rect(cornerRadius: cornerRadius, style: .continuous))
    } else {
      background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(Color.white.opacity(0.12)))
    }
  }

  /// Interactive glass for small controls; `tint` colors the glass when a control is "on".
  @ViewBuilder func glassCapsule(tint: Color? = nil) -> some View {
    if #available(macOS 26.0, *) {
      glassEffect(tint.map { Glass.regular.tint($0.opacity(0.35)).interactive() } ?? .regular.interactive(),
                  in: .capsule)
    } else {
      background((tint?.opacity(0.22) ?? Color.primary.opacity(0.06)), in: Capsule())
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12)))
    }
  }
}

/// The window's own translucent backdrop (behind-window blur).
struct WindowBackdrop: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let v = NSVisualEffectView()
    v.material = .underWindowBackground
    v.blendingMode = .behindWindow
    v.state = .active
    // Lighter than the stock material: more of the desktop shows through; the glass panels keep text legible.
    v.alphaValue = 0.62
    return v
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// A titled group: quiet heading over a glass panel. Rows separate themselves with `GlassDivider`.
struct GlassSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
        .padding(.leading, 6)
      VStack(alignment: .leading, spacing: 10) { content }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }
  }
}

struct GlassDivider: View {
  var body: some View { Divider().opacity(0.4) }
}

/// A label + trailing control row.
struct GlassRow<Trailing: View>: View {
  let label: String
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack {
      Text(label)
      Spacer(minLength: 12)
      trailing
    }
  }
}

/// A toggle drawn as a glass chip: tinted with the accent color when on.
struct ChipToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button { configuration.isOn.toggle() } label: {
      HStack(spacing: 5) {
        Image(systemName: configuration.isOn ? "checkmark" : "plus")
          .font(.system(size: 10, weight: .bold))
        configuration.label
      }
      .font(.callout)
      .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .glassCapsule(tint: configuration.isOn ? .accentColor : nil)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
  }
}

/// A glass capsule button that opens a popover list: hover highlight, checkmark, optional color swatches.
struct GlassDropdown<Value: Hashable>: View {
  @Binding var selection: Value
  let options: [(value: Value, title: String)]
  var swatch: (Value) -> Color? = { _ in nil }
  var accessibilityName: String
  @State private var open = false

  private func title(_ v: Value) -> String { options.first { $0.value == v }?.title ?? "" }

  var body: some View {
    Button { open.toggle() } label: {
      HStack(spacing: 6) {
        if let c = swatch(selection) { Swatch(color: c) }
        Text(title(selection)).lineLimit(1)
        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .glassCapsule()
    }
    .buttonStyle(.plain)
    .fixedSize()
    .accessibilityLabel(accessibilityName)
    .accessibilityValue(title(selection))
    .popover(isPresented: $open, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(options, id: \.value) { option in
          Button {
            selection = option.value
            open = false
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                .opacity(option.value == selection ? 1 : 0)
              if let c = swatch(option.value) { Swatch(color: c) }
              Text(option.title)
              Spacer(minLength: 0)
            }
          }
          .buttonStyle(MenuRowButtonStyle())
        }
      }
      .padding(6)
      .frame(minWidth: 180)
    }
  }
}

struct Swatch: View {
  let color: Color

  var body: some View {
    Circle()
      .fill(color)
      .overlay(Circle().strokeBorder(Color.primary.opacity(0.2)))
      .frame(width: 10, height: 10)
  }
}
