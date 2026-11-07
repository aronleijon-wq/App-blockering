import SwiftUI

/// Pip's wardrobe: hats, glasses, shirts, things for the neck and back, colors and shapes, bought with seeds.
struct WardrobeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kind: WardrobeItem.Kind = .hat
    @State private var buying: WardrobeItem?
    @State private var isPaywallPresented = false
    @State private var isPickingFlag = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    MascotView(mood: .happy, level: model.progress.level, size: 150, outfit: model.progress.outfit)
                        .padding(.top, 8)
                    SeedsChip(seeds: model.progress.seeds)

                    kindPicker

                    if kind == .shirt, ownsFlagShirt {
                        Button { isPickingFlag = true } label: {
                            Label { Text(L("Byt flagga på tröjan")) } icon: { Text(Country.flag(flagCountry)) }
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.mint)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { item in
                            Button { tap(item) } label: { tile(item) }
                                .buttonStyle(.plain)
                        }
                    }

                    Text(L("Tjäna frön med uppdrag, fokuspass och dagens belöning. Säsongssakerna får du bara med månadens säsongsuppdrag, och kistsakerna bara i storkistorna på din resa."))
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
            .sheet(isPresented: $isPickingFlag) {
                FlagPicker(current: flagCountry) { model.chooseFlag($0) }
            }
        }
    }

    /// The kinds as a row of chips, which scroll when they don't all fit.
    private var kindPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WardrobeItem.Kind.allCases, id: \.self) { option in
                    kindChip(option)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }

    private func kindChip(_ option: WardrobeItem.Kind) -> some View {
        let isChosen = kind == option
        return Button {
            withAnimation(.snappy) { kind = option }
        } label: {
            Text(option.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isChosen ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isChosen ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Theme.cardRaised), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private var ownsFlagShirt: Bool {
        WardrobeItem.with(id: WardrobeItem.flagShirt).map { model.progress.owns($0) } ?? false
    }

    /// The flag on Pip's flag shirt, or the one it gets when put on.
    private var flagCountry: String {
        WardrobeItem.flagCountry(of: model.progress.outfit.shirt) ?? model.flagCountry
    }

    /// The items of the chosen kind. The NNN medal is only shown to those the challenge is offered to, or who won it.
    private var items: [WardrobeItem] {
        let offersChallenge = AdultLock.offersChallenge(to: model.introAnswers?.ageGroup)
        return WardrobeItem.all.filter { item in
            item.kind == kind && (item.id != AdultLock.challengeItem || offersChallenge || model.progress.owns(item))
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
        let worn = model.progress.outfit.wears(item)
        return VStack(spacing: 8) {
            ItemPreview(item: item, country: flagCountry)
                .frame(width: 70, height: 70)
            Text(item.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Group {
                if worn {
                    Text(L("På")).foregroundStyle(Theme.mint)
                } else if owned {
                    Text(L("Ägd")).foregroundStyle(.secondary)
                } else if let chest = Journey.chestLevel(giving: item.id) {
                    Label(L("Kista \(chest)"), systemImage: "gift.fill")
                        .foregroundStyle(Theme.orange)
                } else if item.isSeasonal {
                    Label(item.id == AdultLock.challengeItem ? L("NNN-utmaningen") : Season.giving(item: item.id)?.name ?? L("Säsong"),
                          systemImage: "sparkles")
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
    /// The flag a flag shirt shows.
    let country: String

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height) * 0.74
            PipAvatar(outfit: Outfit(wearing: item, country: country), level: 1, size: size)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}

/// Picks the country whose flag Pip's flag shirt shows.
private struct FlagPicker: View {
    let current: String
    let choose: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private struct Place: Identifiable {
        let id: String
        let name: String
    }

    private static let places: [Place] = {
        let locale = Language.current.locale
        let places = Locale.Region.isoRegions.compactMap { region -> Place? in
            let code = region.identifier
            guard Country.code(from: code) == code, let name = locale.localizedString(forRegionCode: code) else { return nil }
            return Place(id: code, name: name)
        }
        return places.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }()

    private var shown: [Place] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return Self.places }
        return Self.places.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.id.caseInsensitiveCompare(query) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List(shown) { place in
                Button {
                    choose(place.id)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(Country.flag(place.id))
                            .font(.title2)
                        Text(place.name)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if place.id == current {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.mint)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: L("Sök land"))
            .navigationTitle(L("Välj flagga"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Avbryt")) { dismiss() }
                }
            }
        }
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
        case .shirt: return L("Tröjor")
        case .shape: return L("Former")
        }
    }
}
