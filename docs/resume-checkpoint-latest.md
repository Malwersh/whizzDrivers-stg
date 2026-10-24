
## 295 — active driver overview and pre-pickup unassignment
Human merchant-discount test order ORD1792721062420 / 691d5628-2497-5a60-88d6-25971d6aa0d2 was read as assigned, attempt1, holdACTIVE, no pickedUpAt. New driver overview with brand palette, route, collection amount, expandable timeline and pinned action. Shared financial-unassign sheet added before departure and reused on heading/at-store; removed legacy whole-order cancellation affordances for those stages. Sheet-pop/navigation sequencing and cache guards corrected; no forced two-hour searching setting. At-store issue callback now requires real API success instead of fake delay. Driver235profile final; see active-driver-trip-redesign-295.md. 13 Flutter +7cod-reassignment +6full-cash-lifecycle tests passed; no server writes/deployment or unassignment of current test. Next: human reviews new first screen, continues to next stage and shares screenshot for staged redesign. Do not unassign this order just to test.

## 296 — pickup display name
User observed generic pickup label. Live order stores actual `storeName=مطعم فتوش`; DriversApi getOrderById ignored storeName and returned only legacy restaurantName/businessName. Fixed response to choose first nonblank storeName/restaurantName/businessName. Six active-order read tests pass against both local source and patched deployed handler. Published name-only change to DriversApi-staging from captured live ZIP, all other entries preserved, revision/hash guarded; activation verified in pickup-name-publication-296.json. No native rebuild, order record edit or finance change. Driver235 restarted to reload server data; current order already heading_to_store by human action (startHeadingToStoreAt present). User reviews pickup name then next-stage UI. Backup candidate/old ZIP kept privately under /private/tmp/pickup-name-296.

## 297 — heading-to-store road route/help + per-driver test location
User approved Mapbox coordinates explicitly. Display-only road endpoint added and bounded-published DriversApi-staging; exact GetSecretValue permission/server reference only. Current order same ORD1792721062420 remains heading_to_store / holdACTIVE. Route check37vertices,3066.682m,269.63s. Heading redesign: map with genuine road polyline store→customer, scoped road metrics, real pickup metadata, pinned arrival, Help menu containing actual contact/items/report/unassign actions. No separate technical unassign label. Report only acknowledges saved report, not nonexistent support notification. No price/money/state changes by agent.
Global old fixed-driver coordinate behavior was found and isolated: GPS default; explicit staging nonproduction driver-ID override only. Final237 profile built with USE_TEST_LOCATION=true / TEST_LOCATION_DRIVER_ID=34d8e408-1021-7076-6055-7325644f97cb for this trial, all other drivers GPS. Unknown/missing GPS does not invent fallback dispatch point. Two location providers, search, websocket and home updated; remaining heading-to-customer literals removed. 25 Flutter +11Node tests pass; broad preexisting home warnings remain, no analyzer errors. See heading-route-redesign-297.md/publication297. Next human reviews heading screen/map/help without pressing arrival, then next stage redesign. No automatic test unassignment.

## 298 — report-sheet redesign, audited reports, arrival drag, external Maps
Driver238 profile: new report form with current palette, left-pointing arrow under RTL + progress fill/reset/single completion, CTA توجّه إلى المتجر. Ordinary Maps uses live device origin/navigation; trial driver explicit Iraq origin/drive preview (cannot simulate external app GPS). Backend reportStoreIssue bounded-published with audit helper: all five options save report/history only, validate owner/pre-pickup/current financial attempt, idempotent reportId retry, preserve money/state. No auto cancellation/refund/support notification; separate financial unassign unchanged. Client must use238 reportId/assignment fields. 23Flutter+22Node tests pass. See heading-interactions-298.md / pickup-issues-publication-298.json. Current order unchanged by agent; human reviews new interactions before actual arrival.

## 299 — driver copy / intended pickup-issue behavior clarified
User asked that issue sheet not explain internal workflows, and requested operational behavior explanation. Replaced yellow internal-flow note with simple driver-facing hint: اختر المشكلة التي واجهتك، وأضف تفاصيل تساعدنا على متابعتها. Native239 profile, same explicitly scoped trial driver flags. No new backend/financial policy or state transitions. Explained intended workflows as recommendations: missing/wrong items require merchant correction/customer consent, store closed requires verification and formal order resolution rather than futile redispatch, delay allows wait/unassign with policy-based compensation only, Other requires review. Current code saves guarded audit reports; admin case queue/contact/decision/closure workflow remains to be implemented. Do not imply existing automatic notifications or resolution merely from selecting a reason.


## إضافة مؤجّلة بطلب المستخدم — معالجة مشكلات الاستلام
أُضيفت دورة معالجة الحالات الخمس (صنف غير متوفر، متجر مغلق، تأخير تجهيز، اختلاف محتويات، أخرى) إلى الخطة الأساسية ../../whizzCentralPlatform-stg/docs/finance-pricing-settlements-returns-unified-plan.md بتاريخ2026-10-22. لكل بلاغ حالة ومسؤول ومهلة ونتيجة إغلاق موثقة؛ المتبقي يشمل المتابعة والتواصل والإشعارات والقرارات وربط آثارها بالمسارات المعتمدة. الموجود حاليًا حفظ البلاغ والسجل والتحقق فقط. البند مؤجّل بطلب المستخدم؛ لا يبدأ تنفيذه تلقائيًا ولا يغيّر الطلب الجاري أو الحسابات. تعليمات السائق دون شرح العمل الداخلي.

## 300 — round arrival slider presentation only
User requested reference pill/circular slider shape without copying its English text. TripArrivalSlider now uses fully rounded pill track and circular yellow thumb. Drag fill/shadow uses brand primary yellow; alpha is zero at rest, so no progress/shadow block appears before dragging. Current Arabic labels, leftward drag, threshold, arrival call and repeat protection unchanged. Existing five heading interaction tests pass. Driver240 profile built with same staging trial-driver scope; no backend or order/financial action. Main pickup-issue workflow remains deferred per user.

## 301 — at-store pickup screen redesign
AtRestaurantScreen now follows shared trip design, clear order number/copy, store/address, items/quantities/options/notes, customer destination and cash collection at customer delivery; no zero unit prices. Pickup is pinned shared circular/yellow slider with contextual labels. Help/contact/report/unassign use real existing actions; pre-pickup actions hidden after pickup. Read-only refresh does not transition state. Retry after confirmed pickup skips duplicate pickup and resumes heading only after human slide; lost replies recover via fresh read. 28Flutter tests pass incl six new pickup/narrow layout/recovery cases; targeted analyzer no errors/warnings. Driver241 profile; no backend/financial changes or agent pickup on live order. See pickup-screen-redesign-301.md. Next: human reviews pickup screen, then confirms pickup to reach next screen for staged redesign and remaining merchant-funded discount settlement test.


## 302 — Heading to customer redesign
Shared trip styling, full destination/landmark, cash due, actual call and scoped Maps navigation, complete store-to-customer road overview, separately refreshed driver GPS marker, pinned circular arrival slider with fresh-read guard. Postpickup Help opens existing return screen only by explicit action. Tests: 15 combined passed, 2 final screen tests passed; analyzer info only. Build 242 in progress. No test-order transition by agent. See driver docs/customer-trip-redesign-302.md.

Build 242 profile succeeded and was installed on the test iPhone; application launch requested. No server deployment needed for 302.


## 303 — Help dismissal and landmark clarity
Added explicit shared “العودة إلى الطلب” button to dismiss Help without actions, retained close icon. Customer screen suppresses generic map-placeholder landmarks, keeps actual customer landmark. Blue map pin is existing scoped GPS driver marker, house is destination and yellow store is pickup. Six customer/store route widget tests passed, including Help dismissal and hidden placeholder at 320/390 widths. Profile build 243 in progress; no server or order mutation.

303 build 243 profile succeeded, installed on test iPhone and launch requested.


## 304 — Unified postpickup Help surface
Fixed detached unable-to-deliver tile: shared DriverTripHelp owns the optional action inside its single scrollable white surface, before the Return-to-order footer. Heading-to-customer handles the returned action after the sheet closes and opens the existing ReturnOrderScreen. Other trip screens explicitly ignore that unavailable action. No financial or order transition on Help open/dismiss. Tests now use a financial order and assert action/footer belong to the same scroll surface at 320/390 widths; 12 customer/store/pickup tests passed. Build 244 in progress.

304 profile build 244 succeeded and installed on the existing test iPhone; app launch requested. No backend deployment.


## 305 — Help bottom safe-area background
Moved bottom SafeArea inside the white rounded DriverTripHelp surface; removes transparent bottom gap across all shared trip Help screens, retains protected controls above home indicator. Reviewed issue and unassign sheets: no corresponding outside SafeArea wrapper. Six customer/store tests passed, with 34px bottom safe inset and geometry assertions that white surface reaches screen bottom and Return button remains above safe inset on 320/390 widths. Build 245 in progress. No order/backend mutations.

305 profile build 245 succeeded, installed on test iPhone and launch requested.


## 306 — Delivery and cash-review redesign
Unified delivery screen, actual phone action, full destination/items/amount, shared round slider gated by full COD confirmation, preserved cash-review/return/completion flows. Cash-review layout restyled without API/financial policy changes. Removed nonpersisted camera control. Fresh read validates delivery stage; cache cleanup scoped to order ID. 16 tests passed; analyzer style info only. Build 246 in progress. See driver docs/delivery-screen-redesign-306.md. No agent mutation on ongoing test order.

306 profile build 246 succeeded and installed on the test iPhone; app launch requested. No backend deployment.


## 307 — Actual optional delivery-photo evidence
Restored camera via private upload + guarded order attachment + authenticated viewing. Three JPEG photos/order, max1.5MB each, client EXIF stripping, SHA256/server timestamps, idempotent retry. DriversApi-only selective deploy; no IAM/env or financial changes. Live disposable-order/JPEG smoke verified upload/read/replay/auth/stage invariance/postdelivery retrieval and deleted all fixture records/objects. 25 backend checks and 9 frontend tests passed; analyzer no errors/warnings. Build247 succeeded, phone installation in progress. Main test order untouched. Details: driver docs/delivery-proof-307.md. Admin viewer not added by this change.

307 build247 installed successfully on test iPhone; app launch requested. Current order photo capture/upload/delivery remain for the user to perform.


## 308 — Delivery failure bottom sheet
Initial unable-to-deliver form is now a shared bottom sheet from both customer-route and delivery screens, with close/Return-to-order controls, safe-area white background and brand styling. Open/dismiss read only; explicit confirmed return resumes existing canonical full continuation. 15 tests passed including narrow-screen dismissal and explicit-request transition; no backend/order mutation. Build248 in progress. See driver docs/delivery-failure-sheet-308.md.

308 native profile build248 succeeded and installed on test iPhone; app launch requested.


## 309 — Full blue completion screen and driver entitlement
Replaced success dialog with full brand-blue completion screen, yellow check/Home CTA, order number and white server-verified driverEarnings card. Fresh delivered/completed read only; no cash/fare/hold-derived amount, missing amount retry, confirmed zero supported. Existing completion recovery and different-assignment protection preserved. 10 tests passed; analyzer style info only. Build249 in progress. No backend deployment or order mutation. See driver docs/delivery-completion-screen-309.md.

309 native profile build249 succeeded and installed on the test iPhone; app launch requested. No redelivery of the already completed order.


## 310 — Yalla human delivery settlement verified (read only)
Order ORD1792721062420 / 691d5628-2497-5a60-88d6-25971d6aa0d2 is delivered, full COD8500, walletFinancialStatus SETTLED, hold5750 SETTLED and lifecycle COMPLETED. Outcome FCS:1d6a2cd40547abe1cc1216f3fba02e78881a56632857b86c COMPLETED. Merchant-funded Yalla500 used once (campaign/customer counters1), no platform goods benefit. Merchant payable5450 LOCKED_PENDING_SETTLEMENT (not paid); driver retains2750 cash and gets0 additional wallet credit. Commission15% goodsGross7000 =1050; service500; platform delivery support1250 (agreement1000 +baseline250); net contribution300 before overhead. Cash conserved8500=2750+5450+300. Posted GL debit=credit7000; paginated ledger reads found exactly2 hold-creation entries and2 completion entries, matching one canonical operation. No open cash review. All16 audit checks PASS. No AWS mutation, declaration, payout or replay invocation. Report: central docs/yalla-settlement-audit-310.json. This verifies this one staging test, not the full acceptance plan.


## 311 — Trip history study/redesign and earnings-source correction
Reviewed official Spark Driver (trip history/receipts), Uber Driver trip earnings and DoorDash app guidance; adapted actual single-order data/brand palette. New lazy date-grouped cards, server period/status filters, correct local end-date/year, cursor/dedupe/retry/session guards. Details show owned terminal trip, verified driver entitlement/base/tip, saved stop map markers only, timestamps/estimated accepted distance/actual elapsed duration, COD settlement breakdown, readonly photo evidence and existing explicit cash/return support actions. Returned history included; unavailable earnings never use customer tariff or zero. DriversApi-staging selectively published read-only helper/list/detail changes; all financial writers/IAM/env preserved. 31 backend and12 frontend checks passed; native profile250 built. Live read-only validation15 trips/page1 confirmed Yalla2750 vs customerfee1500; COD8500/retained2750/settled5750, authorized detail and filters, unrelated driver denied. No order/wallet changes. See driver docs/trips-redesign-study-311.json, trips-history-publication-311.json and trips-history-verification-311.json. Phone install in progress. Main acceptance plan remains pending beyond this one Yalla test.

311 profile250 installed successfully on the existing test iPhone; app launch requested. User can open رحلاتي and Yalla details to review.


## 312 — Simplified driver earnings
Replaced placeholder with brand navy/blue/yellow one-screen period summary (day/week/month/custom), complete confirmed entitlement totals, reconciled base/tips, weekly inline day selection, linked existing trip details and clear empty/retry states. All cursors collected before any total; order dedupe, selection and whole-load identity guards. Excludes COD collection, wallet cashflow and unconfirmed legacy figures. No new API or financial writes. 12 Flutter tests passed; analyzer no errors/warnings (6 brace style info). Live read-only America/Chicago week Oct19–25:12 confirmed completed trips, total37000=base32750+tips4250; Yalla2750. Reports driver docs/earnings-redesign-study-312.json and earnings-verification-312.json. Profile251 build/install pending. Main financial acceptance plan remains separate.

312 native profile251 built successfully and installed on existing test iPhone. App launch requested. No backend publication or financial writes.


## 313 — Earnings calendar contrast
Explicit light date-range picker theme: pale blue selected interval, brand blue endpoints with white numerals, navy text, white header/surface and blue today outline. Removes inherited dark selection band. Flutter analyzer no errors/warnings (brace style info only). Native profile252 build/install pending. No data or financial behavior changes.

313 profile252 built and installed successfully on existing iPhone. Launch requested.


## 314 — Regional demand forecast implemented
Replaced constant home bars with authenticated scoped demand API/card and 7-day hourly bottom sheet (close/return), Baghdad timezone, region name, explicit district fallback, test badge, insufficient/stale/error states. Stream dispatch-job METADATA + hourly reconciliation writes only isolated staging-DriverDemand analytics table; conditional hashed order dedupe, first-dispatch timestamp/pickup region, no offers counted multiple times. 56-day same-weekday/hour weighted estimate (0.85 weekly decay), min3 matching complete days/20 orders; excludes partial/current days and collector-gap days. Known all-store closures masked using merchant schedules incl overnight; unknown hours remain unknown. TEST/SIMULATION/LIVE keys separated; synthetic history only for allowlisted trialdriver in staging, no synthetic orders or money. Readers require complete matching generation/health and hide data older2h. Stream retries/DLQ, hourly rule, CloudWatch alarms (no SNS destination). 6 API+7 worker+4 Flutter tests and6 trip-history regression tests pass; analyzer no errors/warnings,4 style info. Reports driver docs/demand-design-314.json, demand-publication-314.json, demand-verification-314.json. Native253 installed then final254 build/install pending. No dispatch/order/wallet financial writes or production publication. Production LIVE configuration, history accumulation, real-accuracy validation and operations notification destination remain launch tasks.

314 final native profile254 built and installed successfully. Final published service verification PASS:7days/24hours, scoped area الحيرة, explicit simulation flag, unknown driver403, client region/dataset override ignored, raw TEST history remains insufficient. Writer IAM restricted to analytics. App launch requested.


## 315 — Demand region meaning and chart clarity
Read-only verification: profile work region الحيرة Rmhveqa2vrrj13; test merchant pickup region مركز المناذرة Rmhvcpnn3iy5f1; both parent قضاء المناذرة Rmhvc7snfyul1f. Driver not searching; card correctly uses registered work region, not GPS/last live region. Orders count under pickup region plus district aggregation, never relabeled as الحيرة. UI now explicitly labels منطقة العمل, fills available plot width with continuous baseline/background, true zero bar height, low/medium/high legend, relative-height/timezone explanation and tap hour tooltips. 4 Flutter tests passed; analyzer no errors/warnings (4 style info). Profile255 building; no backend/config/order/finance changes. See driver docs/demand-clarity-315.json.

315 native profile255 built and installed successfully on existing test iPhone. App launch requested.


## 316 — Demand times use 12-hour Arabic clock
Changed home/week forecast hour labels, tapped-hour tooltips and last-update time to Arabic numerals with ص/م; midnight12ص, noon12م. Baghdad timezone and internal 24-hour buckets preserved. Profile256 build/install pending. No backend or data changes.

316 final4 Flutter checks passed including320px/390px; native profile256 built and installed successfully; app launch requested.


## 317 — Demand feature uses yellow brand palette
User selected primary yellow. Scoped palette in demand_card.dart: high FDC500, medium FFDC66, low FFEBA3, warm surface FFFCF2/outline E8D69C; dark amber8A6100 actions and navy text for contrast, yellow selected day. Home/week graphs and legends match; closed-state neutral retained. Clock12h unchanged. A faulty slicing script was rejected before execution; safe targeted changes applied instead, file structure preserved. Native257 build/install pending; no backend/data changes.

317 4 Flutter tests passed; analyzer no errors/warnings,4 style info. Native profile257 built and installed successfully; app launch requested. Color-only scope, no data changes.


## 318 — Demand palette changed to secondary navy
User preferred navy over gold. Changed only scoped DemandColors: high00296B, medium4D6997, low99AAC4, surfaceF4F6FA, outlineD6DEEA; actions navy. Selected-day text/check white for contrast. 12h clock and demand behavior unchanged. Profile258 build/install pending. No backend/data changes.

318 analyzer no errors/warnings (4 existing style info). Native profile258 built and installed successfully; app launch requested. Secondary navy demand palette is final user preference, superseding317 yellow.


## 319 — GitHub handoff requested
User authorized publishing all session updates for colleague pull. Scope: four staging repositories on feature/malwersh/bootstrap; legacy non-staging worktrees excluded. Repository-specific Arabic handoff record: docs/github-handoff-2026-10-23.json. Current batch passed: Drivers54Node+7Python+65Flutter, Merchants6Flutter, Customers2Flutter; Central docs whitespace checked. Driver native258 installed, final demand colors secondary navy and12h ص/م. No financial operation or new AWS deployment performed for GitHub upload. Detailed commit messages and GitHub commit comments describe scope and pending work.


## 320 — General delivery pricing audit; NO ACTIVATION
User requested review after colleague NO_PRICING_RULE on Frouj; explicitly forbids activation until agreement. Read-only CURRENT staging-PlatformStaff OPERATIONAL_SETTINGS#DELIVERY_PRICING version1 Oct17 still contains only FATTOUSH_SAMPLE_DELIVERY/DRIVER scoped to business_95ac73c9-feda-4207-9285-550aec61b94c and one destination zone. All14 inspected general-release hosts REQUIRED: execution generalized, pricing data not generalized. Root is incomplete policy rollout, not engine inability. Approved baseline59 remains customer1000+500/km min2000 max6000, road10km/1800s; driver1000+400 delivery/km+250 pickup/km after1km min1500 max8000; nearest250 half-away, optional extras0. Prepared offline DRAFT GLOBAL pair preserving branch overrides over8 active indexed regions. Frouj business_1791634772438_p2hlg6w5qii has own numericGPS/prep20/min10000 but lacks organization/commercial agreement ID/version: separate order-readiness blocker. Published colleague routeInformation/storefront_route verified in downloaded Lambda code; its malformed prep/minimum can still hide valid road info and source was not in fetched integration/colleague refs. Recommendation requires source handoff/readiness and scope approval before audited central publish. Current ZONE means destination, CITY is UNBOUND; no invented city/merchant identity.114 offline tests pass, runtime syncPASS,6 new tests. No Mapbox calls, AWS/financial writes or activation; CURRENT remains version1. Review docs/general-delivery-pricing-review-320.json, local candidate docs/general-delivery-pricing-candidate-320.json, offline generator/scripts test320. New rollout must preserve in-flight driver fallback on rollback; restoring only Fattoush policy can strand non-Fattoush orders. No commits/push/deployment performed for this audit.


## 261 — Reconcile pre-pickup cancellation / administrative unassignment
User reported driver stuck on restaurant pickup after administrative cancellation. Read-only strong DynamoDB audit confirms cancelled order bb2c4170-63ec-56eb-86df-723ea5c629f4 and driver live currentOrderId null, activeOrdersCount0, isActive/isSearching true, available. Existing cancellation and unassignment financial transaction already release live state atomically; no backend business mutation required/performed. Added ActiveAssignmentGuard to heading/pickup screens: authoritative read on entry, every5 seconds, resume; clear only matching cache/provider and leave stale Navigator/GoRouter screens; newer live assignment routed instead, delayed old responses cannot clear new local assignment, postpickup/return/completed screens untouched. Failed/unauthorized/malformed/404 reads never interpreted as no assignment. Existing online search session retained; Home reconciles existing session without inventing a new one. 20 targeted Flutter tests passed (7 new cancellation/unassignment/resume/offline/new assignment/race tests); targeted analyze no errors/warnings, existing print/style info only; simulator build261 installed on both booted devices, launched. iPhone16 screenshot shows login, so authenticated live UI verification requires user login; server availability independently verified. No funds, order or driver data edited. Evidence docs/driver-assignment-release-261.json.


## GitHub handoff and product/import delegation — 2026-10-24

User requested all four staging repos on feature/malwersh/bootstrap ready for colleague pull, with detailed commit messages and GitHub commit comments. docs/github-handoff-2026-10-24.json records repository changes, validation, pull instructions and scope. Full manual products/CSV/Excel/menu/options/images/catalog/stock/branch/versioned publish work delegated to colleague; canonical handoff docs/merchant-products-import-colleague-handoff-2026-10-24.txt in Central and Merchants. Main plan and transition/product plans mark DELEGATED_TO_COLLEAGUE, not complete. Agent must not implement a parallel importer; coordinate order/pricing/stock/COD contracts. No new AWS deployment/business action as part of upload. Next ongoing COD work remains pickup issue resolution, respecting delegated menu/item-change ownership.
