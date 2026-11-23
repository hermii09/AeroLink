# AeroLink for iPhone

This is the optional iPhone companion for the AeroLink watch bridge. Open `AeroLink.xcodeproj` in Xcode on macOS and select an iOS 17+ simulator or iPhone.

GitHub Actions builds an unsigned device `.ipa` as well as a simulator app. The unsigned IPA is a packaging/build artifact, not directly installable; installing on an iPhone requires signing it with an Apple development certificate and a provisioning profile that includes the HealthKit entitlement.

The Activity screen stores received readings on the iPhone even when Apple Health access is unavailable. Health export is optional and still requires a provisioning profile that grants HealthKit. The app and widget share readings through the `group.app.aerolink.ios` App Group; register and enable that group for both bundle IDs when signing. The watch sender currently transmits step-count intervals only. Sleep UI and widgets are ready for sleep-session messages, but the current watch build has no sleep-data source or sender yet.

The watch side samples step-counter changes while connected and sends queued, chunked BLE readings over that second link. The iPhone reassembles packets, saves them locally, and acknowledges them; when HealthKit is available, it also writes steps there. Event IDs are retained locally to suppress duplicate writes after retries. End-to-end behavior is not verified until built and exercised on a Galaxy Watch 6 and iPhone 15. The current build does not sync heart rate or sleep stages.

The companion intentionally writes only data AeroLink receives from the watch. It does not read existing Apple Health records.
