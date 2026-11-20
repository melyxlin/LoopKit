//
//  ProfilePreviewView.swift
//  LoopKitUI
//
//  Created by Jonas Björkert on 2023-05-23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import HealthKit
import LoopKit

enum ActiveAlert {
    case load
    case delete
    case error
    case loadEdited
}

struct ProfilePreviewView: View {
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismissAction) var dismissAction
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.appName) private var appName
    @Environment(\.dosingStrategySelectionEnabled) private var dosingStrategySelectionEnabled
    @State private var profile: Profile
    @State private var editingDelegate: ProfileEditingDelegate
    @State private var therapySettingsViewModel: TherapySettingsViewModel

    @State private var showingAlert = false
    @State private var activeAlert: ActiveAlert = .load
    @State private var errorText: String?
    @State private var newProfileName: String = ""
    @State private var isRenamingProfile = false
    @State private var shouldDismissSelf: Bool = false

    let nilDestination: (_ dismiss: @escaping () -> Void) -> AnyView = { _ in AnyView(EmptyView()) }

    init(viewModel: ProfileViewModel, profile: Profile) {
        self.viewModel = viewModel
        let editingDelegate = ProfileEditingDelegate(viewModel: viewModel, profile: profile)
        _profile = State(initialValue: profile)
        _editingDelegate = State(initialValue: editingDelegate)
        _therapySettingsViewModel = State(initialValue: TherapySettingsViewModel(
            therapySettings: viewModel.therapySettings(applying: profile),
            delegate: editingDelegate))
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Tap a setting to edit it in this profile. Editing changes only the saved profile; \(appName) keeps using its current settings until the profile is loaded. Scroll to find options to Load, Rename, or Delete.")
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding([.leading, .trailing])
                        .fixedSize(horizontal: false, vertical: true)
                        .textCase(nil)
                    
                    profileCardStack
                    
                    Button(action: {
                        activeAlert = .load
                        showingAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Load")
                                .foregroundColor(.white)
                                .padding()
                            Spacer()
                        }
                    }
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Button(action: {
                        isRenamingProfile = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Rename")
                                .foregroundColor(.white)
                                .padding()
                            Spacer()
                        }
                    }
                    .background(Color.orange)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Button(action: {
                        activeAlert = .delete
                        showingAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete")
                                .foregroundColor(.white)
                                .padding()
                            Spacer()
                        }
                    }
                    .background(Color.red)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                }
            }
            .navigationBarHidden(false)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Text(profile.name))
            .alert(isPresented: $showingAlert) {
                switch activeAlert {
                case .load:
                    return Alert(
                        title: Text("Load Profile"),
                        message: Text("Do you want to load the profile \(profile.name)?"),
                        primaryButton: .default(Text("Yes"), action: load),
                        secondaryButton: .cancel()
                    )
                case .delete:
                    return Alert(
                        title: Text("Delete Profile"),
                        message: Text("Are you sure you want to delete the profile \(profile.name)? This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete"), action: {
                            viewModel.removeProfile(profile: profile)
                            self.presentationMode.wrappedValue.dismiss()
                        }),
                        secondaryButton: .cancel()
                    )
                case .error:
                    return Alert(
                        title: Text("Error loading profile"),
                        message: Text(errorText ?? "Unknown error"),
                        dismissButton: .default(Text("OK"))
                    )
                case .loadEdited:
                    return Alert(
                        title: Text("Load Edited Profile?"),
                        message: Text("\(profile.name) is the active profile. Load it now to use the edited settings. \(appName) writes the basal rates to the pump."),
                        primaryButton: .default(Text("Load"), action: load),
                        secondaryButton: .cancel(Text("Later"))
                    )
                }
            }
            if isRenamingProfile {
                // Some hacks here to mimic Alert behaviour.
                // This function should be migrateed to Alert when iOS 16 is required.
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        isRenamingProfile = false
                    }
                
                RenameProfileEditor(
                    isPresented: $isRenamingProfile,
                    currentProfileName: profile.name,
                    viewModel: viewModel,
                    shouldDismissParent: $shouldDismissSelf
                )
                .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity).animation(.default))
                .offset(y: -22)
            }
        }
        .onAppear {
            // Runs again when an editor closes.
            guard let saved = try? viewModel.savedProfile(named: profile.name) else { return }
            profile = saved
            // The editors show the saved values, also after a save that failed.
            therapySettingsViewModel.therapySettings = viewModel.therapySettings(applying: saved)
            if let error = editingDelegate.saveError {
                editingDelegate.saveError = nil
                presentAlertLater(.error, errorText: error.localizedDescription)
            } else if editingDelegate.savedEdits {
                editingDelegate.savedEdits = false
                if viewModel.currentProfileName == profile.name {
                    presentAlertLater(.loadEdited)
                }
            }
        }
        .onChange(of: shouldDismissSelf) { shouldDismiss in
            if shouldDismiss {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }

    private func presentAlertLater(_ alert: ActiveAlert, errorText: String? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard !showingAlert else { return }
            self.errorText = errorText
            activeAlert = alert
            showingAlert = true
        }
    }

    private func load() {
        let validationResult = viewModel.validateProfile(profile)
        switch validationResult {
        case .success:
            viewModel.loadProfile(profile: profile) { result in
                switch result {
                case .success:
                    dismissAction()
                case .failure(let error):
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.errorText = error.localizedDescription
                        self.activeAlert = .error
                        self.showingAlert = true
                    }
                }
            }
        case .failure(let error):
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.errorText = error.localizedDescription
                self.activeAlert = .error
                self.showingAlert = true
            }
        }
    }

    private var profileCardStack: CardStack {
        var cards: [Card] = []

        cards.append(correctionRangeSection)
        cards.append(carbRatioSection)
        cards.append(basalRatesSection)
        cards.append(insulinSensitivitiesSection)

        return CardStack(cards: cards)
    }

    private var correctionRangeSection: Card {
        card(for: .glucoseTargetRange) {
            if let items = profile.correctionRange.schedule(for: glucoseUnit)?.items {
                SectionDivider()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }

                    ScheduleRangeItem(time: items[index].startTime,
                                      range: items[index].value,
                                      unit: glucoseUnit,
                                      guardrail: .correctionRange)
                }
            }
        }
    }

    private var carbRatioSection: Card {
        card(for: .carbRatio) {
            SectionDivider()
            let items = profile.carbRatioSchedule.items
            ForEach(items.indices, id: \.self) { index in
                if index > 0 {
                    SettingsDivider()
                }

                ScheduleValueItem(time: items[index].startTime,
                                  value: items[index].value,
                                  unit: .gramsPerUnit,
                                  guardrail: .carbRatio)
            }
        }
    }

    private var basalRatesSection: Card {
        card(for: .basalRate) {
            let items = profile.basalRateSchedule.items
            if let supportedBasalRates = viewModel.pumpSupportedIncrements()?.basalRates
            {
                SectionDivider()
                let total = profile.basalRateSchedule.total()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }

                    ScheduleValueItem(time: items[index].startTime,
                                      value:  items[index].value,
                                      unit: .internationalUnitsPerHour,
                                      guardrail: .basalRate(supportedBasalRates: supportedBasalRates))
                }
                HStack {
                    Text("Total")
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "%.2f ",total))
                        .foregroundColor(.primary) +
                    Text("U/day")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var insulinSensitivitiesSection: Card {
        card(for: .insulinSensitivity) {
            if let items = profile.insulinSensitivitySchedule.schedule(for: glucoseUnit)?.items
            {
                SectionDivider()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }
                    ScheduleValueItem(time: items[index].startTime,
                                      value: items[index].value,
                                      unit: sensitivityUnit,
                                      guardrail: .insulinSensitivity)
                }
            }
        }
    }
}


// MARK: Utilities
extension ProfilePreviewView {

    private var glucoseUnit: LoopUnit {
        displayGlucosePreference.unit
    }

    private var sensitivityUnit: LoopUnit {
        switch glucoseUnit {
        case .milligramsPerDeciliter:
            return .milligramsPerDeciliterPerInternationalUnit
        case .millimolesPerLiter:
            return .millimolesPerLiterPerInternationalUnit
        default:
            return .milligramsPerDeciliterPerInternationalUnit
        }
    }

    private func card<Content>(for therapySetting: TherapySetting, @ViewBuilder content: @escaping () -> Content) -> Card where Content: View {
        Card {
            SectionWithTapToEdit(
                // The basal editor needs the pump's supported rates.
                isEnabled: therapySetting != .basalRate || viewModel.pumpSupportedIncrements() != nil,
                title: therapySetting.title,
                descriptiveText: therapySetting.descriptiveText(appName: appName, dosingStrategySelectionEnabled: dosingStrategySelectionEnabled),
                destination: { dismiss in
                    editor(for: therapySetting, dismiss: dismiss)
                        .environment(\.dismissAction, dismiss)
                },
                content: content
            )
        }
    }

    /// The therapy settings editors, saving to this profile.
    @ViewBuilder
    private func editor(for therapySetting: TherapySetting, dismiss: @escaping () -> Void) -> some View {
        switch therapySetting {
        case .glucoseTargetRange:
            CorrectionRangeScheduleEditor(mode: .settings, therapySettingsViewModel: therapySettingsViewModel, didSave: dismiss)
        case .carbRatio:
            CarbRatioScheduleEditor(mode: .settings, therapySettingsViewModel: therapySettingsViewModel, didSave: dismiss)
        case .basalRate:
            BasalRateScheduleEditor(mode: .settings, therapySettingsViewModel: therapySettingsViewModel, didSave: dismiss)
        case .insulinSensitivity:
            InsulinSensitivityScheduleEditor(mode: .settings, therapySettingsViewModel: therapySettingsViewModel, didSave: dismiss)
        default:
            EmptyView()
        }
    }
}

fileprivate struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.trailing, -16)
    }
}

fileprivate struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.trailing, -8)
    }
}

/// Saves edits made with the therapy settings editors to a saved profile. Loop's current settings and the pump are not changed.
final class ProfileEditingDelegate: TherapySettingsViewModelDelegate {
    private let viewModel: ProfileViewModel
    private let profileName: String
    private let basalTimeZone: TimeZone
    /// Set when edits were saved, so the view can offer to load the edited active profile.
    var savedEdits = false
    /// Set when saving edits to the profile file failed.
    var saveError: Error?

    init(viewModel: ProfileViewModel, profile: Profile) {
        self.viewModel = viewModel
        self.profileName = profile.name
        self.basalTimeZone = profile.basalRateSchedule.timeZone
    }

    func syncBasalRateSchedule(items: [RepeatingScheduleValue<Double>], completion: @escaping (Result<BasalRateSchedule, Error>) -> Void) {
        guard let schedule = BasalRateSchedule(dailyItems: items, timeZone: basalTimeZone) else {
            completion(.failure(ProfileValidationError.basalRateError))
            return
        }
        completion(.success(schedule))
    }

    func syncDeliveryLimits(deliveryLimits: DeliveryLimits) async throws -> DeliveryLimits {
        return deliveryLimits
    }

    func saveCompletion(therapySettings: TherapySettings) {
        do {
            try viewModel.updateProfile(named: profileName, from: therapySettings)
            savedEdits = true
        } catch {
            saveError = error
        }
    }

    func pumpSupportedIncrements() -> PumpSupportedIncrements? {
        return viewModel.pumpSupportedIncrements()
    }

    func updateCurrentProfileName() {}
}
