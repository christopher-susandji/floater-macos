# Floater → Keynote Live Video Source

Branch: `feature/live-video-source`

## Goal

Let a Floater timer be inserted into a Keynote slide as a **live video source**, so the
countdown appears inside the presentation itself (fullscreen-safe, no floating window on
top of the slideshow).

## Mental model

### How Keynote finds "live video" sources

Keynote's *Add Live Video* feature (`Insert → Live Video`) does **not** know about windows
or apps. It only lists **camera devices** (internal FaceTime camera, an iPhone/iPad
connected over cable, an external camera). Anything that wants to show up in that menu must
present itself to macOS as a camera.

So the feature is really two independent problems:

1. **Become a camera** — register Floater as a virtual camera so Keynote (and every other
   camera consumer: Zoom, QuickTime, FaceTime, Safari) sees it.
2. **Produce frames** — render the current timer (the same `TimerView` we already draw in a
   floating panel) into video frames and push them into that virtual camera at a steady
   frame rate.

### How a virtual camera works on macOS

There are two mechanisms:

- **Legacy: CoreMediaIO DAL plug-in** (`*.plugin` in `/Library/CoreMediaIO/Plug-Ins/DAL/`).
  Deprecated and blocked on macOS 12.3+. Skip it.
- **Modern: Camera Extension (System Extension)** — a sandboxed `.appex` built on the
  CoreMediaIO framework (`CMIOExtensionProvider` / `CMIOExtensionDevice` /
  `CMIOExtensionStream`). Introduced in macOS 12.3, recommended by Apple, App Store
  deployable. **This is the path.**

We are on `MACOSX_DEPLOYMENT_TARGET = 26.5`, so the modern path is fully supported.

### Architecture (target)

```
┌──────────────────────────────────────────────┐
│  Floater.app  (main process)                 │
│                                              │
│  AppViewModel / TimerViewModel / TimerEngine │  ← existing timer logic
│        │                                     │
│        ▼                                     │
│  FrameSource (NEW)                           │  ← renders TimerView offscreen
│    • renders a "broadcast" Timer view        │     into a CVPixelBuffer
│    • 1920x1080 (or 1280x720) @ 30fps         │
│    • transparent → solid background          │
│        │  (XPC shared memory / sink stream)  │
└────────┼─────────────────────────────────────┘
         ▼
┌──────────────────────────────────────────────┐
│  FloaterCamera.appex (Camera Extension)      │
│    CMIOExtensionProvider                     │
│      └ CMIOExtensionDevice  "Floater"        │
│          └ CMIOExtensionStream (video)       │  ← vends frames to clients
└──────────────────────────────────────────────┘
         ▲
         │  AVCaptureDevice(.externalUnknown)
┌────────┴─────────────────────────────────────┐
│  Keynote (Live Video source menu)            │
└──────────────────────────────────────────────┘
```

The extension runs in its **own sandboxed process**. The app does not load the extension
in-process; frames cross the boundary via XPC shared memory (the pattern used by OBS
Virtual Camera) or via a "sink stream" the app writes into and the extension forwards
(see `ldenoue/cameraextension` in References).

### Mapping to the existing codebase

| Existing piece | Role in this feature |
| --- | --- |
| `Timer/TimerView.swift` | The visuals we want to broadcast (classic / vintage) |
| `Timer/TimerViewModel.swift` | Source of truth for a single timer's state |
| `App/AppViewModel.swift` (`shared`) | Which timer(s) are live; could add a "broadcast timer" selector |
| `Timer/TimerEngine.swift` | Already UI-free timer state — ideal to drive the frame source |
| `App/FloatingTimerManager.swift` | Today draws timers as `NSPanel`s; live-video is an *alternative sink* |
| `App/FloaterApp.swift` | Where a broadcast on/off command / menu item would live |
| `AppIntents/` | Precedent for system integration; a "Start Live Video" intent is possible |

Note the broadcast view should render its own clean, full-frame version of the timer
(solid background, centered, larger type) rather than trying to capture the existing
floating panel with transparency.

## TODO checklist

### Phase 0 — Spikes & decisions
- [x] Spike: create a working Camera Extension from the Xcode template, get it to appear as
      a selectable camera in QuickTime/Keynote, and confirm the install/approve flow.
      **Done (code written, compiles + embeds — runtime install/appearance not yet verified).**
- [x] Decide frame transport: **XPC shared memory** (OBS-style) vs **sink-stream** (simpler,
      single-app, `ldenoue/cameraextension`-style).
      **Chose sink-stream.** The extension exposes a second `.sink` stream; the host app
      renders the timer and enqueues frames into it via `CMIOStreamCopyBufferQueue`.
- [ ] Decide resolution/fps (currently 1280x720 @ 30 in `CameraConfig`) and background:
      solid dark is implemented; transparent/chroma not supported by the pipeline.

### Phase 1 — Become a camera
- [x] Add a **Camera Extension** target (`FloaterCamera.appex`) via the CoreMediaIO template.
      Added as a new PBXNativeTarget + synchronized root group (`FloaterCamera/` at repo root).
- [x] Configure `CMIOExtensionProvider` → device "Floater" → one output video stream.
      (`FloaterCamera/FloaterProviderSource.swift` renders a placeholder "FLOATER" + clock.)
- [x] Add entitlements: `com.apple.developer.system-extension.install`, sandbox, app groups.
      (`Floater.entitlements` + `FloaterCamera/FloaterCamera.entitlements`, group
      `YMBQH9QU3B.me.christophersusandji.Floater`.)
- [x] In the host app, request activation with `OSSystemExtensionRequest`.
      (`App/CameraExtensionManager.swift`, invoked from `applicationDidFinishLaunching`.)
- [ ] Handle the user approval flow (System Settings → Privacy & Security → Allow).
      Prompt appears on first launch; needs a manual run to verify.

### Phase 2 — Produce frames
- [x] Build a `FrameSource`/`BroadcastTimerView` that renders the active timer offscreen
      into a `CVPixelBuffer` pool. (`App/LiveVideoFrameSource.swift` + `Timer/BroadcastTimerView.swift`.)
- [x] Drive it from the existing `TimerEngine`/`TimerViewModel` state (tick 30fps, redraw on
      change). (`LiveVideoFrameSource` renders `BroadcastTimerView(viewModel:)` each tick via `ImageRenderer`.)
- [x] Feed frames into the extension via the chosen transport. (Host enqueues into the extension's sink stream via `CMIOStreamCopyBufferQueue`; extension forwards sink→source.)
- [x] Ensure the camera outputs black/placeholder frames when no timer is broadcasting.
      (Extension renders the placeholder when `sinkActive == false`; host renders "Floater" when `viewModel == nil`.)

### Phase 3 — UX & lifecycle
- [x] Add an on/off "Live Video" control (menu command / App Intent / timer context menu).
      Added a per-timer camera/video toggle button in `TimerListCell`.
- [x] Let the user choose *which* timer to broadcast (single active source).
      (`AppViewModel.broadcastTimerID` + `startBroadcast`/`stopBroadcast`.)
- [ ] Handle timer finished / reset / edit while broadcasting.
- [ ] Graceful teardown: stop stream, deactivate or idle the extension, survive app quit.

### Phase 4 — Polish & validation
- [ ] Test in Keynote fullscreen + windowed + presenter display.
- [ ] Test alongside other camera consumers (Zoom, QuickTime).
- [ ] Audio: decide whether the completion chime should also route through the camera
      (likely no — keep it in-app, or add a separate audio stream later).
- [ ] Signing/distribution: confirm the extension ships in the app bundle (App Store / notarization).

## Open questions

1. Should Floater keep its floating-panel mode as-is, and live-video be an *additional* sink,
   or replace it? (Recommend: additional, opt-in.)
2. One broadcast timer, or a composite view of all timers?
3. Transparent background (allowing Keynote's slide to show through) is not supported by the
   camera pipeline — is a solid/chroma background acceptable? What background should the
   broadcast use (match theme, or a neutral dark)?
4. Does the user want this to also work in FaceTime/Zoom, or strictly Keynote?

## References

- [Creating a camera extension with Core Media I/O](https://developer.apple.com/documentation/coremediaio/creating-a-camera-extension-with-core-media-i-o)
- [WWDC22 Session 10022 — Create camera extensions with Core Media I/O](https://developer.apple.com/wwdc22/10022)
- [Apple Support — Add live video in Keynote on Mac](https://support.apple.com/guide/keynote/add-live-video-tan6a7b90433/mac)
- [ldenoue/cameraextension — CoreMediaIO sample w/ source+sink streams](https://github.com/ldenoue/cameraextension)
- [OBS Virtual Camera on macOS (Camera Extension, macOS 13+)](https://obs-versions.com/blog/coremediaio-virtual-camera-macos)
