import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_models.dart';
import '../data/mock_admin_data.dart';
import '../theme/admin_colors.dart';

class AdminService extends ChangeNotifier {
  int _selectedTabIndex = 0;
  bool _isLiveFirebase = false;
  bool _isLoading = false;
  bool _isDarkMode = true;

  DashboardMetrics _metrics = MockAdminData.defaultMetrics;
  List<UserAnalytics> _users = List.from(MockAdminData.defaultUsers);
  final List<CrashReport> _crashes = List.from(MockAdminData.defaultCrashes);
  final List<PushBroadcast> _broadcasts = List.from(MockAdminData.defaultBroadcasts);
  final List<AiSuggestion> _aiSuggestions = List.from(MockAdminData.defaultAiSuggestions);

  UserAnalytics? _preselectedUser;

  // Pre-filled broadcast draft (from AI or preselection)
  String draftTitle = '';
  String draftBody = '';
  String draftScreen = 'wishlist_add';
  String draftTarget = 'dormant';

  int get selectedTabIndex => _selectedTabIndex;
  bool get isLiveFirebase => _isLiveFirebase;
  bool get isLoading => _isLoading;
  bool get isDarkMode => _isDarkMode;
  DashboardMetrics get metrics => _metrics;
  List<UserAnalytics> get users => _users;
  List<CrashReport> get crashes => _crashes;
  List<PushBroadcast> get broadcasts => _broadcasts;
  List<AiSuggestion> get aiSuggestions => _aiSuggestions;
  UserAnalytics? get preselectedUser => _preselectedUser;

  int get activeCrashesCount => _crashes.where((c) => !c.isResolved).length;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    AdminColors.isDark = _isDarkMode;
    notifyListeners();
  }

  void selectTab(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  void selectUserForPush(UserAnalytics user) {
    _preselectedUser = user;
    draftTitle = 'Chào ${user.displayName}, bạn có món đồ nào đang cân nhắc không?';
    draftBody = 'Đừng quên chia sẻ link Shopee/Lazada vào Why I Buy để kích hoạt thời gian 48 giờ suy nghĩ nhé!';
    draftTarget = 'specific';
    draftScreen = 'wishlist_add';
    _selectedTabIndex = 2; // Jump to Push tab
    notifyListeners();
  }

  void clearPreselectedUser() {
    _preselectedUser = null;
    notifyListeners();
  }

  void applyAiSuggestionToPush(AiSuggestion item) {
    draftTitle = item.suggestedTitle;
    draftBody = item.suggestedBody;
    draftScreen = item.targetScreen;
    draftTarget = item.category == 'dormant' ? 'dormant' : 'all';
    _selectedTabIndex = 2; // Jump to Push tab
    notifyListeners();
  }

  void resolveCrash(String id) {
    final index = _crashes.indexWhere((c) => c.id == id);
    if (index != -1) {
      _crashes[index] = _crashes[index].copyWith(isResolved: true);
      _metrics = _metrics.copyWith(
        activeCrashesCount: (_metrics.activeCrashesCount - 1).clamp(0, 999),
      );
      notifyListeners();
    }
  }

  Future<void> sendBroadcast({
    required String title,
    required String body,
    required String targetAudience,
    required String targetScreen,
  }) async {
    final newBc = PushBroadcast(
      id: 'bc_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      targetAudience: targetAudience,
      targetUserId: _preselectedUser?.uid,
      targetScreen: targetScreen,
      sentAt: 'Vừa xong',
      deliveredCount: targetAudience == 'dormant'
          ? _metrics.dormantUsers
          : _metrics.activeUsersToday,
      openRate: '0.0%',
    );

    _broadcasts.insert(0, newBc);
    _preselectedUser = null;

    if (_isLiveFirebase) {
      try {
        await FirebaseFirestore.instance.collection('admin_broadcasts').add({
          'title': title,
          'body': body,
          'targetAudience': targetAudience,
          'targetScreen': targetScreen,
          'createdAt': FieldValue.serverTimestamp(),
          'source': 'flutter_web_admin',
        });
      } catch (e) {
        debugPrint('Firestore broadcast error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> toggleLiveFirebase() async {
    _isLiveFirebase = !_isLiveFirebase;
    notifyListeners();

    if (_isLiveFirebase) {
      await fetchFirebaseData();
    } else {
      _users = List.from(MockAdminData.defaultUsers);
      _metrics = MockAdminData.defaultMetrics;
      notifyListeners();
    }
  }

  Future<void> fetchFirebaseData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      if (snapshot.docs.isNotEmpty) {
        final liveUsers = snapshot.docs.map((doc) {
          final data = doc.data();
          return UserAnalytics(
            uid: doc.id,
            displayName: data['displayName'] ?? data['name'] ?? 'User ${doc.id.substring(0, 4)}',
            email: data['email'] ?? 'user_${doc.id.substring(0, 5)}@gmail.com',
            createdAt: '2026-11-03 09:00',
            lastActiveAt: '2026-11-03 15:30',
            isNewToday: true,
            isActiveToday: true,
            isDormant: false,
            totalSpending: (data['totalSpending'] as num?)?.toInt() ?? 1250000,
            wishlistCount: (data['wishlistCount'] as num?)?.toInt() ?? 2,
            purchaseCount: (data['purchaseCount'] as num?)?.toInt() ?? 3,
            monthlyBudget: (data['monthlyBudget'] as num?)?.toInt() ?? 4000000,
            device: 'Android Device',
          );
        }).toList();

        _users = liveUsers;
        _metrics = _metrics.copyWith(
          totalUsers: liveUsers.length,
          newUsersToday: liveUsers.where((u) => u.isNewToday).length,
          activeUsersToday: liveUsers.where((u) => u.isActiveToday).length,
          dormantUsers: liveUsers.where((u) => u.isDormant).length,
        );
      }
    } catch (e) {
      debugPrint('Firestore fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
