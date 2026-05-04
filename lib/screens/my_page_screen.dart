import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../app/routes/app_routes.dart';
import '../controllers/my_page_controller.dart';
import '../core/theme.dart';
import '../models/group_model.dart';
import '../models/tracked_route.dart';
import '../models/user_stats.dart';

class MyPageScreen extends GetView<MyPageController> {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('my_page_title'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'settings'.tr,
            onPressed: () => Get.toNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: Obx(() => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // ── Profile header ─────────────────────────────────────────
              _ProfileHeader(controller: controller),

              // ── Stats row ──────────────────────────────────────────────
              if (controller.myStats.value != null)
                _StatsRow(stats: controller.myStats.value!),

              const SizedBox(height: 20),

              // ── My Completed Runs ──────────────────────────────────────
              _SectionHeader(
                title: 'my_completed_runs'.tr,
                onSeeAll: () => Get.toNamed(AppRoutes.myRoutes),
              ),
              const SizedBox(height: 10),
              _CompletedRunsSection(controller: controller),

              const SizedBox(height: 24),

              // ── My Clubs ───────────────────────────────────────────────
              _SectionHeader(title: 'my_clubs'.tr),
              const SizedBox(height: 10),
              _MyClubsSection(controller: controller),

              const SizedBox(height: 24),

              // ── Action cards ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'explore'.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _ActionCard(
                      icon: Icons.emoji_events,
                      label: 'leaderboard'.tr,
                      color: const Color(0xFFFFB300),
                      onTap: () => Get.toNamed(AppRoutes.leaderboard),
                    ),
                    _ActionCard(
                      icon: Icons.map_outlined,
                      label: 'my_routes'.tr,
                      color: AppTheme.primary,
                      onTap: () => Get.toNamed(AppRoutes.myRoutes),
                    )
                  ],
                ),
              ),

              // ── Footer ─────────────────────────────────────────────────
              const SizedBox(height: 32),
              const _AppFooter(),
            ],
          )),
    );
  }
}

// ── App footer ────────────────────────────────────────────────────────────────

class _AppFooter extends StatelessWidget {
  const _AppFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_run,
                  color: AppTheme.primary, size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'RunMate',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'app_version_label'.tr,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'developed_by'.tr,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'see_all'.tr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Completed runs hex section ────────────────────────────────────────────────

class _CompletedRunsSection extends StatelessWidget {
  final MyPageController controller;
  const _CompletedRunsSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final refs = controller.routeRefs;
    final pending = controller.localPendingNames;
    if (refs.isEmpty && pending.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _EmptyHexPlaceholder(
          icon: Icons.directions_run,
          label: 'no_runs_yet'.tr,
        ),
      );
    }
    final tiles = <Widget>[
      ...pending.map((name) => _LocalRouteHexTile(fileName: name)),
      ...refs.map((ref) => _RouteHexTile(ref: ref)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _HexGrid(children: tiles.take(6).toList()),
    );
  }
}

// ── My clubs hex section ──────────────────────────────────────────────────────

class _MyClubsSection extends StatelessWidget {
  final MyPageController controller;
  const _MyClubsSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final groups = controller.myGroups;
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _EmptyHexPlaceholder(
          icon: Icons.group_outlined,
          label: 'no_clubs_yet'.tr,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _HexGrid(
        children: groups.take(6).map((g) => _GroupHexTile(group: g)).toList(),
      ),
    );
  }
}

// ── Hex grid (3 top + 3 bottom honeycomb) ────────────────────────────────────

class _HexGrid extends StatelessWidget {
  final List<Widget> children;
  const _HexGrid({required this.children});

  static const _hexW = 80.0;
  static const _hexH = 88.0;
  static const _gap = 4.0;
  static const _step = _hexW + _gap; // 84
  static const _rowOffset = _hexH * 0.52; // ~46

  @override
  Widget build(BuildContext context) {
    final items = children.take(6).toList();
    // Row 1: indices 0,1,2 — y=0, x = col*step
    // Row 2: indices 3,4,5 — y=rowOffset, x = col*step + step/2
    const totalW = 3 * _step - _gap + _step / 2;
    const totalH = _hexH + _rowOffset;

    return SizedBox(
      width: totalW,
      height: totalH,
      child: Stack(
        children: [
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: i < 3 ? i * _step : (i - 3) * _step + _step / 2,
              top: i < 3 ? 0 : _rowOffset,
              width: _hexW,
              height: _hexH,
              child: items[i],
            ),
        ],
      ),
    );
  }
}

// ── Hexagon clipper ───────────────────────────────────────────────────────────

class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(_) => false;
}

// ── Route hex tile ────────────────────────────────────────────────────────────

class _RouteHexTile extends StatelessWidget {
  final fs.Reference ref;
  const _RouteHexTile({required this.ref});

  @override
  Widget build(BuildContext context) {
    final eventName = TrackedRoute.parseEventFromFileName(ref.name);
    final date = TrackedRoute.parseDateTimeFromFileName(ref.name);
    final dateLabel = date.year > 2000
        ? '${date.month}/${date.day}'
        : '';
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.routeDetail, arguments: ref.fullPath),
      child: ClipPath(
        clipper: _HexClipper(),
        child: Container(
          color: AppTheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_run,
                    color: AppTheme.primary.withValues(alpha: 0.7), size: 24),
                const SizedBox(height: 3),
                Text(
                  eventName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary.withValues(alpha: 0.85),
                  ),
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 6.5, color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Local (pending-sync) hex tile ─────────────────────────────────────────────

class _LocalRouteHexTile extends StatelessWidget {
  final String fileName;
  const _LocalRouteHexTile({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        Get.toNamed(AppRoutes.routeDetail,
            arguments: 'local/$uid/$fileName');
      },
      child: ClipPath(
        clipper: _HexClipper(),
        child: Container(
          color: Colors.orange.withValues(alpha: 0.1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_run,
                      color: Colors.orange.withValues(alpha: 0.7), size: 28),
                  const SizedBox(height: 4),
                  Text(
                    'pending_sync'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 7, color: Colors.deepOrange),
                  ),
                ],
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle),
                  child: const Icon(Icons.cloud_upload_outlined,
                      size: 9, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Group hex tile ────────────────────────────────────────────────────────────

class _GroupHexTile extends StatefulWidget {
  final GroupModel group;
  const _GroupHexTile({required this.group});

  @override
  State<_GroupHexTile> createState() => _GroupHexTileState();
}

class _GroupHexTileState extends State<_GroupHexTile> {
  String? _bannerUrl;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('events/${widget.group.eventId}/bannerUrl')
          .get();
      final url = snap.value as String? ?? '';
      if (url.isNotEmpty && mounted) setState(() => _bannerUrl = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.groupDetail, arguments: widget.group),
      child: ClipPath(
        clipper: _HexClipper(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Banner image or fallback colour
            if (_bannerUrl != null)
              Image.network(_bannerUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackBg())
            else
              _fallbackBg(),
            // Dark gradient overlay so text is readable
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
            // Group name + member count at bottom
            Positioned(
              bottom: 10,
              left: 4,
              right: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.group.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${widget.group.memberCount} ${'members'.tr}',
                    style: TextStyle(
                      fontSize: 6.5,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackBg() => Container(color: AppTheme.primary.withValues(alpha: 0.15));
}

// ── Empty hex placeholder ─────────────────────────────────────────────────────

class _EmptyHexPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyHexPlaceholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final MyPageController controller;
  const _ProfileHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final photoUrl = controller.photoUrlObs.value;
      final name = controller.displayName;
      final email = controller.user?.email ?? '';
      final uploading = controller.isUploading.value;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with upload overlay
            GestureDetector(
              onTap: uploading ? null : controller.uploadProfileImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          )
                        : null,
                  ),
                  if (uploading)
                    const Positioned.fill(
                      child: CircleAvatar(
                        backgroundColor: Colors.black38,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Name + email + edit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _editName(context, name),
                        child: const Icon(Icons.edit_outlined,
                            size: 18, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  if (email.isNotEmpty)
                    Text(email,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('runner'.tr,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  void _editName(BuildContext context, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    Get.dialog(
      AlertDialog(
        title: Text('edit_name'.tr),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: 'your_name'.tr),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              controller.updateDisplayName(ctrl.text);
            },
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final UserStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statCol(stats.distanceStr, 'total_distance'.tr),
          _divider(),
          _statCol('${stats.totalRuns}', 'total_runs'.tr),
          _divider(),
          _statCol(stats.avgPaceStr, 'avg_pace'.tr),
        ],
      ),
    );
  }

  Widget _statCol(String value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.75))),
        ],
      );

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: Colors.white.withValues(alpha: 0.3),
      );
}

// ── Action card ───────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
