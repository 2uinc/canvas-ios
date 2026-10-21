# Secrets

How the app stores and reads API keys, tokens and other sensitive values without committing them to git.

> This document never contains secret values. Get them from the team's password manager or a teammate.

---

## 1. Overview

```
  yarn build-secrets "name=value"           (developer machine / CI)
             │  scripts/build-secrets.js
             │  XOR-obfuscates value + random padding
             ▼
  Core/Core/Resources/Assets.xcassets/Secrets/<name>.dataset/   ← git-ignored
             │  bundled into Core.framework as an NSDataAsset
             ▼
  Secret.<name>.string                       (runtime, Core/.../AppEnvironment/Secret.swift)
             │  reads data asset, reverses XOR, strips padding
             ▼
  SDK setup in AppDelegate / Core (AWS, DataDog, Bugfender, Pendo, PSPDFKit…)
```

There are four pieces:

| Piece | Location | Role |
|---|---|---|
| Generator | `scripts/build-secrets.js` (run via `yarn build-secrets`) | Writes obfuscated data assets |
| Storage | `Core/Core/Resources/Assets.xcassets/Secrets/*.dataset` | Git-ignored asset catalog entries |
| Accessor | `Core/Core/Common/CommonModels/AppEnvironment/Secret.swift` | `enum Secret` with a `string` getter that decodes the value |
| Build check | `scripts/build-check-keys.sh` → `scripts/check-required-keys.sh` | Student post-build phase that fails if required secrets are missing |

---

## 2. Generating secrets

Run this from the repo root:

```sh
yarn build-secrets "name1=value1" "name2=value2" …
```

- Each argument is `name=value`. Everything after the first `=` is the value, so values may themselves contain `=`.
- `name` **must match a case of `enum Secret`** exactly (e.g. `bugfenderKey`). Otherwise the app has no way to read it.
- The command is idempotent: re-running it overwrites the existing dataset.
- Values passed on the command line end up in shell history. Clear the history afterwards, or prefix the command with a space if your shell is set to ignore space-prefixed commands.

### What the script writes
For each secret it creates `Core/Core/Resources/Assets.xcassets/Secrets/<name>.dataset/`, containing:
- `<name>`: the obfuscated bytes, and
- `Contents.json`: the asset catalog metadata.

### Encoding
1. Take the value as UTF-8 bytes.
2. Append 1–32 random padding bytes. The last byte stores the padding length.
3. XOR every byte with a repeating key, `"<name>+com.instructure.icanvas.Core"`.

`Secret.string` reverses this. It builds the same key from the case name and `Bundle.core.bundleIdentifier`, XORs the bytes, and drops the padding. **The XOR key depends on Core's bundle identifier.** If Core's `PRODUCT_BUNDLE_IDENTIFIER` ever changes, the script's hard-coded `com.instructure.icanvas.Core` must change with it, or every secret will decode to garbage.

---

## 3. Git handling

`.gitignore` contains:

```
**/*.xcassets/Secrets/*.dataset
!**/*.xcassets/Secrets/testSecret.dataset
```

- Real secrets are never committed.
- `testSecret` is the only dataset that is committed. It holds a known dummy value that `Core/CoreTests/Common/CommonModels/AppEnvironment/SecretTests.swift` uses to check that encoding and decoding round-trip correctly.

---

## 4. Reading secrets at runtime

```swift
guard let key = Secret.bugfenderKey.string else { return }
Bugfender.activateLogger(key)
```

- `string` returns `nil` when the dataset is missing. Call sites use `guard` and **skip SDK setup silently**, so a missing secret doesn't crash the app; the feature just stays off.
- `Secret` lives in Core, so the apps, the SubmitAssignment extension and the widgets can all read it.

### Current secrets

| Case | Used by | Required by build check |
|---|---|---|
| `awsAccessKey`, `awsSecretKey` | `StudentAppDelegate.setupAWS()` (SNS / Lambda for push registration) | ✅ |
| `customPushDomain` | `PushNotificationsInteractor+CustomPushes.swift` | ✅ |
| `bugfenderKey` | `StudentAppDelegate.setupBugfender()` | ✅ |
| `datadogAppID`, `datadogClientToken` | `StudentAppDelegate.setupDatadog()` | — |
| `firebaseApiKey` | `StudentAppDelegate.setupFirebase()` and `SubmitAssignmentViewController.setupFirebaseServices()` (see §9) | ✅ |
| `pendoApiKey` | `PendoAnalyticsTracker` | — |
| `studentPSPDFKitLicense` | `DocViewerViewController.setup(.studentPSPDFKitLicense)` in Student | — |
| `teacherPSPDFKitLicense` | Teacher app delegate | — |
| `heapID` | Declared; no current usage | — |
| `testReadAdmin1`, `testReadStudent1`, `testReadStudent2`, `testReadStudentK5`, `testReadTeacher1`, `testReadParent1`, `testLDAPUser`, `testNotEnrolled`, `testSAMLUser`, `testVanityDomainUser` | `TestsFoundation/UITestModels/UITestUser.swift` (E2E login users) | — |
| `dataSeedAdmin` | E2E data seeding (`DataSeeder`, `E2ETestCase`, `BaseHelper`) | — |
| `k5SubAccountId` | E2E data seeding (`CreateDSCourseRequest`, `CreateDSUserRequest`) | — |
| `testSecret` | `SecretTests` (committed dummy) | — |

---

## 5. Build-time check

The Student target's post-build phase **"Check Required Secret Keys"** (declared in `Student/Student/student.yml`) runs `scripts/build-check-keys.sh`, which calls `scripts/check-required-keys.sh`. The check fails the build with an `error:` message, which includes the exact `yarn build-secrets` command to run, if any of these are missing:

- `awsAccessKey`
- `awsSecretKey`
- `customPushDomain`
- `bugfenderKey`
- `firebaseApiKey`

Other secrets are optional at build time.

---

## 6. CI

- **Bitrise** (inherited from Instructure): the workflow runs the private step `instructure/steps-canvas-ios-secrets` before building. That step generates the datasets on the CI machine.
- **GitHub Actions** (no workflows exist yet): store each value as a GitHub Environment secret and generate the datasets in a step before building or testing:
  ```yaml
  jobs:
    test:
      runs-on: macos-15
      environment: development
      steps:
        - uses: actions/checkout@v4
        - name: Generate secrets
          env:
            BUGFENDER_KEY: ${{ secrets.BUGFENDER_KEY }}
            # … one env var per secret
          run: yarn build-secrets "bugfenderKey=$BUGFENDER_KEY"   # … one argument per secret
  ```
  Pass the values through `env:` rather than putting `${{ secrets.* }}` directly in `run:`, so they don't end up in the generated shell script.

GitHub secrets can't be read back out of GitHub. Developers can't pull them to their machines, so they still get the values out-of-band and run `yarn build-secrets` themselves.

---

## 7. Adding a new secret

1. Add a case to `enum Secret` in `Secret.swift`, with a doc comment saying what it's for.
2. Read it with `Secret.<case>.string` and handle `nil` (normally by skipping the feature).
3. Generate it locally: `yarn build-secrets "<case>=<value>"`.
4. If the app must not ship without it, add a check to `scripts/check-required-keys.sh` in the same style as the existing ones.
5. Add it to CI (the Bitrise secrets step, and/or GitHub Environment secrets plus the generate step).
6. Share the value with the team through the password manager, and update the table above.

---

## 8. Security notes

- This is **obfuscation, not encryption**. The XOR key comes from public information, so anyone with the app binary and this source code can recover the values. The goal is to keep secrets out of git and out of plain-text strings in the bundle.
- Treat every value shipped in the app as recoverable. Limit each key's permissions on the provider's side, e.g. least-privilege IAM for the AWS keys and client-only tokens for DataDog.
- Firebase's `API_KEY` used to be committed in plain text in `GoogleService-Info.plist`, so it is still in git history. Rotate it, and restrict the new key in Google Cloud Console to the app's bundle IDs and the Firebase APIs it uses.

---

## 9. Firebase API key

`API_KEY` is deliberately **left out** of both committed `GoogleService-Info.plist` files (`Student/Student/` and `Student/SubmitAssignment/`). All other plist values stay committed: app ID, project ID, client ID and so on. They are identifiers, and the Crashlytics dSYM upload step needs them.

At launch, `StudentAppDelegate.setupFirebase()` and the extension's `SubmitAssignmentViewController.setupFirebaseServices()` each:

1. read the plist with `FirebaseOptions.defaultOptions()` and copy the result,
2. set `options.apiKey = Secret.firebaseApiKey.string`, and
3. call `FirebaseApp.configure(options:)`.

If the secret is missing, Firebase is not configured. Crashlytics, Remote Config and the analytics handlers stay off; the app doesn't crash. The build check (§5) stops this from happening by accident. The same plist key serves both the app and the extension.

Generate it with:

```sh
yarn build-secrets "firebaseApiKey=<value>"
```

> When downloading a fresh `GoogleService-Info.plist` from the Firebase console, delete its `API_KEY` entry before committing.
