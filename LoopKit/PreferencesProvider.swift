//
//  PreferencesProvider.swift
//  LoopKit
//
//  Created by Jonas Björkert on 2024-02-25.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm

public protocol PreferencesProvider {
    var basalLockThreshold: LoopQuantity { get set }
    var isBasalLockEnabled: Bool { get set }
}
