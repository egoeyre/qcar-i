//
//  Item.swift
//  qcar
//
//  Created by ego on 2025/12/7.
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
