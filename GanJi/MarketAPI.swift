import Foundation

/// Loads market records for a selected county from the public market endpoint.
enum MarketAPI {
    private struct Envelope: Decodable {
        let total: Int?
        let data: [Record]
    }

    private struct Record: Decodable {
        let id: Int
        let name: String
        let marketType: Int?
        let repeatType: Int?
        let repeatValue: [String]?
        let remark: String?
        let place: String?
        let address: String?
        let gps: [Double]?
        let cityCode: Int?
        let areaCode: Int?
        let status: Int?

        enum CodingKeys: String, CodingKey {
            case id, name, remark, place, address, gps, status
            case marketType = "market_type"
            case repeatType = "repeat_type"
            case repeatValue = "repeat_value"
            case cityCode = "citycode"
            case areaCode = "areacode"
        }
    }

    static func fetch(areaCode: Int, province: String = "", city: String = "", area: String = "") async throws -> [Market] {
        var components = URLComponents(string: "https://api.ganjirili.com/gathers")!
        components.queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pageSize", value: "199"),
            URLQueryItem(name: "areacode", value: String(areaCode))
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (rawData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let data: Data
        if (try? JSONSerialization.jsonObject(with: rawData)) != nil {
            data = rawData
        } else if let text = String(data: rawData, encoding: .utf8),
                  let decoded = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  (try? JSONSerialization.jsonObject(with: decoded)) != nil {
            data = decoded
        } else {
            throw URLError(.cannotParseResponse)
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        return envelope.data.compactMap { item in
            guard let gps = item.gps, gps.count >= 2 else { return nil }
            let values = item.repeatValue ?? []
            let branchMap = ["鼠":"子","牛":"丑","虎":"寅","兔":"卯","龙":"辰","蛇":"巳","马":"午","羊":"未","猴":"申","鸡":"酉","狗":"戌","猪":"亥"]
            let branches = item.repeatType == 6 ? values.compactMap { branchMap[$0] }.joined() : ""
            return Market(
                id: String(item.id),
                name: item.name,
                area: area,
                branches: branches,
                lat: gps[1],
                lon: gps[0],
                size: item.marketType == 1 ? "大集" : "集市",
                province: province,
                city: city,
                cityCode: item.cityCode,
                areaCode: item.areaCode ?? areaCode,
                repeatType: item.repeatType,
                repeatValue: values,
                remark: item.remark ?? "",
                place: item.place ?? "",
                address: item.address ?? "",
                status: item.status
            )
        }.filter { $0.status == nil || $0.status == 1 }
    }
}

enum MarketCache {
    private static func url(for areaCode: Int) -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("markets-\(areaCode).json")
    }

    static func save(_ markets: [Market], areaCode: Int) {
        guard let url = url(for: areaCode),
              let data = try? JSONEncoder().encode(Wrapper(markets: markets)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load(areaCode: Int) -> [Market]? {
        guard let url = url(for: areaCode),
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data) else { return nil }
        return wrapper.markets
    }

    private struct Wrapper: Codable { let markets: [Market] }
}