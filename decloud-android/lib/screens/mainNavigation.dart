import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/auth_notifier.dart';

import 'home/homeScreen.dart';
import 'upload/uploadScreen.dart';
import 'files/filesScreen.dart';
import 'wallet/wallet_gate_screen.dart';
import '../widgets/animated_bottom_bar.dart';
import '../screens/profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  static const _walletTabIndex = 3;

  int _selectedIndex = 2;
  final _authNotifier = AuthNotifier();
  String? _prevWalletAddress;

  // ORDER MUST MATCH BottomNavigationBar items
  final List<Widget> _screens = [
    FilesScreen(),
    UploadScreen(),
    HomeScreen(),
    WalletGateScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _prevWalletAddress = _authNotifier.walletAddress;
    _authNotifier.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final current = _authNotifier.walletAddress;
    if (_prevWalletAddress == null && current != null) {
      // Wallet just got connected — switch to Wallet tab
      setState(() => _selectedIndex = _walletTabIndex);
    }
    _prevWalletAddress = current;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,

      // Keeps screen state alive
      body: IndexedStack(index: _selectedIndex, children: _screens),

      bottomNavigationBar: AnimatedBottomBar(
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,

          selectedItemColor: Colors.white,
          unselectedItemColor: const Color.fromARGB(255, 0, 0, 0),

          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),

          onTap: (index) {
            setState(() => _selectedIndex = index);
          },

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_open_sharp),
              activeIcon: Icon(Icons.folder_open),
              label: 'Files',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.cloud_upload_outlined),
              activeIcon: Icon(Icons.cloud_upload_outlined),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.wallet_outlined),
              activeIcon: Icon(Icons.wallet),
              label: 'Wallet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.supervised_user_circle_outlined),
              activeIcon: Icon(Icons.supervised_user_circle_outlined),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
