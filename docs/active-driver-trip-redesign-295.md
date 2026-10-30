# Active driver trip — 295

Current human test: ORD1792721062420 / 691d5628-2497-5a60-88d6-25971d6aa0d2. Read-only AWS inspection after SSO renewal: assigned, financialAcceptance present, attempt1, no pickedUpAt, hold ACTIVE. No order transition, financial action or test unassignment was submitted by the agent.

## Presentation

Active overview rebuilt around a compact current-stage header, pickup/drop-off route, prominent customer collection amount, expandable detailed progress and pinned primary action. Blue/yellow brand palette, dark text on yellow, neutral backgrounds. No invented maps, ETA or earnings. Known assignment/status aliases now map to the timeline correctly. Resuming heading stages uses the correct existing screen; unknown stages refresh instead of blindly starting a trip.

## Unassignment audit and corrections

Existing canonical financial-unassign endpoint is appropriate before food pickup. codReassignment validates actor, immutable assignment selector, pre-pickup status, absence of pickup/cash/return/cancellation/outcome, and atomically archives ASSIGNMENT_RELEASE, releases exactly the driver's collateral, retains order funding and pinned pricing, and schedules redispatch excluding the former driver. Compensation remains pending policy review. No new cancellation/financial policy was introduced.

Live staging-driver-financial-accept has FINANCIAL_COD_ASSIGNMENTS_MODE=REQUIRED and code SHA ERMb+QR9TUlgRLS1P1NnuxuZJcjElxPBHRTQzkCI2nY=, matching publication284. No backend deployment needed/performed.

Added a shared pre-pickup unassign flow to overview, heading-to-restaurant and at-restaurant. Removed old cancel-by-driver affordances in those two subsequent screens: that legacy whole-order cancellation is intentionally rejected for financial orders. Dialog submits and returns first, then parent cleans matching local cache/provider and navigates, fixing old navigation-before-sheet-pop. Server failure keeps sheet and assignment; pending prevents dismissal/double submit. Removed forced two-hour searching preference changes. Frozen financial assignment is sent through existing authenticated transport, which requires matching successful order receipt. Legacy endpoint remains only for orders without financialAssignment and retains its server-side financial guards.

While auditing, found at-restaurant issue callback merely waited one second and printed fake success. Replaced with existing authenticated reportStoreIssue API and matching server receipt requirement. It records a report; it does not cancel the order or settle money.

## Verification

13 Flutter tests passed: narrow layout320/390 at text scale1.3, pinned action, assigned stage, pre/post-pickup availability, exact financial selector/no-cash payload, wrong receipt rejection, failure feedback, plus existing return/cache regression suite. Canonical backend cod-reassignment7 and full-cash-lifecycle6 tests passed. Analyzer: existing info-level lints, no errors/warnings in changed targets. Device profile build235 intended final.

## References

- https://sparkdriverapp-walmart.helpdocs.io/l/en/article/8rm6c03tzi-picking-up-a-curbside-order (stage/next-action hierarchy)
- https://help.doordash.com/en-us/dashers/article/how-can-i-unassign-myself-from-an-order (help, reasons, confirmation, pre-pickup unassign)
- https://help.uber.com/en-GB/driving-and-delivering/article/what-if-i-need-to-cancel-a-delivery-request-ive-accepted?nodeId=53face98-77c0-41ac-b117-847d1a60d0cb (replacement driver before pickup vs support after pickup)

Patterns adapted to our own data/policies, not copies of vendor penalty/payment rules. Subsequent stages retain their existing layouts until reached with the user; this change redesigns the first accepted-order overview.
