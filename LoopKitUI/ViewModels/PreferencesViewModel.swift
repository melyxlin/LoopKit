//
//  PreferencesViewModel.swift
//  LoopKitUI
//
//  Created by Jonas Björkert on 2024-02-25.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import LoopAlgorithm

public class PreferencesViewModel: ObservableObject {
    @Published var basalLockThreshold: LoopQuantity
    @Published var isBasalLockEnabled: Bool

    private var preferencesProvider: PreferencesProvider

    public init(preferencesProvider: PreferencesProvider) {
        self.preferencesProvider = preferencesProvider
        self.basalLockThreshold = preferencesProvider.basalLockThreshold
        self.isBasalLockEnabled = preferencesProvider.isBasalLockEnabled
    }

    func updateBasalLockThreshold(_ newValue: LoopQuantity) {
        preferencesProvider.basalLockThreshold = newValue
        self.basalLockThreshold = newValue
    }

    func updateBasalLockEnabled(_ newValue: Bool) {
        preferencesProvider.isBasalLockEnabled = newValue
        self.isBasalLockEnabled = newValue
    }
}
