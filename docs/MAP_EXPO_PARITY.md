# Map: porting the Expo map-shell architecture to Flutter

Goal: the Flutter map behaves like the Expo app's (`gate-closes-app`) map shell.
Status is kept current as each phase lands.

## Expo architecture (reference)

```
(tabs) Stack ── one custom bottom nav on every tab (MapBottomNav)
│   Map · Feed · [ECHO dome button] · Connections · Settings
│
├── map/        ← home after login
│   MapScreen
│   ├── MapShellLocationTracker   watchPosition; re-detect airport every 250 m
│   ├── CentralMapCanvas          Mapbox dark-v11, globe + atmosphere,
│   │   │                         time-of-day tint overlay (Map Lighting)
│   │   ├── AirportBoundariesLayer  fill + glow + outline (disk-cached)
│   │   └── TerminalMapNodesLayer   heatmap + clustered badge symbols
│   │                               (radius 45, max zoom 15), user dot,
│   │                               tap cluster → zoom, tap pin → EchoCard
│   │                               modal (+ START CONVERSATION for PS/DT/BT)
│   ├── TerminalMapTabContent     "SEARCH AIRPORT..." pill + recenter FAB
│   └── MapConnectivityBanner     "NO INTERNET — SHOWING SAVED DATA" /
│                                 "SLOW CONNECTION…" (> 3 s)
├── feed/, connections/, settings/   full screens with the same nav
└── ECHO button → AirportGateModal (Locating you… / Airport detected /
    Outside airport) → create-echo (transparent modal)
```

State: `MapHostContext` (zustand) owns the camera: follow-user mode,
`recenterToUser`, `setCamera`, visible bounds. Preferences (`preferencesStore`)
hold Map Lighting: `realtime` (dawn 5–8, day 8–17, dusk 17–19, night) or a
fixed preset.

Note: Expo also passes `lightPreset` to a Mapbox style import, but its style is
`dark-v11`, which has no imports, so that call has no effect. The visible
time-of-day change is the canvas tint overlay; Flutter reproduces the overlay.

## Flutter mapping

| Expo | Flutter |
|---|---|
| `MapBottomNav` + `AirportGateModal` | `shared/widgets/map_bottom_nav.dart`, `airport_gate_dialog.dart` |
| `map/index.tsx` + `CentralMapCanvas` | `worldMap/presentation/pages/world_map_page.dart` (home route `/`) |
| `MapHostContext` camera state | `WorldMapController` + page-local camera/follow state |
| `AirportBoundariesLayer` | GeoJSON source; only on-screen polygons (`AirportBoundaryIndex`) |
| `TerminalMapNodesLayer` | clustered GeoJSON source + badge symbol layers + heatmap |
| Echo detail modal | `/map/echo/:echoId` dialog route (terminal_echo feature) |
| `MapShellLocationTracker` | position stream → `AirportController.detectAirport` |
| `MapConnectivityBanner` + disk caches | connectivity + cached pins/boundaries |
| Settings → Map Lighting | Settings page + persisted preference, tint overlay |

## Phases

1. **Shell & navigation.** Map is home; nav = Map · Feed · Echo · Connections ·
   Settings with a raised center button behind the live airport check. Map is
   full-screen with a search pill and recenter button (no app bar/list mode).
2. **Pins & canvas.** Clustered badge pins, cluster tap zooms in, activity
   heatmap, user location, globe; pin tap opens the Expo echo card with
   Start Conversation.
3. **Location & offline.** Continuous tracking (250 m), offline/slow banner,
   on-disk pin and boundary caches.
4. **Map Lighting.** Settings page; realtime or fixed preset tint.

## Status (Sept 29)

All four phases are built. 137 tests pass, the analyzer is clean, and the
debug APK builds. **Not yet tried on a device.**

- [x] Crash fix: only on-screen airport polygons reach Mapbox (Android ran
      out of memory converting the full collection in `setStyleSourceProperty`).
- [x] Phase 1: map is home; nav Map · Feed · Echo · Connections · Settings;
      raised center button behind the live airport check (`AirportGateDialog`);
      full-screen map with search pill and recenter button.
- [x] Phase 2: clustered badge pins (Expo SVGs, radius 45, max zoom 15),
      cluster tap zooms to Mapbox's expansion zoom, activity heatmap (Expo's
      expressions), user location puck, globe projection; pin tap opens
      `EchoPreviewDialog` with START CONVERSATION for PS/DT/BT.
- [x] Phase 3: position stream re-detects the airport every 250 m and moves
      the camera while following; last location remembered 15 min; offline /
      slow banner; boundaries and pins cached on disk.
- [x] Phase 4: Settings → Map Lighting (realtime or static preset), shown as
      Expo's time-of-day tint.

## Known gaps (same structure and features — not yet identical)

- **Ported since the first pass:** map theming (terrain 1.08, dark water +
  sheen, 3D buildings from zoom 13), gestures (flat camera, rotation locked
  at zoom 3.5 and below), selected pin (0.85 vs 0.72), and the echo card's
  capitalized name and emoji reaction bar.
- **Land fills skipped.** Expo's `map-theme-land-base/accent` read a `land`
  source layer that `mapbox-streets-v8` doesn't have, so they draw nothing
  in Expo either.
- **Echo card.** No expiry indicator (echoes don't expire) and no alias
  gender prefix (the echo carries no gender).
- **Nav bar styling** is built from Expo's proportions but not matched
  pixel-for-pixel to the Figma.
- The API's `/terminal-echo/map` features now carry `createdAt` and
  listen/reaction counts (needs API deploy), so pins show "new" and the
  heatmap is weighted. No pin is "fading" (no `expiresAt`), and reply
  counts aren't sent.
- Expo's custom globe atmosphere colors have no API in `mapbox_maps_flutter`
  2.31; Mapbox's default atmosphere is used.
- Expo's animated sweep/pulse effects over the map are not ported.

## Low-end phones (Flutter only)

- **Lite map**: on 32-bit ARM Android phones, terrain and 3D buildings are
  skipped (a realme RMX3231 with a PowerVR GPU couldn't open the map).
- **Render guard** (`MapRenderGuard`): a marker is saved before the map
  starts and cleared once it has rendered and stayed up 5 s. If the app
  dies in between, or the map doesn't render within 25 s (online), the map
  tab shows "Map isn't available on this phone" with *Open Feed* and *Try
  the map again* instead of starting the map.
- Badges ship as PNGs (`tool/render_map_badges.dart`): Mapbox decodes image
  files, and rasterizing on the GPU at runtime crashed PowerVR drivers.
