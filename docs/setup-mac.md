# Setup — first build on a Mac (simulator)

Goal for day one: **build and run the M1 app in the iOS Simulator.** That's the real
correctness check. You do NOT need any of this today: Screen Time, a real device, a
paid Apple Developer account, the App Group, entitlements, XcodeGen, or Homebrew.
Those come later.

## Prerequisites (ideally done the night before)

- macOS **Sonoma 14.5 or newer** (a 2018 Mac can't run the latest macOS — that's fine).
- **Xcode 16.2** (~40 GB expanded, slow — install ahead of time).
- **~40 GB free** disk space.

> ⚠️ **Don't install Xcode from the Mac App Store.** It only offers the newest
> Xcode, which demands the newest macOS (you'll see a "macOS 26.2 or later" message).
> Instead download an older, compatible Xcode:
> 1. Confirm macOS is **14.5+** (Software Update to the latest 14.x if not).
> 2. Go to **https://developer.apple.com/download/all/** and sign in with any free
>    Apple ID.
> 3. Search **`Xcode 16.2`**, download the `.xip`.
> 4. Double-click the `.xip` to expand → drag **Xcode.app** to **Applications** →
>    open it once to finish installing components.
>
> Xcode 16.2 runs on Sonoma 14.5+ and has the iOS 18 SDK + SwiftData. Don't grab a
> newer Xcode or it will demand a newer macOS.

## Step 1 — Get the project onto the Mac

Copy the whole `wanna develop an app` folder over by whichever is easiest:
- USB stick, or
- Upload to Google Drive on Windows → download on the Mac, or
- Zip it and email it to yourself.

You only need the `Sources/` folder and `docs/` for today. (Skip
`DeviceActivityMonitorExtension/` — that's the Screen Time target, not needed yet.)

## Step 2 — Create a new Xcode project

In Xcode: **File → New → Project → iOS → App**, then:
- Product Name: **HealthAssistant**
- Interface: **SwiftUI**
- Language: **Swift**
- Storage: **None** (we use SwiftData manually)
- Organization Identifier: `com.example` (anything is fine for the simulator)
- Save it somewhere easy, e.g. the Desktop.

## Step 3 — Remove the two generated files

Xcode generates its own `@main` app file and a `ContentView.swift`. We have our own
(`HealthAssistantApp.swift`), so the generated ones will **conflict** (two `@main`).
In the left sidebar, delete:
- the generated `HealthAssistantApp.swift` (or `<Name>App.swift`) → **Move to Trash**
- `ContentView.swift` → **Move to Trash**

## Step 4 — Add our source files

Drag the **`Sources`** folder from Finder into the Xcode project navigator. In the
dialog:
- ✅ **Copy items if needed**
- ✅ **Create groups**
- ✅ make sure the **HealthAssistant target** is checked

You should now see App / Models / AI / Data / Rewards / Persistence / Shared /
Features in the project.

## Step 5 — Set the deployment target

Select the project (top of the navigator) → the **HealthAssistant** target →
**General** → set **Minimum Deployments → iOS 17.0** (SwiftData needs 17+).

## Step 6 — Run

Pick an **iPhone 15 / 16 simulator** in the top bar and press **▶︎ (Cmd+R)**.
The **simulator needs no Apple ID and no signing** — it should just build and launch.

You should land on the **Today** dashboard, with entry points to Nutrition, Workout,
Sleep, Check-in, and Habits. Log a meal, a workout, a check-in — they persist and
the dashboard updates.

## If something fails to build or launch

This code now uses local SwiftData storage for the M1 simulator build, so it should
not hit App Group entitlement errors. If you see an App Group error anyway, you are
running an old copied Xcode project. Delete that copy and re-import this updated
`Sources/` folder.

Other possible issues:

- **Workout sets don't save.** In `Sources/Features/Workout/WorkoutLogView.swift`,
  `WorkoutEntryForm.save()`, insert each set explicitly before `repo.addWorkout`.
- **Any red compile error** — copy the exact text and send it; these are usually
  one-line fixes.

## Later (not day one)

- **On a real iPhone:** Xcode → Settings → Accounts → add your own Apple ID (free is
  fine), pick your Personal Team on the target, set a unique bundle ID.
- **Screen Time:** needs the XcodeGen project (`project.yml`), the
  `DeviceActivityMonitorExtension` target, the App Group, the Family Controls
  entitlement (Apple approval), and a real device.
- **Real AI (M2):** add your Claude API key in-app (stored in Keychain) and flip
  `AIClientFactory` to return `ClaudeAIClient`.
