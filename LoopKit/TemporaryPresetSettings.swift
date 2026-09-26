//
//  TemporaryScheduleOverrideSettings.swift
//  LoopKit
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopAlgorithm

public struct TemporaryPresetSettings: Hashable, Sendable {
    private var targetRangeInMgdl: DoubleRange?
    public var insulinNeedsScaleFactor: Double?
    public var limitAutomaticDosing: Bool

    public var targetRange: ClosedRange<LoopQuantity>? {
        return targetRangeInMgdl.map { $0.quantityRange(for: .milligramsPerDeciliter) }
    }

    public var basalRateMultiplier: Double? {
        return insulinNeedsScaleFactor
    }

    public var insulinSensitivityMultiplier: Double? {
        return insulinNeedsScaleFactor.map { 1.0 / $0 }
    }

    public var carbRatioMultiplier: Double? {
        return insulinNeedsScaleFactor.map { 1.0 / $0 }
    }

    public var effectiveInsulinNeedsScaleFactor: Double {
        return insulinNeedsScaleFactor ?? 1.0
    }

    public init(
        unit: LoopUnit,
        targetRange: DoubleRange?,
        insulinNeedsScaleFactor: Double? = nil,
        limitAutomaticDosing: Bool = false
    ) {
        self.init(
            targetRange: targetRange?.quantityRange(for: unit),
            insulinNeedsScaleFactor: insulinNeedsScaleFactor,
            limitAutomaticDosing: limitAutomaticDosing
        )
    }

    public init(
        targetRange: ClosedRange<LoopQuantity>?,
        insulinNeedsScaleFactor: Double? = nil,
        limitAutomaticDosing: Bool = false
    ) {
        self.targetRangeInMgdl = targetRange?.doubleRange(for: .milligramsPerDeciliter)
        self.insulinNeedsScaleFactor = insulinNeedsScaleFactor
        self.limitAutomaticDosing = limitAutomaticDosing
    }
}

extension TemporaryPresetSettings: RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum Key {
        static let targetRange = "targetRange"
        static let insulinNeedsScaleFactor = "insulinNeedsScaleFactor"
        static let limitAutomaticDosing = "limitAutomaticDosing"
        static let version = "version"
    }

    public init?(rawValue: RawValue) {
        self.limitAutomaticDosing = rawValue[Key.limitAutomaticDosing] as? Bool ?? false
        if let targetRangeRawValue = rawValue[Key.targetRange] as? DoubleRange.RawValue,
            let targetRange = DoubleRange(rawValue: targetRangeRawValue) {
            self.targetRangeInMgdl = targetRange
        }
        let version = rawValue[Key.version] as? Int ?? 0

        // Do not allow target ranges from versions < 1, as there was no unit convention at that point.
        if version < 1 && targetRange != nil {
            return nil
        }

        self.insulinNeedsScaleFactor = rawValue[Key.insulinNeedsScaleFactor] as? Double
    }

    public var rawValue: RawValue {
        var raw: RawValue = [:]

        if let targetRangeInMgdl = targetRangeInMgdl {
            raw[Key.targetRange] = targetRangeInMgdl.rawValue
        }

        if let insulinNeedsScaleFactor = insulinNeedsScaleFactor {
            raw[Key.insulinNeedsScaleFactor] = insulinNeedsScaleFactor
        }

        if limitAutomaticDosing {
            raw[Key.limitAutomaticDosing] = true
        }

        raw[Key.version] = 1

        return raw
    }
}

extension TemporaryPresetSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case targetRangeInMgdl
        case insulinNeedsScaleFactor
        case limitAutomaticDosing
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        targetRangeInMgdl = try container.decodeIfPresent(
            DoubleRange.self,
            forKey: .targetRangeInMgdl
        )
        insulinNeedsScaleFactor = try container.decodeIfPresent(
            Double.self,
            forKey: .insulinNeedsScaleFactor
        )
        limitAutomaticDosing = try container.decodeIfPresent(
            Bool.self,
            forKey: .limitAutomaticDosing
        ) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(
            targetRangeInMgdl,
            forKey: .targetRangeInMgdl
        )
        try container.encodeIfPresent(
            insulinNeedsScaleFactor,
            forKey: .insulinNeedsScaleFactor
        )

        if limitAutomaticDosing {
            try container.encode(true, forKey: .limitAutomaticDosing)
        }
    }
}
