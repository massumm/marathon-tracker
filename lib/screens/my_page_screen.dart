import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/my_page_controller.dart';
import '../../core/theme.dart';
import '../../models/group_model.dart';
import '../../models/user_stats.dart';

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
      body: MyPageBody(controller: controller),
    );
  }
}

/// Public widget — used by both MyPageScreen and the home bottom sheet.
class MyPageBody extends StatelessWidget {
  final MyPageController controller;
  final ScrollController? scrollController;

  const MyPageBody({
    super.key,
    required this.controller,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView(
          controller: scrollController,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          children: [
            // ── Profile header ───────────────────────────────────────
            _ProfileHeader(controller: controller),

            // ── Stats row ────────────────────────────────────────────
            if (controller.myStats.value != null)
              _StatsRow(stats: controller.myStats.value!),

            const SizedBox(height: 20),

            // ── My Completed Runs ─────────────────────────────────────
            _SectionHeader(
              title: 'my_completed_runs'.tr,
              onSeeAll: () => Get.toNamed(AppRoutes.myRoutes),
            ),
            const SizedBox(height: 10),
            _CompletedRunsSection(controller: controller),

            const SizedBox(height: 24),

            // ── My Clubs ──────────────────────────────────────────────
            _SectionHeader(title: 'my_clubs'.tr),
            const SizedBox(height: 10),
            _MyClubsSection(controller: controller),

            const SizedBox(height: 24),

            // ── Action cards ──────────────────────────────────────────
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
                  ),
                ],
              ),
            ),

            // ── Footer ───────────────────────────────────────────────
        
            const _AppFooter(),
          ],
        ));
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
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (_, snap) => Text(
            snap.hasData
                ? '${('version'.tr)} ${snap.data!.version} (${snap.data!.buildNumber})'
                : 'version'.tr,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
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
    // Own Obx so the grid reacts to routeRefs/localPendingNames changes —
    // the parent Obx only tracks myStats and won't rebuild this otherwise.
    return Obx(() {
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
    });
  }
}

// ── My clubs card section ─────────────────────────────────────────────────────

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
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _GroupCard(group: groups[i]),
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
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.routeDetail, arguments: ref.fullPath),
      child: ClipPath(
        clipper: _HexClipper(),
        child: Container(
          color: AppTheme.primary.withValues(alpha: 0.08),
          child: Center(
            child: Icon(Icons.directions_run,
                color: AppTheme.primary.withValues(alpha: 0.7), size: 30),
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

// ── Group card (horizontal list item) ────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  final GroupModel group;
  const _GroupCard({required this.group});

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  String? _bannerUrl;
  String _eventName = '';

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('events/${widget.group.eventId}')
          .get();
      if (!mounted) return;
      final data = snap.value as Map<dynamic, dynamic>?;
      if (data == null) return;
      final banner = data['bannerUrl'] as String? ?? '';
      final name = data['name'] as String? ?? '';
      setState(() {
        if (banner.isNotEmpty) _bannerUrl = banner;
        if (name.isNotEmpty) _eventName = name;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.groupDetail, arguments: widget.group),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Event banner ──────────────────────────────────────────
            SizedBox(
              height: 88,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_bannerUrl != null)
                    CachedNetworkImage(
                      imageUrl: _bannerUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _bannerFallback(),
                      errorWidget: (_, __, ___) => _bannerFallback(),
                    )
                  else
                    _bannerFallback(),
                  // gradient so text is readable
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black45],
                      ),
                    ),
                  ),
                  if (_eventName.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 8,
                      right: 8,
                      child: Text(
                        _eventName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Club info ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group_outlined,
                          size: 12, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.group.memberCount} ${'members'.tr}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
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

  Widget _bannerFallback() => Container(
        color: AppTheme.primary.withValues(alpha: 0.12),
        child: const Center(
          child: Icon(Icons.emoji_events_outlined,
              color: AppTheme.primary, size: 32),
        ),
      );
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
                    child: photoUrl.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: photoUrl,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                              errorWidget: (_, __, ___) => Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
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
                      if (controller.myStats.value?.gender != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: controller.myStats.value!.gender == 0
                                ? Colors.blue.withValues(alpha: 0.1)
                                : Colors.pink.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            controller.myStats.value!.gender == 0
                                ? Icons.male
                                : Icons.female,
                            size: 15,
                            color: controller.myStats.value!.gender == 0
                                ? Colors.blue.shade400
                                : Colors.pink.shade300,
                          ),
                        ),
                      ],
                    ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Top highlight bar ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, Color(0xFFFF9A5C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _highlightStat(Icons.straighten_rounded,
                    stats.distanceStr, 'total_distance'.tr),
                _vDivider(),
                _highlightStat(Icons.directions_run_rounded,
                    '${stats.totalRuns}', 'total_runs'.tr),
                _vDivider(),
                _highlightStat(Icons.timer_outlined,
                    stats.timeStr, 'total_time'.tr),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Secondary stats grid ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.speed_rounded,
                  value: stats.avgPaceStr,
                  label: 'avg_pace'.tr,
                  color: const Color(0xFF5C7AFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  icon: Icons.local_fire_department_rounded,
                  value: stats.caloriesStr,
                  label: 'total_calories'.tr,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  icon: Icons.directions_walk_rounded,
                  value: stats.stepsStr,
                  label: 'total_steps'.tr,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _highlightStat(IconData icon, String value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500)),
        ],
      );

  Widget _vDivider() => Container(
        width: 1, height: 36, color: Colors.white.withValues(alpha: 0.3));

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.2)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
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
