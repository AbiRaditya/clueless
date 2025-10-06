//
//  Item.swift
//  clueless
//
//  Created by Abi Raditya on 06/10/25.
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
