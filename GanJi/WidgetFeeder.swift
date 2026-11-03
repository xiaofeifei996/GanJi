import Foundation
import WidgetKit

/// 把 App 里「收藏的圩点」整理成小组件能直接用的规则快照。
///
/// 只写收藏，不写当前地区的全部圩点 —— 小组件要显示的是用户自己挑的圩。
/// 也只写「名字 + 地区 + 圩期规则」，不写坐标、地址、备注，更不写任何图片。
enum WidgetFeeder {

    static func publish(favorites: [Market]) {
        let rules = favorites.compactMap { market -> MarketRule? in
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
        WidgetFeed(
            source: WidgetFeed.favoriteSource,
            updatedAt: Date(),
            rules: rules
        ).publish()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
