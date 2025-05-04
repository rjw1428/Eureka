# expense_tracker

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
ß
## How to get Sign In With Google to work on iOS
- Download GoogleService-Info.plist from your firebase project settings
- Add the firebase-ios-sdk in xcode (File > Add Package & search https://github.com/firebase/firebase-ios-sdk)
- Add the reverse client ID from the GoogleService-Info.plist as:
```
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>{{ReverseClientID}}</string>
			</array>
		</dict>
	</array>
```
