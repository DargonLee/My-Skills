//
//  NBSystemDeviceService.swift
//  NBSystemDevice
//

import Foundation
import NBVAppManager
import NBVAppProtocol
import UIKit

@objc public final class NBSystemDeviceService: NSObject, NBSystemDeviceProtocol {
    public static let shared: NSObject = NBSystemDeviceService()
    @objc public static let serviceName: String = "NBSystemDeviceService"

    private override init() {
        super.init()
    }

    public func setClipboard(_ text: String) -> Bool {
        UIPasteboard.general.string = text
        return true
    }

    public func getClipboard() -> String {
        return UIPasteboard.general.string ?? ""
    }
}

public enum NBSystemDeviceReg: NBServiceRegistrable {
    public static func register() {
        NBVAppManager.shared.register(NBSystemDeviceService.self, as: NBSystemDeviceProtocol.self)

        NBUnifiedAPIRegistry.shared.register("setClipboard", ownerServiceName: NBSystemDeviceService.serviceName) { params, completion in
            guard let service = NBSystemDeviceService.shared as? NBSystemDeviceProtocol else {
                completion(["code": "-1", "message": "system device service unavailable"])
                return
            }

            guard let text = params?["text"] as? String else {
                completion(["code": "-1", "message": "invalid text"])
                return
            }

            completion(["success": service.setClipboard(text)])
        }

        NBUnifiedAPIRegistry.shared.register("getClipboard", ownerServiceName: NBSystemDeviceService.serviceName) { _, completion in
            guard let service = NBSystemDeviceService.shared as? NBSystemDeviceProtocol else {
                completion(["code": "-1", "message": "system device service unavailable"])
                return
            }

            completion(["text": service.getClipboard()])
        }
    }
}
