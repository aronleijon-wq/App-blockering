import SwiftUI

/// Pip's wardrobe: hats, glasses, things for the neck and colors, bought with seeds.
struct WardrobeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kind: WardrobeItem.Kind = .hat
    @State private var buying: WardrobeItem?
    @State private var isPaywallPresented = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    MascotView(mood: .happy, level: model.progress.level, size: 150, outfit: model.progress.outfit)
                        .padding(.top, 8)
                    SeedsChip(seeds: model.progress.seeds)

                    Picker(L("Kategori"), selection: $kind) {
                        ForEach(WardrobeItem.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(WardrobeItem.all.filter { $0.kind == kind }) { item in
                            Button { tap(item) } label: { tile(item) }
                                .buttonStyle(.plain)
                        }
                    }

                    Text(L("Tjäna frön med uppdrag, fokuspass och dagens belöning. Säsongssakerna får du bara med månadens säsongsuppdrag."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle(L("Pips garderob"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Klar")) { dismiss() }
                }
            }
            .confirmationDialog(
                L("Köpa \(buying?.name ?? "")?"),
                isPresented: Binding(get: { buying != nil }, set: { if !$0 { buying = nil } }),
                titleVisibility: .visible
            ) {
                if let item = buying {
                    Button(L("Köp för \(item.price) frön")) { model.buy(item) }
                }
                Button(L("Avbryt"), role: .cancel) {}
            }
            .sheet(isPresented: $isPaywallPresented) {
                PaywallView()
            }
        }
    }

    private func tap(_ item: WardrobeItem) {
        if model.progress.owns(item) {
            model.toggle(item)
        } else if item.isSeasonal {
            return
        } else if item.needsPro && !model.isPro {
            isPaywallPresented = true
        } else if model.progress.seeds >= item.price {
            buying = item
        }
    }

    private func tile(_ item: WardrobeItem) -> some View {
        let owned = model.progress.owns(item)
        let worn = model.progress.outfit.item(for: item.kind) == item.id
        return VStack(spacing: 8) {
            ItemPreview(item: item)
                .frame(width: 70, height: 70)
            Text(item.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Group {
                if worn {
                    Text(L("På")).foregroundStyle(Theme.mint)
                } else if owned {
                    Text(L("Ägd")).foregroundStyle(.secondary)
                } else if item.isSeasonal {
                    Label(Season.giving(item: item.id)?.name ?? L("Säsong"), systemImage: "sparkles")
                        .foregroundStyle(Theme.orange)
                } else if item.needsPro && !model.isPro {
                    Label("PRO", systemImage: "lock.fill").foregroundStyle(Theme.pink)
                } else {
                    Label("\(item.price)", systemImage: "leaf.fill")
                        .foregroundStyle(model.progress.seeds >= item.price ? Theme.mint : .secondary)
                }
            }
            .font(.caption2.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(worn ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.clear), lineWidth: 2)
        }
        .opacity(owned || model.progress.seeds >= item.price || item.isSeasonal || (item.needsPro && !model.isPro) ? 1 : 0.55)
        .accessibilityElement(children: .combine)
    }
}

/// A still Pip wearing just this item, for the wardrobe grid, where dozens of animated ones would be too heavy.
private struct ItemPreview: View {
    let item: WardrobeItem

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height) * 0.78
            ZStack {
                if item.kind == .back {
                    PipItemView(id: item.id, size: size)
                }
                Ellipse()
                    .fill(LinearGradient(colors: PipColors.colors(for: item.kind == .color ? item.id : nil) ?? [Theme.mint, Color(red: 0.2, green: 0.75, blue: 0.95)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size, height: size * 0.94)
                HStack(spacing: size * 0.2) {
                    Circle().fill(.white).frame(width: size * 0.17)
                    Circle().fill(.white).frame(width: size * 0.17)
                }
                .offset(y: -size * 0.07)
                if item.kind != .color && item.kind != .back {
                    PipItemView(id: item.id, size: size)
                        .offset(PipItemView.offset(for: item.kind, size: size))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}

struct SeedsChip: View {
    let seeds: Int

    var body: some View {
        Label(L("\(seeds) frön"), systemImage: "leaf.fill")
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(Theme.mint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.mint.opacity(0.15), in: Capsule())
            .contentTransition(.numericText())
    }
}

extension WardrobeItem.Kind {
    var title: String {
        switch self {
        case .hat: return L("Hattar")
        case .glasses: return L("Glasögon")
        case .neck: return L("Hals")
        case .back: return L("Rygg")
        case .color: return L("Färger")
        }
    }
}
