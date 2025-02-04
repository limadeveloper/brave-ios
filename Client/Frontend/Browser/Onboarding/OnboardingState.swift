// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

enum OnboardingState: Int {
    /// Unknown, this can happen for upgrading users where other information
    /// (e.g. `firstLaunch` is used to determine the onboarding state.
    case undetermined
    /// The user has not seen this onboarding.
    case unseen
    /// The user has completed this onboarding.
    case completed
}
