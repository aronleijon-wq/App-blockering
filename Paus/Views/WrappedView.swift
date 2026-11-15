import SwiftUI

/// The player's year with Paus as a story to tap through, ending in a card to share, like a music app's wrap-up.
struct WrappedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let year: Int
    @State private var page = 0
    @State private var shareImage: Image?

    private var review: YearInReview {
        YearInReview.make(from: model.progress, year: year, at: .now, calendar: .current)
    }

    private struct Slide: Identifiable {
        let id: Int
        let colors: [Color]
        let kicker: String
        let big: String
        let line: String
    }

    private var slides: [Slide] {
        let r = review
        var out: [Slide] = []
        func add(_ colors: [Color], _ kicker: String, _ big: String, _ line: String) {
            out.append(Slide(id: out.count, colors: colors, kicker: kicker, big: big, line: line))
        }
        add([Theme.violet, Theme.pink], L("Paus Wrapped"), "\(year)", L("Ditt år med Pip. Tryck för att se."))
        add([Theme.pink, Theme.orange], L("Du tog tillbaka"), L("\(Format.number(r.hours)) timmar"),
            r.days >= 1 ? L("Det är \(r.days) hela dygn. Eller \(r.books) böcker.") : L("Varje minut räknas. Nästa år blir ännu större."))
        add([Color(red: 0.2, green: 0.55, blue: 1), Theme.violet], L("Fokuspass"), Format.number(r.focusSessions),
            L("På \(r.focusDays) olika dagar. Längsta streak: \(r.bestStreak) dagar."))
        if let best = r.bestDay, let date = DayKey.date(from: best, calendar: .current) {
            add([Theme.orange, Color(red: 0.95, green: 0.3, blue: 0.35)], L("Din bästa dag"),
                date.formatted(.dateTime.day().month(.wide).locale(Language.current.locale)),
                L("\(Format.minutes(r.bestDayMinutes)) fokus på en dag. Legendariskt."))
        }
        if let month = r.bestMonth {
            add([Color(red: 0.2, green: 0.75, blue: 0.5), Color(red: 0.1, green: 0.4, blue: 0.7)], L("Din bästa månad"),
                Season.monthName(String(format: "%04d-%02d", year, month)).capitalized,
                L("Och du stängde blockerade appar \(Format.number(r.closes)) gånger i år."))
        }
        if r.eggs > 0 {
            add([Color(red: 1, green: 0.8, blue: 0.3), Color(red: 0.85, green: 0.45, blue: 0.1)], L("Fokusägg kläckta"), Format.number(r.eggs),
                r.legendaryEggs > 0 ? L("Varav \(r.legendaryEggs) legendariska!") : L("Nästa år: jaga det legendariska."))
        }
        add([Theme.violet, Color(red: 0.15, green: 0.1, blue: 0.4)], L("Pip blev"), Level.title(for: r.level), L("Nivå \(r.level). Tack för att du tog hand om Pip."))
        return out
    }

    var body: some View {
        let all = slides
        ZStack {
            TabView(selection: $page) {
                ForEach(all) { slide in
                    slideView(slide)
                        .tag(slide.id)
                }
                shareSlide
                    .tag(all.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .animation(.easeInOut, value: page)

            VStack {
                HStack(spacing: 4) {
                    ForEach(0...all.count, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(index <= page ? 0.95 : 0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.25), in: Circle())
                    }
                    .accessibilityLabel(L("Stäng"))
                }
                .padding(.horizontal, 14)
                Spacer()
            }
        }
        .task { shareImage = renderShareImage() }
        .statusBarHidden()
    }

    private func slideView(_ slide: Slide) -> some View {
        ZStack {
            LinearGradient(colors: slide.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Text(slide.kicker.uppercased())
                    .font(.headline.weight(.heavy))
                    .tracking(1.5)
                    .opacity(0.85)
                Text(slide.big)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(slide.line)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .opacity(0.92)
                Spacer()
                MascotView(mood: slide.id == 0 ? .hyped : .proud, level: model.progress.level, size: 120, outfit: model.progress.outfit)
                    .padding(.bottom, 50)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { page += 1 } }
    }

    private var shareSlide: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                WrappedShareCard(review: review, outfit: model.progress.outfit)
                    .frame(width: 270, height: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: Theme.pink.opacity(0.4), radius: 24)
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview(L("Mitt år med Paus"), image: shareImage)) {
                        Label(L("Dela"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.horizontal, 40)
                }
                Spacer()
            }
        }
    }

    @MainActor
    private func renderShareImage() -> Image? {
        let renderer = ImageRenderer(content: WrappedShareCard(review: review, outfit: model.progress.outfit).frame(width: 360, height: 640))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// The card to share: the year's numbers, Pip and Paus, sized like a story.
struct WrappedShareCard: View {
    let review: YearInReview
    let outfit: Outfit

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.violet, Theme.pink, Theme.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 16) {
                Text(L("MITT \(String(review.year)) MED PAUS"))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                PipAvatar(outfit: outfit, level: review.level, size: 92)
                    .frame(width: 130, height: 130)
                stat(L("\(Format.number(review.hours)) h"), L("tillbakatagen tid"))
                HStack(spacing: 18) {
                    stat(Format.number(review.focusSessions), L("fokuspass"))
                    stat("\(review.bestStreak)", L("dagars streak"))
                }
                HStack(spacing: 18) {
                    stat(Format.number(review.eggs), L("ägg"))
                    stat(Level.title(for: review.level), L("titel"))
                }
                Spacer(minLength: 0)
                Text(L("Ta tillbaka din tid · Paus"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .padding(24)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity)
    }
}
