import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app/features/submissions/presentation/submission_attachment_list.dart';

void main() {
  test('maps every scan status to a distinct user-facing state', () {
    expect(AttachmentScanVisual.from('pending').label, 'Menunggu pemindaian');
    expect(AttachmentScanVisual.from('clean').label, 'Aman');
    expect(AttachmentScanVisual.from('rejected').label, 'Ditolak');
  });
}
