
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
