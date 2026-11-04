# Full-screen delivery completion — 309

Replaced the success AlertDialog with a full brand-blue screen, yellow success mark, short order number, white entitlement card and yellow Home CTA. SafeArea/scroll layout supports 320/390 widths; system back goes Home instead of exposing the delivery form again.

The amount is only the same-order server-confirmed delivered/completed ActiveOrder.driverEarnings field. It is never derived from customer cash, customer delivery fee, wallet hold or stale pre-delivery quote. Delivery success triggers a fresh order read; an already delivered server read can seed the screen directly. Missing/unavailable/invalid earnings show a retry state, not a guessed zero. Actual confirmed zero remains zero. No backend/financial calculation changes.

Existing completion polling and scoped cache cleanup remain. Confirmed delivered/completed now shows the completion screen; returned/cancelled still goes Home. A different current assignment remains preserved and goes Home. No extra delivery mutation on recovery.

Validation: 10 completion/delivery/recovery widget tests passed (including differing customer cash vs entitlement, zero, wrong-order retry, small widths, administrative completion and new-assignment preservation). Analyzer no errors/warnings, 6 style infos. Profile build249 succeeded and installed on test iPhone; app launch requested. No live order or money changes. The user's already completed order is not redelivered; the app may restore Home after prior successful cleanup.
