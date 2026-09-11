import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app/app/router/app_router.dart';

void main() {
  group('role route guard', () {
    test('submitter can only enter the submission area', () {
      expect(roleRedirectFor('/submissions/sub_1', ['submitter']), isNull);
      expect(roleRedirectFor('/backoffice', ['submitter']), '/submissions');
    });

    for (final role in ['checker', 'acknowledger', 'approver']) {
      test('$role can only enter the reviewer area', () {
        expect(roleRedirectFor('/backoffice/history', [role]), isNull);
        expect(roleRedirectFor('/submissions', [role]), '/backoffice');
      });
    }

    test('multi-role account can enter both application areas', () {
      const roles = ['submitter', 'approver'];
      expect(roleRedirectFor('/submissions', roles), isNull);
      expect(roleRedirectFor('/backoffice', roles), isNull);
    });

    test('roleless account remains on the neutral workspace', () {
      expect(roleRedirectFor('/', const []), isNull);
      expect(roleRedirectFor('/backoffice', const []), '/');
    });
  });
}
