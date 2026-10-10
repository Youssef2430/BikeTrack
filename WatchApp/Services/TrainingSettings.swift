import Foundation
import RideCore

enum TrainingSettings {
    static var profile: TrainingProfile {
        TrainingProfile(maximumHeartRate: UserDefaults.standard.double(forKey: "maximumHeartRate"),
                        functionalThresholdPower: UserDefaults.standard.double(forKey: "ftp"))
    }
    static let demoProfile = TrainingProfile(maximumHeartRate: 190, functionalThresholdPower: 240)
}
