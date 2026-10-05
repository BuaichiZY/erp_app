# ERP iOS / iPadOS

`ERP/` contains the native SwiftUI app. The iPhone layout uses compact tabs. On iPad, regular windows show a desktop-style sidebar and wider, multi-column pages; narrow Split View windows switch to compact tabs.

On a Mac, run `brew install xcodegen`, then `cd ios && xcodegen generate`, open `ERP.xcodeproj`, and select an iPhone or iPad simulator. The repository's iOS GitHub Action builds an unsigned simulator app and publishes it with the generated project as an artifact. Installing on a physical device requires Apple signing.

On Windows, run `powershell -File ios/export-playground.ps1`. Copy the resulting `ios/ERP-iPad.swiftpm` folder to Files on an iPad and open it in Swift Playgrounds. It uses the same Swift source and only asks for camera access when the QR scanner opens and microphone access when recording voice. Photo selection uses the system picker.

The current iOS build checks for an iOS `.ipa` release. Android `.apk` files are not installable on iPhone or iPad. This project has not yet been tested on a physical Apple device.

For signed TestFlight distribution from the Windows-hosted repository, see [TESTFLIGHT.md](TESTFLIGHT.md).
For personal installation with a free Apple Account, see [LOCAL_INSTALL.md](LOCAL_INSTALL.md). The build workflow also publishes an unsigned IPA for local signing.
