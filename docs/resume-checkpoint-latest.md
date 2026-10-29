
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


## 253 — P0 launch priority and physical-handover report guard
User requires Android+iPhone cash-first launch; advanced address change/driver transfer/partial delivery deferred, preserving all work in central tracker. Central pickup issue workflow published with staff ownership/deadlines/contact records/observed operational outcomes, using existing management for cancellation/unassignment. Driver report helper now rejects merchantHandover and includes absent/null merchantHandover in atomic Update condition;12report tests pass. Effective DriversApi-staging codeSHA YnSIzfgrCYQphIhgxEQoLyHEET/c4YHnL/Nfg+9kLoU=. No native Dart change/rebuild required for this server helper. No real report/contact/order/money by agent. Android/iOS release build, signing, actual GPS and background push acceptance remain P0 and are not proven by simulator261. Evidence central docs/pickup-workflow-publication-253.json and pickup-workflow-verification-253.json. Products/import scope remains delegated to colleague.


## تصحيح مرجع الأولويات — الخطة كاملة، 2026-10-24
طلب المستخدم مراجعة جميع بنود الخطة الأساسية عبر التطبيقات الأربعة، وليس استثناءاتCODأوتطبيقًامنفردًا. المرجع الموحد ../whizzCentralPlatform-stg/docs/main-plan-all-apps-priority-review-2026-10-24.json وCSVالمرافق، معالقسمالشاملبختامfinance-pricing-settlements-returns-unified-plan.md. يشمل61بندًاو127قسممواصفةوالحزم14معحالةودليلومتبقٍوأولوية؛ الموجودلايعادبناؤهوغيرالمثبتلايسمىمكتملًا. المنتجاتوالقوائموكلنطاقالاستيرادوالمخزونالمحالللزميلمستثنىمنتنفيذنا،وليسباقيتطبيقالمطعم. يبدأالعملمنسدالضرورياتالتشغيليةحسبالتبعياتعبرالجميع،ثمفحوصالإطلاقAndroid+iPhoneبعدإكمالالتشغيلواختباره.


## الدفعة258 — بدء الدفعة التشغيلية الأولى: أمان استعادة شحن محفظة السائق

بدأ التنفيذ منF02/F03ضمنجردجميعالتطبيقات،لاكتغييرأولويةإلىتطبيقواحد. فُحصمصدرالشحنوالأرصدةوالقبولالماليوالإعدادالمنشورقراءةً:اليدويمفعل/حد25000،الدفعالمباشرزينكاشوالبطاقةمعطلان. لايعادبناءمحركالشحنالموجود. النقصالمثبتفيالعميلكانغيابحفظالمحاولةعندفقدالرد/إغلاقالتطبيقوغيابربطتحميلالمستلموالوصلوالإرسالبالحسابنفسه.

أضيفتخدمةاتصالعميلمحدودةWalletFundingServiceيعيداستعمالواجهاتالمحفظةالقائمة،ويحفظالطلبالثابتبمفتاححسابمعزولقبلالإرسال،ويستأنفنفسالمبلغ/الوصل/المرجع/نسخةالإعداد/هويةالمحاولة. لايخزنالتوكنأورابطS3الموقع. عندالنتيجةالمجهولةتُخفىحقولطلبجديدوتظهرخياراتالتحديثوإعادةالطلبنفسه. مطابقةقائمةالطلباتتشترطصاحبالطلبوالوصوللمرجعووصلمبلغمتطابقين،ولايفسرالغيابمنأحدث50نتيجةبأنالطلبلميسجل. تغييرالحسابيمسحالبياناتالمرئيةويمنعطلبًاأوردًاأجنبيًا،ولا يمنع تجديد توكن الحساب نفسه.

نجح15اختبارFlutterمنها10جديدةللخدمةوالواجهة،و10اختباراتخادمالشحنالقائم. لاAPIماليأوإعدادأوصلاحيةأومبلغتغير،ولاطلبشحنأوقبضأووصلتمتسجيلهبواسطةالوكيل. نسخةمحاكي262قيدالتجهيزمعنفسأعلامGPSالتجريبية؛هذاتحديثاختبارتشغيليوليسبدءبواباتإطلاقالنظامينالمؤجلة. مرجعالدليل ../whizzCentralPlatform-stg/docs/operational-funding-hardening-258.json ونسخةالسائق wallet-funding-hardening-258.json.

لايعدF02مكتملًابشريًامنالاختبارات. الباقي: قبولالشحنالفعلينفسهبإثباتقبضومراجعةبشريين،وتدقيقصفحاتالتاريخوالاستردادالقديم،وF05صرفالحقوقوالأرصدةالمؤهلة،وD01الأهليةوالوثائقوالمركبة،ثمبقيةحزمالدفعةالموحدة. يبقىاستحقاقالمطعم6000كماهومعلّقًاللصرفبطلبالمستخدم.


إتمام تجهيز258: نجح بناء محاكي السائق262 وثُبت وشُغل علىiPhone16معالحفاظعلىبياناتالتطبيقوأعلامالموقعالتجريبيالسابقة. لم يُنشأ طلبشحنأووصلأوتحويلأوقيدمالي. دليل15اختبارFlutterو10اختباراتخادم،وقبولالشحنالبشريوبقيةالدفعةمعلقان. جرد61بندًاوCSVمحدثانبحالةF02بعدهذاالإصلاح.


## شحن محفظة السائق وزين كاش — 260

مرجع الدليل الكامل في Central-stg: `docs/zaincash-readiness-260.json`. جُهّز الوصل والدفع المباشر وإعدادات الأسرار والتجربة المحددة والتفعيل العام والمطابقة والاستعادة. LIVE وUAT الجديدان معطلان؛ بيانات UAT مهيأة ومصادقة OAuth ناجحة دون دفع. القبول البشري وبيانات الشركة والإشعار الفعلي باقية، فلا إعلان اكتمال F02 أو خطة التطبيقات كلها. الطلبات للزبون نقدية، وصرف المطعم الحالي و6000 المعلق لا يتغيران. المنتجات/import للزميل، وبقية أولويات الدفعة محفوظة.

السائق: النسخة النهائية للمحاكي 264 مع GPS التجريبي السابق. `zaincash_funding_service.dart` و`zaincash_payment_screen.dart` يثبتان الحساب/المبلغ/البيئة/UUID ويستعيدان المحاولة، ويستخدمان المسار الجديد لـUAT وLIVE. لا تخلط قبول هذا المسار مع شاشة sandbox القديمة؛ Qi مستقل. تتحدث المحفظة عند العودة/الاستئناف/الإشعار، والسجل فعلي، والنص المرجعي لا يعد بكفاية ضمان قبول الطلب. معرف رابط العودة في Android/iOS مضاف، والجولة المصادقة على المحاكي تنتظر تسجيل الدخول. نجح22 اختبار Flutter وبناء iOS للمحاكي؛ فحوص إصدار الجهازين ما زالت بعد التشغيل.


## Wallet monthly statement and collateral — build 266
Read-only month-filtered history published via existing driver route on wallet service; Baghdad month boundaries and account/month-bound continuation with fixed asOf. Driver month/year picker, full pagination before summary/export, CSV via existing native file picker, internal holds/releases separated from actual credits/debits. FULL_CASH_RELEASED is now a neutral release and FULL_CASH_COMPLETED locked capture is a guarantee settlement, not a delivery fee. Removed fixed 25,000 progress/alert and legacy SparkNow fixed balance gate; ACTIVE wallet still required; backend immutable-offer collateral check unchanged. 24 Flutter tests + final9 pass, backend2 pass; real read-only76-row net -30,750 verified. iOS266 built with staging/nonproduction/USE_TEST_LOCATION=false. Real iMohammed device disconnected before install, awaiting reconnect. No money writes, no gateway activation. See docs/monthly-wallet-266.json and CENTRAL evidence.

Build266 follow-up: iMohammed reconnected; installed com.wiz.wizdriverapp as an update and launched successfully. devicectl installed-app listing confirms version266. User walkthrough of monthly statement/CSV remains pending; no account logout or app data deletion performed.

Release follow-up267: user reported debug266 immediately closes. Built ios --release build267 with staging/nonproduction/USE_TEST_LOCATION=false; updated same bundle on real iMohammed, launched, verified installed267 and process still running via devicectl. Human monthly CSV walkthrough pending.

Release268: restored prior scoped staging test location after user map waited for GPS in267 (USE_TEST_LOCATION=false had changed during physical build). Preserve ongoing test profile: RELEASE, ENVIRONMENT=staging, IS_PRODUCTION=false, USE_TEST_LOCATION=true, TEST_LOCATION_DRIVER_ID=34d8e408-1021-7076-6055-7325644f97cb, TEST_LATITUDE=31.913292, TEST_LONGITUDE=44.476014. Verified generated defines, installed268 on iMohammed and launched. Test override remains staging and matching-driver only. Do not reset this ongoing test profile to real GPS absent user direction. Actual map appearance awaits user confirmation.

Wallet269: user requested collapsible collateral explanation, meaningful dynamic indicator, clearer month picker and replacing visible CSV with top vertical-ellipsis / bottom-sheet تحميل الكشف PDF. Delivered available/(available+locked) ratio with actual amount labels; explanation initially collapsed; white picker/dropdown surfaces and explicit white confirmation text; PDF with bundled licensed NotoSansArabic, full monthly summary and all visible movements, Baghdad dates and page numbers. Existing file_picker native saveFile now saves PDF, CSV UI removed (legacy model CSV remains for compatibility). Ten tests pass; rendered120-row16-page fixture reviewed visually. Release269 built preserving scoped staging fixedGPS, installed/launched and app listing confirms269. Native user save confirmation pending. No financial/backend changes in269.

Transfer visibility batch270: Release270 installed on real iMohammed. Existing CONFIG#TRANSFERS.enabled gates transfer entry/actions with fail-closed refresh on resume and30s polling. Balance/history and uncertain-attempt recovery remain available; no commission and no actual transfer created. DRIVER additionally reads posted cancellation entitlement+matching case operation from Holds; ORD1792849495126 has500IQD already credited, now shown as compensation, not unknown delivery earnings. Missing proof differs from known pending review. Central evidence docs/trip-transfer-controls-270.json. User confirms no payment license or partner transfer contract: public money-transfer classification and commission need Iraqi legal/provider review before launch.

D01 server271: active-profile eligibility tightened in candidate selection, offer issuance and atomic acceptance. Explicitly disabled profile cannot get/accept new offers; missing legacy flag retains approved compatibility.47 source+59 captured runtime tests, deployed START/TIMEOUT/financialaccept only, no native build or driver/money/order mutations. Full vehicle/document/region audit remains open. CENTRAL docs/driver-eligibility-271.json records current financial acceptance SHA.


Driver basic performance + authenticated support: local implementation and tests complete, Release271 built; source docs/driver-performance-support-ready.json. New /driver/performance reads verified explicit financial offers and settled operational outcomes; observed/provisional rates show sample and exclusions, unknown expiry/cancellation does not penalize drivers. Legacy dispatch metrics/policy remain unchanged. More profile now transports verified customer ratings. Support uses colleague deployed JWT/session-owner/receipt/history protocol, no test driver identity or old bridge. No live support messages, business/financial writes or installation. Automatic approval review REJECTED shared DriversApi Lambda deployment and scoped IAM GetItem/Query change pending explicit user approval. Candidate preserves all other ZIP entries; do not bypass rejection. Request user approval for manifest docs/driver-performance-publication.json and policy docs/driver-performance-read-policy.json, then recheck live hash/revision before publish. Full v1.6 / device ACK / historical classification / shared-fault scoring remain tracked, not claimed complete.


Explicit user approval received: performance/support publication is now COMPLETE on staging, not awaiting approval. DriversApi downloaded package SHA cqqGl1C377pSrQb3ENo+SDB7e3MJQRHU4Mi4+GxSau0= verified, all other entries/config unchanged; exact offer GetItem/Query policy applied.14 captured-runtime tests pass, anonymous /driver/performance returns401. Release271 installed and launched on real iMohammed B8850CE6-BCC2-551D-B930-3E108456B23F without uninstall. No live support message or business/financial write. Human acceptance of More > performance and support remains pending; advanced v1.6 is not claimed complete. See driver-performance-support-ready.json.


Performance policy272 FIRST PHASE is prepared, NOT PUBLISHED/INSTALLED. User approved the design separating performance from compensation and asked to begin. Implemented sidecar DISPLAY_ACK receipts (no financial-offer mutation), authenticated server-time display proof, displayed-expiry nonacceptance with V1 compatibility, explicit case-linked/per-attempt COUNT_FAILURE/EXCUSED/PENDING_REVIEW, independent evidence/reason/version/supersession/audit/account-lifecycle fences, appeal protection, readable future driver unassignment reason, Arabic case UI.70 source backend,46 candidate/captured,20 Flutter checks, full current-page browser PASS; old235 browser harness lacked required workflow mount and was superseded. Release272 built with same test location. Auto-review REJECTED deployment to DriversApi/financialaccept/staff + Amplify and permanent receipt-row IAM writes because previous explicit approval was READ ONLY. Need explicit user approval; do not retry/bypass rejection. See docs/driver-performance-policy-272.json, driver-performance-packages-272.json and driver-offer-receipt-policy-272.json. No cloud/business writes;271 stays active. After publication test actual timeout and admin decision, then punctuality/quality/activity, per-indicator detail and performance review/appeal ownership; advanced score/tiers/ranking stay deferred.


Superseding publication checkpoint272: explicit user publication approval received. All three tested Lambda candidates published and downloaded byte-identical; IAM receipt policy exact/simulated allowed; hosted job203 SUCCEED with all four changed files byte-verified. Release272 installed and launched on real iMohammed without uninstall; anonymous new routes401. No live case decision, wallet/ledger write or support message by agent. Human displayed-timeout and independent case performance decision tests remain PENDING. This completes phase1 publication only: punctuality, quality, activity, indicator history/review and appeals remain open; no new hard eligibility/ranking/score/tier policy. See driver-performance-publication-272.json.


User deferred manual acceptance tests to an ordered queue; NOT PASSED. See driver-performance-ordered-acceptance-tests.json. Continue automated checks and operational implementation: original-target punctuality/exceptions, quality/rating/activity, indicator details/review, then vehicle/documents/region. All-app hardware gates stay after operations; no repetition of skipped finance tests.


Performance273 published/installed on staging with byte-verified financial/driver Lambda candidates and unchanged config, no new IAM or financial calculations. Original timing per accepted attempt, first progress timestamps/attempt fences, observation-only punctuality, bounded thirty-day acceptance activity and Arabic event details.78 source backend,89 captured checks,22 Flutter checks, TS and Release273 build pass. Human tests remain DEFERRED_NOT_PASSED by user. Potential pickup waiting delays remain review; no automatic fault/excuse from reports or compensation. Next: verified quality/rating review and evidence-backed delay resolution, then vehicle/documents/region. Full metrics and v1.6 score/tiers/ranking remain OPEN. See driver-performance-timing-273.json.


Presentation274 complete: compact grouped performance rows (value/sample/status), tap for existing explanations/events, collapsed bottom definitions/eligibility guide, Baghdad update time and responsive narrow/large-text layout.23 regression widget checks plus1 portrait preview check, clean page analysis and Release274 build PASS. Installed and launched on real iMohammed without uninstall. No backend or metric formula change. Human acceptance stays deferred/not passed; next operational scope remains delay review and quality/rating moderation/appeals. See driver-performance-layout-274.json.


More presentation275 implemented, Release275 installed and launched on real iMohammed without uninstall. Neutral grouped menu/profile styling replaces rainbow borders. Verified rating/count and Arabic join date separated; no manufactured date/rating; profile refresh + mounted guards; performance and authenticated support routes retained. Real WalletHomeScreen replaces old construction placeholder. Unimplemented instant-pay option disabled explicitly, developer preview menus debug-only.29 widget checks including route targets (without mounting service screens), narrow/large text and screenshot fixture pass; page analysis clean; Release build pass. No backend or agent business writes. Human acceptance deferred under MORE_UI_275 in ordered test queue; continue original operational delay/quality/rating review scope. See more-layout-275.json.


More functional audit276 supersedes assumptions that all menu actions were real.22 entry source audit; earnings menu had static-data EarningsTab, now same live EarningsScreen as main tab. Disabled legacy placeholder payment methods, equipment, phone change, emergency/safety, More identity submit, UI-only settings, draft policies and no-op stop availability callback. Actual main-home stop remains the path. Account legacy password form replaced with unavailable notice; real deletion retained. About fictitious old build metadata removed. Account basic read/update partly real but profilePhoto not allowed by current backend; vehicle read partly real with synthetic empty-field defaults. These remain open requirements, not completed by disabling.39 widget checks and clean More analysis plus Release276 build pass; installed/launched on real phone. Human tests deferred; no backend/business writes. See more-functional-audit-276.json; integrate findings into operational prioritization before launch.


Navigation277 complete: earnings removed from primary bottom bar/IndexedStack, retained solely in More -> modern EarningsScreen. Five visible tabs retain original route IDs0,1,2,4,5 for notification/wallet compatibility; DriverTabs maps IDs to bar/stack positions and old earnings id3 to More.18 navigation/More/earnings checks and mapping analysis pass; Release277 built, installed and launched on real iMohammed without uninstall. No backend/business writes; manual acceptance deferred; operational backlog unchanged. See navigation-277.json.


Location notice278 complete: static untappable more-orders advice replaced with actual device service/permission check. Hidden for enabled service+Always; distinct off/denied/whileInUse/unknown or failure states. Tap opens Geolocator OS location/application settings, returns false/errors show truthful retry. Resumed/settings return refresh; stale async/disposal guards. Does not request permissions, change driver availability/dispatch/ranking/test coordinates or prove background GPS tracking.52 widget checks including10 notice cases and regression navigation/More/earnings/performance/support/rating pass; clean component analysis; Release278 built/installed/launched on real iMohammed without uninstall. Real-device permissions/background location tests remain deferred in LOCATION_NOTICE_278 and existing launch gates. Backend unchanged; operational backlog unchanged. See location-permission-notice-278.json.


## المرحلة279 — مراجعة التأخير

نُفذت مراجعة مرتبطة بمحاولة السائق والمواعيد الأصلية: أدلة وتعليل ومالك متابعة وقرار واعتراض وسجل محفوظ. لا تغيير مالي أو عقوبة أهلية تلقائية. اختبارات المصدر والحزمة والمصنع الفعلي والمتصفح وFlutter ناجحة. Release279 مثبت ومشغل. النشر قيد التحقق؛ راجع driver-timing-review-publication-279.json قبل اعتباره منشورًا. الاختبارات العملية مؤجلة وغير ناجحة بعد. التالي: جودة ومراجعة التقييمات مع الحفاظ على مصدر الزميل، ثم المركبة والوثائق والمنطقة. لا مساس بالمنتجات المحالة للزميل أو المستحقات المالية التي طلب إبقاءها.

تأكيد279: نُشرت وظائف المراجعة الثلاث وتحققت الحزم المنشورة بايتًا ببايت؛ نشر الواجهة204 ناجح وملفاته متطابقة. Release279 مثبت ومشغل على iMohammed. لا IAM جديد ولا قرار على طلب حقيقي ولا حركة مال بواسطة الوكيل. التالي جودة ومراجعة التقييمات، ثم المركبة والوثائق والمنطقة. القبول العملي مؤجل بطلب المستخدم.

تأكيد الواجهة279a: نشر205 ناجح، وأعيد التحقق بعد انتشار CDN من مطابقة أسماء حالات المراجعة العربية وملف الصفحة للنسخة المختبرة.


## المرحلة280 — مراجعة تقييم السائق جاهزة بانتظار الموافقة

التنفيذ والاختبارات جاهزة؛ لم تنشر280. رفضت مراجعة الموافقة الآلية نشر الخدمات الأربع وتوسيع دور خدمة القبول المالي لصلاحيات GetItem/PutItem/ConditionCheckItem على جدول whizz-order-ratings-staging لأن هذا التغيير المحدد غير مصرح به صراحةً. لا تحاول تجاوزه. اطلب موافقة نهائية بعد تجهيز النسخة. راجع driver-rating-review-280.json وdriver-rating-review-policy-280.json والحزم ذات البصمات. المنشور ما زال279 والواجهة205، ولا قرار مراجعة/مال/سجل تقييم حقيقي نُفذ بواسطة الوكيل. المصدر يحافظ على عمل الزميل الأصلي ويفصل متوسط السائق عن المطعم والأموال. نافذةآخر100 وحوادث الجودة المستقلة ثم المركبة والوثائق والمنطقة تبقى مفتوحة. كل الاختبارات العملية مؤجلة وغير ناجحة.


## تأكيد نشر280 بعد موافقة المستخدم الصريحة

الموافقة «نعم اوافق» حسمت رفض النشر السابق. طُبّقت DriverRatingReview280 لقراءة/كتابة/تحقق مشروط على جدول التقييمات وحده؛ نُشرت الخدمات الأربع والواجهة206 وتحققت الحزم المنشورة بايتًا ببايت والإعدادات. Release280 مثبت ومشغل مع حفظ الجلسة والموقع الاختباري. لا قرارات على تقييمات حقيقية ولا حركة مال بواسطة الوكيل. انظر driver-rating-review-publication-280.json. كل الاختبارات العملية مؤجلة وغير ناجحة بعد. التالي نافذة آخر100تقييم صالح وحوادث الجودة والسلامة الموثقة، ثم المركبة والوثائق والمنطقة؛ لا مساس بجزء المنتجات المحال للزميل.


## 281 — جاهزة ومختبرة؛ النشر متوقف على موافقة الفهرس والصلاحية الجديدة

87اختبارحزمة و21اختبارFlutter ناجحة؛ Release281 مبني وغيرمثبت. الجديد مصدرV4 لآخر100تقييم صالح مع الترتيب الزمني والتحقق القوي والملء من الأقدم ووسم نقص التغطية. لا تغيير للنجوم/التعليقات/متوسط السجل الكامل/المال. معاينةCFN موجودة ولم تنفذ؛ الجدول لا يستبدل، وفقط الفهرس مصدر تعديل مباشر مع إعادة تقييم تبعياتARN الحالية. رفضت الموافقة الآلية نشر281 لأنه يضيف بنية وصلاحية قراءة جديدة خارج الموافقة السابقة. لا تتجاوز الرفض؛ يلزم موافقة المستخدم على DriverRatingWindow281 والفهرس وإعداد المفاتيح المشتقة المشروط ونشرالخدمتين. الحالي280والمنصة206؛ لا IAMأوبياناتأوLambdaتغيرت ل281، فقط إنشاءمعاينة. راجعdriver-rating-window-281.jsonوالحزم والمعاينة والسياسة. حوادثالجودة ثمالمركبةوالوثائقوالمنطقة مازالت مفتوحة. الاختبارات العملية مؤجلة وغيرناجحة.

تحديث جارٍ281 بعد موافقة المستخدم: الفهرسACTIVEوالبنيةUPDATE_COMPLETE؛ لا تعِد تنفيذ المعاينة أو التهيئة. تعثرSDKالمحلي لأن رمزSSOالمخزن عنده انتهى، بينماAWSCLIلنفسالملف صالح. الاستئناففيscripts/resume-driver-rating-window-281.py يستخدم اعتمادات الدور المؤقتة منCLIفيالذاكرة دون حفظ أسرار، ويتابعفحصالمصدر ثم قارئالسائق فقط. راجعإيصالالنشرلمعرفةالمرحلة قبلأيإعادةمحاولة.


## تأكيد281 بعد الموافقة الصريحة

تم تنفيذ معاينة الفهرس مع التبعيات الحالية دون استبدال الجدول، والتحقق منACTIVEوتغطية المصدر وصلاحيةGetItem/Query المحدودة لدورالسائق. نُشرت خدمتاالتقييمات/السائق وتحققت الحزم بايتًا ببايت والإعدادات؛ Release281 مثبت ومشغل مع حفظ الجلسة والموقعالاختباري. الأصواتوالتعليقات ومتوسطالسجل الكامل والأموال محفوظة. لا قرارات على تقييماتحقيقية بواسطةالوكيل. راجعdriver-rating-window-publication-281.json. اختبارنافذة100 مؤجل وغيرناجح عمليًا بعد. التالي حوادثالجودةوالسلامة الموثقة والمراجعةوالاعتراض، ثمأهليةالمركبة/الوثائق/المنطقة؛ لا تعديل لاستيرادالمنتجات المحالل للزميل ولاScoreأومستويات أوعقوباتتلقائية.


## 282 — ملف السائق وربط التقييم
أوقف المستخدم الانتقال لحوادث الجودة مؤقتًا. أعيد تصميم الملف الشخصي بالعربية وتصحيح القراءة وحصر الحفظ بالاسم والمدينة. 12 اختبارًا آليًا ناجحًا؛ البناء جارٍ والقبول اليدوي مؤجل. لم تُنشأ تقييمات أو نجوم؛ قرار بيانات اختبار معلّمة أو تقييم حقيقي من الزبون ينتظر رده. ربط عرض التقييم للزبون والمطعم غير مكتمل ومسجل قبل استئناف الجودة. الدليل: `docs/driver-account-rating-audit-282.json`.

تحديث282: نجح بناء وتثبيت وتشغيل Release282 على iMohammed. اختار المستخدم تقييمًا حقيقيًا من الزبون بعد التسليم، لا بيانات مصطنعة. فحص مصدر wizzuser-stg وجد زر تقييم الطلب ما زال TODO برسالة قريبًا؛ شاشة وخدمة تقييم الزميل موجودتان في origin/feature/order-ratings-20261024 وغير مدمجتين في النسخة المحلية الحالية. لا تدّع جاهزية اختبار تقييم الزبون قبل دمج ضيق وفحص وتثبيت النسخة.


### تحقق تقييم حقيقي بعد دمج283
أرسل المستخدم تقييمًا حقيقيًا: المطعم4 والسائق5 للطلب96cd4249-41af-5ebb-885a-d7dae2c321d0. القراءة القوية أكدت السجل الأصلي ومتوسط السائق5/5 وعدد1 ومجموع5 وملفه المطابق، ووجود السجل في فهرس281. لا كتابة من الوكيل. هذا يثبت تقديم التقييم وتجميع السائق فقط؛ عرض الزبون/المطعم وواجهة السائق بعد تحديثها وسيناريوهات المراجعة لا تزال منفصلة. دليل `docs/customer-real-rating-verification-284.json`.


### 286 — شارة تقييم السائق
بطلب المستخدم: المزيد تعرض نجمة ذهبية واضحة ورقم التقييم فقط، وعدد التقييمات يبقى داخل الملف الشخصي في سطر منفصل. نفس مصدر customerRating الموثق دون تغيير الحسابات أوالبيانات. نجحت9اختبارات بما فيها عرض320 مع تكبيرالنص1.6. Release286 قيد البناء. دليل `docs/driver-rating-badge-286.json`.

إغلاق286: نجح بناء وتثبيت وتشغيلRelease286 علىiMohammed مع الحفاظ على جلسة السائق وإعدادات موقعه الاختباري. فحص الكود دون ملاحظات واختبارات9 ناجحة.


### 287 — عرض التقييم غير المتوفر
طلب المستخدم شرطة بدل0.0 للمطعم والسائق. توحيد تسميات العرض إلى— مع إبقاء القيم الرقمية الداخلية للفرز دون تعديل التقييمات. صُحح نص500+ ثابت آخر في بطاقة الخريطة إلى العدد الفعلي إن كان موجبًا. اختبارات16زبون و9سائق ناجحة. بناء محاكي الزبون وRelease287للسائق جارٍ. دليل `docs/unrated-display-287.json`.

إغلاق287: نجح بناء وتثبيت وتشغيل الزبون287على المحاكي والسائقRelease287علىiMohammed. اختبارات25ناجحة،لا تعديل بيانات تقييم.


### 288 — تنسيق التقييم
طلب المستخدم إزالة الخلفية الصفراء الفاتحة وتصغير رقم التقييم في المزيد والملف الشخصي. أزيلت الزخرفة وأصبح الرقم17 والنجمة19 دون تغيير البيانات؛ اختبارات العرض والبناء قيد التنفيذ.

إغلاق288: نجحت اختبارات9 والبناء والتثبيت والتشغيل علىiMohammed بنسخةRelease288.


### 289 — استئناف حوادث الجودة والسلامة
أنشئ مسار إداري مستقل للقضايا والأدلة والقرار والاعتراض، مرتبط بمحاولة قبول موثقة ويستمر على السائق الأصلي بعد إعادة الإسناد. 35اختبارمصدر/تراجع و9علىالحزمة المعدة للنشر واختبارمتصفح390ناجحة؛ النشر جارٍ. لا أموال أو تقييم أو أهلية تتغير تلقائيًا ولا حوادث أنشأها الوكيل. خطة التجارب أضيفت مؤجلة. عرض الحوادث والاعتراض مباشرة للسائق، بدء حادث لمحاولة محررة سابقة، واحتفاظ القضايا أثناء حذف الحساب ما زالت مفتوحة ولا يدّعى اكتمالها.

إغلاق جزء الإدارة289: نُشرت الحزمتان staging-driver-financial-accept وstaging-wizz-staff-service وتأكدت مطابقتهما بايتًا للحزم المختبرة مع بقاء الإعدادات كما هي؛ واجهةAmplify207و6ملفاتمغيرة تحققت بايتًا. طلب دون جلسة رفض401. لاحوادث أوأموال كتبهاالوكيل. المسار: الطلبات←إدارة←تسجيل حادث جودة أو سلامة، والمتابعة في قضايا الطلبات. التالي داخل البند نفسه: عرض الحوادث والاعتراض للسائق وتدقيق احتفاظ القضايا أثناء حذف الحساب وبدء حادث لمحاولة محررة سابقة؛ ثمD01. لا إغلاق لكاملD09/D10 أوادعاء درجة جودة رقمية.


### 290 — حوادث السائق والاعتراض والمحاولات السابقة والاحتفاظ
المصدر والواجهة جاهزان ومختبران: 38 اختبار خادم، و272 لحذف الحساب، و16 على حزمة القضايا والاعتراض، و13 على حزم الاحتفاظ، و13 اختبار Flutter. فحص Flutter دون ملاحظات. نسخة Release 290 مبنية وغير مثبتة.

أفاد المستخدم بعدم وجود سياسة احتفاظ معتمدة؛ لا تُستخدم مدة السجلات المالية للقضايا غير المالية. يوقف وجود قضية جودة أو سلامة حذف الحساب عند مراجعة واضحة للسياسة. المحاولات السابقة ترتبط بأرشيف التحرير وحدثه الأصلي والعرض المقبول، دون صلاحية Query جديدة للخدمة المالية.

رفضت المراجعة الآلية إضافة Query على staging-Holds لدور DriversApi لأن الجدول مشترك وحساس ويحتاج موافقة محددة. لم تُضف الصلاحية ولم يُنشر DriversApi أو تُثبّت النسخة. نشر الأجزاء المستقلة فقط جارٍ عبر scripts/publish-driver-quality-core-290.py. يلزم انتظار الموافقة الصريحة ثم إكمال النشر؛ لا تُنشأ قضايا أو اعتراضات فعلية كاختبارات آلية.

إغلاق الجزء المتاح من 290: نُشرت الخدمة المالية وخدمة طلبات الحذف وعامل الحذف، وتحققت الحزم بايتًا مع حفظ الإعدادات. DriversApi لم يُنشر وRelease 290 غير مثبتة؛ موافقة المستخدم على Query فقط على staging-Holds هي المتطلب المتبقي للنشر. ملف السياسة: docs/driver-quality-read-policy-290.json. عند الموافقة الصريحة استخدم scripts/finish-driver-quality-self-service-290.py --approved-read-policy؛ يتحقق من عدم تغير الحزم ويضيف الصلاحية المحددة ثم ينشر DriversApi ويثبت ويشغّل Release 290. لا تعاود نشر الخدمات الثلاث ولا تنشئ أي قضايا فعلية.


### إكمال نشر290 وفحص الطلب ORD1792911323338
وافق المستخدم صراحة على Query للقراءة فقط على staging-Holds لدور DriversApi. أُضيفت السياسة المحددة وتحقق السماح، ثم نُشرت الحزمة وتحققت بايتًا مع بقاء الإعدادات، وثُبّت وشُغّل Release290 على iMohammed. طلبا قائمة القضايا والاعتراض دون جلسة رُفضا401. لا إعادة نشر للخدمات الثلاث السابقة.

طلب المستخدم فحص الطلب أولًا واختار تنفيذ أزرار المنصة بنفسه. القراءة القوية: السائق اعتذر Emergency وفُك إسناده، ثم الإدارة ألغت الطلب؛ الضمان محرر، والأجرة والتعويض صفر منفّذان، والقضيةv4 ما زالت بلا قرار مسؤولية أوأداء وإغلاق مالي. معدل الإكمال المبدئي100% من19رحلة محسومة (18تسليم+1إرجاع)، و4مراجعة؛ احتساب المحاولة الأولى وحدها فشلًا يُتوقع أن يجعل النسبة95% (19/20). لم يغيّر الوكيل أي قيد أعمال لهذه القضية.

صُحح خلل واجهة العهدة للإلغاء قبل الاستلام، وربط إغلاقه بصفحة الإلغاء لا زر الإرجاع؛ نُشر ملفان فقط فيAmplify208 وتحققا بايتًا. عند إبلاغ المستخدم بإتمام الأزرار، أعد القراءة عبر scripts/inspect-order-driver-performance-20261025.cjs وتحقق منfindingوCOUNT_FAILUREوالإغلاق والنسبة؛ لا تستنتج الخطأ من تعويضصفر أو سببالطوارئ وحده. دليل docs/cancellation-case-progress-20261025.json.


توقف المستخدم يوم2026-10-25. نقطة الاستئناف التفصيلية محفوظة في whizzCentralPlatform-stg/docs/resume-checkpoint-latest.md. طلب ORD1792911323338: الإفادة والمسؤولية مسجلتان؛ قرار COUNT_FAILURE للمحاولة1 والإغلاق المالي لم يؤكدا بعد. إصلاح القارئ الفعلي نشر واختبر؛ لا تعتبر اختبار الأداء مكتملًا قبل تحقق القراءة بعد إجراء المستخدم.


## استئناف بعد تجديد AWS — تأكيد إغلاق الاختبار الحالي
قراءة قوية تؤكد ORD1792911323338 الإصدار9: المسؤولية DRIVER، COUNT_FAILURE للمحاولة1، financialClosure موجودة (التعليل: تم انهاء النزاع)، completionRate=0.95 وsampleSize20 وdriverFailures1 وreviewExcluded3. العملية المالية الأصلية EXF:abcfdbfc1d33999380ad5859f72c4449cfbe9fb57e788b9d دون تغيير، صفر أجرة وصفر تعويض مطعم، order.holdStatus=NONE وwalletFinancialStatus=CANCELLED. لا كتابة أعمال من الوكيل. سجل الاختبار HUMAN_PASSED_VERIFIED؛ لا نطلب من المستخدم إعادة القرار أو الإغلاق. التالي تدقيق D01 المركبة والوثائق والمنطقة وفق الخطة؛ لا نفترض أن التقييم أو السياسة أو الاختبارات الأخرى اكتملت. المرجع docs/completion-failure-human-verification-20261025.json. طلبات دمج GitHub محدثة وتنتظر المراجع؛ هذه نتيجة توثيق محلية جديدة بعد دفعة الرفع.


تدقيق تصميم الأداء بطلب المستخدم: /driver/performance?rules=4 يعيد الحساب خادميًا عند كل طلب ولا يحفظ aggregate حديثًا؛ الموجات تقرأ legacy metricsSnapshot من LiveState ولا تعيد الحساب الحديث الآن. المطلوب قبل D01 توحيد مصدر محفوظ محدث بالأحداث مع قواعد حداثة/إصدارات/تكرار/نافذة متحركة ومطابقة shadow قبل تغيير الأهلية. تم تسجيل التصميم فقط دون نشر أو تغيير اختيار السائق. المرجع docs/driver-performance-unified-projection-audit-20261025.json.


## 291 — المصدر المحفوظ لمؤشرات السائق: محلي جاهز، النشر ينتظر الموافقة
أُضيف backend/driver-performance-projection في المنصة: جدول ملخص/تفاصيل/مراجع، Collector منفصل عن Worker بطابور، منع تكرار وgeneration وlease، فحص الحداثة وصحة Stream، تهيئة قابلة للاستئناف، ومحو المشتق عند حذف الحساب. الرفض المتتالي مستقل عن آخر100عرض ويحتاج تغطية كاملة. حزم ترقيع للخدمات الخمس جاهزة ومحفوظة البصمة في /private/tmp/driver-performance-projection-291. لا يعاد بناء خدمة كاملة من مصدر قديم. اختبارات محلية وقالب SAM وفحص TypeScript ناجحة.
رفضت المراجعة الآلية أمرًا كان يتضمن تفعيل Streams على staging-Holds والتقييمات، ورفع حزمة وإنشاء change set؛ **لم ينفذ ذلك الأمر ولا أي من هذه الآثار**. لا تحاول تنفيذها أو التحايل عليها قبل موافقة المستخدم الصريحة على النطاق في docs/driver-performance-projection-291.json.
الخطوة التالية بعد الموافقة: إنشاء البنية/الصلاحيات المحددة، تفعيل streams الجدولين، تمرير مفاتيح الطلبات من CreateDispatchJob دون ثالث قارئ، وتهيئة البيانات ومطابقة التخزين الحقيقي ثم نشر القراءة وSHADOW. يلزم تدقيق وترقية جميع قراء dispatchPolicy قبل نشر VERIFIED_SNAPSHOT_V1 للدورات الجديدة فقط؛ الدورات القديمة تبقى على اللقطة الملتقطة. لا نشر أو تفعيل للموجات في هذه الجولة. قراءة المصادر الحية مسموحة وحُصرت دون أي كتابة. لا ادعاء اكتمال التخزين الحقيقي أو تشغيله قبل هذه الخطوات.

291 إغلاق العمل المحلي: 21اختبار إسقاط،93تراجع خادم،14علىكلحزمةموجاتملتقطتين،31Flutterتراجع و8لجناحرسمالأداءمعرسالةالتحديث،TypeScriptوSAMناجحة. مقارنةمصادرالسائقالحقيقيةبالقراءةفقطأثبتتقبول92٪وإكمال95٪ورفضمتتالٍ1،وقيمالإسقاطالمحليتتطابقللتطبيقوالموجات. لاجدولAWSجديدولانشرأوكتابةأعمال. بانتظارموافقةالمستخدمعلىالتغييراتالحيةالتيمنعتهاالمراجعةالآلية. الرفضالمتتاليحُسبمستقلاًعننافذةآخر100عرض.


## 291 — النشر الفعلي بعد موافقة المستخدم (الحالة الأحدث)
وافق المستخدم صراحة على البنية والصلاحيات ونشر المستهلكين في staging. اكتمل إنشاء DriverPerformanceSnapshots_staging وخدمتي Collector/Worker وطابوري العمل والفشل، وتفعيل Streams الجدولين المصرح بهما، وتمرير مفاتيح أحداث الطلبات من المستهلك القائم دون ثالث قارئ. HEALTH سليم؛ المطابقة الفعلية لبيانات السائقين الخمسة نجحت، ولا كتابة في جداول الأعمال. قبول السائق التجريبي92٪ وإكمال95٪ ورفض متتالٍ1. حُسِب الرفض المتتالي بوقت الرد الموثق مستقلًا عن نافذة آخر100عرض.
فُعّلت قراءة DriversApi من الملخص المشترك، ونُشرت قراءة الإدارة مع فحص النطاق. الموجات SHADOW: تحافظ على الاختيار الحالي وتقارن مؤشرات المصدر الحديث. تمت ترقية جميع قراء enum سياسة التوزيع والحفاظ على إعدادات وحدود الدورات السابقة. استضافة المنصة210 تعرض اختيار المصدر الجديد. لا تكتب سياسة VERIFIED_SNAPSHOT_V1 مباشرة: اعتمدها من واجهة الإدارة الأصلية بعد مراقبة دورة حقيقية، ولا تعتبر اختبار الحزمة بديلًا عن هذه المراقبة. لا CONTROL/DISPATCH_READY جاهز زائف.
نجحت51اختبارًا للحساب والإسقاط،15للمرشحين، و15علىكلحزمةموجاتمنشورة، إضافة إلى الفحوص السابقة. Release291 ثُبت وشُغّل على iMohammed. إيصالات النشر والمطابقة في docs/driver-performance-projection-*-291.json وdriver-performance-policy-ui-291.json. الاختبارات البشرية مؤجلة ضمن القائمة المرتبة؛ لا نعيد القضية ORD1792911323338 التي أُغلقت وتحققت سابقًا. التالي D01 للمركبة والوثائق والمنطقة مع الحفاظ على بوابة التفعيل السابقة. هذه التعديلات الجديدة محلية ومنشورة staging، وليست دفعة GitHub مرفوعة بعد.


## 291 — تفعيل فوري بطلب المستخدم (يلغي انتظار SHADOW السابق)
طلب المستخدم صراحة استخدام المؤشرات الحديثة فورًا للاختيار والاستبعاد، مع التحكم بالحدود من المنصة. نُشر تعديل ضيق لمساري StartWave وHandleWaveTimeout وفُعّل ENFORCE على كليهما. ENFORCE يستبدل مصدر الأداء القديم حتى للدورات الموسومة LEGACY_METRICS؛ تبقى حدود كل دورة الملتقطة كما هي. لا تتغير نسب أو أوزان أو قرارات أو أموال. لا يعتمد التفعيل الآن على تغيير enum السياسة من المستخدم. لا يُدّعى نجاح تجربة بشرية لدورة جديدة؛ المستخدم طلب عدم انتظارها، وتبقى اختبارات القبول في القائمة المؤجلة.
الحدود موجودة أصلًا في المنصة لكل موجة: minimumAcceptancePercent وminimumCompletionPercent وmaximumConsecutiveDeclines، مع newDriverExemption وباقي إعدادات الموجة. القراءة القوية لسياسة التشغيل الحاليةv2 أثبتت للموجات1–4: قبول70/60/50/0٪، إكمال85/75/60/0٪، حدرفض2/3/5/999، في LEGACY وFINANCIAL. لم يعدل الوكيل أيًا منها. تعديلات الإدارة المستقبلية تسري على الدورات الجديدة وفق آلية السياسة القائمة. مصدر التنفيذ الموحّد مفعّل على مستوى الخدمة؛ أُزيل اختيار المصدر القديم المضلل من الواجهة مع الحفاظ على قيم السياسة للتوافق. نجحت15اختبارًا للمصدر و15لكل حزمة منشورة واختبار متصفح يغير حد القبول ويحفظ سائر القيم. دليل التفعيل docs/driver-performance-enforce-291.json. التالي D01؛ لا تطلب تفعيل المصدر أو إعادة اختبار الإغلاق السابق.


## 292 — تدقيق الموجات حتى التسليم وإصلاح صوت العرض وأثر الرفض
بطلب المستخدم قبل العودة إلى D01: دُققت تسع حزم فعلية منشورة، ومسار التطبيق من العرض والقبول إلى التقدم والتسليم النقدي. تطابقت8ملفات حرجة في DriversApi مع المصدر المختبر. نجحت219اختبارخادم و26للمحولات/الأصوات، و34Flutter (منها11للصوت وأثر الرفض بعد إعادة القراءة)، و7حواجز على الحزم الفعلية. لا يُدّعى بذلك خلو النظام كله من العيوب أو نجاح تجربة صوت فعلية جديدة؛ يختبر المستخدم الطلب الآن.
أُغلق رجوع StartWave وTimeout إلى الاختيار القديم لدورات غير مثبتة عندما يعمل الإطلاق العام الحديث؛ وأضيف فحص علامات الطلب المالي وغياب الطلب/المهمة قبل أي كتابة رفض قديمة. نُشرت3ترقيعات index.js ضيقة مع حفظ بقية الحزم والإعدادات وعدم تعديل IAM؛ ENFORCE باقٍ. لا مال أو طلب أو قرار اختباري أنشأه الوكيل.
صوت العرض: إزالة وسم التشغيل قبل نجاح الصوت، دمج وصول FCM/WebSocket، سماح بإعادة المحاولة عند الفشل، ضبط جلسة الصوت، fallback للأصل عند فشل ملف مخصص مع احترام اختيار silent. سياسة المنصة الفعلية driver_original، والملف غير صامت وموجود للأمام والخلفية في تطبيق iOS. السماع الفعلي على الجهاز والخلفية ضمن تجربة المستخدم ولا يعد ناجحًا قبل تأكيده.
قائمة الرفض تعرض الحالي والمتوقع بعد التأكيد من نفس نسخة آخر100عرض مؤهل، مع إسقاط الأقدم عند اكتمال100، ودون نسبة مصطنعة عند عدم كفاية البيانات. أُضيف sentAt لتفاصيل الملخص وأعيدت تهيئة المشتق ومطابقته فعليًا للسائقين الخمسة. الرفض من تفاصيل العرض صار يمر بالقائمة نفسها. لا يكتب فتح القائمة رفضًا؛ القرار عند التأكيد فقط.
Release292 بُني وثُبت وشُغّل على iMohammed؛ الزبون287 على محاكيiPhone16 والمطعم علىiPhone16Pro، وصفحة الطلبات بالمنصة مفتوحة. الأدلة: driver-offer-delivery-audit-292.json وwave-legacy-fences-publication-292.json. التعديلات الحالية لم تُرفعGitHubبعد. بعد تجربة المستخدم يُستأنفD01 المركبة والوثائق والمنطقة.

292 تشغيل المحاكيات: التشغيل المباشر أغلق نسختي debug؛ شُغّلتا عبر Flutter --use-application-binary مع بقاء الجلستين75905/80706. تحقق بصريًا من الصفحة الرئيسية للزبون وشاشة اختيار نشاط المطعم (فتوش)، دون تبديل حساب أو إرسال طلب. Release292 النهائي أُعيد تثبيته وتشغيله بعد اختبار إعادة قراءة الملخص.


## 293 — الطلب ORD1792947001532 بعد تجربة المستخدم
UUID90b60570-c1ed-5b7b-8df0-d408769657a7 سُلّم وتسوى بنجاح في الموجة1، attempt1. المقبوض17000، أجرةالسائق1500نقدًا، الضمان15500SETTLED، استحقاقالمطعم11250LOCKED_PENDING_SETTLEMENT، مساهمةالمنصة4250. قيدان Ledger متطابقان وقيد GL POSTED ومتوازن وفهرس مستحق المطعم موجود. السائق available/isSearchingtrue/currentOrderIdnull. المصدر المحفوظv84: قبول24/26=92.3077٪، إكمال20/21=95.2381٪ (19تسليم+1إرجاع+1فشل)، رفضمتتالٍ0،3مراجعةمستبعدة. لا إنشاء/إعادة تنفيذ لقيد من الوكيل.
الصوت292 فشل بشريًا والتطبيق مفتوح. وصل WebSocket، لكنpushAcceptedfalse بسبب HTTPtimeout3000ms بينما خدمةالإشعار4322ms+تهيئة589ms. نُشرت مهلة8000ms مطلقة ومقيدة بانتهاء العرض على StartWave وTimeout مع حفظENFORCEوالإعدادات. عُزل/وُحّد مسار عرض الإشعار المسترجع معWSليستدعي الصوت دائمًا (منعالتكرار عند نجاحالتشغيل فقط). أضيف NativeAVAudioPlayeriOSبملف التشخيص المحدود Library/Caches/driver-offer-audio-diagnostic.json، وزرالمزيد←اختبار صوت العروض. Release293بني وثبت وشغل؛14اختبارFlutterو12للنقلنجحت. السماع الفعلي293لم يؤكد بعد، والسؤال للمستخدم معلق؛ لا تدّع نجاحه ولا تبدأطلبًا أوإشعارًا تجريبيًا دون طلبه.
كشفالتدقيق حدثمتابعةCompletionPENDING_INTEGRATION،و15حدثًا مشابها. السببصلاحيةLeadingKeysتستثنيFCSبينماGetItemبدونcontextكانيوحيبالسماح. أُضيفFCS:*:EVENTفقطإلىFinancialIntegrationEventsفيالدورالقائم،دونتغييرAction/Resourceأومنحكتابةمحافظ.المحاكاةمعLeadingKeysأثبتتFCSallowedوالفئةالأخرىimplicitDeny.أصبححدثالطلبINTEGRATEDبالمجدولعند17:11:34Z دونإعادةالمال.لاتسقطالتشخيصالمهمبعدنجاحالمال؛سجلالمراقبةكانيفتقدأخطاءماقبلtryوأُصلح.الدليلorder-ORD1792947001532-verification-293.jsonوcod-integration-fcs-policy-293.json.
لايرفضهذاالطلبولا تختلقاختبارنافذةالرفضأوانتهاءمهلةمشاهدة:المستخدمقبلهوأكملتسليمه.يبقىاختبارالصوت293فيالمقدمةوالخلفيةوتجربةنافذةالرفضضمنالاختباراتالمرتبة.بعدهاD01كمافيالخطة.نسختاالمحاكياتحاليًاالزبونعلىiPhone16Pro(جلسة18903)والمطعمiPhone16(22101).


## 294 — فتح قائمة الرفض بالأرقام جاهزة
طلب المستخدم منع ظهور الشرطات أولًا ثم النسب. حُوّل العرض إلى StatelessWidget يرسم النسب من لقطة جاهزة، ونُقل جلب البيانات قبل فتح القائمة. التحميل المسبق يبدأ مع وصول العرض ويتجدد فقط مع وجود عروض حية. cacheذاكرة5ثوانٍ مرتبطة بالحساب، single-flight، تفحص validUntil، وتُمسح بعد القرار وتغير الجلسة؛ لا تخزين دائم ولا نسبة مصطنعة. بعد انتظار أي تحديث يعاد فحص المالك/epoch ووجود العرض وصلاحيته قبل فتح القائمة. عند الفشل رسالة صريحة بلا شرطات تحميل ولا حظر قرار الرفض. نجحت16اختبارًا، منها أول إطار مع النسبتين وسباقات الحساب/تحديث cache. لا تغيير خادم أوIAM. إصلاح الصوت الأصلي293وزرالمزيد←اختبارصوتالعروض محفوظان، والسماع الفعلي لا يزال ينتظر تأكيد المستخدم. Release294 يبنى للتثبيت؛ راجع إيصال offer-performance-prefetch-294.json للحالة النهائية.

294: اكتمل بناء Release294 وتثبيته وتشغيله على iMohammed. الفحص البشري لظهور النسبتين مع القائمة ينتظر المستخدم؛ إصلاح الصوت293محفوظ ولم يؤكد السماع بعد.


## 295 — رفض اسم ملف الصوت في Swift
أكد المستخدم أنه لم يسمع اختبار الصوت293/294. لم يوجد ملف تشخيص أصلي على الجهاز. وُجد خطأ في التعديل293: نمطSwiftاستخدمأربعشرطاتعكسيةقبل.wavبدلتحققنقطةحرفية،فرفضdriver_original.wavقبلAVAudioPlayerوأعادFlutterErrorدونسجلالتشخيص.استُبدلبنصSwiftخاموطُبّقعلى7ملفاتصحيحةو7مساراتمرفوضةبتنفيذFoundationالفعلينفسه؛نجحت14حالة.أُضيفتسجيلالفشلالمبكرأيضًا.اختبارDartالسابقكانيسخرالقناةولميختبرالتحققSwift؛لايُعدكافيًاللسماع.
Release295يبنىللتثبيتويحفظتحميلالمؤشراتالمسبق294.السماعالفعليينتظرإعادةاختبارالمستخدممنالمزيد←اختبارصوتالعروض؛لاضرورةلطلبجديد.راجعدليلoffer-sound-native-validator-295.jsonللتثبيتالنهائي.لاتدعنجاحالصوتقبلتأكيدالسماعأودليلالجهاز.

295: اكتمل بناء وتثبيت وتشغيل Release295 على iMohammed؛ اختبار التحققSwiftنجح، وإعادة السماع من زرالمزيد تنتظر المستخدم.


## 296 — إعداد الصوت المركزي والتشغيل الأصلي
أكد المستخدم أن النسخة 295 تعرض «تعذر تشغيل الصوت». إعداد المنصة v3 هو driverNewOffer=driver_original، غير مكتوم ولم يُغيّر. أُصلح التحقق من أسماء الأصوات المخصصة في Swift، وعُزل تعثر تثبيتها عن تحديث اختيار صوت العرض. تحديث السياسة الآن single-flight، ويطلب زر الاختبار أحدث إعداد. أضيف تشخيص Dart محدود دون بيانات شخصية لتمييز فشل القناة عن فشل التشغيل.
نجحت 18 حالة Foundation و6 اختبارات Flutter. اختبار MethodChannel حقيقي في محاكي iOS أعاد playing=true عبر Speaker بمستوى 0.6؛ هذه النتيجة لا تثبت السماع على الآيفون. حُذف التطبيق التشخيصي المعزول وأعيد تطبيق المطعم للمقدمة. بناء Release 296 بالمدخل lib/main.dart جارٍ؛ الآيفون غير متصل وسُئل المستخدم توصيله. راجع offer-sound-central-policy-296.json لحالة التثبيت النهائية. لم تُرفع هذه التغييرات إلى GitHub.

296: اكتمل بناء Release والتحقق من رقم النسخة والمدخل الصحيح ونجح git diff --check. لم تُثبّت بعد لأن الآيفون لا يزال unavailable. سؤال توصيل الجهاز معلق لدى المستخدم.

296: وصل المستخدم الآيفون الحقيقي؛ ثُبتت Release 296 وشُغّل com.wiz.wizdriverapp بنجاح عبر devicectl. السماع الفعلي لا يزال ينتظر اختبار المستخدم من المزيد ← اختبار صوت العروض.


## 297 — سبب فشل الصوت داخل التطبيق الكامل
فشل اختبار المستخدم على الآيفون بعد تثبيت 296. قُرئ ملف التشخيص المحدود tmp/driver-offer-audio-dart.json: reason=APP_NOT_ACTIVE، selectedFile=driver_original.wav، ولا يوجد تشخيص أصلي لأن التنفيذ لم يصل إلى Swift. السبب: GlobalAppStateManager القديم يستبدل SystemChannels.lifecycle.setMessageHandler، فيحجب تحديث حالة Flutter وإشعارات observers. استُبدل بمراقب WidgetsBindingObserver، وأزيل التحويل المكرر من home، ولا يمس dispose قناة Flutter.
أُثبت باختبار رسالة lifecycle عبر binary messenger: يفشل على الكود القديم (الحالة تبقى null) وينجح بعد التصحيح، مع تشغيل المقدمة ومنع الخلفية واستمرار تحديث Flutter بعد إزالة المراقب. نجحت الاختبارات السبعة وdiff check. Release 297 يبنى للتثبيت على الآيفون المتصل؛ لا تدّع السماع قبل تأكيد المستخدم. التفاصيل offer-sound-lifecycle-root-cause-297.json. بقية تغييرات الأداء والرفض والإعدادات محفوظة، ولا تعديل مال أو طلبات أو إعداد صوت المنصة.

297: اكتمل بناء Release والتحليل دون ملاحظات، وثُبتت النسخة 297 وشُغّلت على الآيفون الحقيقي. اختبار السماع بعد تصحيح lifecycle ينتظر المستخدم؛ لا حاجة لإنشاء طلب جديد.

297: أكد المستخدم «نعم ظهر الصوت» من زر الاختبار على الآيفون الحقيقي. السماع في الاختبار مثبت بشريًا؛ يبقى العرض الحقيقي في المقدمة والخلفية/القفل. طُلب تشغيل الزبون على iPhone16Pro والمطعم على iPhone16 لإكمال التجربة.


## 298 — شرط المستخدم لإعادة البحث الإدارية
اشترط المستخدم أن إعادة الموجات بقرار الإدارة تتيح العرض مجددًا لكل السائقين المؤهلين، بما فيهم من رفض أو انتهت مهلته أو فُك إسناده سابقًا. الاستثناء خاص بالدورة الإدارية الجديدة، مع حفظ تاريخ الرفض والأداء وفك الإسناد وتطبيق شروط التوفر والضمان والمنطقة والحساب. لا تغيير للإلغاء/الضمان أو تشغيل للطلب خلال تأكيد السياسة.
لم يُنفّذ هذا المسار بعد: التنفيذ المالي الحالي يقبل إعادة البحث الأولية دون عروض سابقة فقط. كشف التدقيق اعتماد مفاتيح العروض المالية على driver+wave حتى مع cycle keyVersion2، لذلك يلزم فصل هوية عروض الدورة الجديدة عبر الإصدار والقبول والتسليم والتدقيق قبل إعادة إرسال العرض لنفس السائق في الموجة1؛ لا يكفي مسح excludedDrivers. أولوية المعالجة قبل تشغيل الطلب ORD1792947277354 (جاهز للاستلام، PREPARATION_DEADLINE، عرض واحد سابق). تفاصيل الشرط والتبعيات في المنصة docs/admin-dispatch-retry-policy-298.json.


## 298 — نُشرت إعادة البحث الإدارية مع شمول السائقين السابقين
تم تنفيذ شرط المستخدم ونشره على staging في تسع حزم خدمات قائمة. يبدأ المسار فقط بقرار موظف مخول مسجل من «مراجعة التوزيع ← طلب إعادة البحث». يتم التحقق من العروض السابقة وانتهاء صلاحيتها ومن فك الإسناد والضمان واكتمال التكامل المالي، ثم تُحفظ الدورة السابقة وتُفتح دورة keyVersion3 مستقلة، مع إفراغ استبعادات السائقين الخاصة بالدورة السابقة فقط. تُحفظ نسب الأداء والتاريخ والقيود والأسعار وشروط الأهلية؛ لا كتابة مباشرة من الوكيل في الطلب أو المال.
أضيف حفظ offerStorageKey في أرشيف فك الإسناد وقضايا الجودة، لتظل المراجعات التاريخية على العرض الصحيح بعد تبديل الدورة. واجهة المراجعة تعرض شرح شمول السائقين السابقين ورسائل انتظار واضحة. نُشر توضيح الواجهة مع الحفاظ على كل ملفات نشر211 الأخرى وتحسينات shell المنشورة، في hosting212، وتم التحقق من البايتات. نُقلت تحسينات صفحة الطلبات المنشورة سابقًا إلى المصدر أيضًا حتى لا تضيع في الرفع المقبل.
التحقق النهائي: 1633 اختبار مصدر و47 اختبار حزمة، دون إخفاق، و13 فحصًا للعقود والحواجز، وفحص توافق SDK الحزمة الجديدة مع finance-rollout المنشور. لا تعديل IAM؛ تضييق مفتاح الأرشيف المباشر أغنى عن أي Query أو توسيع قراءة. جميع إعدادات الخدمات بما فيها ENFORCE بقيت كما هي، عدا تفعيل DISPATCH_REVIEW_EXECUTION_MODE=SAFE_FINANCIAL_RETRY في عامل القرارات القائم، بعد نشر القراء أولًا. ملفا النشر في المنصة admin-dispatch-retry-publication-298.json وadmin-dispatch-retry-ui-298.json.
الطلب ORD1792947277354 /11f7b253-537c-5890-8993-25269ae95bc3 لا يزال no_driver_available دون dispatchRestart، والطلب جاهز للاستلام؛ لم ينفذ الوكيل إعادة البحث من قاعدة البيانات أو من حساب بديل. ينتظر قرار المستخدم من حساب الإدارة. سبب تعثر الموجة السابقة المؤكد DISPATCH_PERFORMANCE_REFRESH_PENDING؛ فحص صحة المنظومة المحفوظة healthy=true بعد النشر. بعد قرار المستخدم افحص دورة جديدة ووصول عرض إلى السائق السابق، والصوت في المقدمة والخلفية/القفل والقبول/الضمان/التسليم/المؤشرات، ثم استأنف D01 المركبة والوثائق والمنطقة. لم تُرفع تغييرات هذه الجولة إلى GitHub.


## 298 — تجربة المستخدم: القرار نفّذ لكن بدء الدورة تعطل
سجل المستخدم requestId=a5108b18-d9f7-44ec-999e-730aeb52c96c. القرار القديم caseId=bd2ace1f78e3736e3d8b853e70d358ee3f1ac994c70ec9bb2d9dd54a14da559d أصبح EXECUTED/SEARCH_RESTART_QUEUED عند 2026-10-25T21:10:27.624Z. الدورة الجديدة DC:9c8fbb8e4e4ff53043f8150173f9b24d26cacfadb62fd27874832768be4e53bf، restartId=DRS:9c8fbb8e4e4ff53043f8150173f9b24d26cacfadb62fd278، مهلة البحث21:25:27.624Z، الحالة searching والموجة0، محاولات البدء0. لم يُرسل عرض بعد حتى آخر فحص21:22Z.
أُضيف تسجيل رمز آمن في catch كان يبتلع خطأ العامل؛ أظهر Error قبل محاولة البدء. فحص قراءة فقط مع منع صارم لكل كتابة/إرسال اجتاز سياق القرار ووصل إلى حد الكتابة المحظور. كشف التدقيق أن حزم الخدمات القديمة تستخدم SDK منفصلة عن الحزمة الجديدة، وأن الاختبار السابق كان يحول الأوامر من طرف أداة الاختبار، ما أخفى هذا الحد. أُضيف التحويل إلى أجسام delegates الفعلية باستخدام namespace SDK الأصلية لكل مصنع، دون أي توسيع صلاحيات أو تغيير الأمر أو المدخلات المالية. اختبار أجسام الحزم الفعلية دون تحويل مساعد من الاختبار نجح في47حالة. سكربت النشر scripts/publish-admin-dispatch-retry-sdk-298.py قيد التنفيذ، بالترتيب StartWave ثم financial-accept ثم Timeout ثم البقية؛ تابع /private/tmp/admin-retry-298-sdk-publish.log وإيصال sdkBoundaryOverlay في docs/admin-dispatch-retry-publication-298.json. لا تمدد مهلة الطلب مباشرة ولا تكرر القرار نيابة عن الموظف. إن انقضت المهلة قبل نجاح البداية، يصدر العامل مراجعة للدورة الجديدة ويستطيع المستخدم تسجيل قرار جديد من الواجهة.

298 متابعة تجربة المستخدم: اكتمل نشر SDK boundary على الخدمات التسع، ونجح اختبار47حالة من أجسام delegates الفعلية دون أي تطبيع من أداة الاختبار. بعده انتقل restart من attempts0 إلى attempts1 عند21:23:56Z، وأنشئت فعليًا خطة موجة keyVersion3 مستقلة تحدد السائق السابق34d8...؛ لم تُرسل لأن فحص الهوية أعاد DRIVER_OFFER_DRIVER_UNAVAILABLE من حد Cognito بين الحزم. فُحص الحساب الحقيقي في pool us-east-1_RGTqUXF5C: Enabled=true/CONFIRMED والاسم مطابق. أضيف تحويل أوامر Cognito إلى SDK العامل نفسه في مصنع createStagingPinnedFinancialRunner ونُشر StartWave overlay، دون تخفيف فحص الهوية أو تغيير pool أو IAM. نجح اختبار صارم بأوامر Cognito وDB من عميل المضيف نفسه، مع4اختبارات إعادة البحث:5حالات ناجحة.
انتهت مهلة الدورة أثناء الإصلاح عند21:25:27Z. أعاد المجدول الحالة للمراجعة SEARCH_WINDOW_EXPIRED عند21:25:46.422Z، وبقيت حالة WizzOrders ready_for_pickup دون سائق أو ضمان جديد. يلزم المستخدم تحديث صفحة الطلبات وفتح مراجعة التوزيع من جديد وتسجيل طلب إعادة بحث للدورة الحالية من حسابه؛ لا تمدد المهلة أو تعيد القرار بكتابة مباشرة. فحص وصول العرض الحقيقي والصوت بعد هذه التصحيحات لا يزال معلقًا. إيصال admin-dispatch-retry-publication-298.json يضم sdkBoundaryOverlay وcognitoBoundaryOverlay وبصمات الخدمات النهائية، وملف admin-dispatch-retry-cognito-boundary-298.json يثبت StartWave الأخير. سكربتا الجسور محفوظان في scripts/publish-admin-dispatch-retry-sdk-298.py وpublish-admin-dispatch-retry-cognito-298.py.

## 298 — القرار الثاني وتصحيح انتظار المؤشرات
سجل المستخدم القرار الثاني requestId=288f278a-426b-483c-bb23-88674cebdc34 للحالة caseId=ea9913d40b57773cdbe887e6442b2f055be1057c585cd3583760f840c343ea6b. أصبح EXECUTED وفتح restartId=DRS:d65a9fd606155349e8e8068d6869cb73a7e02d1d43882976. فشل اختيار البداية بـDISPATCH_PERFORMANCE_REFRESH_PENDING ثم أصبحت لقطة السائق current generation=builtGeneration=93. لم ينشأ أي مخطط موجة لهذه الدورة؛ الموجود القديم PREPARING من الدورة السابقة فقط.
أُصلح استهلاك مهلة التجهيز عند تأخر الأداء: انتظار محدود200/500/1000ms يقرأ اللقطة المحفوظة ويعيد فحص lease، ثم يسمح Coordinator بإعادة تهيئة نفس نية الموجة المنتهية فقط إذا غاب سجل الموجة تمامًا، والسائق غير مسند، ووقت البحث/إعادة الإسناد الأصلي ما زال قائمًا. لا تمديد لأي عرض أو لمهلة البحث ولا إعادة ضبط لخطة جزئية محفوظة. يحفظ firstCreatedAt وعدد preparationRetries ويمنع lease القديمة. نجحت33حالة تشمل3اختبارات مخصصة، ثم نُشر StartWave وTimeout فقط مع حفظ كل SDK bridges/Cognito والإعدادات. الإيصال dispatch-performance-preparation-298.json، والبصمات النهائية دُمجت في admin-dispatch-retry-publication-298.json.
آخر فحص: الطلب searching/currentWave0، restartPENDING attempts3، nextAttemptAt1792964627068، updatedAt21:41:47Z. السائق34d8... أصبح offline/isActive=false/isSearching=false، موقعه21:42:41.924Z. أُبلغ المستخدم أن يفتح تطبيق السائق الرئيسية ويضغط «شارك الآن» ويبقيه مفتوحًا؛ لا تشغّل حالته نيابة عنه ولا تغير DB. راقب القرار الحالي دون طلب قرار جديد ما دامت مهلة البحث قائمة، وتأكد من وصول العرض فعليًا والصوت.


## 298 — نجاح إعادة البحث والتسليم والصوت الفعلي
أكد المستخدم وصول العرض بصوت صحيح وتسليم الطلب ORD1792947277354 إلى الزبون. تحقق التدقيق للقراءة فقط: وصل العرض الجديد إلى السائق السابق ضمن دورة إدارية مستقلة، وقُبل عند 2026-10-25T21:46:23.806Z وسُلّم عند21:47:21.600Z بتوقيتUTC. القيد FULL_CASH منشور ومتوازن: تحصيل14000، احتفاظ السائق1500نقدًا، تسوية ضمان12500، مستحق المطعم9000مقفل بانتظار التسوية، وصافي المنصة3500د.ع. لا ائتمان إضافي لأجرة السائق ولا صرف للمطعم في هذه الخطوة. حدث التكامل INTEGRATED؛ عاد السائق available ونشطًا وباحثًا، دون طلب نشط.
تحدّثت لقطة الأداء المحفوظة عند21:47:24.988Z، generation=builtGeneration=110: القبول92.59٪ والإكمال95.45٪ والرفض المتتالي0. لا إعادة حساب للأداء داخل الموجة. دليل التدقيق: order-ORD1792947277354-verification-298.json في مستودع المنصة.
تتجاوز هذه النتيجة حالة الانتظار/عدم الاتصال السابقة مع حفظ سجلها. نجح اختبار الصوت لعرض حقيقي؛ يبقى اختبار الخلفية/قفل الشاشة ومسار إعادة البحث بعد فك إسناد موثق ضمن الاختبارات المرتبة. التالي في التنفيذ D01: اعتماد المركبة وصلاحية الوثائق والمنطقة المسموحة؛ رفع المنتجات المفوض للزميل خارج نطاقنا. لم تُرفع تغييرات هذه الجولة إلىGitHub بعد.


## 299 — زر انطلق فوق لوحة الرئيسية
بطلب المستخدم استبدل زر «شارك الآن» داخل اللوحة بزر دائري ذهبي بعنوان «انطلق»، فوق اللوحة بفاصل12 وبحجم96، مربوط بامتداد DraggableScrollableController أثناء السحب. الحلقة الداخلية بلون النص الكحلي تتنفس بدورة1600ms وتتوقف عند التحميل أو تقليل الحركة. نفس مسار بدء البحث وفحص الأهلية والضمان دون تغيير. أزيل الزر القديم وحدثت تسمية قائمة وقت البحث. فحص التحليل دون أخطاء؛ توجد تحذيرات سابقة في الشاشة. بناءRelease299 قيد التجهيز؛ لا تدع تثبيته قبل نتيجةdevicectl. الخطوة الرئيسية التالية تبقىD01.

299: اكتمل بناءRelease299 وثُبت وشُغل بنجاح على الآيفونB8850CE6-BCC2-551D-B930-3E108456B23F. معاينة المستخدم للشكل والحركة لم تؤكد بعد.


## 300 — استعادة موقع السائق التجريبي بعد بناء299
نبه المستخدم لغياب الموقع الثابت؛ بناء299 لم يمررdart-defines فعاد GPS الافتراضي بالخطأ. أُعيد بناءRelease300 بالإعداد السابق: staging،IS_PRODUCTION=false،USE_TEST_LOCATION=true، حساب34d8e408-1021-7076-6055-7325644f97cb،31.913292/44.476014. أضيف ملفfrontend/config/staging-test-driver.json لإعادة استخدامه في البناء: --dart-define-from-file=config/staging-test-driver.json. يجب الحفاظ على ملف الاختبار هذا أثناء جلسات المستخدم الحالية؛ لا تفعله لحسابات أخرى أو الإنتاج ولا تحذف التطبيق أو بياناته. تصميمانطلقمحفوظ. التثبيت ينتظر انتهاء البناء.

300: نجح البناء وتحققنا من إعدادات الموقع الستة فيGenerated.xcconfig؛ راجع نتيجة تثبيتdevicectl لتأكيد التشغيل.

300: تأكد تثبيت وتشغيلRelease300 بنجاح على الآيفون الحقيقي دون حذف بيانات التطبيق.

## 301 — تجربة اللون الكحلي لزر انطلق
طلب المستخدم تغيير خلفية زر انطلق إلى اللون الثانوي للتطبيق#00296B والنص والحلقة إلى الأبيض. تغيرت الألوان فقط مع الحفاظ على حركة الحلقة والارتباط باللوحة ومسار الأهلية. البناء يستخدم --dart-define-from-file=config/staging-test-driver.json للحفاظ على موقع الحساب التجريبي. التثبيت ينتظر اكتمالالبناء.

301: نجح تحليل ملف الزر دون ملاحظات وبناءRelease301 وتثبيته وتشغيله على الآيفون الحقيقي، مع ملف إحداثيات الاختبار المعتمد.


## 302 — تصغير انطلق وتوحيد ألوان الخريطة
طلب المستخدم تصغير زر انطلق ونصه مع خط عادي، وخلفيات علامات المتاجر بتدرج كحلي فاتح جدًا، وهالة/موجة موقع السائق بالكحلي بدل الذهب. الزر80بدل96 والنص18بدل22 بوزنnormal والحلقة68، مع بقاء النص والحلقة بالأبيض والخلفية#00296B. علامات المتاجر تدرج أبيض ممزوج4٪ إلى14٪ من اللون الثانوي، والأيقونات بقيت كحلية. تغير لون الهالة والموجة دون تغيير الحساب أو الموقع. تحليل دون أخطاء (تحذيرات الشاشة السابقة قائمة)، والبناءRelease302 يستخدم ملفstaging-test-driver.json. لا تغيير للأهلية أو المنصة أو خطةD01.

302: نجح بناءRelease302 وتثبيته وتشغيله على الآيفون الحقيقي مع إعداد الموقع التجريبي. معاينة المستخدم البصرية تنتظر تأكيده.


## 303 — أيقونات المتاجر ذهبية وتدرج كحلي أوضح
بطلب المستخدم لون أيقونات المطاعم والمتاجر على الخريطة هوAppColors.primary الذهبي؛ التدرج الكحلي للخلفية أغمق قليلًا بمزج12٪ إلى24٪ من اللون الثانوي بدل4٪ إلى14٪. لا تغيير لزر انطلق أو هالة السائق. بناءRelease303 باستخدام ملف إحداثيات الاختبار المعتمد. التثبيت ينتظر اكتمال البناء.

303: اكتمل بناءRelease303 وتثبيته وتشغيله بنجاح على الآيفون الحقيقي مع الحفاظ على ملف الموقع التجريبي.


## 304 — تحسين وضوح أيقونات المتاجر
طلب المستخدم إعادة أيقونات المطاعم والمتاجر للكحلي الثانوي#00296B لضعف وضوح الذهبي. بقي تدرج الخلفية الحالي12٪–24٪ وباقي التصميم وموقع الاختبار. بناءRelease304 يستخدمconfig/staging-test-driver.json. التثبيت ينتظر اكتمال البناء.

304: نجح بناءRelease304 وتثبيته وتشغيله على الآيفون الحقيقي مع إعداد الموقع التجريبي المحفوظ.


## 305 — تنسيق رأس لوحة السائق المتصل
طلب المستخدم تصغير خيار «الحصول على طلبات حتى» وجعله أقل ارتفاعًا وأعرض باليسار، واختصار الوقت إلىص/م، وإضافة نقطة ذهبية وكلمةمتصل أعلىاليمين. نُفذ رأسRTL بحالةمتصل يمينًا وشريحةوقت يسارًا، نص12/13 وحشوةعمودية7 مع مساحةلمس48، ونفسقائمةتعديلوقتالبحثوالإيقاف. تغيرتنسيقالوقتالمشتركإلىص/م. يظهرالمؤشرضمنحالةالبحثالفعالةفقط. بناءRelease305 يحافظعلىملفالموقعالتجريبي.

305: تحليل دون أخطاء، نجح بناءRelease305 وتثبيته وتشغيله على الآيفون الحقيقي مع حفظ موقع الاختبار؛ معاينة المستخدم تنتظر تأكيده.


## 306 — إعادة تنسيق قائمة وقت البحث
بطلب المستخدم تحسن تصميم القائمة: عنوانكحلي20 وأيقونةساعة بخلفيةناعمة، وصفمختصر، خياراتوقتارتفاعأقل مع اختياركحلي واضح، وأزرارارتفاع48. إيقافالبحثذهبي بنصكحلي؛ تحديثالوقت كحلي بنصأبيض وإلغاءبجانبه بدل ثلاثةأزراركاملةالعرض. مراعاةSafeAreaوقائمةوقتقابلةللتمرير. احتفظت بمسار اختيارالوقت والتأكيد والإيقافومنعالتكرار أثناءالتحميل. بناءRelease306بملفموقعالاختبارالمعتمد؛ التثبيت ينتظرانتهاءالبناء.

306: نجح التحليل دون أخطاء وبناءRelease306 وتثبيته وتشغيله على الآيفون الحقيقي مع ملف الموقع التجريبي المعتمد.


## 307 — مطابقة المزيد مع التسجيل وتدقيق D01
اكتملت مطابقة الملف والمركبة مع حقول التسجيل schema2: المحافظة، منطقة العمل، النقطة الدالة، نوع المركبة، والوثائق الثلاث. رُبطت سنوية المركبة بالحقل الصحيح registrationPaperUrl، وفُصلت حالة الرفع عن نتيجة المراجعة. أزيل عرض تفاصيل المركبة القديمة التي لا يطلبها التسجيل، وتوقف حفظ city عند تعديل بيانات schema2 الأساسية. نجح 17 اختبارًا، وتحليل الملفات الستة دون ملاحظات. بُنيت Release307 وثُبتت وشُغلت على الآيفون مع موقع الاختبار.
شمل تدقيق D01 للقراءة فقط الحزم المنشورة DriversApi وStartWave وfinancial-accept وstaff. صور الوثائق الثلاث موجودة للسائق التجريبي، لكن لا توجد نتيجة مراجعة منفصلة أو صلاحية إجازة أو اعتماد مركبة مسجل. هذا لا يثبت صلاحية الوثائق ولا ينفي صحتها.
الفجوات P0 موثقة في driver-registration-and-d01-audit-307.json: اعتماد الحساب لا يفحص الوثائق أو نوع المركبة؛ تغيير الوثيقة أو المركبة قد يبقي الاعتماد القديم؛ منطقة العمل ليست موحدة بين بدء البحث والموجات والقبول مع وجود fallback قديم لفئات Bronze/Silver/Gold؛ ولا يوجد عقد إدارة موحد لمراجعة كل وثيقة وصلاحيتها.
التالي: عقد أهلية موحد ومراجعة إدارية مدققة، ثم ربطه ببدء البحث وتجهيز العرض وقبوله. الاختبارات المطلوبة تشمل حدود التواريخ والتزامن وتغيير الوثائق والمركبة والمنطقة. يجب تحديد انتقال الحسابات المعتمدة حاليًا دون افتراض صلاحية وثائقها، مع السماح بإكمال الطلبات الجارية. D01 لا يزال مفتوحًا؛ لم ينشر باك إند جديد ولم يسجل الوكيل أي قرار اعتماد أو يغير بيانات فعلية. أعمال المنتجات والاستيراد المفوضة للزميل تبقى مستثناة.


## 308 — مركباتي واعتماد المركبات والوثائق
نُفذ ونُشر المسار على staging: سجل لكل مركبة مع اللوحة والسنوية، عدة مركبات مع واحدة مختارة للعمل، إضافة وتحديث وإزالة مؤرشفة، ومراجعة منفصلة لسنوية كل مركبة وإجازة السوق والبطاقة الوطنية. يسجل الموظف السبب وتاريخ الانتهاء الفعلي أو عدم وجود تاريخ انتهاء مبرر؛ لا تواريخ أو موافقات مخترعة. حد الانتهاء نهاية اليوم بتوقيت بغداد.
في المنصة: السائقون ← إدارة، مع عدّاد وفلتر للمراجعات. تستعمل القرارات API بصلاحية drivers.review/قراءة الوثائق ونطاق المنطقة، مع فحص إصدار الموظف والملف وقفل حذف الحساب والتدقيق. استُهدف مسار التنفيذ الداخلي الفعلي _discount_review/central-staff/index.js وحُفظ مسار قراءة الأداء المنشور. نُشرت الاستضافة213 وتطابقت الملفات الثلاثة مع الحزمة.
في السائق: المزيد ← مركباتي؛ إضافة المركبة وتحديث السنوية والوثائق الشخصية واختيار المعتمدة وإزالة المركبة مع حفظ بياناتها. اختيار المركبة والإزالة وتحديث المركبة المختارة يتطلب عدم الاتصال وعدم وجود طلب جارٍ، مع شروط ذرية تمنع سباق بدء البحث/قبول الطلب. أضيف إيقاف الاستقبال من مركباتي، وتُحدّث الرئيسية والذاكرة المحلية فقط بعد تأكيد الخادم؛ رفض الطلب الجاري لا يمس الحالة. أتيحت صفحة التصحيح من انتظار المراجعة والحساب المعلق. التسجيل الأول يطلب رقم اللوحة ويحفظه مع نوع المركبة والسنوية؛ تبقى طلبات العملاء القدامى بلا رقم لوحة قيد المراجعة حتى تصحيحه، ولا تمنح اعتمادًا تلقائيًا.
تقرأ الموجات وتجهيز العرض والقبول ملخص vehicleOperational صغيرًا محفوظًا في معاملة تحديث vehicleRegistry نفسها، مع مراجعات الوثائق الحالية. فُعل DRIVER_VEHICLE_REGISTRY_ENFORCE=true في الخدمات التسع دون تغيير IAM أو حدود الأداء. تُحفظ هوية المركبة مع العرض والطلب، ويُرفض قبول عرض قديم بعد تغيير المركبة ولو كان النوع واحدًا. حُظر إنشاء حجز من عرض Legacy قديم لا يحمل دليل مركبة قبل الوصول لكاتب الضمان. انتهاء/رفض/تبديل الوثائق يمنع العمل الجديد؛ لم يُغيّر مسار إكمال طلب مقبول أو قيوده.
التحقق: 27 اختبارًا للخدمة وصلاحيات السائقين، 64 على أجسام التفويض المعبأة فعليًا (مع SDK وCognito)، 30 Flutter تشمل توقف البحث والصوت والدخول، واختبار متصفح لحوار الإدارة، واختبار مسار الإدارة الداخلي، واختبارات مسار الملف وحارس إيقاف البحث. تطابقت تجزئات الخدمات التسع وأعلام التفعيل؛ المساران يرفضان الطلب غير المصادق401. ثُبتت وشُغلت Release308 على الآيفون الحقيقي مع ملف staging-test-driver.json والإحداثيات السابقة، دون حذف بيانات الدخول. بقيت بعض ملاحظات تنسيق Flutter؛ لا أخطاء بناء.
المهم الآن: السائق الحالي لم يُرحّل أو يُعتمد من الوكيل. تحتاج الإدارة إلى فتح الوثائق الحقيقية وتهيئة السجل برقم اللوحة الصحيح، ثم تسجيل مراجعاتها. بعد ذلك يوقف السائق الاستقبال ويختار المركبة المعتمدة. سُجلت التجارب البشرية الثماني بالترتيب دون إعلان نجاحها. لا حاجة لإنشاء طلب قبل إكمال المراجعة والاختيار.
التخزين محدود صراحة بـ12 مركبة غير مؤرشفة و60 سجل مركبة، وسجل أحداث بلا حذف صامت حتى260KB؛ عند بلوغه يرفض التعديل برسالة تتطلب الأرشفة. توسيع الأرشيف الدائم محفوظ في الخطة قبل الوصول للسعة؛ لا ينفذ الوكيل حذفًا تلقائيًا للوثائق. أدلة النشر والمتطلبات في driver-vehicle-implementation-308.json وdriver-vehicle-publication-308.json.
التالي ضمن D01: توحيد صلاحية منطقة العمل والجيران وإزالة تجاوز الفئات القديمة Bronze/Silver/Gold. لم يُغلق D01 كله. يبقى اختبار صوت الخلفية/قفل الشاشة والاختبارات البشرية الأخرى محفوظًا؛ المنتجات والاستيراد المفوضان للزميل خارج نطاقنا، ومستحق المطعم6000 المتروك بطلب المستخدم لم يُمس. هذه الجولة منشورة staging ومحلية؛ لا ادعاء برفعها إلى GitHub.


## 309 — تباين نصوص مركباتي
بطلب المستخدم أزيل اللون الذهبي من نصوص وأيقونات TextButton وOutlinedButton على الخلفيات البيضاء في مركباتي، وحوار الإزالة، وصفحات تحديث البيانات والوثائق. استُخدم الكحلي#00296B، والأزرار ذات الخلفية الكحلية بنص أبيض، مع بقاء إضافة مركبة بخلفية ذهبية ونص كحلي. أزيل تلوين شريط العنوان بالذهبي عند التمرير. لا تغيير في قواعد المركبات أو البيانات أو الباك إند. البناءRelease309 يستخدم ملف الموقع التجريبي المعتمد؛ التثبيت ينتظر نهاية البناء.

309: نجح بناءRelease309 وتثبيته وتشغيله على الآيفون الحقيقي مع ملف الإحداثيات التجريبية. لا أخطاء تحليل أو بناء؛ ملاحظات التنسيق السابقة فقط.

### Vehicle default selection — Release 310
- User rule: a sole nonremoved vehicle becomes selected by default only after actual administrative approval. Additional approved vehicles never replace the driver's current selection; switching remains explicit and offline/no active order.
- Shared versioned vehicle operation establishes the first default in the same approval transaction (registry, small operational projection, canonical references, audit). It does not grant account/document/region approval or turn searching on.
- Existing approved sole-vehicle profiles are normalized by explicit SELECT_DEFAULT POST when opening My Vehicles. Server rechecks count/status/no existing selection and fences the original profile/version; no direct business database mutations.
- Core regression tests: 24 pass. Vehicle screen tests: 5 pass. Actual packaged staff route test: pass. Release310 built with the existing scoped staging test-location profile. Deployment receipt: docs/driver-vehicle-default-310.json.
- D01 allowed work-region/neighbor permissions remains next; this change does not complete that item.
- Publication confirmed: both staging mutation cores hash-verified; Release310 installed and launched on iMohammed without uninstall/reset.

## 311 — توحيد منطقة العمل والجوار
تقدم التنفيذ: مصدر مشترك لصلاحية المنطقة من work_region_id المعتمد؛ علاقات الجوار الموجهة بأولوية0/1 من جدول المنصة، مع قراءة قوية مباشرة بمفتاح الزوج. لا توسع حسبBronze/Silver/Gold، ولا صلاحية من allowed_region_ids القديمة أو تطابق المحافظة. تُفحص حالة المنطقة وآبائها في المصدر والجدول المشتق، مع منع الحالة المجهولة وإغلاق التوصيل. تُحفظ شروط قراءة المناطق وعلاقة الجوار والحدود الجغرافية ضمن معاملات تجهيز/حفظ/قبول العرض لمنع سباقات إغلاق المنطقة.
الموجات تقرأ المرشحين المتاحين ثم تتحقق من نطاق كل سائق، حتى لا يُحجب الجوار لمجرد وجود سائق محلي. تُملأ حقول التوافق للترتيب من النتيجة المتحققة فقط. يبقى مصدر الأداء المحفوظ والحدود المركزية والحجز المالي كما هي.
تحديث الموقع كان يستدعي فحص الصلاحية بمعاملات غير متطابقة. استُبدل بفحص موحد ومعاملة شرطية؛ أثناء طلب جارٍ يحدث GPS فقط ويحافظ علىbusy/الإسناد، وخارج النطاق يوقف البحث الجديد فقط. تحديد المنطقة يستخدم نفسH3/Polygon الخاص بالطلبات؛ أزيل تخمين أقرب منطقة. الفحص القرائي وجد أن نقطة الاختبار تقع فيRmhvcpnn3iy5f1، وهي جار مسموح لمنطقة العملRmhveqa2vrrj13؛ لا تعديل مباشر لسجلات السائق.
الاختبارات الآلية:12لقواعد المنطقة،56على التفويضات المعبأة والرحلة المالية والاختيار والقبول، واختبار جسمupdateLocation الفعلي. نجحت القراءة الحقيقية للموقع/الصلاحية. النشر جارٍ وإيصالهdriver-work-region-publication-311.json؛ لا يُعلن نجاحه قبلPUBLISHED_VERIFIED. المستخدم أكد نجاح إضافة مركبة ثانية في310؛ بقيت التجارب البشرية المرتبة الأخرى محفوظة، ولا تُعامل كناجحة تلقائيًا. لا تعديل لمستحق المطعم6000 أو المنتجات المفوضة للزميل.

311: اكتمل النشر والتحقق من بصمات الخدمات التسع وتفعيلDRIVER_WORK_REGION_ENFORCE=true. مُنحت قراءة/شروط تحقق فقط لمراجع المناطق دون صلاحيات تعديلها. لا يتطلب تحديث تطبيق310؛ لا تثبيت أو إعادة تشغيل أو تسجيل خروج. بقيت التجارب البشرية مؤجلة حسب طلب المستخدم، ولم يُغلقD01 بالكامل قبل تدقيق فئة الطلب والمركبة وخدمات الإطلاق.


## 312 — إدارة المناطق منشورة ومتحقق منها على staging
نُشرت واجهة المناطق بالمهمة214 وتطابقت الملفات الستة مع الحزمة المختبرة، مع الحفاظ على تنسيق المنصة وملفاتها الأخرى. تدقيق الرسم مشترك بين المتصفح والخادم: تقاطع ذاتي، خروج عن الأب، تداخل مناطق المستوى نفسه، وصحة Polygon/MultiPolygon والثقوب. تظهر الحدود والإجزاء المخالفة بالأحمر؛ لا يُنشر شكل غير صالح. توجد مسودات بإصدارات، تحقق خطة التغييرات، أسباب وتاريخ مراجعة، وتتبع النشر وإلغائه واستعادته عند الفشل.
نُشرت خدمة الإدارة والعامل الدائم وطابور SQS مع DLQ واستعادة دورية؛ الأعلام والمستهلك مفعلة. يبني العامل تغطية H3 كاملة دون اقتطاع، ويتحقق من جاهزية الفهرس ثم يفعّل المصدر والمشتق والجوار ذريًا، مع حفظ التسعير والحدود الحالية. أثناء إعادة بناء حدود منطقة قائمة تتوقف الطلبات الجديدة مؤقتًا فيها؛ الطلب الجاري يبقى محفوظًا. لا جداول DynamoDB جديدة ولا تفعيل للمحركات القديمة أو Streams. العامل بلا صلاحيات مالية، ومنحة التدقيق الجديدة للإضافة فقط.
رُقّي قارئ إحداثيات الزبون الفعلي لقراءة الفهرس المركب والتحقق من الحدود والآباء؛ نجح الفحص القرائي الحقيقي. بقي عدد المصدر والمشتق15 لكل منهما، والطابور فارغ. لم يُنشئ الوكيل مناطق فعلية أو ينشر حدودًا أو يعدل الإحداثيات القائمة. سبع مناطق أظهر التدقيق الأولي خروج نقاطها عن الأب؛ تحتاج مراجعة بشرية وتصحيحًا معتمدًا، ولا يُستنتج الشكل الصحيح آليًا.
التحقق:16 اختبار خدمة وعامل،13 اختبار تغطية قائم، وفحوص جسم الإدارة وقارئ الزبون الفعليين والمتصفح. أُعيد فحص حزمة الاستضافة النهائية بتنسيقها الحقيقي في Chrome. الإيصالات:region-management-publication-312.json وregion-management-ui-publication-312.json وregion-management-validation-312.json.
اختبارات بشرية مؤجلة بالترتيب: فتح الصفحة بصلاحية الإدارة؛ رسم خطأ وتصحيحه؛ حفظ مسودة دون تغيير التشغيل؛ مراجعة الحدود الحقيقية المتنازع عليها ونشر تصحيح معتمد؛ متابعة اكتمال الفهرس والجوار وسجل التدقيق؛ اختبار إغلاق/إعادة تفعيل المنطقة على بدء البحث والعرض والقبول مع حفظ الطلب الجاري. لا تُعتبر هذه الاختبارات مكتملة تلقائيًا.
التالي بعد مراجعة المناطق: بقية D01، توافق فئة الطلب مع المركبة في خدمات الإطلاق؛ لا إعلان إغلاق D01 كله. لا تحديث Flutter مطلوب لهذا الجزء، ولا رفع GitHub في هذه الجولة. المنتجات والاستيراد المفوضان للزميل خارج النطاق، ومستحق المطعم6000 لم يُمس.


## 327 — صرف رصيد السائق من صندوق المنصة — 2026-10-27
أقر المستخدم شمول التعويض المعتمد ورصيد الشحن غير المستخدم. نُفذ ونُشر وفُعّل في staging مسار driver_cash_payout، مع namespace مستقل للسائق ومحرك صندوق وسند الصرف المشترك للمطعم. مراجعة ثم حجز الرصيد وتسليم نقدي مؤكد من الصندوق وتأكيد السائق بنفسه ثم مطابقة؛ لا إعادة صرف لأجرة COD ولا سحب للمحجوز أو للشحن التجريبي UAT أو الرصيد مجهول المصدر. المنصة: صفحة المحافظ/المالية بها قائمة طلبات الصرف، وسجل السائق به زر صرف الرصيد.
نُشرت خمس خدمات مع الحفاظ على بقية الحزم، وسياسة IAM محدودة للخدمة المالية فقط، وستة ملفات استضافة فقط؛ Amplify215 ناجح وفحص البايتات المنشورة ناجح. اختبار مسار السائق بلا مصادقة يعيد401، ولم ينفذ الوكيل طلب صرف أو تسليم نقد أو قيدًا حقيقيًا. نجح98اختبار خدمات و14اختبار Flutter واختبار المتصفح وحزم الخدمات الخمس. Release327 unsigned بُني؛ التوقيع والتثبيت قيد المتابعة. الإيصالات المركزية: docs/driver-cash-payout-publication-v1.json وdocs/driver-cash-payout-v1-review.json.
محفظة الاختبار القديمة بها فرق مطابقة86750د.ع (الرصيد2750والدفتر-84000)، فلا يجوز صرفها قبل مراجعة F01؛ لم يُعدّل الرصيد ولم يختلق قيد افتتاحي. هذا ليس إثبات قبول نقدي بشري. الاختبارات البشرية المرتبة محفوظة في review. لا رفع GitHub في هذه الجولة، ولا تغيير لمستحق المطعم6000، واستيراد المنتجات يبقى للزميل.

تحديث327: نجح بناء Release الموقّع وتثبيته على iMohammed iPhone17ProMax دون حذف التطبيق أو إعادة ضبط بياناته. لا يعد ذلك قبولًا بشريًا للتسليم النقدي.

## 328 — توضيح سبب منع صرف المحفظة
طلب المستخدم تفسير الحقل المعطل. أضيف سبب واضح فوق الحقل حسب رمز أهلية الخادم: فرق مطابقة، سجل أو مصدر غير موثق، محفظة غير متاحة، تغير الرصيد، تعذر تحقق مؤقت، رصيد مؤهل صفر، أو طلب صرف جارٍ. الحقل يبقى معطلًا وفق نفس الأهلية، وصار يتعطل أيضًا عند وجود طلب صرف جارٍ. لا تجاوز مالي ولا تعديل رصيد. نجحت6اختبارات مركزة؛ بناء Release328 وتثبيته قيد المتابعة.

تحديث328: اكتمل بناء Release الموقّع وتثبيته وتشغيله على الآيفون المتصل؛6اختبارات ناجحة، لا أخطاء أو تحذيرات تحليل (ملاحظات تنسيق فقط).


## 329 — أدوات خريطة السائق وخدمة العملاء
طلب المستخدم نقل المزيد إلى أيقونة منزل كحلية أعلى يمين الخريطة، والبحث في المقابل، وأدوات النشاط والإحصائيات والدعم والتوسيط يمين انطلق. نُفذت مع الحفاظ على IndexedStack ومعرفات الروابط القديمة. البحث في المتاجر الظاهرة ويحدد الكاميرا، مع إلغاء الفلتر؛ اختُبر أيضًا مع لوحة المفاتيح وشاشة320. الإحصائيات تستخدم لقطة الطلب الأسبوعية الحالية وتعرض البيانات التجريبية بصراحة؛ لا حوافز مختلقة. نشاط الاستلام مستقل: طلبات ready_for_pickup غير المسندة، بمراجعة قوية بعد الفهرس ومعيار منطقة العمل المعتمدة؛ الحجز/القبول الجاري والتسليم والإلغاء لا يحتسب. لا تفاصيل زبائن أو معرفات طلبات للسائق، والأخطاء ليست صفرًا مؤكدًا.
زود المستخدم رقم07831367435 وطلب التحكم بأي معلومة قابلة للتعديل من المنصة. إعداد مركزي في صفحة الإعدادات يحرر رقم الدعم وتفعيل النشاط وحد النشاط الأعلى وفاصل التحديث، عبر نفس صلاحيات ومراجعات وتدقيق الإعدادات. تُمنح خدمة السائق قراءة مفتاح هذه السياسة وحده. مراجعة329 تسجل الاختبارات البشرية المؤجلة. نجح25اختبار Flutter و6اختبارات نشاط و21اختبار إعدادات/سير عمل و6حالات IAM وفحص حزم فعلي واختبار متصفح. Release329 الموقّع جاهز، النشر والتثبيت قيد المتابعة. لا تغيير طلب أو إسناد أو رصيد أو سياسة موجات، ولا GitHubpush في هذه الجولة، والمنتجات والاستيراد للزميل.

تحديث329: نجح نشر الخدمتين وإعداد الرقم عبر السياسة المركزية وصفحة الإعدادات Amplify216، وحُفظت بقية الملفات المنشورة. نجح تثبيت وتشغيل Release329 على iMohammed دون حذف البيانات. فحص القراءة الفعلية وجد5متاجر ظاهرة؛ عدد الطلبات الجاهزة غير المسندة فيها1،0،0،0،0، ورقم الخدمة قادم من السياسة الإصدار1 عبر Lambda. لم يُنشأ طلب أو يُغيّر إسناد أو مال. القبول البشري للتفاعل وتغيير الإعدادات ومتابعة الطلبات الفعلية يبقى في review329.

## 330 — تنسيق أيقونات أدوات الخريطة
حسب طلب المستخدم: دوائر بيضاء52مع ظل محيطي خفيف وأيقونات30 بدل24، وألوان وظيفية واضحة للنشاط والإحصائيات والدعم والبحث والتوسيط، والمنزل كحلي. تبقى الخلفية بيضاء عند تفعيل النشاط ويظهر إطار يميز الحالة. لا تغيير للخدمات أو السياسة أو وظائف الأزرار. التحليل بلا ملاحظات، وRelease330الموقّع بُني وثُبّت وشُغّل على الآيفون دون حذف البيانات.

## 331 — صور المطاعم والمتاجر في علامات الخريطة
استبدال الأيقونة بصورة النشاط إن توفرت، بقص دائري كامل وغطاء cover وحافة بيضاء رفيعة؛ تظهر أيقونة الفئة عند فقد الصورة أو فشلها. تحميل الصور بعد العرض الأول للخريطة،4صور متوازية، كاش100علامة، مهلة6ثوان وإعادة محاولة الفشل بعد120ثانية. يمنع تحديث علامة من جيل خريطة قديم. فحص روابط صور المتاجر الخمسة المعادة فعليًا نجح HTTP200 image/png للجميع. التحليل لا أخطاء جديدة؛ Release331 قيد البناء والتثبيت. لا تغيير في الخدمات أو الطلبات أو الأرصدة.

تحديث331: نجح بناء نسخة Release الموقّعة وتثبيتها وتشغيلها على الآيفون، دون حذف البيانات.

## 332 — محاكاة توهج ثلاثة متاجر بطلب المستخدم
نُشرت إضافة للقراءة في خدمة السائق، مع سجل SIMULATION خاص بالسائق التجريبي المسموح ضمن إعدادات الخريطة، صالح لساعتين فقط. تظهر علامة نشاط تجريبي مؤقت. الأعداد المعروضة: فروج المدينة2(1حقيقي+1تجريبي) أصفر؛ كي أف سي دك المسحال3تجريبية أحمر؛ ماكدونالد أبوصخير6تجريبية أحمر. لا إنشاء لأي طلب في WizzOrders، ولا موجة أو إشعار طلب أو قيد مالي. لا صلاحيات IAM جديدة؛ قراءته محصورة بمفتاح إعداد الخريطة الموجود. اختبارات8ناجحة، وحُفظت بقية الحزمة وإعداداتها. بُني Release332 وثُبّت وشُغّل على الآيفون. الإيصال docs/driver-map-simulation-332.json. بعد ساعتين يتجاهل القارئ المحاكاة تلقائيًا ويعود للأعداد الحقيقية.

## 333 — العروض والإشعارات وهالة نشاط المتجر، وتسليم GitHub
أصبح اسم تبويب0 «العروض» مع أيقونة عرض، دون تغيير معرفات الروابط. إشعارات المحفظة والحساب مصنفة حسب يوم بغداد، بأوقات مقروءة وبطاقات واضحة قابلة للنقر إلى المحفظة. استبدلت دوائر النشاط الجغرافية بهالة بكسلية ملاصقة لعلامة الصورة أو الأيقونة: أحمر واضح، أصفر، أو لا شيء؛ الحجم لا يتباعد مع الزوم. تنتهي الهالة عند انتهاء صلاحية بيانات النشاط. موجات موقع السائق بقيت كما هي. نجح12اختبارًا مركزًا وراجعت صورة الهالة بصريًا. Release333 قيد البناء.
طلب المستخدم رفع ودمج التطبيقات الأربعة لزميله. الفروع الأربعة الحالية هي feature/malwersh/bootstrap، والفرع الرئيسي الفعلي staging-main. طلبات الدمج القائمة تتطلب REVIEW_REQUIRED؛ لا تجاوز لهذه السياسة. تُحدّث طلبات الدمج والأوصاف وتعليمات السحب، وبند المنتجات/CSV/Excel يبقى مفوضًا للزميل. فحص الملفات الجديدة والمعدلة لم يجد مفاتيح خاصة أو رموز دخول حقيقية؛ ملفات pycache تُستثنى. النتيجة النهائية للرفع وتثبيت333 قيد المتابعة.

تحديث333: بُني Release333 الموقّع وثُبّت وشُغّل على الآيفون. ملف تسليم GitHub28أكتوبر2026 يشرح سحب staging-main بعد موافقة ودمج PR، ولا تُعد الفروع محمية المراجعة مدمجة قبل تحقق ذلك في GitHub. ملفات التحديثات الأربعة خضعت لفحص الأسرار وdiff-check؛ لا force push أو تجاوز مراجعة أو تغيير صلاحيات الفروع.

## 350 — استعادة ملف موقع السائق الاختباري بعد 349
أكد المستخدم أن موقعه الحقيقي في أمريكا يمنع اختبار الحساب. اتضح أن البناء العادي للنسخ الأخيرة لم يمرر الملف المقصود للاختبار، فعاد GPS الافتراضي. بُني Release350 باستخدام frontend/config/staging-test-driver.json: staging، nonproduction، USE_TEST_LOCATION=true، هوية الحساب التجريبي34d8e408-1021-7076-6055-7325644f97cb،31.913292/44.476014. تحققت قيم DART_DEFINES المولدة. اختبار حصر الموقع بهذه الهوية وstaging ورفضه للإنتاج/الحسابات الأخرى ناجح. نقطة الاختبار أعادت HTTP200 ومنطقة Al-Manathirah Center وخمسة متاجر وفق حدود الخدمة الحالية. لا كتابة في الطلبات أو الأموال أو تغيير أهلية الموجات.
للاستمرار في جلسة هذا المستخدم: استخدم scripts/build-driver-trial.sh release، الذي أصبح يقرأ رقم البناء من pubspec ويعيد استخدام ملف الإعدادات نفسه. لا تستبدله ببناء عادي دون ملف التعريف؛ ذلك يعيد GPS ويعطل التجربة الجارية. يبقى GPS هو الافتراضي في البناء العام والحسابات الأخرى. تثبيت350 قيد التنفيذ وقت هذه الملاحظة.
تحديث350: اكتمل التثبيت على الآيفون الحقيقي iMohammed وتشغيل التطبيق بنجاح، مع الحفاظ على البيانات والجلسة. إعداد الاختبار المشار إليه أعلاه هو المطلوب للبناء التالي خلال هذه الجلسة.
