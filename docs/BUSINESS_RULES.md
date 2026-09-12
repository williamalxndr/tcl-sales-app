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

## Review task delegation

- Only the current assignee may delegate a `ready` task.
- The replacement must be another active employee with the matching stage role;
  Mengetahui and Menyetujui replacements must also be eligible for the proposer.
- Delegation cannot introduce self-approval or give one employee multiple tasks
  in the same submission. The task remains ready and every assignment change is
  recorded in the audit log.

## Revisions after rejection

- Rejection remains terminal and its submitted record is never reopened in
  place. The proposer may create one linked successor draft.
- The successor copies editable program fields, locations, and reviewers that
  are still eligible. Attachments, task decisions, signatures, and snapshots do
  not carry over.
- The new draft receives a new program number and takes a fresh policy, identity,
  routing, and signature snapshot when it is submitted.

## Administrative review reassignment

- A superadmin may reassign only `waiting` or `ready` tasks; completed and
  voided decisions are immutable.
- The replacement follows the same active-role, eligibility, self-approval, and
  duplicate-assignment rules as delegation.
- Reassignment keeps the task stage and readiness state, increments the parent
  version, and records both assignees in the audit log.
