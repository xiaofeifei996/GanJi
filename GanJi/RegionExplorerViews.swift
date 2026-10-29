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

struct RegionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: RegionArea
    let onSelect: (RegionArea) -> Void
    @State private var searchText = ""

    private var areas: [RegionArea] {
        guard !searchText.isEmpty else { return RegionArea.supported }
        return RegionArea.supported.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.city.localizedCaseInsensitiveContains(searchText)
                || $0.province.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("目前已接入数据的县级地区")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    ForEach(areas) { area in
                        Button {
                            selection = area
                            onSelect(area)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(area.name).foregroundColor(.primary)
                                    Text("\(area.province) · \(area.city)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selection == area {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("省级全国搜索可通过地图地点搜索使用；县级圩日数据当前覆盖列表中的地区，其他地区需要补充接口行政区划数据。")
                }
            }
            .searchable(text: $searchText, prompt: "搜索省、市、县")
            .navigationTitle("选择赶集地区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
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
