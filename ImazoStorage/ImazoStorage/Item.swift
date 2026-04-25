//
//  Item.swift
//  ImazoStorage
//
//  Created by リョーマ on 2026/04/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
