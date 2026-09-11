import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/core/session/session_store.dart';
import 'package:sales_app/features/authentication/data/auth_repository.dart';
import 'package:sales_app/features/authentication/domain/auth_session.dart';
import 'package:sales_app/features/backoffice/data/backoffice_repository.dart';
import 'package:sales_app/features/submissions/data/submission_repository.dart';
import 'package:sales_app/features/submissions/domain/submission.dart';

const _apiBaseUrl = String.fromEnvironment('TEST_API_BASE_URL');
const _submitterEmail = String.fromEnvironment('TEST_SUBMITTER_EMAIL');
const _submitterPassword = String.fromEnvironment('TEST_SUBMITTER_PASSWORD');
const _checkerEmail = String.fromEnvironment('TEST_CHECKER_EMAIL');
const _checkerPassword = String.fromEnvironment('TEST_CHECKER_PASSWORD');
const _acknowledgerEmail = String.fromEnvironment('TEST_ACKNOWLEDGER_EMAIL');
const _acknowledgerPassword = String.fromEnvironment(
  'TEST_ACKNOWLEDGER_PASSWORD',
);
const _approverEmail = String.fromEnvironment('TEST_APPROVER_EMAIL');
const _approverPassword = String.fromEnvironment('TEST_APPROVER_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'creates a draft and completes checker, acknowledger, and approver tasks',
    () async {
      final uri = Uri.parse(_apiBaseUrl);
      expect(uri.path, endsWith('/api/v1'));

      final submitter = await _actor(uri, _submitterEmail, _submitterPassword);
      final checker = await _actor(uri, _checkerEmail, _checkerPassword);
      final acknowledger = await _actor(
        uri,
        _acknowledgerEmail,
        _acknowledgerPassword,
      );
      final approver = await _actor(uri, _approverEmail, _approverPassword);
      addTearDown(() async {
        submitter.api.close();
        checker.api.close();
        acknowledger.api.close();
        approver.api.close();
      });

      final submissions = SubmissionRepository(submitter.api);
      var draft = await submissions.createEmptyDraft();
      final policy = await submissions.policy(draft.id);
      expect(policy.routingConfigured, isTrue);
      expect(policy.checker?.id, checker.session.user.id);

      final locations = await submissions.locations();
      final programTypes = await submissions.programTypes();
      expect(locations, isNotEmpty);

      final acknowledgerOption = await _reviewerOption(
        submissions,
        draft.id,
        ReviewerStage.acknowledgement,
        acknowledger.session,
      );
      final approverOption = await _reviewerOption(
        submissions,
        draft.id,
        ReviewerStage.approval,
        approver.session,
      );
      final start = DateTime.now().toUtc().add(const Duration(days: 7));
      final end = start.add(const Duration(days: 14));

      draft = await submissions.updateDraft(draft.id, {
        'programName': 'E2E ${DateTime.now().toUtc().toIso8601String()}',
        'locationIds': [locations.first.id],
        'periodStart': _date(start),
        'periodEnd': _date(end),
        'acknowledgerIds': [acknowledgerOption.person.id],
        'approverIds': [approverOption.person.id],
        if (programTypes.isNotEmpty) 'programTypeId': programTypes.first.id,
        if (programTypes.isNotEmpty)
          'estimatedCost': {'currency': 'IDR', 'amount': '1000000.00'},
      }, draft.version);
      var submitted = await submissions.submitDraft(draft.id, draft.version);
      expect(submitted.status, 'pendingChecker');

      submitted = await _approveReadyTask(checker.api, submitted.id);
      expect(submitted.status, 'pendingAcknowledgement');
      submitted = await _approveReadyTask(acknowledger.api, submitted.id);
      expect(submitted.status, 'pendingApproval');
      submitted = await _approveReadyTask(approver.api, submitted.id);

      expect(submitted.status, 'approved');
      expect(submitted.myActiveTaskIds, isEmpty);
      expect(
        submitted.reviewTasks.where((task) => task.status == 'approved'),
        hasLength(3),
      );
    },
    skip: _configured
        ? false
        : 'Set TEST_API_BASE_URL and the four TEST_* reviewer credentials.',
  );
}

bool get _configured => [
  _apiBaseUrl,
  _submitterEmail,
  _submitterPassword,
  _checkerEmail,
  _checkerPassword,
  _acknowledgerEmail,
  _acknowledgerPassword,
  _approverEmail,
  _approverPassword,
].every((value) => value.isNotEmpty);

Future<_Actor> _actor(Uri baseUrl, String email, String password) async {
  final api = ApiClient(baseUrl: baseUrl);
  final auth = AuthRepository(
    api: api,
    sessionStore: MemorySessionStore(),
    isWeb: false,
  );
  return _Actor(api, await auth.login(email: email, password: password));
}

Future<ReviewerOption> _reviewerOption(
  SubmissionRepository repository,
  String submissionId,
  ReviewerStage stage,
  AuthSession actor,
) async {
  final page = await repository.reviewerOptions(
    submissionId,
    stage: stage,
    query: actor.user.fullName,
  );
  return page.items.singleWhere(
    (option) => option.person.id == actor.user.id,
    orElse: () => throw StateError(
      '${actor.user.fullName} is not eligible for ${stage.apiValue}.',
    ),
  );
}

Future<Submission> _approveReadyTask(ApiClient api, String submissionId) async {
  final repository = BackofficeRepository(api);
  final detail = await repository.getSubmission(submissionId);
  expect(detail.submission.myActiveTaskIds, hasLength(1));
  return (await repository.approveTask(
    submissionId: submissionId,
    taskId: detail.submission.myActiveTaskIds.single,
    version: detail.submission.version,
    note: 'Disetujui oleh integration test.',
  )).submission;
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class _Actor {
  const _Actor(this.api, this.session);

  final ApiClient api;
  final AuthSession session;
}
