import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'dashboard.dart';
import 'organizers_screen.dart';
import 'users_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selected = 0;

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavItem(Icons.manage_accounts_outlined, Icons.manage_accounts,
        'Organizers'),
    _NavItem(Icons.people_outline, Icons.people, 'Users'),
  ];

  final _pages = const [
    AdminDashboard(),
    OrganizersScreen(),
    AdminUsersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final width = MediaQuery.of(context).size.width;
    final isCollapsed = width < 900;

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
                // ── Logo area ──────────────────────────────────────────
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

                const Divider(
                    height: 1, color: Colors.white10, thickness: 1),

                const SizedBox(height: 16),

                // ── Nav items ──────────────────────────────────────────
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
                        onTap: () => setState(() => _selected = i),
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

                // ── Sign-out ───────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => FirebaseAuth.instance.signOut(),
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
                // ── Top bar ────────────────────────────────────────────
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
                      Text(
                        _navItems[_selected].label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      // User info
                      if (user != null) ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              user.displayName ?? 'Admin',
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
                                  (user.displayName ?? user.email ?? 'A')
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

                // ── Page content ───────────────────────────────────────
                Expanded(
                  child: IndexedStack(
                    index: _selected,
                    children: _pages,
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
