import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var locator = LocationModel()
    @State private var rows: [MarketDay] = MarketStore.upcoming(from: Date())

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    if locator.denied {
                        Text("未开启定位，距离显示不可用（不影响圩日）")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(rows) { row in
                        MarketCard(row: row, distanceText: distanceText(for: row))
                    }
                    Text("三日一圩 · \(LunarCalendar.ganzhiName(Date()))日 · v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") · 数据来源：圩日表")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("赶集日记").font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .onAppear {
            rows = MarketStore.upcoming(from: Date())
            locator.start()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(LunarCalendar.shortDate(Date()))
                    .font(.system(size: 26, weight: .bold))
                Text(LunarCalendar.weekdayText(Date()))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(LunarCalendar.branchName(Date()))日 · \(LunarCalendar.zodiacName(Date()))")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                    .foregroundColor(.accentColor)
            }
            Text("农历 " + LunarCalendar.lunarText(Date()))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private func distanceText(for row: MarketDay) -> String? {
        guard let lat = locator.latitude, let lon = locator.longitude else { return nil }
        let km = MarketStore.distanceKm(row.market, from: lat, lon: lon)
        return kmText(km)
    }
}

struct MarketCard: View {
    let row: MarketDay
    let distanceText: String?

    private var badgeColor: Color {
        switch row.daysAhead {
        case 0: return Color(red: 0.18, green: 0.72, blue: 0.31)
        case 1: return Color(red: 0.18, green: 0.42, blue: 0.90)
        case 2: return Color(red: 0.95, green: 0.55, blue: 0.13)
        default: return Color(red: 0.45, green: 0.47, blue: 0.52)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(row.market.name)
                        .font(.system(size: 17, weight: .semibold))
                    Text(row.market.size)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(badgeColor))
                    Text(row.dayLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(badgeColor.opacity(0.75)))
                }
                Text("\(row.market.area) · \(row.branches)日 · 属相 \(row.animals)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let d = distanceText {
                    Text(d)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text(LunarCalendar.shortDate(row.date))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}
