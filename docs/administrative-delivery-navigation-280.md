# Driver delivery screen after administrative completion

The customer delivery screen retained the route's initial order and did not read terminal server status after staff adjudication. A driver could therefore remain on cash confirmation even though the customer already saw delivery completed.

The screen now reads its specific order on entry, every three seconds while it is visible and the app is foregrounded, after returning from cash review, on resume, through an explicit refresh action, and before ordinary delivery submission. Only a matching order ID and an explicit delivered/completed/returned/cancelled status trigger navigation home. Read errors do not clear local state. Clearing persisted/provider state is conditional on the original order ID, preserving any newer assignment. The screen never sends an additional delivery or cash attestation for a terminal order.

Validation: Eleven navigation and cash-review widget tests pass (six navigation tests), including four new cases for existing completion, later completion, read failure, and preserving a newer assignment. Targeted Flutter analyzer reports no issues.

Human staging test: ORD1792679331051 / 2209bbd1-9e9f-5d18-8d47-97293159773e. User executed company coverage adjudication: declared/administratively recorded cash 8,500 IQD and company-covered shortfall 750 IQD. UI showed the case closed and decision executed, with the original driver statement preserved and no customer statement created. Customer showed delivered; driver screen reconciliation discovered and fixed here. All physical cash and contact events were explicitly simulated. Post-install device observation remains pending until verified by the tester.
