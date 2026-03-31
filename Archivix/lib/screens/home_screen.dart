import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed/feed_screen.dart';
import 'search_screen.dart';
import 'submit_screen_tabs.dart';
import 'settings_screen.dart';
import '../../core/constants/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  void _navigateToSettings() {
    setState(() {
      _currentIndex = 3; // Settings tab index
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      FeedScreen(onNavigateToSettings: _navigateToSettings),
      const SearchScreen(),
      const SubmitScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.slatePrimary,
          unselectedItemColor: AppColors.textSubtle,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.article),
              label: 'Feed',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: 'Submit',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}