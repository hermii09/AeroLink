 <div align="center">
   
  # AeroLink

  **Connect your Samsung Galaxy Watch to your iPhone.**

  Notifications, music controls, and planned Apple Health integration.

</div>

---

AeroLink is an open-source **Wear OS–to–iPhone Bluetooth bridge**, based on [WeakBridge](#credits). It allows an already configured Samsung Galaxy Watch to communicate with an iPhone using Apple's built-in Bluetooth services.

AeroLink supports:

- **ANCS:** Receive and manage iPhone notifications directly on your watch.
- **AMS:** View music information and control playback from your watch.
- **Apple Health:** An optional iPhone companion is under development to enable step-data synchronization with Apple Health.

Music continues playing through your iPhone or its selected audio output. AeroLink does not stream audio to the watch.

<p align="center">
  <img src="docs/images/watch6-home-0.2.0.png" width="220" alt="Connection and service status on Galaxy Watch6">
  <img src="docs/images/watch6-settings-0.2.0.png" width="220" alt="Connection settings">
  <img src="docs/images/watch6-quiet-hours-0.2.0.png" width="220" alt="Quiet hours settings">
</p>

<sub>Interface screenshots are from the original WeakBridge project, not AeroLink. Screenshots were captured on a Galaxy Watch6. The interface is available in English and Russian.</sub>

## Features

| Feature | Description |
|---|---|
| **Notifications** | Receive new iPhone notifications, updates, removals, and supported notification actions. |
| **Notification filters** | Choose notification categories and individual apps after their first notification arrives. |
| **Alert controls** | Group notifications by app, hide message previews, configure quiet hours, and limit repeated alerts. |
| **Music controls** | View track information and control play/pause, next/previous track, and relative volume through the watch's system player. |
| **Health integration** | Step-counter synchronization code and an iPhone HealthKit receiver have been added. End-to-end synchronization is not yet verified. |
| **Connection management** | Reconnect to a saved iPhone, monitor notification and music service status separately, and keep the bridge running after closing the app. |
| **Diagnostics** | View, copy, and clear local diagnostic counters without logging notification content. |

### What's new in version 0.2.0?

Version 0.2.0 introduces:

- A redesigned interface.
- Expanded notification controls.
- Improved connection handling.
- Fewer unnecessary reconnection attempts when changing ordinary settings.
- Reduced obsolete Bluetooth operations.

See the [CHANGELOG](CHANGELOG.md) for the full list of changes.

## Compatibility and limitations

<sub>Beta software — device compatibility is still being tested.</sub>

**Confirmed test devices:**
- Samsung Galaxy Watch6 (SM-R930).
- iPhone 13 running iOS 26.0.
- iPhone 15 running iOS 27.0 Developer Beta 4.

Pairing, music controls, the interface, and ordinary daily use have been tested on the supported device combinations.

| Requirement | Details |
|---|---|
| Watch OS | Wear OS with Android 13 / API 33 or later |
| Initial setup | Watch must already be configured |
| Confirmed watch | Samsung Galaxy Watch6 (SM-R930) |
| Other devices | Not yet independently verified |

### Important limitations

- AeroLink does not configure factory-reset watches.
- It does not replace Samsung Galaxy Wearable.
- It does not stream audio from the iPhone to the watch.
- Arbitrary text replies are not supported.
- Notification actions depend on the functionality exposed by iOS.
- Step synchronization code exists across both applications, but end-to-end device testing is still required.
- Heart-rate synchronization is not currently implemented.
- Watch gestures depend on firmware. Double pinch in Always-On Display and global fist-to-pause functionality are not provided by AeroLink.

AeroLink relies on Apple's ANCS (Apple Notification Center Service) and AMS (Apple Media Service).

## Getting started

### Connecting your Samsung Galaxy Watch to an iPhone

1. Install and open AeroLink on your Galaxy Watch.
2. Grant the requested permissions, including Nearby Devices and notification access. Health-related permissions are optional at this stage.
3. Navigate to **Connection → Connect iPhone**.
4. Approve the system request to make your watch discoverable. The discoverability window lasts two minutes.
5. On your iPhone, open **Settings → Bluetooth**.
6. Select your Galaxy Watch and confirm that the pairing codes match on both devices.
7. Allow notification sharing on your iPhone.
8. If available, enable **Share System Notifications** in your watch's Bluetooth device settings.
9. Return to AeroLink and open the saved-device list under **Connection**.
10. Select your iPhone. If it has already been selected, use **Reconnect**.

To verify everything works, send a new notification to your iPhone and start playing music.

**A few things to know:**
- Your watch retains its existing Bluetooth name.
- The optional compatible-device scan is a diagnostic feature. An empty scan result does not necessarily mean your iPhone is incompatible.

For Russian setup instructions and troubleshooting, see the [Russian documentation](docs/README.ru.md).

## Frequently asked questions

### Does the Samsung Galaxy Watch6 work with an iPhone?

Yes! The Galaxy Watch6 (SM-R930) has been tested with an iPhone 13 on iOS 26.0 and an iPhone 15 on iOS 27.0 Developer Beta 4.

AeroLink provides notification mirroring and music controls for an already configured watch.

It does not restore the complete Samsung Galaxy Wearable experience on iOS.

### Do I need to install an iPhone companion app?

**No.** If you only want notifications and music controls, the watch application is sufficient.

An optional iPhone companion application is being developed for future Apple Health integration.

### Which notifications and music features are supported?

**Notifications:**
- New notifications.
- Notification updates and removals.
- Supported notification actions.
- Per-app and category filtering.
- Notification grouping.
- Quiet hours.
- Hidden notification previews.

**Music:**
- Track information.
- Play and pause.
- Next and previous track.
- Relative volume controls.

Music continues playing on the iPhone or its selected audio output.

Arbitrary text replies and audio streaming are not supported.

### Does AeroLink support Apple Health?

Apple Health integration is under development.

Step synchronization code has been added to both applications, including an iPhone-side HealthKit receiver. However, end-to-end synchronization has not yet been verified on a physical device.

Heart-rate synchronization is not currently implemented.

### Can I set up a factory-reset Galaxy Watch using only an iPhone?

No. Your watch must already be configured and running Wear OS with Android 13 / API 33 or later.

AeroLink is a Bluetooth bridge, not a replacement for the initial Samsung watch setup process.

### Does AeroLink work with other Wear OS watches?

Possibly, but compatibility is not guaranteed.

The Galaxy Watch6 is the only watch currently confirmed through this project's device testing. Other models, firmware versions, and music applications require independent testing.

## Privacy and battery efficiency

### Privacy

AeroLink is designed to operate locally.

- Notification content and observed application names remain in memory and Android's notification system.
- No persistent notification message history is maintained.
- Preferences, blocked application identifiers, the selected Bluetooth device, and pending step-sync intervals are stored locally.
- No Internet permission is required.
- There is no analytics or account system.

The optional iPhone companion stores notification deduplication identifiers locally and writes authorized step samples directly to Apple Health.

### Battery efficiency

AeroLink uses an event-driven, low-power Bluetooth Low Energy design.

It avoids:
- Continuous Bluetooth scanning.
- Periodic keepalive operations.
- Permanent wake locks.

Connection recovery attempts are bounded, and version 0.2.0 reduces redundant background operations.

No specific battery-life improvement is claimed yet. Long-term battery consumption still requires measurement.

For technical details, retry limits, LOW_POWER connection hints, and reproducible battery-testing scenarios, see [BATTERY_OPTIMIZATION.md](BATTERY_OPTIMIZATION.md).

## License

AeroLink is released under the [MIT License](LICENSE).

Third-party dependency licenses are documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Credits

AeroLink is based on [WeakBridge](https://github.com/).

The original WeakBridge project provided the foundation for the Bluetooth bridge and parts of the interface. AeroLink builds upon that foundation with its own development, interface changes, notification controls, and ongoing health-integration work.

