//
//  Item.swift
//  Pocket Dex
//
//  Created by Valerie Carruthers on 2026-07-01.
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
