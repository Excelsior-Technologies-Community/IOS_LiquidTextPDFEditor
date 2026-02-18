//
//  WorkspaceModel.swift
//  LiquidTextPDFEditor
//
//  Created by Noman belim on 17/02/26.
//

import Foundation
import UIKit

struct PersistedBlock: Codable {
    var id: String
    var text: String?
    var imageData: Data?
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
}

struct PersistedConnection: Codable {
    var fromID: String
    var toID: String
}

struct WorkspaceState: Codable {
    var blocks: [PersistedBlock]
    var connections: [PersistedConnection]
}
