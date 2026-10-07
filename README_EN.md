[🇨🇳 简体中文](README.md) | [🇺🇸 English](README_EN.md)

# ERP Android

ERP 1.4.0_beta, an unofficial native Android client for [erp.sex](https://erp.sex). Supports Android 8.0 (API level 26) and higher.

An app introductory guide is displayed on first launch. "Open Source Projects" under "About ERP" opens this repository in your browser. The app interface supports Simplified Chinese, Traditional Chinese, Japanese, English, and Korean; it automatically detects your system language by default, or you can manually select one in the settings.

## Permissions & Data Privacy

The `AndroidManifest.xml` declares permissions required for network access, microphone, camera, and app updates:
- **Microphone:** Requested only when the user actively initiates audio recording.
- **Camera:** Requested only when the user actively opens the QR scanner page. Alternatively, users can scan QR codes or pick chat images directly from the gallery via the system Photo Picker, requiring no storage or photo permissions.
- **Install Updates:** System permission is prompted only when the user explicitly chooses to install a new version via "Check for Updates."

Account session cookies, size-restricted caches for avatars/business card images, and user preferences are stored locally. All network requests are routed directly to existing website endpoints.

## Building the APK

### Prerequisites
- Python 3
- JDK 17
- Android SDK Platform 35
- Android SDK Build-Tools 35.0.0

*Note: Neither Gradle nor third-party Python packages are required.*

### Build Example (Windows PowerShell)

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:ANDROID_SDK_ROOT = 'C:\Users\YourUsername\AppData\Local\Android\Sdk'
python build.py
```

Under a standard SDK setup, the built APK is saved to `dist/ERP-Native-1.4.0_beta.apk` along with its SHA-256 checksum file.

### Environment Variables
- `ERP_OUTPUT_DIR`: Customizes the output directory.
- `ERP_JAVA_HOME`: Overrides the default JDK directory.
- `ERP_BUILD_TOOLS`: Specifies a custom Android Build-Tools version.
- `ERP_SIGNING_DIR`: Specifies an existing keystore directory containing `release.p12` and `password.txt` (key alias: `erp-release`).

On the first build, a local signing key and random password will be auto-generated in the git-ignored `.signing/` folder. Please back up your signing key; APKs signed with different keys cannot be updated in-place. Keystores used for official releases are not included in this repository.

The build script handles resource compilation, Java compilation, DEX generation, APK alignment, signing, and post-build installation verification. Currently verified on Windows; testing on other operating systems is recommended.

## Testing & Verification

```powershell
python run_tests.py
```

This test suite covers pure business logic, including theme rules, pairing states, gestures, chat link parsing, refresh batching, update version comparisons, and WebSocket frame decoding. 

UI rendering, camera scanning, downloads/updates, Cloudflare verification, and live account interactions should be tested manually on an actual Android device.

## Repository Structure

- `src/sex/erp/android/`: Native UI, website API integration, and real-time connectivity.
- `src/io/nayuki/qrcodegen/`: Business card QR code generator.
- `third_party/zxing-core-3.5.3.jar`: QR code decoder library.
- `res/`: Application icons, website branding assets, themes, and localization resources.
- `AndroidManifest.xml`: Versioning, API compatibility levels, and permission declarations.
- `tests/`: Pure Java unit tests.
- `build.py`: Standalone APK build automation script.

## License

The core application code is open-source under the [MIT License](LICENSE). 

- **Branding & Assets:** Website names, logos, and third-party icons are not covered by the main project license. For icon license details, see `res/raw/third_party_licenses.txt`.
- **Third-Party Libraries:** The QR code generator is licensed under the MIT License (`res/raw/nayuki_license.txt`), and the decoder is licensed under Apache License 2.0 (`res/raw/zxing_license.txt`).

*Disclaimer: This project is independent and is not affiliated with, endorsed by, or sponsored by the website or VRChat.*
