# AeroLink for iPhone

This is the optional iPhone companion for Apple Health step export. Open `AeroLink.xcodeproj` in Xcode on macOS, select an iOS 17+ simulator or iPhone, and choose a signing team with HealthKit enabled.

GitHub Actions builds an unsigned device `.ipa` as well as a simulator app. The unsigned IPA is a packaging/build artifact, not directly installable; installing on an iPhone requires signing it with an Apple development certificate and a provisioning profile that includes the HealthKit entitlement.

The companion requests permission to write step samples to Apple Health. Open AeroLink, set up Health access, and start the watch receiver. Keep the watch's existing Samsung setup and AeroLink notification/music connection as they are: the watch discovers the companion's custom GATT service over a separate BLE connection. The iPhone receiver needs to be running; background Bluetooth behavior and coexistence with ANCS must be verified on an iPhone 15 and Galaxy Watch 6 before relying on background sync.

The watch side samples step-counter changes while connected and sends queued, chunked BLE readings over that second link. The iPhone reassembles packets and acknowledges a sample only after HealthKit saves it; event IDs are retained locally to suppress duplicate writes after retries. End-to-end behavior is not verified until built and exercised on a Galaxy Watch 6 and iPhone 15. The current build does not sync heart rate.

The companion intentionally writes only data AeroLink receives from the watch. It does not read existing Apple Health records.
