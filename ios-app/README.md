# AeroLink for iPhone

This is the optional iPhone companion for future Apple Health export. Open `AeroLink.xcodeproj` in Xcode on macOS, select an iOS 17+ simulator or iPhone, and choose a signing team.

The companion requests permission to write steps and heart-rate samples to Apple Health. Open AeroLink, set up Health access, and start the watch receiver before reconnecting the watch. The Bluetooth receiver exposes a small custom GATT service so the watch can submit samples without an internet or cloud relay. Bluetooth background behavior and coexistence with ANCS must be verified on an iPhone 15 and Galaxy Watch 6 before relying on background sync.

The watch side now samples step-counter changes while connected and sends queued, chunked BLE readings. The iPhone reassembles packets and acknowledges a sample only after HealthKit saves it; event IDs are retained locally to suppress duplicate writes after retries. Heart-rate writing is supported by the iPhone data model but no watch heart-rate sampler is implemented yet. End-to-end behavior is not verified until built and exercised on a Galaxy Watch 6 and iPhone 15.

The companion intentionally writes only data AeroLink receives from the watch. It does not read existing Apple Health records.
