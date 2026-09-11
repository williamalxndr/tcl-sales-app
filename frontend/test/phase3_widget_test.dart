import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/di/providers.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/core/ui/app_theme.dart';
import 'package:sales_app/features/backoffice/presentation/backoffice_detail_screen.dart';
import 'package:sales_app/features/backoffice/presentation/backoffice_inbox_screen.dart';
import 'package:sales_app/features/submissions/presentation/submission_detail_screen.dart';
import 'package:sales_app/features/submissions/presentation/submission_editor_screen.dart';
import 'package:sales_app/features/submissions/presentation/submission_list_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('submission list renders API rows', (tester) async {
    _desktop(tester);
    final api = _api(
      (request) => _json({
        'data': [_submission(summary: true)],
        'meta': _meta(totalItems: 1),
      }),
    );
    addTearDown(api.close);

    await _pump(tester, api, const SubmissionListScreen());

    expect(find.text('Pengajuan Saya'), findsOneWidget);
    expect(find.text('Program September'), findsOneWidget);
    expect(find.text('PRG-2026-0001'), findsOneWidget);
  });

  testWidgets('editor renders API data and opens the upload picker', (
    tester,
  ) async {
    _desktop(tester);
    final picker = _CancelingFilePicker();
    FilePicker.platform = picker;
    final api = _api((request) {
      final path = request.url.path;
      if (path.endsWith('/policy')) {
        return _json({'data': _policy(), 'meta': _meta()});
      }
      if (path.endsWith('/reviewer-options')) {
        return _json({'data': [], 'meta': _meta()});
      }
      if (path.endsWith('/master-data/locations')) {
        return _json({
          'data': [
            {'id': 'loc_1', 'name': 'BSD'},
          ],
          'meta': _meta(),
        });
      }
      if (path.endsWith('/master-data/program-types')) {
        return _json({
          'data': [
            {'id': 'typ_1', 'name': 'Bundling'},
          ],
          'meta': _meta(),
        });
      }
      return _json({
        'data': _submission(actions: const ['update', 'uploadAttachment']),
        'meta': _meta(),
      });
    });
    addTearDown(api.close);

    await _pump(
      tester,
      api,
      const SubmissionEditorScreen(submissionId: 'sub_1'),
    );

    expect(find.text('Form Pengajuan Program'), findsOneWidget);
    expect(find.text('Program September'), findsOneWidget);
    final upload = find.text('Unggah lampiran');
    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -1200),
      1800,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(upload);
    await tester.tap(upload);
    await tester.pump();
    expect(picker.calls, 1);
  });

  testWidgets('submission detail confirms and submits a draft', (tester) async {
    _desktop(tester);
    var submitted = false;
    final api = _api((request) {
      if (request.url.path.endsWith('/policy')) {
        return _json({'data': _policy(), 'meta': _meta()});
      }
      if (request.method == 'POST') {
        submitted = true;
        return _json({
          'data': _submission(status: 'pendingChecker', actions: const []),
          'meta': _meta(),
        });
      }
      return _json({
        'data': _submission(actions: const ['submit']),
        'meta': _meta(),
      });
    });
    addTearDown(api.close);

    await _pump(
      tester,
      api,
      const SubmissionDetailScreen(submissionId: 'sub_1'),
    );
    final submit = find.text('Kirim pengajuan');
    await tester.scrollUntilVisible(submit, 500, scrollable: _listScrollable());
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Kirim pengajuan?'), findsOneWidget);
    await tester.tap(find.text('Ya, kirim'));
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
    expect(find.text('Pengajuan berhasil dikirim.'), findsOneWidget);
  });

  testWidgets('backoffice inbox renders an actionable API row', (tester) async {
    _desktop(tester);
    final api = _api(
      (request) => _json({
        'data': [
          _submission(
            summary: true,
            backoffice: true,
            status: 'pendingChecker',
          ),
        ],
        'meta': _meta(totalItems: 1),
      }),
    );
    addTearDown(api.close);

    await _pump(tester, api, const BackofficeInboxScreen());

    expect(find.text('Inbox reviewer'), findsOneWidget);
    expect(find.text('Program September'), findsOneWidget);
    expect(find.text('Checker'), findsOneWidget);
  });

  testWidgets('backoffice detail opens approve and reject dialogs', (
    tester,
  ) async {
    _desktop(tester);
    final api = _api(
      (request) => _json({
        'data': _submission(
          backoffice: true,
          status: 'pendingChecker',
          actions: const ['approve', 'reject'],
        ),
        'meta': _meta(),
      }),
    );
    addTearDown(api.close);

    await _pump(
      tester,
      api,
      const BackofficeDetailScreen(submissionId: 'sub_1'),
    );
    final approve = find.text('Approve');
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();
    expect(find.text('Setujui pengajuan'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    final reject = find.text('Not Approved');
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await tester.pumpAndSettle();
    expect(find.text('Tolak pengajuan'), findsOneWidget);
  });

  for (final viewport in const {
    'mobile': Size(390, 844),
    'tablet': Size(768, 1024),
    'desktop': Size(1440, 1000),
  }.entries) {
    testWidgets('${viewport.key} layouts render without overflow', (
      tester,
    ) async {
      _setViewport(tester, viewport.value);
      final api = _api((request) {
        final path = request.url.path;
        if (path.endsWith('/policy')) {
          return _json({'data': _policy(), 'meta': _meta()});
        }
        if (path == '/api/v1/backoffice/program-submissions/sub_1') {
          return _json({
            'data': _submission(
              backoffice: true,
              status: 'pendingChecker',
              actions: const ['approve', 'reject', 'downloadPdf'],
            ),
            'meta': _meta(),
          });
        }
        if (path == '/api/v1/backoffice/program-submissions') {
          return _json({
            'data': [
              _submission(
                summary: true,
                backoffice: true,
                status: 'pendingChecker',
              ),
            ],
            'meta': _meta(totalItems: 1),
          });
        }
        if (path == '/api/v1/program-submissions/sub_1') {
          return _json({
            'data': _submission(actions: const ['submit', 'downloadPdf']),
            'meta': _meta(),
          });
        }
        return _json({
          'data': [_submission(summary: true)],
          'meta': _meta(totalItems: 1),
        });
      });
      addTearDown(api.close);

      for (final screen in const <Widget>[
        SubmissionListScreen(),
        SubmissionDetailScreen(submissionId: 'sub_1'),
        BackofficeInboxScreen(),
        BackofficeDetailScreen(submissionId: 'sub_1'),
      ]) {
        await _pump(tester, api, screen);
        if (screen is BackofficeInboxScreen) {
          final filterCard = find
              .ancestor(of: find.text('Filter'), matching: find.byType(Card))
              .first;
          expect(tester.getSize(filterCard).height, lessThan(260));
        }
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} overflowed at ${viewport.value}',
        );
      }
    });
  }
}

Finder _listScrollable() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

void _desktop(WidgetTester tester) {
  _setViewport(tester, const Size(1280, 900));
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(WidgetTester tester, ApiClient api, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ApiClient _api(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      baseUrl: Uri.parse('https://api.example.com/api/v1'),
      client: MockClient(handler),
    );

Future<http.Response> _json(Map<String, dynamic> body) async =>
    http.Response(jsonEncode(body), 200);

Map<String, dynamic> _meta({int totalItems = 0}) => {
  'requestId': 'req_widget',
  'page': 1,
  'pageSize': 20,
  'totalItems': totalItems,
  'totalPages': totalItems == 0 ? 0 : 1,
  'hasNextPage': false,
};

Map<String, dynamic> _policy() => {
  'policyVersion': 'policy-v1',
  'checker': {
    'id': 'usr_checker',
    'fullName': 'Andi Setiawan',
    'jobTitle': 'Supervisor Sales',
  },
  'minAcknowledgers': 1,
  'maxAcknowledgers': 2,
  'minApprovers': 1,
  'maxApprovers': 3,
  'allowedAttachmentExtensions': ['pdf'],
  'maxAttachmentBytes': 5000000,
  'routingConfigured': true,
};

Map<String, dynamic> _submission({
  String status = 'draft',
  List<String> actions = const ['update'],
  bool summary = false,
  bool backoffice = false,
}) {
  final data = <String, dynamic>{
    'id': 'sub_1',
    'programNumber': 'PRG-2026-0001',
    'programName': 'Program September',
    'programType': {'id': 'typ_1', 'name': 'Bundling'},
    'locations': [
      {'id': 'loc_1', 'name': 'BSD'},
    ],
    'periodStart': '2026-09-01',
    'periodEnd': '2026-09-30',
    'estimatedCost': {'currency': 'IDR', 'amount': '1000000.00'},
    'status': status,
    'currentStage': status == 'pendingChecker' ? 'checker' : null,
    'version': 5,
    if (backoffice)
      'owner': {
        'id': 'usr_owner',
        'fullName': 'Rizky Pratama',
        'jobTitle': 'Sales Executive',
      },
    'submittedAt': '2026-09-01T03:00:00Z',
    'myActiveTaskIds': status == 'pendingChecker' ? ['tsk_1'] : [],
  };
  if (!summary) {
    data.addAll({
      'reviewPlan': {
        'checker': {
          'id': 'usr_checker',
          'fullName': 'Andi Setiawan',
          'jobTitle': 'Supervisor Sales',
        },
        'acknowledgers': [],
        'approvers': [],
      },
      'reviewTasks': status == 'pendingChecker'
          ? [
              {
                'id': 'tsk_1',
                'stage': 'checker',
                'reviewer': {'id': 'usr_checker', 'fullName': 'Andi Setiawan'},
                'position': 1,
                'status': 'ready',
                'decidedAt': null,
                'note': null,
              },
            ]
          : [],
      'attachments': [],
      'allowedActions': actions,
      'submissionIssues': [],
    });
  }
  return data;
}

class _CancelingFilePicker extends FilePicker {
  int calls = 0;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    calls++;
    return null;
  }
}
