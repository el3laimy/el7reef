/// خدمة التحقق من الموعد النهائي للانتقالات (Transfer Deadline)
/// لضمان نزاهة اللعبة ومنع أي مدرب من تغيير تشكيلته بعد انطلاق مباريات الجولة.
class TransferDeadlineService {
  /// يتحقق مما إذا كان الوقت الحالي قد تجاوز موعد إغلاق الميركاتو
  ///
  /// [currentDateTime]: الوقت المراد فحصه (عادةً الوقت الحالي أثناء الطلب).
  /// [firstMatchKickoffTime]: موعد انطلاق أول صافرة في أول مباراة تخص هذه الجولة.
  /// [bufferMinutes]: عدد الدقائق التي يتم إضافتها أز خصمها. 
  /// (مثلاً في الفانتازي الكلاسيكي يُغلق المتجر قبل ساعة، يعني تمرير `-60`).
  ///
  /// يعود بـ [true] إذا تم إغلاق الانتقالات، ولا يسمح بالتعديل.
  static bool isDeadlinePassed({
    required DateTime currentDateTime,
    required DateTime firstMatchKickoffTime,
    int bufferMinutes = 0,
  }) {
    // حساب موعد الإغلاق الفعلي (وقت المباراة + أو - فترة السماحيات)
    final DateTime actualDeadline = firstMatchKickoffTime.add(Duration(minutes: bufferMinutes));
    
    // يعتبر الميركاتو مغلقاً إذا كان الوقت الحالي هو نفسه أو بعد موعد الإغلاق المخصص 
    return currentDateTime.isAfter(actualDeadline) || currentDateTime.isAtSameMomentAs(actualDeadline);
  }

  /// إرجاع نص مخصص للمستخدم لعرضه في لوحة التحكم (الـ Dashboard)
  /// يخبره بالوقت المتبقي بدقة قبل الإغلاق.
  static String getTimeRemainingMessage(DateTime currentDateTime, DateTime firstMatchKickoffTime, {int bufferMinutes = 0}) {
    final DateTime actualDeadline = firstMatchKickoffTime.add(Duration(minutes: bufferMinutes));
    
    if (currentDateTime.isAfter(actualDeadline) || currentDateTime.isAtSameMomentAs(actualDeadline)) {
      return 'تم الإغلاق (Deadline Passed)';
    }

    final Duration difference = actualDeadline.difference(currentDateTime);
    
    if (difference.inDays > 0) {
      return 'يغلق بعد ${difference.inDays} أيام و ${difference.inHours % 24} ساعات';
    } else if (difference.inHours > 0) {
      return 'يغلق بعد ${difference.inHours} ساعات و ${difference.inMinutes % 60} دقيقة';
    } else {
      return 'أسرع! يغلق المتجر بعد ${difference.inMinutes} دقيقة!';
    }
  }
}
