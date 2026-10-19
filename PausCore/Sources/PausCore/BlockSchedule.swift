import Foundation

/// A weekly window when the selected apps are blocked.
/// A window whose end is at or before its start runs past midnight into the next day.
struct BlockSchedule: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    /// Weekdays the window starts on, using `Calendar` numbering (1 = Sunday … 7 = Saturday).
    var weekdays: Set<Int>
    /// Minutes after midnight, 0..<1440.
    var startMinute: Int
    var endMinute: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        weekdays: Set<Int>,
        startMinute: Int,
        endMinute: Int,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.weekdays = weekdays
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        weekdays = try container.decode(Set<Int>.self, forKey: .weekdays)
        startMinute = try container.decode(Int.self, forKey: .startMinute)
        endMinute = try container.decode(Int.self, forKey: .endMinute)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    var crossesMidnight: Bool { endMinute <= startMinute }

    /// Length of the window in minutes; a window with equal start and end lasts a full day.
    var durationMinutes: Int {
        let minutes = (endMinute - startMinute + 1440) % 1440
        return minutes == 0 ? 1440 : minutes
    }

    /// The window that contains `date`, if any. Checks windows starting today and yesterday.
    func activeWindow(containing date: Date, calendar: Calendar) -> DateInterval? {
        guard isEnabled, !weekdays.isEmpty else { return nil }
        let startOfToday = calendar.startOfDay(for: date)
        for dayOffset in [0, -1] {
            guard
                let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
                weekdays.contains(calendar.component(.weekday, from: day)),
                let window = window(startingOn: day, calendar: calendar),
                window.start <= date, date < window.end
            else { continue }
            return window
        }
        return nil
    }

    private func window(startingOn day: Date, calendar: Calendar) -> DateInterval? {
        guard
            let start = calendar.date(bySettingHour: startMinute / 60, minute: startMinute % 60, second: 0, of: day),
            let endDay = crossesMidnight ? calendar.date(byAdding: .day, value: 1, to: day) : day,
            let end = calendar.date(bySettingHour: endMinute / 60, minute: endMinute % 60, second: 0, of: endDay),
            end > start
        else { return nil }
        return DateInterval(start: start, end: end)
    }
}
