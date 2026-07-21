import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:el7reef/core/firestore/firestore_date_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads legacy millis, Timestamp, and DateTime values', () {
    final date = DateTime(2026, 7, 13, 12);

    expect(FirestoreDateAdapter.tryRead(date.millisecondsSinceEpoch), date);
    expect(FirestoreDateAdapter.tryRead(Timestamp.fromDate(date)), date);
    expect(FirestoreDateAdapter.tryRead(date), date);
    expect(FirestoreDateAdapter.tryRead('invalid'), isNull);
  });

  test('writes new values as Firestore Timestamp', () {
    final date = DateTime(2026, 7, 13, 12);

    expect(FirestoreDateAdapter.write(date).toDate(), date);
    expect(FirestoreDateAdapter.writeOptional(null), isNull);
  });
}
