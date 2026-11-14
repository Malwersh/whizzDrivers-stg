# Pickup confirmation redesign — 301

User requested at-store pickup screen consistent with heading UI, circular slide confirmation and necessary driver information.

Rebuilt AtRestaurantScreen with neutral background, white/blue header, dark-blue order-number card (copy/select), actual store name/address/contact when available, ordered items with quantities/modifiers/notes, order instructions when present, customer drop-off identity/address and clearly labelled customer cash collection due at delivery. Removed misleading zero unit-price rows. No invented fare, payout or store-payment instruction. No new internal-workflow explanation in product UI. Shared help menu replaces old orange unassign/red-report buttons and removes old inert store call action.

Reused the round yellow TripArrivalSlider with pickup-specific labels via optional parameters; heading labels remain unchanged. Slider pinned at bottom, leftward gesture and yellow progress/shadow preserved. Fresh server read required before pickup; no automatic pickup or heading transition on entry/refresh. Original pickup then heading-to-customer calls remain the workflow, both following the human slide.

Recovery improvement: if pickup was confirmed but heading failed, next human retry starts from saved picked_up state and does not repeat pickup. Lost pickup acknowledgement reads server state before proceeding, rather than blindly resubmitting. Unknown/unreadable stages block pickup and expose refresh. Help hides pre-pickup report/unassignment after saved pickup. Existing report-ID/frozen-assignment service remains shared.

Verification: 28 Flutter tests passed. Six new pickup tests cover320/390 widths at text scale1.3, displayed quantities/notes/no bogus price, no entry-triggered mutation, human-only transition, heading retry with pickup count1, lost pickup response recovery and failed initial read block. Existing slider/help/route/overview/return tests remain passing. Targeted analyzer: no errors/warnings, only existing info-level styling notices. First narrow-layout test found item-header overflow; moved count below heading and reran all checks successfully.

Driver241 profile build, same explicitly scoped trial-driver flags. No backend deploy, report submission, pickup, heading, cash action or monetary change performed by the agent on the real staging order. Full issue-resolution workflow remains deferred in the main plan.
