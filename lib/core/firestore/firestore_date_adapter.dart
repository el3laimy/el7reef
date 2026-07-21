import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDateAdapter {
  const FirestoreDateAdapter._();

  static DateTime? tryRead(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  static DateTime readOr(Object? value, DateTime fallback) =>
      tryRead(value) ?? fallback;

  static Timestamp write(DateTime value) => Timestamp.fromDate(value);

  static Timestamp? writeOptional(DateTime? value) =>
      value == null ? null : write(value);
}
