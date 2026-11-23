# AeroLink for iPhone

This is the optional iPhone companion for the AeroLink watch bridge. Open `AeroLink.xcodeproj` in Xcode on macOS and select an iOS 17+ simulator or iPhone.

GitHub Actions builds an unsigned device `.ipa` as well as a simulator app. The unsigned IPA is a packaging/build artifact, not directly installable; installing on an iPhone requires signing it with an Apple development certificate and a provisioning profile that includes the HealthKit entitlement.

The Activity screen reads daily steps and sleep sessions from Apple Health after the user grants access, and it can also store readings received over Bluetooth. HealthKit access and export require a provisioning profile that grants the HealthKit entitlement. The app and widget share the HealthKit report through the `group.app.aerolink.ios` App Group; register and enable that group for both bundle IDs when signing. The current watch sender transmits step-count intervals only, so Galaxy Watch sleep still needs a watch-side sleep data source and sender.

The watch side samples step-counter changes while connected and sends queued, chunked BLE readings over that second link. The iPhone reassembles packets, saves them locally, and acknowledges them; when HealthKit access is enabled, it writes received steps and sleep samples and refreshes the HealthKit report. Event IDs are retained locally to suppress duplicate writes after retries. End-to-end behavior is not verified until built and exercised on a Galaxy Watch 6 and iPhone 15. The current watch build does not sync sleep stages.

Apple Health remains on-device; the app queries the last 30 days of daily step totals and sleep sessions for the dashboard and widgets.
