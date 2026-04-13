import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../domain/entities/player.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../services/auth_service.dart';

class SearchPlayersController extends GetxController {
  final PlayerRepositoryImpl _playerRepo;
  final AuthService _authService = Get.find<AuthService>();

  SearchPlayersController(this._playerRepo);

  final TextEditingController searchController = TextEditingController();
  
  final RxList<Player> searchResults = <Player>[].obs;
  final RxBool isLoading = false.obs;
  
  Timer? _debounce;

  String? get currentUserId => _authService.currentUserId;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void onClose() {
    searchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    final query = searchController.text.trim();
    
    if (query.isEmpty) {
      searchResults.clear();
      isLoading.value = false;
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      isLoading.value = true;
      final results = await _playerRepo.searchPlayers(query);
      
      // لا تعرض المستخدم نفسه في النتائج
      final filteredResults = results.where((p) => p.id != currentUserId).toList();
      
      searchResults.value = filteredResults;
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر جلب نتائج البحث');
    } finally {
      isLoading.value = false;
    }
  }

  void clearSearch() {
    searchController.clear();
    searchResults.clear();
  }
}
