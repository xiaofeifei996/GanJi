import Foundation
import WidgetKit

/// 把 App 里当前的圩点整理成小组件能直接用的规则快照。
///
/// 只写「名字 + 地区 + 圩期规则」，不写坐标、地址、备注，
/// 也不写任何图片 —— 小组件那边完全自绘。
enum WidgetFeeder {

    static func publish(markets: [Market], region: String) {
        let rules = markets.compactMap { market -> MarketRule? in
            guard let type = market.repeatType, type == 1 || type == 4 || type == 6,
                  !market.repeatValue.isEmpty else { return nil }
            return MarketRule(
                id: market.id,
                name: market.name,
                area: market.area,
                repeatType: type,
                repeatValue: market.repeatValue
            )
        }
        WidgetFeed(updatedAt: Date(), regionName: region, rules: rules).publish()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
