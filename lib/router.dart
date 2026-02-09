import 'package:flutter/material.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';
import 'screens/camera_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'screens/tool_form_screen.dart';
import 'models/tool.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: authProvider, // Dengarkan perubahan auth

  // Logika Redirect Otomatis
  redirect: (context, state) async {
    final isAuthenticated = authProvider.isAuthenticated;

    // Cek apakah user sedang berada di halaman login
    final loggingIn = state.matchedLocation == '/login';

    // Jika tidak ada token dan tidak sedang login -> Redirect ke Login
    if (!isAuthenticated && !loggingIn) return '/login';

    // Jika ada token dan sedang mencoba akses login -> Redirect ke Home (Kamera)
    if (isAuthenticated && loggingIn) return '/';

    // Tidak ada redirect
    return null;
  },

  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // Implementasi StatefulShellRoute untuk Bottom Navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Camera (Home)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const CameraScreen(),
            ),
          ],
        ),
        // Tab 2: Inventory
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inventory',
              builder: (context, state) {
                final searchQuery = state.uri.queryParameters['q'];
                return InventoryScreen(searchQuery: searchQuery);
              },
            ),
          ],
        ),
        // Tab 3: History
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
      : super(key: key);

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Opsi A: Tombol Back kembali ke Home (Index 0) jika di tab lain
      body: PopScope(
        canPop: navigationShell.currentIndex == 0,
        onPopInvoked: (didPop) {
          if (didPop) return;
          _goBranch(0);
        },
        child: navigationShell,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _goBranch,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
