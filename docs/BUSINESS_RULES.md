# Approved business rules

This document records the default decisions used by the application when a
previously deferred policy is implemented. Changes to these rules require a new
review and must not rewrite historical submission snapshots.

## Submission cancellation

- A proposer may cancel their own submission while it is a `draft`,
  `pendingChecker`, `pendingAcknowledgement`, or `pendingApproval`.
- `approved`, `rejected`, and `cancelled` submissions are terminal and cannot be
  cancelled or reopened in place.
- A nonblank reason is required. Cancellation keeps the submission, review
  history, and attachment metadata, and voids every unfinished review task.
- The rule applies to the current workflow policy. Existing signed snapshots are
  not rewritten.

## Superadmin account management

- Superadmin authority uses Django's separately provisioned `is_superuser`
  capability; ordinary employee role grants never imply administration access.
- Superadmins may create and maintain employee identities. Creation requires a
  unique company email, employee number, and a password that passes Django's
  configured password validators.
- Administrative mutations are audited and use idempotency keys where they
  create resources.
- Signature replacement creates a new normalized private PNG version and only
  moves the employee's current pointer. Historical signature rows and signed
  submission/task references are immutable.
