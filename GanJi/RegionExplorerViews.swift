import SwiftUI
import MapKit
import UIKit

struct RegionArea: Hashable, Identifiable {
    let code: Int
    let name: String
    let city: String
    let province: String
    var id: Int { code }

    static let pingnan = RegionArea(code: 450821, name: "平南县", city: "贵港市", province: "广西壮族自治区")
    static let supported: [RegionArea] = [
        .pingnan,
        RegionArea(code: 450881, name: "桂平市", city: "贵港市", province: "广西壮族自治区"),
        RegionArea(code: 450924, name: "兴业县", city: "玉林市", province: "广西壮族自治区"),
        RegionArea(code: 451324, name: "金秀瑶族自治县", city: "来宾市", province: "广西壮族自治区")
    ]
}

private struct RegionOption: Identifiable, Hashable {
    enum Kind { case province, city, county }
    let code: Int
    let name: String
    let city: String
    let province: String
    let kind: Kind
    var id: Int { code }
}

@MainActor
private final class RegionCatalog: ObservableObject {
    @Published var options: [RegionOption] = []
    @Published var isLoading = false
    @Published var message: String?
    
    func load() async {
        guard options.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let sources = [
            "https://dmfw.mca.gov.cn/9095/xzqh/getList?code=&maxLevel=3",
            "https://unpkg.com/province-city-china@latest/dist/level.json"
        ]
        for source in sources {
            guard let url = URL(string: source) else { continue }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 20
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { continue }
                let root = try JSONSerialization.jsonObject(with: data)
                var parsed: [RegionOption] = []
                var seen = Set<Int>()
                func walk(_ value: Any, province: String, city: String, depth: Int) {
                    guard depth < 16 else { return }
                    if let array = value as? [Any] {
                        for item in array { walk(item, province: province, city: city, depth: depth + 1) }
                        return
                    }
                    guard let object = value as? [String: Any] else { return }
                    let codeKeys = ["code", "xzqhCode", "areaCode", "adcode", "value", "id", "c"]
                    let nameKeys = ["name", "xzqhName", "areaName", "label", "title", "n"]
                    let rawCode = codeKeys.compactMap { object[$0] }.compactMap { item -> String? in
                        if let string = item as? String { return string }
                        if let number = item as? NSNumber { return number.stringValue }
                        return nil
                    }.first(where: { $0.allSatisfy(\.isNumber) && [2, 4, 6, 9, 12].contains($0.count) })
                    let rawName = nameKeys.compactMap { object[$0] as? String }.first
                    var nextProvince = province
                    var nextCity = city
                    if let rawCode, let rawName, !rawName.isEmpty {
                        let digits = String(rawCode.prefix(6))
                        if digits.count == 6, let code = Int(digits) {
                            let kind: RegionOption.Kind
                            if digits.hasSuffix("0000") { kind = .province; nextProvince = rawName; nextCity = "" }
                            else if digits.hasSuffix("00") { kind = .city; nextCity = rawName }
                            else { kind = .county }
                            if seen.insert(code).inserted {
                                parsed.append(RegionOption(code: code, name: rawName,
                                    city: kind == .county ? city : (kind == .city ? province : ""),
                                    province: kind == .province ? rawName : province, kind: kind))
                            }
                        }
                    }
                    let metadata = Set(codeKeys + nameKeys + ["province", "city", "area", "town", "parent", "parentCode", "parent_adcode", "level"])
                    for (key, child) in object where !metadata.contains(key) {
                        if child is [Any] || child is [String: Any] {
                            walk(child, province: nextProvince, city: nextCity, depth: depth + 1)
                        }
                    }
                }
                walk(root, province: "", city: "", depth: 0)
                guard parsed.filter({ $0.kind == .county }).count > 2500 else { continue }
                options = parsed.sorted {
                    if $0.province != $1.province { return $0.province.localizedCompare($1.province) == .orderedAscending }
                    if $0.city != $1.city { return $0.city.localizedCompare($1.city) == .orderedAscending }
                    return $0.name.localizedCompare($1.name) == .orderedAscending
                }
                message = "行政区划已加载。注意：行政区划覆盖全国，但圩日数据可能仅覆盖部分地区。"
                return
            } catch { continue }
        }
        options = RegionArea.supported.map {
            RegionOption(code: $0.code, name: $0.name, city: $0.city, province: $0.province, kind: .county)
        }
        message = "全国行政区划加载失败，暂显示内置地区。"
    }
}

struct RegionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: RegionArea
    let onSelect: (RegionArea) -> Void
    @StateObject private var catalog = RegionCatalog()
    @State private var searchText = ""

    private var results: [RegionOption] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return catalog.options.filter { $0.kind == .county }.prefix(120).map { $0 } }
        return catalog.options.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.city.localizedCaseInsensitiveContains(q)
                || $0.province.localizedCaseInsensitiveContains(q)
        }.sorted {
            let a = $0.kind == .county ? 0 : ($0.kind == .city ? 1 : 2)
            let b = $1.kind == .county ? 0 : ($1.kind == .city ? 1 : 2)
            return a == b ? $0.name.localizedCompare($1.name) == .orderedAscending : a < b
        }.prefix(80).map { $0 }
    }

    var body: some View {
        NavigationView {
            List {
                if catalog.isLoading {
                    HStack { ProgressView(); Text("正在加载全国行政区划…").font(.footnote) }
                }
                if let message = catalog.message {
                    Text(message).font(.footnote).foregroundColor(.secondary)
                }
                Section("搜索行政区划") {
                    ForEach(results) { option in
                        Button {
                            guard option.kind == .county else { return }
                            let area = RegionArea(code: option.code, name: option.name, city: option.city, province: option.province)
                            selection = area
                            onSelect(area)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.name).foregroundColor(.primary)
                                    Text([option.province, option.city].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if option.kind != .county {
                                    Text(option.kind == .province ? "省级" : "市级")
                                        .font(.caption).foregroundColor(.secondary)
                                } else if selection.code == option.code {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                                }
                            }
                        }
                        .disabled(option.kind != .county)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "输入省、市、县名称")
            .navigationTitle("选择赶集地区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } }
            }
            .task { await catalog.load() }
        }
    }
}

private struct MarketPin: Identifiable {
    let market: Market
    var id: String { market.id }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: market.lat, longitude: market.lon)
    }
}

struct MarketMapView: View {
    @Environment(\.dismiss) private var dismiss
    let markets: [Market]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 23.55, longitude: 110.4),
        span: MKCoordinateSpan(latitudeDelta: 1.4, longitudeDelta: 1.4)
    )
    @StateObject private var placeSearch = PlaceSearchModel()
    @State private var searchText = ""
    @State private var selectedMarket: Market?
    @State private var searchError: String?

    private var pins: [MarketPin] { markets.map(MarketPin.init) }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("搜索地点、城市、街道", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: searchText) { placeSearch.query($0) }
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                placeSearch.clear()
                                searchError = nil
                            } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                        }
                    }
                    .padding(11)
                    .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    if placeSearch.isSearching { ProgressView().frame(maxWidth: .infinity, alignment: .leading) }
                    if let error = placeSearch.errorMessage {
                        Text(error).font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !placeSearch.results.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(placeSearch.results.enumerated()), id: \.offset) { _, item in
                                    Button {
                                        Task { await selectPlace(item) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.title).foregroundColor(.primary)
                                            if !item.subtitle.isEmpty {
                                                Text(item.subtitle).font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                    }
                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    }
                }
                .padding(12)

                Map(coordinateRegion: $region, annotationItems: pins) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        Button { selectedMarket = pin.market } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.red)
                                Text(pin.market.name)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color(UIColor.systemBackground).opacity(0.92), in: Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        region = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: 23.55, longitude: 110.4),
                            span: MKCoordinateSpan(latitudeDelta: 1.4, longitudeDelta: 1.4)
                        )
                    } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(11)
                            .background(Color(UIColor.systemBackground), in: Circle())
                            .shadow(radius: 2)
                    }
                    .padding(12)
                }
                if let selectedMarket {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(selectedMarket.name).font(.headline)
                            Spacer()
                            Button { self.selectedMarket = nil } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                        }
                        Text("\(selectedMarket.province ?? "") \(selectedMarket.city ?? "") \(selectedMarket.area)")
                            .font(.subheadline).foregroundColor(.secondary)
                        if let address = selectedMarket.address, !address.isEmpty {
                            Text(address).font(.caption).foregroundColor(.secondary)
                        }
                        Text("圩期：\(selectedMarket.branches)日")
                            .font(.subheadline)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                }
            }
            .navigationTitle("集市地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func selectPlace(_ completion: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: completion)
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                searchError = "未找到地点坐标"
                return
            }
            region = MKCoordinateRegion(
                center: item.placemark.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
            searchText = completion.title
            placeSearch.clear()
            searchError = nil
        } catch {
            searchError = "地点定位失败，请重试。"
        }
    }
}
