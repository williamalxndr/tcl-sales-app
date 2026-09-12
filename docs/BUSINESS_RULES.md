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
