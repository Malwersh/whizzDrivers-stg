# Customer trip screen — 302

Replaced the legacy heading-to-customer screen with the shared blue/yellow trip layout. Full customer address and landmark, real phone action, order number and cash due, item quantities, pinned circular arrival slider. Google Maps uses the existing scoped test origin for the designated trial driver and actual device GPS navigation for other drivers.

The existing authenticated route API displays the complete store-to-customer road geometry. Its distance/time are explicitly labeled as the complete route, not remaining driver distance/ETA. A separately refreshed GPS marker uses DriverSearchApiService; no straight-line substitute or guessed 40 km/h ETA. No new route provider coordinates or server changes.

Arrival requires an explicit driver slide and a fresh order read; only heading_to_customer / arrived_at_customer / at_customer are accepted. Duplicate gestures are blocked while pending, and confirmed arrival can be resumed without repeating the mutation. Opening, refresh, Help and map reads do not change order stage.

Help retains actual phone and item actions. Before-pickup unassignment/report actions are absent after pickup. Financial orders expose an explicit unable-to-complete action opening the existing ReturnOrderScreen; opening Help does not enter that flow or submit a return. Deferred issue-management work remains deferred.

Validation: two new widget tests at 320/390 widths; combined 15 tests including slider/navigation and financial-return regressions passed. Re-ran two screen tests after GPS refresh addition. Targeted analyzer has no errors/warnings, only style/deprecation info. iOS profile build 242 succeeded and installed on the existing test iPhone; launch requested. No live financial/stage mutation performed.
