# Backend setup and operation

The development API uses Django REST Framework and MySQL 8.4. [openapi.yaml](openapi.yaml) describes all 30 mounted operations; [API_DESIGN.md](API_DESIGN.md) records flows, permissions and remaining policy questions. Flutter remains at its existing startup shell and has not been modified by this backend implementation.

## Start or update

From the repository root, preserve an existing `.env`. On a fresh checkout only, copy `.env.example` to `.env` and configure it.

```sh
docker compose up -d --wait mysql
docker compose build backend
docker compose run --rm backend python manage.py migrate --noinput
docker compose run --rm backend python manage.py configure_workflow
docker compose run --rm backend python manage.py seed_master_data
docker compose up -d --wait backend
docker compose --profile uploads up -d clamav attachment-scanner
```

Migrations add tables/constraints without resetting the existing database. `configure_workflow` records the confirmed sequential order, terminal rejection and required provisioned signatures. It preserves any existing cancellation/type-cost settings. `seed_master_data` creates the observed BSD/Bekasi and Bundling/Diskon examples without overwriting existing records or creating users/submissions. Skip it if master records will be imported separately.

The API is at `http://localhost:8000/api/v1`; database access from the host is at `127.0.0.1:3307` by default. Docker-internal MySQL uses `mysql:3306`. API health checks MySQL connectivity, not scanner availability or pending migrations.

```sh
curl --fail http://localhost:8000/api/v1/health/ready
docker compose --profile uploads ps
docker compose logs --tail=30 backend attachment-scanner clamav
```

ClamAV runs privately with no published host port. Its official 1.4 image is amd64-only, so Compose explicitly uses Docker Desktop emulation on Apple Silicon. Initial database updates/loading take time. Uploads stay pending while scanning is unavailable; the worker retries without releasing them. The `uploads` profile can be omitted for attachment-free workflows.

The backend and scanner share `backend/media/`, ignored by Git and stored outside any public route. MySQL and scanner databases use persistent Docker volumes. `docker compose --profile uploads down` preserves those volumes and private files. Keep DB and media together in backups. This Compose setup uses Django’s development server and is not a production deployment.

## Provision real employees

Accounts, roles, location grants, eligibility and signatures come from the organization. No default employee password, public signup endpoint or admin site is included. The future superadmin interface can call the same domain models/services once its permissions are agreed.

Prepare the actual employee signature images under a private path accessible inside the container, for example ignored `backend/media/provisioning/`. Provision reviewers before their proposer. Commands prompt privately for each password (minimum 15 characters plus Django password validation). Replace all example names/emails/employee numbers with real approved values.

```sh
docker compose run --rm backend python manage.py provision_employee \
  --email checker@example.com --name "Checker Name" --employee-number EMP002 \
  --job-title "Sales Supervisor" --roles checker \
  --signature /app/media/provisioning/checker.png

docker compose run --rm backend python manage.py provision_employee \
  --email mengetahui@example.com --name "Mengetahui Name" --employee-number EMP003 \
  --roles acknowledger --signature /app/media/provisioning/mengetahui.png

docker compose run --rm backend python manage.py provision_employee \
  --email menyetujui@example.com --name "Menyetujui Name" --employee-number EMP004 \
  --roles approver --signature /app/media/provisioning/menyetujui.png

docker compose run --rm backend python manage.py provision_employee \
  --email proposer@example.com --name "Proposer Name" --employee-number EMP001 \
  --roles submitter --checker-email checker@example.com --locations BSD BEKASI \
  --acknowledgers mengetahui@example.com --approvers menyetujui@example.com \
  --signature /app/media/provisioning/proposer.png
```

The signature input accepts PNG/JPEG up to 2 MB and 4 megapixels, normalizes to private PNG, and creates an immutable AccountSignature record. Login works before a signature is present, but submit/approve require it. Approval requests never accept signature bytes or a caller-selected signature ID. Historical events retain the exact signature version used.

`--acknowledgers`/`--approvers` assign eligible people, not a default program plan; the proposer selects and orders them per draft. `--checker-email` is the fixed Checker relation. `--locations` expects master codes. Multiple `--roles` are supported, but no grant bypasses ownership/assignment. Existing accounts are not silently overwritten. Updating existing account/signature provisioning is a future explicit management workflow; a trusted maintenance script must preserve old signature rows and use new immutable versions.

For controlled automation, the command can read `SALES_EMPLOYEE_PASSWORD` from its process environment. Inject it via your secret mechanism; never put real passwords in shell command arguments, tracked files or logs. Initial signature provisioning source images should remain private too.

## Workflow configuration still awaiting answers

Sequential approvals, rejection ending the program and provisioned image snapshots are already configured. Cancellation source states remain empty. `/cancel` returns `409 WORKFLOW_POLICY_UNRESOLVED` until the user chooses allowed states. Do not enable cancellation merely to make a test/demo succeed.

After business confirmation, use `configure_workflow --cancellation-states` followed by the approved states from `draft`, `pendingChecker`, `pendingAcknowledgement`, `pendingApproval`, `approved`. The provisional action contract requires a nonblank reason and preserves history/files while voiding outstanding tasks. Rejected/cancelled programs cannot be reopened through this command.

Type/cost requiredness is nullable/unresolved. Complete type and IDR cost can be submitted now. Missing values block submit with a policy issue until `configure_workflow --require-type-and-cost yes` or `no` is explicitly selected. Reviewer limits default to the mockup’s two Mengetahui and three Menyetujui; self/cross-stage duplicate approvals and delegation are not enabled. Existing submitted policy snapshots are not rewritten by configuration changes; cancellation checks the current explicitly authorized source-state allowlist.

## Client sequence

Native clients call login with `{email, password, clientType: "native"}`, keep the access token in memory and refresh credential in OS secure storage, and send `Authorization: Bearer ...` on business endpoints. Web first calls `/auth/csrf` with credentials enabled, sends returned X-CSRFToken and `clientType: "web"` on login, then uses the rotated CSRF token for refresh/logout. Web refresh/logout bodies are `{}` and use the HttpOnly cookie; native bodies contain `refreshToken`. Deploy frontend/API on the same site for SameSite=Lax cookies and configure exact CORS/CSRF trusted origins.

Create a draft with a fresh Idempotency-Key; save its ID and ETag. Query `/policy` and `/reviewer-options` for valid selections. PATCH with If-Match. Upload optional files with both headers, poll metadata, and refetch parent detail after scanning changes its version. Submit with both headers. Reviewers list `/backoffice/program-submissions`, act on a specific ready review-task ID, then find completed work in `/backoffice/review-history`. Use `allowedActions`, `myActiveTaskIds` and `submissionIssues`; never calculate authorization or next statuses in Flutter.

## Verification

```sh
docker compose run --rm backend python manage.py check
docker compose run --rm backend python manage.py makemigrations --check --dry-run
docker compose run --rm backend python manage.py test --keepdb --noinput
```

Tests use the isolated `test_sales` MySQL database and temporary private media. They cover native/web sessions and CSRF, rotation/reuse/logout, role/object scopes, strict inputs, drafts/versioning/idempotency, sequential workflow/rejection/history/signatures, cancellation gating, upload quarantine/download/removal, signed PDFs and concurrent mutations. Scanner verdicts are mocked in the deterministic suite; live ClamAV integration is checked separately when the profile is running. Tests never seed real employees or approvals.

Contract checks can run independently of Django:

```sh
python3 -m venv .venv-contract
.venv-contract/bin/pip install -r tools/requirements-contract.txt
.venv-contract/bin/python tools/validate_api_contract.py
```

The validator checks OpenAPI 3.1, JSON request/response examples, Markdown parity and Django URL coverage. CI repeats contract and MySQL checks. Flutter checks remain in CI, but this backend-only task does not change or rebuild feature screens.

## Operational boundaries

Production still needs TLS, a production server, trusted proxy/rate handling, secrets, media/database backups and recovery tests, monitoring, least-privilege runtime database users, approved retention/aggregate upload quotas and deliberate credential cleanup. Rate buckets, idempotency records, session token history and audit rows are persisted; no automatic destructive purge has been introduced before retention is selected. Raw signature assets and storage keys are never API resources. Dashboard metrics, recovery, signature replacement UI, account management and review reassignment remain deferred.
