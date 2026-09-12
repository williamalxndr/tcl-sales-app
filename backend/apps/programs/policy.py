"""Approved business-policy values shared by configuration and runtime code."""

# A proposer may withdraw work that has not reached a terminal decision. Approved,
# rejected, and already-cancelled submissions remain immutable audit records.
CANCELLABLE_STATUSES = (
    "draft",
    "pendingChecker",
    "pendingAcknowledgement",
    "pendingApproval",
)
