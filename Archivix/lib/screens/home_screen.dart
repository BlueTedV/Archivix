import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/services/notification_service.dart';
import 'collections_screen.dart';
import 'feed/feed_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'submit_screen_tabs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();

    // Re-check unread count whenever auth state changes (e.g. after sign-in).
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) _refreshUnreadCount();
    });
  }

  Future<void> _refreshUnreadCount() async {
    final count = await _notificationService.unreadCount();
    if (mounted) setState(() => _unreadNotifications = count);
  }

  void _navigateToSettings() {
    setState(() => _currentIndex = 4); // Settings is now index 4
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _refreshUnreadCount();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      FeedScreen(
        onNavigateToSettings: _navigateToSettings,
        onOpenNotifications: _openNotifications,
        unreadNotifications: _unreadNotifications,
      ),
      const SearchScreen(),
      const SubmitScreen(),
      const CollectionsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.slatePrimary,
          unselectedItemColor: AppColors.textSubtle,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 8,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.article),
              label: 'Feed',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: 'Submit',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.collections_bookmark_outlined),
              activeIcon: Icon(Icons.collections_bookmark),
              label: 'Collections',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
