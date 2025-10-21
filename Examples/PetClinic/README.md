# PetClinic iOS App

This iOS app is an ADOT iOS instrumented app for testing the SDK.  

To successfully generate telemetry to your app monitor, do one of the following options.

## Option 1

Create a Settings.plist file at `./PetClinic/Settings.plist` (same folder as `Info.plist`) and update the following fields: 

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>APP_MONITOR_ID</key>
	<string>APP_MONITOR_ID_VALUE</string>

	<key>AWS_REGION</key>
	<string>AWS_REGION_VALUE</string>

    <key>LOGS_OVERRIDE_URL</key>
	<string>LOGS_OVERRIDE_URL_VALUE</string>

    <key>TRACES_OVERRIDE_URL</key>
	<string>TRACES_OVERRIDE_URL_VALUE</string>
</dict>
</plist>

```

## Option 2

Update the values of strings for these variables in `./PetClinic/PetClinicApp.swift`: 

```swift
    var APP_MONITOR_ID = "APP_MONITOR_ID"
    var AWS_REGION = "AWS_REGION"
    var LOGS_OVERRIDE_URL = "LOGS_OVERRIDE_URL"
    var TRACES_OVERRIDE_URL = "TRACES_OVERRIDE_URL"
```
