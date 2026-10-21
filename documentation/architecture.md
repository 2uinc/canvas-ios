# Architecture

This document describes how the Canvas iOS codebase (2U fork) is put together. It is meant as a reference for anyone picking up the codebase. For setup commands and repository rules, see `CLAUDE.md` and `.github/README.md`.

---

## 1. Repository layout

```
canvas-ios/
├── Canvas.xcworkspace      # Always open this; it ties all projects together
├── Core/                   # Shared framework (almost all app logic lives here)
│   ├── Core/               #   framework sources
│   ├── CoreTests/          #   unit tests for Core
│   ├── CoreTester/         #   host app for CoreTests
│   ├── TestsFoundation/    #   shared test helpers, mocks, E2E infrastructure
│   └── project.yml         #   XcodeGen spec
├── Student/                # Student app (the target 2U ships)
│   ├── Student/            #   app sources, Routes.swift, AppDelegate
│   ├── SubmitAssignment/   #   share extension
│   ├── Widgets/            #   WidgetKit extension
│   ├── StudentUnitTests/
│   ├── StudentE2ETests/
│   ├── project.yml         #   XcodeGen spec (local)
│   └── project-ci.yml      #   XcodeGen spec (CI, no signing team)
├── Teacher/                # Teacher app (checked-in .xcodeproj)
├── Parent/                 # Parent app (checked-in .xcodeproj)
├── TestPlans/              # .xctestplan files (unit, iPad, E2E)
├── scripts/                # build phases, secrets, icons, translations, coverage
├── .github/                # README, conventions, style guide, Xcode templates
├── .bitrise/               # CI workflows
└── documentation/          # this folder
```

### Project generation
The Core and Student `.xcodeproj` files are **generated** by [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml` (`make sync`). After adding or removing files, or changing targets and dependencies, edit the YAML and regenerate. Don't hand-edit those `.xcodeproj` files. The Teacher and Parent projects are not generated.

### Dependencies
All third-party code comes in through **Swift Package Manager**, declared in `project.yml`:

| Package | Used for |
|---|---|
| PSPDFKit | Document viewing and annotation (`DocViewer`) |
| Pendo | Product analytics |
| DataDog (Core, Logs, Trace) | Logging, RUM, network instrumentation |
| Firebase (Crashlytics, RemoteConfig) | Crash reporting, remote flags (Student) |
| Bugfender | Remote device logging (Student) |
| AWS SDK (SNS, Lambda) | Push-notification endpoint registration (Student) |
| Realm + `mobile-offline-downloader-ios` | 2U offline content downloads |
| Lottie, CombineExt, CombineSchedulers, CombineReachability, SwiftUIIntrospect | UI and reactive utilities |

---

## 2. Targets and how they relate

```
            ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
            │   Student    │   │   Teacher    │   │    Parent    │
            │ AppDelegate  │   │ AppDelegate  │   │ AppDelegate  │
            │ Routes.swift │   │ Routes.swift │   │ Routes.swift │
            │ app-specific │   │ SpeedGrader… │   │ Observer…    │
            └──────┬───────┘   └──────┬───────┘   └──────┬───────┘
                   │                  │                  │
   SubmitAssignment│ Widgets          │                  │
     (extension)   │ (extension)      │                  │
                   ▼                  ▼                  ▼
            ┌────────────────────────────────────────────────────┐
            │                   Core.framework                   │
            │ API · Store/UseCase · CoreData · Router · InstUI   │
            │ Features/* (Assignments, Inbox, Planner, Modules…) │
            └────────────────────────────────────────────────────┘
```

- **Core** is a dynamic framework built with `APPLICATION_EXTENSION_API_ONLY = YES`, because the share extension and widgets link it. APIs that are unavailable in extensions (such as `UIApplication.shared`) must not be used directly in Core.
- **App targets are thin.** Each app has an AppDelegate (bootstrapping, login and logout, SDK setup), a `Routes.swift` (the URL to screen table), a tab bar controller, and the few screens that only that app needs.
- The `AppEnvironment.App` enum (`.student`, `.teacher`, `.parent`) lets Core code branch on which app it is running in.

---

## 3. App lifecycle (Student)

`StudentAppDelegate.application(_:didFinishLaunchingWithOptions:)` runs these steps in order:

1. **Configure `AppEnvironment.shared`.** Sets the router from `Routes.swift`, `app = .student`, the window, and the login delegate.
2. **Register background processing tasks.** Registers offline course sync via `BackgroundProcessingAssembly`.
3. **Set up SDKs.** Sets up DataDog, Firebase, PSPDFKit, AWS and Bugfender. Their keys come from `Secret`.
4. **Pick the starting screen.** If `LoginSession.mostRecent` exists, it shows a loading screen and calls `userDidLogin(session:)`. Otherwise it shows `LoginNavigationController`.

`userDidLogin(session:)` then stores the session, tags DataDog with the user ID, and calls `AppEnvironment.userDidLogin`. That call:
- creates a **per-session CoreData container** (`NSPersistentContainer.create(session:)`), so each user and school has an isolated database,
- creates an authenticated `API(session)`,
- sets up `SessionDefaults` (per-session `UserDefaults`), and
- re-initializes `OfflineModeAssembly`.

Finally the delegate calls `DownloaderClient.setup(with:)` for 2U offline downloads.

Logout (`userDidLogout`) reverses these steps. It revokes the OAuth token, removes the session, unregisters push notifications, and returns to the login screen.

---

## 4. AppEnvironment

`Core/Core/Common/CommonModels/AppEnvironment/AppEnvironment.swift`

`AppEnvironment` is the codebase's dependency container, used as a service locator. `AppEnvironment.shared` holds:

| Property | Purpose |
|---|---|
| `api: API` | Authenticated HTTP client for the current session |
| `database: NSPersistentContainer` | CoreData stack for the current session |
| `globalDatabase` | Database shared across sessions |
| `router: Router` | App-specific route table |
| `currentSession: LoginSession?` | Base URL, tokens, user ID, act-as-user info |
| `userDefaults: SessionDefaults?` | Per-session preferences |
| `logger`, `k5`, `window`, `loginDelegate`, `app` | Misc. app state |

**Convention:** newer code takes `env: AppEnvironment` (or `environment:`) as an initializer parameter that defaults to `.shared`, which lets tests inject a test environment. Avoid reaching for `AppEnvironment.shared` deep inside logic.

---

## 5. Networking

`Core/Core/Common/CommonModels/API/`

- **`API`** wraps `URLSession` (instrumented for DataDog through `URLSession.instrumented` and `DataDogSessionDelegate`). It handles base URL resolution, auth headers, act-as-user, token refresh, pagination (`exhaust`), downloads and uploads.
- **`APIRequestable`**: every endpoint is a small struct that declares `Response`, `method`, `path`, `query`, and `body`. `APIRequestable` supplies URL building, encoding, decoding and `Link` header pagination (`getNext`). GraphQL endpoints use `APIGraphQLRequestable`.
- **`API*` models** (`APIAssignment`, `APIPage`, …) are plain `Codable` structs that mirror the Canvas REST payloads. They live next to their feature in `Core/Core/Features/<Feature>/`.
- **`SensitiveDataRedactor`** removes tokens and PII from logs before they are sent to DataDog.

---

## 6. Data layer

Two patterns coexist. Both persist to the CoreData model at `Core/Core/Resources/Database.xcdatamodeld`.

### 6.1 UseCase + Store (the older pattern, used throughout the codebase)

`Core/Core/Common/CommonModels/Store/`

```
     View/ViewController/ViewModel
                │ observes
                ▼
   Store<U> / ReactiveStore<U>  ──reads──►  CoreData (scope: predicate + sort)
                │ refresh()                       ▲
                ▼                                 │ write(response:)
           UseCase U  ──makeRequest──►  API  ─────┘
```

A **`UseCase`** describes one cached fetch:

| Member | Meaning |
|---|---|
| `Model` | The `NSManagedObject` type |
| `Response` | The decoded API response type |
| `cacheKey` | Identifies this fetch in the TTL table (`nil` means no caching) |
| `ttl` | Cache lifetime (default 2 h) |
| `scope` | `Scope(predicate:orderBy:naturally:)` used to read results back out of CoreData |
| `request` / `makeRequest` | Which `APIRequestable` to call |
| `write(response:urlResponse:to:)` | Maps API models into CoreData (`APIUseCase` and `CollectionUseCase` supply defaults) |
| `reset(context:)` | Clears stale rows before writing (collections) |

Example: `Core/Core/Features/Pages/GetPages.swift`.

**`Store<U>`** is the classic consumer, used mostly from UIKit. It wraps an `NSFetchedResultsController` and is driven with `refresh(force:)`, `exhaust()` and `getNextPage()`. It notifies through a change closure or `ObservableObject`.

**`ReactiveStore<U>`** is the Combine-based consumer used by newer code. `getEntities(ignoreCache:loadAllPages:keepObservingDatabaseChanges:)` returns a publisher. It returns valid cache when available, otherwise fetches, writes and returns. When offline (`OfflineModeInteractor`), it reads only from CoreData.

A typical feature folder therefore contains `APIX.swift` (the API model and request), `X.swift` (the CoreData model), `GetX.swift` (the UseCase), and the UI.

### 6.2 MVVM + Interactor (the newer pattern for SwiftUI screens)

Scaffolded from `.github/templates/Canvas/MVVM Module.xctemplate`. Install it by copying the template to `~/Library/Developer/Xcode/Templates/`.

```
Feature/
├── FeatureAssembly.swift         # enum with static make…() factories (composition root)
├── Model/
│   ├── FeatureInteractor.swift          # protocol + FeatureInteractorLive
│   └── FeatureInteractorPreview.swift   # stub for SwiftUI previews
├── ViewModel/FeatureViewModel.swift     # ObservableObject, @Published state
└── View/FeatureScreen.swift             # SwiftUI view
```

- The **Interactor** owns data access, usually by wrapping `ReactiveStore`s and API calls, and exposes Combine publishers. It is a protocol, so it can be mocked in tests and stubbed in previews.
- The **ViewModel** owns presentation state, typically `@Published var state: InstUI.ScreenState` (`.loading`, `.data(loadingOverlay:)`, `.empty`, `.error`), and receives the interactor and router through its initializer.
- The **Screen** is a SwiftUI view, hosted in UIKit with `CoreHostingController`.
- The **Assembly** wires everything from `AppEnvironment` and returns a `UIViewController`. Routes call the Assembly, for example `InboxAssembly.makeInboxViewController()` or `PlannerAssembly.makeEventDetailsViewController(eventId:)`.

Larger features (Inbox, Planner, CourseSync) split further into subfolders per screen, but follow the same shape. **New screens should use this pattern.**

### 6.3 Legacy UIKit screens
Many screens are still `UIViewController`s with storyboards and a static `create(...)` factory (e.g. `PageListViewController`). They usually own a `Store` directly.

---

## 7. Navigation (URL routing)

`Core/Core/Common/CommonModels/Router/`

Navigation is URL-driven and mirrors Canvas web paths. Deep links, push notifications, links inside rich content, and in-app taps all go through the same router.

```swift
// Student/Student/Routes.swift
let router = Router(routes: [
    RouteHandler("/courses/:courseID/pages/:url") { url, params, userInfo in
        ...return a UIViewController
    },
    ...
])

// anywhere in the app
env.router.route(to: "/courses/1/pages/intro", from: self, options: .push)
```

- **`RouteHandler`** matches a path template. Templates support literals, `:params` and `*splat` segments, and a leading `/api/v1` is ignored. Its factory receives the URL, the extracted params, optional `userInfo`, and (optionally) the `AppEnvironment`.
- **`RouteOptions`** controls presentation: `.push`, `.detail` (split-view detail on iPad), or `.modal(style, isDismissable, embedInNav, addDoneButton, animated)`.
- **Each app has its own table**, so the same path can open different screens in Student, Teacher and Parent. Adding a screen means adding a `RouteHandler` to every app that should reach it. `Student/StudentUnitTests/RoutesTests.swift` checks the Student table.
- Unmatched URLs fall back to the router's fallback handler, which typically opens them in an in-app web view or externally.
- `CourseTabUrlInteractor` filters routes to course tabs the user has disabled.

---

## 8. UI layer

`Core/Core/Common/CommonUI/`

- **InstUI** is the in-house design system: SwiftUI components, styles, `BaseScreen`, and `InstUI.ScreenState`.
- **Brand / Appearance** handle institution branding (`Brand.shared`, colors and header image) and are applied globally at launch.
- **CoreWebView** is the shared `WKWebView` used to render Canvas rich content (HTML pages, discussions, LTI). It shares a process pool with the offline downloader.
- **Hosting:** SwiftUI screens are wrapped in `CoreHostingController` and pushed inside `CoreNavigationController`.
- **Strings** use String Catalogs (`Localizable.xcstrings`). Core code uses `String(localized: "…", bundle: .core)`, and each app has its own catalog.

---

## 9. Offline support

There are two separate mechanisms:

1. **Canvas offline mode / course sync** (`Features/Offline`, `Features/CourseSync`)
   - `OfflineModeInteractor` tracks connectivity and whether offline mode is enabled. `ReactiveStore` consults it to serve CoreData-only results.
   - CourseSync lets users pick courses to download. It runs as a background task registered in the AppDelegate.
   - Offline-aware UI helpers include `OfflineBannerView`, `OfflineObservingButton`, and `NotSupportedInOfflineAlert`.

2. **2U offline downloader** (`Core/Core/DownloaderClient`, `Core/Core/UIDownloads`)
   - This mechanism is built on the `mobile-offline-downloader-ios` package (Realm-backed).
   - `DownloaderClient.setup(with:)` configures per-user storage (`<host>_<userID>`) under Application Support. Downloadable types are `Page`, `ModuleItem`, and `File`.
   - Extensions such as `Page+OfflineStorageDataProtocol` and `ModuleItem+OfflineDownloadHelperProtocol` adapt Canvas models to the downloader.
   - `UIDownloads/` holds the Downloads screens plus helpers, including `HTMLWistiaHandler` for embedded Wistia video.

---

## 10. Observability

| Tool | Where | What |
|---|---|---|
| DataDog | `CommonModels/DataDog`, AppDelegate `setupDatadog()` | Logs, RUM, traced `URLSession`, user ID tagging; PII redacted by `SensitiveDataRedactor` |
| Pendo | `PendoAnalyticsTracker` | Product analytics (disabled on logout) |
| Firebase | Crashlytics, `RemoteConfigManager` | Crashes, remote flags |
| Bugfender | AppDelegate, `OfflineLogsMananger` | Remote device logs (e.g. download errors) |
| `Analytics` / `RemoteLogger` | `CommonModels/Analytics` | Screen-view and breadcrumb logging (`ScreenViewTrackingParameters`, `PageViewEventController`) |

---

## 11. Configuration and secrets

- **Secrets:** static keys (PSPDFKit, AWS, Bugfender, …) are cases of `Secret` in `Secret.swift`. Their values are generated into data assets by `yarn build-secrets "key=value" …` and are not committed. See [secrets.md](secrets.md) for the full mechanism.
- **Feature flags:** these come from Canvas environment feature flags (`GetEnvironmentFeatureFlags`), from `ExperimentalFeature`, and from Firebase Remote Config.
- **MDM:** managed logins are read from `UserDefaults` key `com.apple.configuration.managed` via `MDMManager`.

---

## 12. Testing architecture

| Layer | Location | Notes |
|---|---|---|
| Core unit tests | `Core/CoreTests` | Hosted by `CoreTester` |
| App unit tests | `Student/StudentUnitTests`, `Teacher/TeacherTests`, `Parent/ParentUnitTests` | Include route-table tests |
| E2E/UI tests | `*E2ETests` | Built on `TestsFoundation` (`UITestCases`, data seeding, `MiniCanvas` mock server) |
| Test plans | `TestPlans/*.xctestplan` | CI, Core, iPad, and E2E per app |

- **`CoreTestCase`** (`Core/CoreTests/TestHelpers/CoreTestCase.swift`) sets up a test `AppEnvironment` with an in-memory database and a mock `API`. Use `api.mock(<APIRequestable or UseCase>, value: …)` to stub responses.
- **Interactors** are protocols with `*Preview` or mock implementations, so ViewModels can be tested without networking.
- **Fixtures:** API models expose `#if DEBUG` `static func make(...)` builders in their own files (e.g. `APIAssignment.make()`); CoreData and GraphQL fixtures live in `TestsFoundation/Fixtures`.

---

## 13. Adding a new feature: checklist

1. Create `Core/Core/Features/<Feature>/`. For SwiftUI, scaffold it with the MVVM Module template.
2. Add the `API*` models and an `APIRequestable` request.
3. If the data is cached, add the CoreData entity to `Database.xcdatamodeld`, the `NSManagedObject` subclass, and a `UseCase`.
4. Write the Interactor (protocol, Live, and Preview), the ViewModel, the Screen, and the Assembly.
5. Register a `RouteHandler` in each app's `Routes.swift` that should reach it.
6. Add localized strings to the relevant `.xcstrings`.
7. Add tests based on `CoreTestCase`, and a route test where relevant.
8. Run `make sync` so the generated Core and Student projects include the new files.
