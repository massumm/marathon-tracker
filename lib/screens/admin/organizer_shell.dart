import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/admin_user_model.dart';
import '../../models/event_model.dart';
import 'organizer_dashboard.dart';
import 'organizer_events_screen.dart';
import 'organizer_live_leaderboard_screen.dart';

class OrganizerShell extends StatefulWidget {
  final AdminUser organizer;
  const OrganizerShell({super.key, required this.organizer});

  @override
  State<OrganizerShell> createState() => _OrganizerShellState();
}

class _OrganizerShellState extends State<OrganizerShell> {
  int _selected = 0;
  String? _subPageTitle;

  final _innerNavKey = GlobalKey<NavigatorState>();

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavItem(Icons.event_outlined, Icons.event, 'Events'),
  ];

  void _selectTab(int i) {
    while (_innerNavKey.currentState?.canPop() ?? false) {
      _innerNavKey.currentState!.pop();
    }
    setState(() {
      _selected = i;
      _subPageTitle = null;
    });
  }

  void _pushLeaderboard(EventModel event) {
    setState(() => _subPageTitle = 'Live Leaderboard');
    _innerNavKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => OrganizerLiveLeaderboardScreen(event: event),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCollapsed = width < 900;

    final topTitle = _subPageTitle ?? _navItems[_selected].label;
    final canGoBack = _subPageTitle != null;

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
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Marathon Map',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.organizer.displayName,
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
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

                ..._navItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isActive = _selected == i && _subPageTitle == null;

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
                          onPressed: () {
                            _innerNavKey.currentState?.pop();
                            setState(() => _subPageTitle = null);
                          },
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
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.organizer.displayName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            widget.organizer.email,
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
                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                        child: Text(
                          (widget.organizer.displayName.isNotEmpty
                                  ? widget.organizer.displayName
                                  : widget.organizer.email)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Inner navigator
                Expanded(
                  child: Navigator(
                    key: _innerNavKey,
                    onGenerateRoute: (_) => MaterialPageRoute(
                      builder: (_) => IndexedStack(
                        index: _selected,
                        children: [
                          OrganizerDashboard(organizer: widget.organizer),
                          OrganizerEventsScreen(
                            organizerUid: widget.organizer.uid,
                            onLeaderboardTap: _pushLeaderboard,
                          ),
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
