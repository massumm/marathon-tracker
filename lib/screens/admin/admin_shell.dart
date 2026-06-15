import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/event_model.dart';
import 'dashboard.dart';
import 'organizer_live_leaderboard_screen.dart';
import 'organizers_screen.dart';
import 'users_screen.dart';

// Allows OrganizersScreen to push into the shell's inner navigator.
class AdminShellNavigator {
  static GlobalKey<NavigatorState>? _key;
  static void _register(GlobalKey<NavigatorState> key) => _key = key;

  static void push(Widget page) {
    _key?.currentState?.push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  static void pop() => _key?.currentState?.maybePop();
}

class AdminShell extends StatefulWidget {
  final VoidCallback onSignOut;
  const AdminShell({super.key, required this.onSignOut});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selected = 0;
  // Stack of sub-page titles pushed on top of the root IndexedStack.
  // Each push into the inner navigator adds a title here; each pop removes one.
  final _titleStack = <String>[];

  final _innerNavKey = GlobalKey<NavigatorState>();

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavItem(Icons.manage_accounts_outlined, Icons.manage_accounts,
        'Organizers'),
    _NavItem(Icons.people_outline, Icons.people, 'Users'),
  ];

  @override
  void initState() {
    super.initState();
    AdminShellNavigator._register(_innerNavKey);
  }

  void _selectTab(int i) {
    while (_innerNavKey.currentState?.canPop() ?? false) {
      _innerNavKey.currentState!.pop();
    }
    setState(() {
      _selected = i;
      _titleStack.clear();
    });
  }

  void _pushPage(Widget page, String title) {
    setState(() => _titleStack.add(title));
    _innerNavKey.currentState?.push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _popPage() {
    _innerNavKey.currentState?.pop();
    setState(() {
      if (_titleStack.isNotEmpty) _titleStack.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final width = MediaQuery.of(context).size.width;
    final isCollapsed = width < 900;

    final topTitle = _titleStack.isNotEmpty
        ? _titleStack.last
        : _navItems[_selected].label;
    final canGoBack = _titleStack.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCollapsed ? 72 : 250,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1D2E),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo
                Container(
                  height: 64,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.directions_run,
                            color: Colors.white, size: 20),
                      ),
                      if (!isCollapsed) ...[
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Marathon Map',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Super Admin',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1, color: Colors.white10, thickness: 1),
                const SizedBox(height: 16),

                // Nav items
                ..._navItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isActive = _selected == i;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 2),
                    child: Material(
                      color: isActive
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _selectTab(i),
                        hoverColor: Colors.white10,
                        child: Container(
                          height: 46,
                          padding: EdgeInsets.symmetric(
                              horizontal: isCollapsed ? 0 : 14),
                          alignment: isCollapsed
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: isCollapsed
                                ? MainAxisSize.min
                                : MainAxisSize.max,
                            children: [
                              Icon(
                                isActive ? item.activeIcon : item.icon,
                                size: 20,
                                color: isActive
                                    ? AppTheme.primary
                                    : Colors.white54,
                              ),
                              if (!isCollapsed) ...[
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white60,
                                    fontSize: 14,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const Spacer(),

                // Sign-out
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.onSignOut,
                      hoverColor: Colors.red.withValues(alpha: 0.15),
                      child: Container(
                        height: 46,
                        padding: EdgeInsets.symmetric(
                            horizontal: isCollapsed ? 0 : 14),
                        alignment: isCollapsed
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: isCollapsed
                              ? MainAxisSize.min
                              : MainAxisSize.max,
                          children: [
                            const Icon(Icons.logout,
                                size: 20, color: Colors.red),
                            if (!isCollapsed) ...[
                              const SizedBox(width: 12),
                              const Text(
                                'Sign Out',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Main content area ────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (canGoBack) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: AppTheme.textPrimary),
                          tooltip: 'Back',
                          onPressed: _popPage,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        topTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (user != null) ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              user.displayName ?? 'Super Admin',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              user.email ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.15),
                          backgroundImage: user.photoURL != null
                              ? NetworkImage(user.photoURL!)
                              : null,
                          child: user.photoURL == null
                              ? Text(
                                  (user.displayName ?? user.email ?? 'S')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                    fontSize: 15,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),

                // Inner navigator — sidebar stays visible while pages push/pop
                Expanded(
                  child: Navigator(
                    key: _innerNavKey,
                    onGenerateRoute: (_) => MaterialPageRoute(
                      builder: (_) => IndexedStack(
                        index: _selected,
                        children: [
                          const AdminDashboard(),
                          OrganizersScreen(
                            onOrganizerTap: (org) {
                              _pushPage(
                                OrganizerEventsPage(
                                  organizer: org,
                                  onLeaderboardTap: (EventModel event) {
                                    _pushPage(
                                      OrganizerLiveLeaderboardScreen(
                                          event: event),
                                      'Live Leaderboard',
                                    );
                                  },
                                ),
                                'Organizer Events',
                              );
                            },
                          ),
                          const AdminUsersScreen(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
