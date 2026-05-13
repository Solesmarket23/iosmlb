# Show 26 Flip Tracker — v2.0

A premium iOS app for tracking profitable card flips in MLB The Show 26. Built with SwiftUI, featuring real-time market data, saved filter presets, push notifications, and automatic price refreshes.

## New Features (v2.0)

### Saved Filter Presets
- **Create custom filters** — Name and save any combination of rarity, position, series, price range, and overall rating
- **Instant application** — Tap any preset to instantly load all matching cards
- **Edit & delete** — Full CRUD operations on saved presets
- **"Save as Preset" button** — In the filter sheet, save your current filters with one tap

### Push Notifications
- **Per-preset alerts** — Toggle notifications for individual presets
- **New card detection** — Get notified when a new card enters the market matching your saved filters
- **Smart deduplication** — Only notifies once per card (tracks seen cards in `UserDefaults`)
- **Net profit display** — Notifications show estimated profit after 10% tax

### Automatic Price Refresh
- **5-minute polling** — Prices refresh every 5 minutes while the app is open
- **Silent background fetch** — No UI disruption, updates happen behind the scenes
- **New card checking** — Each refresh checks for new matches against all notification-enabled presets
- **Last refresh timestamp** — Track when prices were last updated

### Overall Rating Filter
- **Min/max overall** — Filter by card OVR (e.g., only show 85+ diamonds)
- **Works with all other filters** — Combine with rarity, position, series, and price

### Roster Updates Tracking
- **View update history** — See all roster update dates (e.g., "March 09, 2026")
- **Latest badge** — Most recent update highlighted
- **Card rating changes** — Track when cards get upgraded/downgraded (affects flipping opportunities)
- **Accessible from Filters tab** — Tap "View Update History" to see full list

## Features (v1.0)

### Card Flipping Intelligence
- **Profit-per-minute sorting** — Top opportunities ranked by estimated profit velocity based on completed order history
- **Net profit calculation** — Automatic 10% community market tax applied to all profit estimates
- **Real-time pricing** — Live sell/buy prices from `https://mlb26.theshow.com/apis`
- **Load all cards** — Fetches all available listings (up to 100 pages) for comprehensive market scanning

### Advanced Filtering
- **Rarity** — Diamond, Gold, Silver, Bronze, Common
- **Position** — SP, RP, CP, C, 1B, 2B, 3B, SS, LF, CF, RF
- **Series** — Live, Rookie, Breakout, Veteran, All-Star, Awards, Postseason, Signature, Prime, Topps Now, and more
- **Price range** — Min/max sell price in stubs
- **Overall rating** — Min/max OVR

### Premium UI/UX
- **Dark theme** — Near-black `#0A0B11` background with elevated surfaces
- **Rarity-colored glows** — Every card floats with its rarity gradient (Diamond = cyan/violet, Gold = amber/orange, etc.)
- **Player card images** — AsyncImage loading with shimmer placeholders
- **Haptic feedback** — Success, error, selection, and press feedback throughout
- **Staggered animations** — Cards cascade in with spring physics (45ms delay per row)
- **Tap for details** — Full card detail sheet with large card image, price breakdown, and net profit estimate

### Three-Tab Navigation
1. **Flips** — Shows only profitable opportunities, sorted by profit-per-minute or net profit
2. **Market** — Browse all cards with live search (client-side filtering on current results)
3. **Filters** — Manage saved filter presets, create new ones, toggle notifications

## API Endpoints Used

- `GET /apis/listings.json` — Paginated market listings with filters (rarity, position, series, price)
- `GET /apis/listing.json?uuid=...` — Detailed listing with `price_history` and `completed_orders`
- `GET /apis/meta_data.json` — Series and brand metadata
- `GET /apis/roster_updates.json` — Roster update history (dates when card ratings changed)

## Implementation Details

### Filter Preset System
- **Persistence** — `PresetManager` saves all presets to `UserDefaults` as JSON
- **Model** — `FilterPreset` struct with `Codable` conformance
- **Matching algorithm** — Each preset defines a `matches(_ listing:)` method that applies all filter criteria
- **Seen card tracking** — `Set<String>` of card UUIDs persisted to prevent duplicate notifications

### Notification System
- **Authorization** — Requests notification permissions on app launch
- **Local notifications** — Uses `UNUserNotificationCenter` (no remote push server required)
- **Delivery** — Notifications fire immediately when a new matching card is detected
- **Content** — Shows card name, preset name, and net profit

### Auto-Refresh System
- **Timer-based** — `Timer.scheduledTimer(withTimeInterval: 300)` runs every 5 minutes
- **Silent fetch** — Reloads all cards without showing loading spinner
- **Diff detection** — Compares previous card UUIDs with new results to detect additions
- **Lifecycle management** — Timer starts after first load, stops when view disappears

### Profit-per-Minute Algorithm
1. Fetch `completed_orders` array from detailed listing API
2. Parse ISO8601 timestamps, sort chronologically
3. Calculate `orders_per_minute = (order_count - 1) / total_time_in_minutes`
4. Multiply by net profit: `profit_per_minute = orders_per_minute * net_profit`
5. Fall back to raw net profit if insufficient order history

### Parallel Page Fetching
`fetchAllListings()` loads page 1, then spawns concurrent tasks for pages 2–N using `TaskGroup`, merging results into a single array. Max 100 pages (configurable).

### Design System
- **Colors** — `Color.appBG`, `Color.appSurface`, `Color.appAccent`, rarity-specific gradients
- **Haptics** — `Haptics.success()`, `.error()`, `.medium()`, `.light()`, `.rigid()`, `.selection()`
- **Typography** — SF Pro with `.semibold`/`.bold` weights, rounded design for numbers
- **Number formatting** — Comma-separated stub values (`1,234`)

## Requirements

- iOS 17.0+
- Xcode 16.4+
- Swift 5.0+
- User notification permissions (requested on first launch)

## Build & Run

```bash
cd Show26FlipTracker
xcodegen generate
open Show26FlipTracker.xcodeproj
```

Select an iPhone simulator and run. Grant notification permissions when prompted.

## Project Structure

```
Show26FlipTracker/
├── Show26FlipTrackerApp.swift       # App entry point
├── ContentView.swift                # TabView shell with 3 tabs
├── Models.swift                     # Data models (ListingsPage, MarketListing, FlipOpportunity)
├── TheShowAPIClient.swift           # API client (actor-based, async/await)
├── ListingsViewModel.swift          # Observable view model with auto-refresh
├── DesignSystem.swift               # Colors, rarity styles, haptics
├── FilterPreset.swift               # Preset model and PresetManager
├── NotificationManager.swift        # Local notification system
├── FlipsView.swift                  # Flip opportunities tab
├── MarketView.swift                 # Full market browser tab
├── SavedFiltersView.swift           # Preset management tab with CRUD
├── CardTileView.swift               # Card row component with profit badge
├── CardDetailSheet.swift            # Full-screen card detail
├── FilterSheetView.swift            # Bottom sheet filters with "Save as Preset"
└── RosterUpdatesView.swift          # Roster update history viewer
```

## Usage

### Creating a Saved Filter
1. Tap the filter icon in **Flips** or **Market** tab
2. Configure rarity, position, series, price, and/or overall
3. Tap **"Save as Preset"** at the bottom
4. Enter a name (e.g., "Gold Under 3K")
5. Tap **Save**

### Enabling Notifications for a Preset
1. Go to the **Filters** tab
2. Tap the ⋯ menu on any preset
3. Select **"Enable Alerts"**
4. New matching cards will trigger push notifications every 5 minutes

### Applying a Saved Preset
1. Go to the **Filters** tab
2. Tap any preset card
3. The app switches to the **Flips** tab and loads all matching cards

### Viewing Roster Updates
1. Go to the **Filters** tab
2. Scroll down to the "Roster Updates" section
3. Tap **"View Update History"**
4. See all roster update dates, with the latest one highlighted
5. Use this to track when cards get upgraded (better flip opportunities after rating changes)

## Notification Behavior

- Notifications check every **5 minutes** (when app is open)
- Only **new cards** (not seen before) trigger notifications
- Only presets with **notifications enabled** send alerts
- Each card triggers a notification **once** (tracked in `UserDefaults`)
- Notifications include **net profit** after 10% tax

## Future Enhancements

- Background app refresh (iOS Background Tasks framework)
- Watchlist/favorites separate from presets
- Price alerts for specific cards
- Historical price charts (using `price_history`)
- Equipment/stadium flipping
- Dark mode toggle (currently forced)
- iCloud sync for presets
- Export/import preset JSON

## License

MIT
