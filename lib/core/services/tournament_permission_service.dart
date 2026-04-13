import 'package:get/get.dart';
import '../../domain/entities/tournament.dart';
import '../enums/tournament_enums.dart';

/// خدمة التحقق من صلاحيات المشرفين والمساعدين في الدورات
class TournamentPermissionService extends GetxService {
  
  /// هل يملك المستخدم الصلاحية لتعديل نتائج المباريات؟
  bool canEditResults(Tournament tournament, String userId) {
    if (tournament.organizerId == userId) return true;
    
    final role = _getActiveRole(tournament, userId);
    return role == TournamentAssistantRole.full ||
           role == TournamentAssistantRole.resultsOnly ||
           role == TournamentAssistantRole.emergency;
  }

  /// هل يملك المستخدم الصلاحية لإدارة الفرق (قبول/طرد)؟
  bool canManageTeams(Tournament tournament, String userId) {
    if (tournament.organizerId == userId) return true;
    
    final role = _getActiveRole(tournament, userId);
    return role == TournamentAssistantRole.full ||
           role == TournamentAssistantRole.emergency;
  }

  /// هل يملك المستخدم الصلاحية لتعديل إعدادات الدورة (جوائز، مقرات)؟
  bool canEditSettings(Tournament tournament, String userId) {
    if (tournament.organizerId == userId) return true;
    
    final role = _getActiveRole(tournament, userId);
    return role == TournamentAssistantRole.full ||
           role == TournamentAssistantRole.emergency;
  }

  /// هل يملك المستخدم الصلاحية لتعيين أو إزالة المساعدين؟
  /// يمكن للمنظم الرئيسي فقط أو البديل الطارئ إدارة المساعدين
  bool canAssignAssistants(Tournament tournament, String userId) {
    if (tournament.organizerId == userId) return true;
    
    final role = _getActiveRole(tournament, userId);
    // البديل الطارئ يحل محل المنظم لذلك يمتلك صلاحيات إدارة المساعدين
    return role == TournamentAssistantRole.emergency;
  }

  /// جلب الدور النشط حالياً للمستخدم. 
  /// يأخذ في الاعتبار انتهاء فترة البديل الطارئ (72 ساعة).
  TournamentAssistantRole? _getActiveRole(Tournament tournament, String userId) {
    try {
      final assistant = tournament.assistants.firstWhere((a) => a.userId == userId);
      
      // التحقق من صلاحية "البديل الطارئ" 72 ساعة
      if (assistant.role == TournamentAssistantRole.emergency) {
        if (assistant.isValidEmergency) {
          return TournamentAssistantRole.emergency;
        } else {
          // انتهت فترة الـ 72 ساعة
          return null;
        }
      }
      
      return assistant.role;
    } catch (_) {
      return null;
    }
  }
}
