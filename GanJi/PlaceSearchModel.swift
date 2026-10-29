import Foundation
import MapKit
import Combine

@MainActor
final class PlaceSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?
    private let completer = MKLocalSearchCompleter()
    private var pendingQuery = ""
    private var requestTask: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.8617, longitude: 104.1954),
            span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 60)
        )
    }

    func query(_ value: String) {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingQuery = text
        requestTask?.cancel()
        errorMessage = nil
        results = []
        guard text.count >= 2 else {
            isSearching = false
            completer.queryFragment = ""
            return
        }
        isSearching = true
        requestTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self, !Task.isCancelled, self.pendingQuery == text else { return }
            self.completer.queryFragment = text
        }
    }

    func clear() {
        requestTask?.cancel()
        pendingQuery = ""
        completer.queryFragment = ""
        results = []
        isSearching = false
        errorMessage = nil
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard completer.queryFragment == pendingQuery else { return }
        results = Array(completer.results.prefix(10))
        isSearching = false
        if results.isEmpty { errorMessage = "没有找到地点，请尝试更完整的名称。" }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard completer.queryFragment == pendingQuery else { return }
        results = []
        isSearching = false
        errorMessage = "地点搜索暂不可用，请检查网络后重试。"
    }
}
