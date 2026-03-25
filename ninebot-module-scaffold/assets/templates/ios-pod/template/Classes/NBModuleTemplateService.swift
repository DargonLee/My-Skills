//
//  NBModuleTemplateService.swift
//  NBModuleTemplate
//
//  Created by taowei on 2026/2/9.
//

import Foundation
import NBVAppProtocol
import NBVAppManager

@objc final class NBModuleTemplateService: NSObject, NBCapabilityProtocol {

    /// 【必须】提供 shared 单例
    static var shared: NSObject = NBModuleTemplateService.shared
    /// 【必须】提供 serviceName
    @objc public static let serviceName: String = "NBModuleTemplateService"
    /// 【必须】私有初始化（防止外部创建）
    private override init() { super.init() }

    /// 进入能力搜索页面
    /// - Parameter navi: 导航控制器
    public func enterCapabilitySearch(navi: UINavigationController?) {
        let vc = NBModuleTemplateVC()
        navi?.pushViewController(vc, animated: true)
    }

    /// 退出能力搜索页面
    /// - Parameter navi: 导航控制器
    public func exitCapabilitySearch(navi: UINavigationController?) {
        navi?.popViewController(animated: true)
    }

    /// 检查能力搜索是否可用
    /// - Returns: 是否可用
    public func isCapabilitySearchAvailable() -> Bool {
        return true
    }
}

// MARK: - 【必须】注册一个服务
public enum NBModuleTemplateReg: NBServiceRegistrable {
    public static func register() {
        NBVAppManager.shared.register(NBModuleTemplateService.self, as: NBCapabilityProtocol.self)
    }
}
