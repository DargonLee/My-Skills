//
//  SearchDataModels.swift
//  NBModuleTemplate
//
//  Created by taowei on 2026/1/30.
//

import Foundation

// MARK: - 数据模型

/// feature_search_list.json 顶层结构
struct NBModuleTemplateFeatureSearchList: Codable {
    let version: String?
    let search_items: [NBModuleTemplateFeatureSearchItem]
}

/// 单条搜索能力配置
struct NBModuleTemplateFeatureSearchItem: Codable {
    let capability_id: String
    let title: String
    let tips: String?
    let keywords: [String]
    let navigationPath: [NBModuleTemplateFeatureNavigationNode]?
    let scenes: [String]?
}

/// 导航节点
struct NBModuleTemplateFeatureNavigationNode: Codable {
    let capability_id: String
}

/// vehicle_features_config.json 顶层结构
struct NBModuleTemplateVehicleFeaturesConfig: Codable {
    let version: String?
    let capability: [NBModuleTemplateVehicleFeature]
}

/// 单条功能配置
struct NBModuleTemplateVehicleFeature: Codable {
    let capability_id: String
    let title: String?
    let icon: String?
    let tips: String?
    let jump: NBModuleTemplateVehicleFeatureJump?
}

struct NBModuleTemplateVehicleFeatureJump: Codable {
    let page: String?
}

/// 搜索结果 Cell 数据
struct NBModuleTemplateSearchResultCell {
    let item: NBModuleTemplateFeatureSearchItem
    let feature: NBModuleTemplateVehicleFeature?
    let level: Int
    let breadcrumbs: [String]
    let tips: String?
    let capability_id: String
}

/// 搜索结果分组
struct NBModuleTemplateSearchResultGroup {
    let topLevelCell: NBModuleTemplateSearchResultCell
    var childCells: [NBModuleTemplateSearchResultCell]
}
