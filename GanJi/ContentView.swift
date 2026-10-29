import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var locator = LocationModel()
    @State private var markets = MarketStore.load()
    @State private var query = ""
    @State private var showingFavorites = false
    @State private var favorites = Set(UserDefaults.standard.stringArray(forKey: "favoriteMarketIDs") ?? [])
    @State private var isRefreshing = false
    @State private var loadMessage: String?

    private var filteredMarkets: [Market] {
        markets.filter { market in
            let matchesQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || market.name.localizedCaseInsensitiveContains(query)
                || market.area.localizedCaseInsensitiveContains(query)
                || (market.city ?? "").localizedCaseInsensitiveContains(query)
            return matchesQuery && (!showingFavorites || favorites.contains(market.id))
        }
    }

    private var rows: [MarketDay] {
        MarketStore.upcoming(from: Date(), markets: filteredMarkets)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    searchAndFilters
                    if locator.denied {
                        Label("未开启定位，距离显示不可用（不影响圩日）", systemImage: "location.slash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if isRefreshing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在更新本地区圩日…").font(.system(size: 12)).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let loadMessage {
                        Text(loadMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if rows.isEmpty {
                        ContentUnavailableView(
                            showingFavorites ? "还没有收藏的集市" : "没有找到集市",
                            systemImage: showingFavorites ? "heart" : "magnifyingglass",
                            description: Text(showingFavorites ? "点选集市旁的心形按钮即可收藏。" : "试试其他集市名或地区名称。")
                        )
                        .padding(.top, 20)
                    } else {
                        ForEach(rows) { row in
                            MarketCard(
                                row: row,
                                distanceText: distanceText(for: row),
                                isFavorite: favorites.contains(row.market.id),
                                onFavorite: { toggleFavorite(row.market.id) }
                            )
                        }
                    }
                    Text("圩期以数据记录为准 · \(LunarCalendar.ganzhiName(Date()))日 · v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await refreshMarkets() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel("刷新圩日")
                }
            }
        }
        .onAppear {
            locator.start()
            if markets.isEmpty { markets = MarketStore.load() }
            Task { await refreshMarkets() }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            Text("农历 " + LunarCalendar.lunarText(Date()) + " · " + LunarCalendar.ganzhiName(Date()) + "日")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "calendar").foregroundColor(.accentColor)
                Text("今日赶集").font(.system(size: 12, weight: .medium))
                Text("\(rows.filter { $0.daysAhead == 0 }.count) 个集市")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                Spacer()
                Text("未来 40 天排期").font(.system(size: 11)).foregroundColor(.secondary)
            }
            .padding(.top, 3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索集市或地区", text: $query)
                    .font(.system(size: 15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                filterButton("全部集市", selected: !showingFavorites) { showingFavorites = false }
                filterButton("我的收藏", selected: showingFavorites) { showingFavorites = true }
                Spacer()
                Text("\(rows.count) 个结果").font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
    }

    private func filterButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if title == "我的收藏" { Image(systemName: "heart.fill").font(.system(size: 10)) }
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(selected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? Color.accentColor : Color(UIColor.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        UserDefaults.standard.set(Array(favorites), forKey: "favoriteMarketIDs")
    }

    @MainActor
    private func refreshMarkets() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            // Default coverage starts with Pingnan County; cached data remains available offline.
            let fetched = try await MarketAPI.fetch(areaCode: 450821, province: "广西壮族自治区", city: "贵港市", area: "平南县")
            if !fetched.isEmpty {
                markets = fetched
                MarketCache.save(fetched, areaCode: 450821)
                loadMessage = "已更新平南县圩日数据"
            } else {
                loadMessage = "接口暂未返回圩日，继续显示本地数据"
            }
        } catch {
            if let cached = MarketCache.load(areaCode: 450821), !cached.isEmpty {
                markets = cached
                loadMessage = "网络暂不可用，正在显示缓存数据"
            } else {
                loadMessage = "网络暂不可用，正在显示内置圩日表"
            }
        }
    }

    private func distanceText(for row: MarketDay) -> String? {
        guard let lat = locator.latitude, let lon = locator.longitude else { return nil }
        return kmText(MarketStore.distanceKm(row.market, from: lat, lon: lon))
    }
}

struct MarketCard: View {
    let row: MarketDay
    let distanceText: String?
    let isFavorite: Bool
    let onFavorite: () -> Void

    private var badgeColor: Color {
        switch row.daysAhead {
        case 0: return Color(red: 0.18, green: 0.62, blue: 0.35)
        case 1: return Color(red: 0.18, green: 0.42, blue: 0.90)
        case 2: return Color(red: 0.90, green: 0.48, blue: 0.16)
        default: return Color(red: 0.45, green: 0.47, blue: 0.52)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(row.market.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
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
                Text("\(row.market.area) · \(row.branches.isEmpty ? row.market.branches : row.branches)日")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if let remark = row.market.remark, !remark.isEmpty {
                    Text(remark).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 7) {
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(isFavorite ? .pink : .secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(UIColor.tertiarySystemGroupedBackground), in: Circle())
                }
                .buttonStyle(.plain)
                if let distanceText {
                    Text(distanceText).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
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
