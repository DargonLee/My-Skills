//
//  NBSystemDeviceProtocol.swift
//  NBSystemDevice
//

import Foundation
import NBVAppProtocol

@objc public protocol NBSystemDeviceProtocol: NBBaseServiceProtocol {
    func setClipboard(_ text: String) -> Bool
    func getClipboard() -> String
}

extension NBSystemDeviceProtocol {
    public static var registrarName: String? {
        return "NBSystemDeviceReg"
    }
}
