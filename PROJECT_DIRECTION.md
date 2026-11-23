# AeroLink project direction

## Project idea

AeroLink is a small, local Bluetooth companion that lets an already configured Galaxy Watch 6 share the useful iPhone basics: notifications and music controls first, with opt-in health export as a later iPhone companion feature. It should keep working without an account or cloud relay.

## Current foundation

This repository is based on WeakBridge 0.2.0. The watch app already implements iPhone notification mirroring and media controls over Apple's ANCS and AMS Bluetooth services. Galaxy Watch 6 cannot use Samsung's normal iOS setup path, so the bridge expects the watch to have been configured with Android first.

## Brand direction

- Product name: **AeroLink**
- Style: boxier cards, crisp aqua and mint accents, dark water-like AMOLED background, high contrast text
- Keep controls compact and legible on the round watch display; use the Frutiger Aero influence through color and highlight, not low-contrast glass effects
- Watch notifications get a sender-colored initials tile so different apps are easier to scan

## Notification icon behavior

The watch can reliably receive an iPhone notification's app identifier, display name, category, text and supported actions. ANCS does not provide the original iPhone app icon image. iOS also does not expose a general API for one app to fetch every other app's icon. This build therefore creates a local colored initials badge from the sender name and identifier; no images are downloaded and no notification content is sent elsewhere. Exact Apple or third-party logos would require a separately curated asset set and still would not cover every app.

## Apple Health path

HealthKit is available only to an iOS or watchOS app with the HealthKit capability and the user's per-type authorization. The iPhone companion requests write permission for steps and heart rate and hosts a local Bluetooth GATT receiver. The watch now samples step-counter changes while connected and uses a queued, chunked sender; heart-rate sampling is still pending. Apple permits background Bluetooth work under declared modes, but limits how long an app runs, so sync reliability and battery use need real-device validation. Start with steps, then add heart rate and workouts only after validating timestamps, units, deduplication and permission behavior.

Suggested milestones:

1. Finish the watch identity badge and AeroLink visual pass.
2. Validate notification delivery, music controls, reconnects and watch battery behavior on the Galaxy Watch 6 + iPhone 15.
3. Verify end-to-end step sync on real devices, then add a watch heart-rate sampler and test retry and duplicate handling.
4. Add more metrics only after tests confirm samples are neither lost nor duplicated after disconnects.

## Platform limits to plan around

- The watch must already be set up with an Android phone; this bridge is not a replacement for Galaxy Wearable setup.
- iOS decides which notification information and actions are available over ANCS.
- Arbitrary message replies and full Samsung Health integration are outside this watch-only app's reach.
- iOS background Bluetooth is event-driven and time-limited; it is not an always-running service.

## Build notes

The watch app builds with the included Gradle wrapper and Android SDK. The optional iPhone companion is in `ios-app/` and requires Xcode on macOS plus a signing team with HealthKit enabled.
