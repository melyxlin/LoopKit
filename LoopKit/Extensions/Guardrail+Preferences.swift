//
//  Guardrail+Preferences.swift
//  LoopKit
//
//  Created by Jonas Björkert on 2024-02-25.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm

public extension Guardrail where Value == LoopQuantity {
    static let basalLockThreshold = Guardrail(
        absoluteBounds: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 200)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 300),
        recommendedBounds: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 220)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 300),
        startingSuggestion: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 250)
    )
}
