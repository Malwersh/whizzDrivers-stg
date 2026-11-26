# Heading to pickup — 297

Heading screen rebuilt with shared blue/yellow palette, road map, store-to-customer road metrics, full address cards, contents, external navigation and pinned arrival slider. Unassignment is named الاعتذار عن التوصيل inside Help only. Removed fake fixed driver marker, straight polyline and air-distance/30kmh ETA. Failure leaves markers plus retry, without invented route or ETA.

Help actions are wired: call stored store/customer numbers when available; show items; report pickup issue through authenticated real API with matching receipt; financial unassignment before food pickup. Removed old report success dialog claiming support notification (backend support notification is unimplemented). No whole-order cancellation action.

GET /driver/orders/:id/route is display-only. Reads saved coordinates; verifies assignment/active status before and after routing; gets GeoJSON from existing Mapbox provider; validates bounds, geometry, size and deadline. One-minute memory cache. No client coordinates or prices accepted, no database writes, no fare/hold/settlement changes. Existing ANY proxy handles the route.

Pickup metadata now supports storeId/storeName/storeAddress/phone and legacy aliases. Published only handler read-route/getOrderById and new driver-trip-route.js using live ZIP preservation. Added exact-secret GetSecretValue policy and server env reference; no app secret. See heading-route-publication-297.json, backend/driver-trip-route-iam.json. Private rollback ZIP/config in /private/tmp/heading-route-297.

Validation: 11 Node tests (pickup, ownership/terminal denial, provider geometry mocks/cache/invalid geometry, existing financial reads); nine Flutter heading/overview tests, plus return regression requested; analyzer no errors/warnings; profile build236 succeeds.

Automatic approval review rejected separate live provider probe: explicit approval required to send pickup/drop-off coordinates to Mapbox. Async approval question pending. Do not probe or launch236 until response. Existing235 remains installed. No route request or order/financial mutation by agent. Update on resolution.

References: https://help.doordash.com/dashers/s/article/In-app-Navigation ; https://docs.mapbox.com/api/navigation/directions/ ; https://developers.google.com/maps/flutter-package/samples/polylines . Patterns adapted to our data and financial policies.

## Consent and location scope resolved

User explicitly approved sending only pickup/drop-off coordinates to Mapbox, reminding that fixed driver coordinates belong only to the trial driver. A direct provider check after approval returned Ok, 37 road vertices, 3066.682m and269.63s for the current order. No names or phones were sent.

Audit found older global test behavior beyond this heading screen. Replaced generic `USE_TEST_LOCATION=true` defaults with GPS default and centralized DriverLocationMode gating: explicit opt-in + staging + nonproduction + nonempty configured driver ID exactly matching current driver. Applied to search position, websocket updates and both location providers. Home search/map refresh uses newly acquired current position rather than hardcoded Najaf; no fallback point is sent after GPS failure. Removed the remaining literal demonstration driver positions from heading-to-customer as well, which now reads the same scoped current-position source (its visual redesign remains for the next stage). Websocket failure clears prior point instead of replaying it as a new GPS observation.

Final build237 includes USE_TEST_LOCATION=true and TEST_LOCATION_DRIVER_ID=34d8e408-1021-7076-6055-7325644f97cb exclusively for this human staging trial. General builds default to GPS; production blocks this override. Server rules remain authoritative. Current order read heading_to_store, holdACTIVE, same trial driver. No agent arrival/pickup/unassign/cash/order writes.

25 final Flutter tests passed including identity scope, real/test disabled/unknown/production boundaries, heading/help/route failures, overview, search authentication and return regression. 11 Node tests passed. Broad home analyzer has existing unused-member warnings; no errors. Targeted new heading/route/help analysis clean apart from info-level existing deprecations.
