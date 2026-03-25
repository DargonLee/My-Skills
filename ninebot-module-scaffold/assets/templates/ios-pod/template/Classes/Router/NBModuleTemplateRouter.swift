//
//  NBModuleTemplateRouter.swift
//  NBModuleTemplate
//
//  Created by taowei on 2026/2/9.
//

import Foundation
import NBRouter

/// 路由处理器
/// 用于处理模块相关的路由跳转
@objcMembers
public class NBModuleTemplateRouterHandler: NSObject, NBRouteHandlerType {

    /// 是否可以打开指定路由
    /// - Parameter request: 路由请求
    /// - Returns: 是否可以打开
    public func canOpen(_ request: NBJumpRequest) -> Bool {
        #if DEBUG
        guard let destination = request.destination else {
            return false
        }
        return destinations.contains(destination)
        #else
        return false
        #endif
    }

    /// 路由目的地列表
    public var destinations: [String] {
        return ["nbTest"]
    }

    public required override init() {
        super.init()
    }

    /// 打开路由
    /// - Parameters:
    ///   - request: 路由请求
    ///   - context: 路由上下文
    public func open(_ request: NBJumpRequest, context: NBRouteContext) throws {
        // TODO: 实现路由打开逻辑
        // 例如：打开搜索页面
        // let vc = NBModuleTemplateVC()
        // context.navigate(to: vc)
    }
}
