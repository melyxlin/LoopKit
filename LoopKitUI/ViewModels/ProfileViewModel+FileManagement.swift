//
//  ProfileViewModel+FileManagement.swift
//  LoopKitUI
//
//  Created by Jonas Björkert on 2023-05-19.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import LoopKit
import HealthKit

public enum ProfileValidationError: Error, LocalizedError {
    case fileLoadError
    case unsupportedIncrement
    case correctionRangeError
    case insulinSensitivityError
    case carbRatioError
    case basalRateError
    case maxBasalRateNotSet

    public var errorDescription: String? {
        switch self {
        case .fileLoadError:
            return "Unable to load the profile file."
        case .unsupportedIncrement:
            return "The profile contains unsupported increments."
        case .correctionRangeError:
            return "Correction Range values are out of bounds."
        case .insulinSensitivityError:
            return "Insulin Sensitivity values are out of bounds."
        case .carbRatioError:
            return "Carb Ratio values are out of bounds."
        case .basalRateError:
            return "Basal Rate values are out of bounds."
        case .maxBasalRateNotSet:
            return "Maximum Basal Rate is not set."
        }
    }
}

public enum LoadProfileResult {
    case success
    case failure(Error)
}

// MARK: File management
extension ProfileViewModel {
    private func setCurrentProfile(name: String, syncChange: Bool = false) {
        let sanitizedProfileName = sanitizeProfileName(name)
        currentProfileName = sanitizedProfileName
        if syncChange {
            triggerProfileSync()
        }
    }
    
    private func clearCurrentProfile() {
        currentProfileName = nil
        triggerProfileSync()
    }
    
    private func getCurrentProfileName() -> String? {
        return currentProfileName
    }
    
    private var profilesDirectory: URL {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("LoopProfile")
    }

    private func createProfileDirectoryIfNotExists() throws {
        let fileManager = FileManager.default
        var isDir : ObjCBool = false
        if !fileManager.fileExists(atPath: profilesDirectory.path, isDirectory: &isDir) {
            try fileManager.createDirectory(at: profilesDirectory, withIntermediateDirectories: true, attributes: nil)
        } else if !isDir.boolValue {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: nil)
        }
    }

    private func getAllProfileFiles() throws -> [URL] {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil)
        return files.filter { $0.pathExtension == "json" }
    }

    private func encodeProfile(_ profile: Profile) throws -> Data {
        return try JSONEncoder().encode(profile)
    }

    private func decodeProfile(from data: Data) throws -> Profile {
        return try JSONDecoder().decode(Profile.self, from: data)
    }

    public func sanitizeProfileName(_ name: String) -> String {
        // Replace problematic characters
        var sanitized = name.replacingOccurrences(of: ".", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "<", with: "_")

        // Limit the name to 32 characters
        if sanitized.count > 32 {
            sanitized = String(sanitized.prefix(32))
        }

        return sanitized
    }

    public func saveProfile(withName name: String) {
        let sanitizedName = sanitizeProfileName(name)

        do {
            try createProfileDirectoryIfNotExists()

            if let existingProfile = getProfileReference(withName: sanitizedName) {
                removeProfile(profileReference: existingProfile)
            }

            let profile = Profile(
                name: sanitizedName,
                correctionRange: (therapySettings.glucoseTargetRangeSchedule?.schedule(for: .milligramsPerDeciliter)!)!,
                carbRatioSchedule: therapySettings.carbRatioSchedule!,
                basalRateSchedule: therapySettings.basalRateSchedule!,
                insulinSensitivitySchedule: (therapySettings.insulinSensitivitySchedule?.schedule(for: .milligramsPerDeciliter)!)!,
                sortOrder: -1
            )

            let jsonData = try encodeProfile(profile)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let fileName = dateFormatter.string(from: Date()) + ".json"
            let fileURL = profilesDirectory.appendingPathComponent(fileName)

            try jsonData.write(to: fileURL)
            setCurrentProfile(name: sanitizedName, syncChange: true)

            self.loadProfiles()
        } catch {
            print("An error occurred while saving profile: \(error)")
        }
    }

    public func renameProfile(oldName: String, newName: String) {
        let sanitizedProfileName = sanitizeProfileName(newName)

        if currentProfileName == oldName {
            setCurrentProfile(name: sanitizedProfileName, syncChange: true)
        }
        
        do {
            guard let profileReference = getProfileReference(withName: oldName) else {
                print("Profile with old name not found.")
                return
            }
            
            let profile = try getProfile(from: profileReference)
            
            let newProfile = Profile(
                name: sanitizedProfileName,
                correctionRange: profile.correctionRange,
                carbRatioSchedule: profile.carbRatioSchedule,
                basalRateSchedule: profile.basalRateSchedule,
                insulinSensitivitySchedule: profile.insulinSensitivitySchedule,
                sortOrder: profile.sortOrder
            )
            
            if let existingProfile = getProfileReference(withName: sanitizedProfileName) {
                removeProfile(profileReference: existingProfile)
            }
            
            let jsonData = try encodeProfile(newProfile)
            let fileURL = profilesDirectory.appendingPathComponent(profileReference.fileName)
            
            try jsonData.write(to: fileURL)
            
            self.loadProfiles()
            triggerProfileSync()
        } catch {
            print("An error occurred while renaming profile: \(error)")
        }
    }

    public func updateProfilesOrder() {
        for (index, profileReference) in profiles.enumerated() {
            do {
                var profile = try getProfile(from: profileReference)
                let newProfile = Profile(
                    name: profile.name,
                    correctionRange: profile.correctionRange,
                    carbRatioSchedule: profile.carbRatioSchedule,
                    basalRateSchedule: profile.basalRateSchedule,
                    insulinSensitivitySchedule: profile.insulinSensitivitySchedule,
                    sortOrder: index
                )
                
                let jsonData = try encodeProfile(newProfile)
                let fileURL = profilesDirectory.appendingPathComponent(profileReference.fileName)
                try jsonData.write(to: fileURL)
                
            } catch {
                print("An error occurred while updating profile order: \(error)")
            }
        }
        loadProfiles()
    }
    
    public func loadProfiles() {
        do {
            let profileFiles = try getAllProfileFiles()
            
            var newProfiles = [ProfileReference]()
            for fileURL in profileFiles {
                let data = try Data(contentsOf: fileURL)
                let profile = try decodeProfile(from: data)
                let profileRef = ProfileReference(name: sanitizeProfileName(profile.name), fileName: fileURL.lastPathComponent, sortOrder: profile.sortOrder)
                newProfiles.append(profileRef)
            }
            
            newProfiles.sort { $0.sortOrder ?? 0 < $1.sortOrder ?? 0 }
            
            self.profiles = newProfiles
        } catch {
            print("An error occurred while loading profiles: \(error)")
        }
    }

    public func loadProfile(profile: Profile, completion: @escaping (LoadProfileResult) -> Void) {
        if(therapySettings.glucoseTargetRangeSchedule == profile.correctionRange &&
           therapySettings.carbRatioSchedule == profile.carbRatioSchedule &&
           therapySettings.basalRateSchedule == profile.basalRateSchedule &&
           therapySettings.insulinSensitivitySchedule == profile.insulinSensitivitySchedule) {
            self.setCurrentProfile(name: profile.name, syncChange: true)
            completion(.success)
        }
        else
        {
            do {
                delegate?.syncBasalRateSchedule(items: profile.basalRateSchedule.items, completion: { result in
                    switch result {
                    case .success(let syncedSchedule):
                        DispatchQueue.main.async {
                            let previousSettings = self.therapySettings
                            let unit = self.therapySettings.glucoseTargetRangeSchedule?.unit ?? LoopUnit.milligramsPerDeciliter
                            self.therapySettings.glucoseTargetRangeSchedule = profile.correctionRange.schedule(for: unit)!
                            self.therapySettings.carbRatioSchedule = profile.carbRatioSchedule
                            self.therapySettings.basalRateSchedule = syncedSchedule
                            self.therapySettings.insulinSensitivitySchedule = profile.insulinSensitivitySchedule.schedule(for: unit)!
                            // One settings change, so the stored and uploaded settings never mix two profiles.
                            self.setCurrentProfile(name: profile.name, syncChange: false)
                            self.delegate?.saveCompletion(therapySettings: self.therapySettings)
                            if self.therapySettings == previousSettings {
                                // Nothing changed, so only the profile name needs to reach the uploaded settings.
                                self.triggerProfileSync()
                            }
                            print("New profile loaded")
                            completion(.success)
                        }
                    case .failure(let error):
                        print("An error occurred while syncing basal rates: \(error)")
                        completion(.failure(error))
                    }
                })
            }
        }
    }

    func getProfileReference(withName name: String) -> ProfileReference? {
        let sanitizedInputName = sanitizeProfileName(name)
        return profiles.first(where: { sanitizeProfileName($0.name) == sanitizedInputName })
    }

    public func removeProfile(profile: Profile) {
        guard let profileReference = getProfileReference(withName: profile.name) else {
            print("No ProfileReference found for given Profile")
            return
        }

        removeProfile(profileReference: profileReference)
        if getCurrentProfileName() == profile.name {
            clearCurrentProfile()
        } else {
            triggerProfileSync()
        }
    }

    public func removeProfile(profileReference: ProfileReference) {
        do {
            let fileManager = FileManager.default
            let fileURL = profilesDirectory.appendingPathComponent(profileReference.fileName)
            try fileManager.removeItem(at: fileURL)
            loadProfiles()
        } catch {
            print("An error occurred while removing profile: \(error)")
        }
    }

    func doesProfileExist(withName name: String) -> Bool {
        return profiles.contains(where: { $0.name == name })
    }

    public func getProfile(from profileReference: ProfileReference) throws -> Profile {
        let fileURL = profilesDirectory.appendingPathComponent(profileReference.fileName)
        let data = try Data(contentsOf: fileURL)
        let getProfile = try decodeProfile(from: data)
        return getProfile
    }

    /// The saved profile named `name`, or nil when there is none.
    public func savedProfile(named name: String) throws -> Profile? {
        guard let profileReference = profiles.first(where: { $0.name == name }) else {
            return nil
        }
        return try getProfile(from: profileReference)
    }

    public func validateProfile(_ profile: Profile) -> Result<Void, ProfileValidationError> {
        guard let supportedIncrements = delegate?.pumpSupportedIncrements() else {
            return .failure(.fileLoadError)
        }

        // Checking Correction Range Schedule
        for item in profile.correctionRange.items {
            let minValue = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: item.value.minValue)
            let maxValue = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: item.value.maxValue)

            if !(Guardrail.correctionRange.absoluteBounds.contains(minValue) && Guardrail.correctionRange.absoluteBounds.contains(maxValue)) {
                return .failure(.correctionRangeError)
            }
        }

        // Checking Insulin Sensitivity Schedule
        for item in profile.insulinSensitivitySchedule.items {
            let value = LoopQuantity(unit: .milligramsPerDeciliterPerInternationalUnit, doubleValue: item.value)

            if !Guardrail.insulinSensitivity.absoluteBounds.contains(value) {
                return .failure(.insulinSensitivityError)
            }
        }

        // Checking Carb Ratio Schedule
        for item in profile.carbRatioSchedule.items {
            let value = LoopQuantity(unit: .gramsPerUnit, doubleValue: item.value)

            if !Guardrail.carbRatio.absoluteBounds.contains(value) {
                return .failure(.carbRatioError)
            }
        }

        // Checking Basal Rate Schedule
        if let maximumBasalRate = therapySettings.maximumBasalRatePerHour {
            for item in profile.basalRateSchedule.items {
                let value = item.value

                if value > maximumBasalRate || !supportedIncrements.basalRates.contains(value) {
                    return .failure(.basalRateError)
                }
            }
        } else {
            return .failure(.maxBasalRateNotSet)
        }

        return .success(())
    }

    func isCorrectionRangeEqual(a: GlucoseRangeSchedule, b: GlucoseRangeSchedule) -> Bool {
        guard a.items.count == b.items.count else {
            return false
        }
        
        for (item1, item2) in zip(a.items, b.items) {
            if item1.startTime != item2.startTime ||
                abs(item1.value.minValue - item2.value.minValue) > 0.01 ||
                abs(item1.value.maxValue - item2.value.maxValue) > 0.01 {
                return false
            }
        }
        
        return true
    }
    
    func isInsulinSensitivityScheduleEqual(a: InsulinSensitivitySchedule, b: InsulinSensitivitySchedule) -> Bool {
        guard a.items.count == b.items.count else {
            return false
        }
        
        for (item1, item2) in zip(a.items, b.items) {
            if item1.startTime != item2.startTime ||
                abs(item1.value - item2.value) > 0.01 {
                return false
            }
        }
        
        return true
    }
    
    public func isCurrentProfileOutOfSync() -> Bool {
        guard let currentProfileName = self.currentProfileName,
              let currentProfileReference = profiles.first(where: { $0.name == currentProfileName }),
              let profile = try? getProfile(from: currentProfileReference),
              let therapyGlucoseSchedule = therapySettings.glucoseTargetRangeSchedule?.schedule(for: LoopUnit.milligramsPerDeciliter),
              let therapyInsulinSensitivitySchedule = therapySettings.insulinSensitivitySchedule?.schedule(for: LoopUnit.milligramsPerDeciliter) else {
            return false // No current profile set or profile not found or schedules not available
        }
        
        var isOutOfSync = false
        
        if !isCorrectionRangeEqual(a: therapyGlucoseSchedule, b: profile.correctionRange.schedule(for: LoopUnit.milligramsPerDeciliter)!) {
            print("Glucose target range schedule differs")
            isOutOfSync = true
        }
        if therapySettings.carbRatioSchedule?.items != profile.carbRatioSchedule.items {
            print("Carb ratio schedule differs")
            isOutOfSync = true
        }
        if therapySettings.basalRateSchedule?.items != profile.basalRateSchedule.items {
            print("Basal rate schedule differs")
            isOutOfSync = true
        }
        if !isInsulinSensitivityScheduleEqual(a: therapyInsulinSensitivitySchedule, b: profile.insulinSensitivitySchedule.schedule(for: LoopUnit.milligramsPerDeciliter)!) {
            print("Insulin sensitivity schedule differs")
            isOutOfSync = true
        }
        
        return isOutOfSync
    }
}

extension Profile {
    /// Passes the schedules this profile activates to `check`.
    public func verify(with check: (GlucoseRangeSchedule, CarbRatioSchedule, BasalRateSchedule, InsulinSensitivitySchedule) throws -> Void) throws {
        try check(correctionRange, carbRatioSchedule, basalRateSchedule, insulinSensitivitySchedule)
    }
}

extension ProfileViewModel {
    /// The current settings with the schedules of `profile`, for editing the profile with the therapy settings editors.
    func therapySettings(applying profile: Profile) -> TherapySettings {
        var settings = therapySettings
        let unit = settings.glucoseTargetRangeSchedule?.unit ?? LoopUnit.milligramsPerDeciliter
        settings.glucoseTargetRangeSchedule = profile.correctionRange.schedule(for: unit)
        settings.carbRatioSchedule = profile.carbRatioSchedule
        settings.basalRateSchedule = profile.basalRateSchedule
        settings.insulinSensitivitySchedule = profile.insulinSensitivitySchedule.schedule(for: unit)
        return settings
    }

    /// Saves edited schedules to the profile named `name`, keeping its file and place in the list.
    func updateProfile(named name: String, from settings: TherapySettings) throws {
        loadProfiles()
        guard let profileReference = profiles.first(where: { $0.name == name }) else {
            throw ProfileValidationError.fileLoadError
        }
        let profile = try getProfile(from: profileReference)
        let updatedProfile = Profile(
            name: profile.name,
            correctionRange: settings.glucoseTargetRangeSchedule?.schedule(for: .milligramsPerDeciliter) ?? profile.correctionRange,
            carbRatioSchedule: settings.carbRatioSchedule ?? profile.carbRatioSchedule,
            basalRateSchedule: settings.basalRateSchedule ?? profile.basalRateSchedule,
            insulinSensitivitySchedule: settings.insulinSensitivitySchedule?.schedule(for: .milligramsPerDeciliter) ?? profile.insulinSensitivitySchedule,
            sortOrder: profile.sortOrder
        )
        try encodeProfile(updatedProfile).write(to: profilesDirectory.appendingPathComponent(profileReference.fileName), options: .atomic)
        loadProfiles()
        triggerProfileSync()
    }
}
