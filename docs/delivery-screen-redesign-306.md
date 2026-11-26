# Delivery and cash review — 306

Unified delivery and customer-cash-review screens with TripStyle blue/yellow palette, white bordered cards, full destination, working phone link, order ID, item quantities and total/payment method. Pinned shared circular delivery slider is disabled for COD until driver confirms full cash receipt. Actual delivery still requires a fresh order read and arrived_at_customer/at_customer state; server financial actions remain unchanged. Successful cache cleanup is scoped to the specific order. Completion polling/lifecycle recovery and administrative terminal closure remain in place.

Cash review retains existing APIs, expectedVersion, stable idempotency keys, actual-payment confirmation and explicit refund execution/receipt confirmations. Restyled amount summary, inputs, submit and refund-empty state; no money/status writes on opening.

Removed misleading optional camera UI: prior implementation captured a local file but never uploaded or bound it to delivery. Photo evidence requires a separately implemented upload/receipt path before restoring the control. Legacy unavailable-customer mock action is not exposed; financial orders retain the existing ReturnOrderScreen flow.

Validation: targeted analyzer no errors or warnings (4 style info); 16 tests passed covering 320/390-width COD gating, cash review idempotent submission/refund safeguards, administrative delivery recovery and slider interactions. Existing tests adjusted to scroll controls into the visible viewport for the taller new cards. All writes in tests are mocked. Profile build 246 succeeded and installed on the test iPhone; app launch requested. No live test-order submission, declaration, refund, return, arrival or delivery performed.

Superseded photo limitation: 307 now implements and restores optional private photo evidence; see delivery-proof-307.md.
