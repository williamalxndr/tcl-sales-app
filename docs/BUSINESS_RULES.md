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

## Dashboard metrics

- The first dashboard is personal, not company-wide. Every authenticated user
  sees only submissions they own and review tasks assigned to them; superadmin
  status does not widen dashboard data access.
- Submission cards report `draft`, `inReview`, `approved`, `rejected`, and
  `cancelled` counts. Non-draft counts use `submittedAt` as their date basis;
  drafts are a current snapshot.
- Reviewer cards report the current number of `ready` assignments plus
  `approved` and `rejected` assignments decided in the selected period.
- The default period is the trailing 30 calendar days in `Asia/Jakarta`.
  Explicit inclusive `dateFrom` and `dateTo` values may cover at most 366 days.

## Data retention

- Bytes for soft-removed attachments are retained for 30 days for operational
  recovery, then deleted with their metadata. Attachments on terminal submissions
  are retained for seven years from `closedAt`, then deleted. Files belonging to
  active submissions are not age-purged.
- PDFs are generated on demand and are not application records. They are never
  persisted by the API; any unexpected operational spool artifact is limited to
  24 hours.
- Audit logs are retained for seven years from `occurredAt`, then deleted in
  bounded batches. Application records and immutable signature versions are not
  included in these automated jobs.
- Retention commands run in dry-run mode unless an operator supplies an explicit
  confirmation flag. Production scheduling is daily and must record command
  output in the platform's operational logs.
