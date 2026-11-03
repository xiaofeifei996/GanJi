import Foundation
import WidgetKit

/// 把 App 里「收藏的圩点」整理成小组件能直接用的规则快照。
///
/// 只写收藏，不写当前地区的全部圩点 —— 小组件要显示的是用户自己挑的圩。
/// 也只写「名字 + 地区 + 圩期规则」，不写坐标、地址、备注，更不写任何图片。
enum WidgetFeeder {

    static func publish(favorites: [Market]) {
        // 全部收藏都过一遍，不做「是否可判定」的筛选：
        // 少一条会让小组件的「收藏 N 处」和 App 对不上。
        // 规则无法判定的圩（repeatType 非 1/4/6）只是永远不开圩，不影响计数。
        let rules = favorites.map { market in
            MarketRule(
                id: market.id,
                name: market.name,
                area: market.area,
                repeatType: market.repeatType ?? 0,
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
