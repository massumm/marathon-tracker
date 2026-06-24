import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../models/user_stats.dart';
import '../../services/user_stats_service.dart';
import '../../widgets/user_avatar.dart';

// Premium dark leaderboard palette.
const _bg = Color(0xFF0E0D0F);
const _card = Color(0xFF1C1A1D);
const _gold = Color(0xFFFFC24B);
const _silver = Color(0xFFC2CBD2);
const _bronze = Color(0xFFD08A57);
const _muted = Color(0xFF8A8590);

Color _medalColor(int rank) => rank == 1
    ? _gold
    : rank == 2
        ? _silver
        : rank == 3
            ? _bronze
            : _muted;

String _tierLabel(int rank) => rank <= 3
    ? 'Podium runner'
    : rank <= 10
        ? 'Top 10 challenger'
        : 'Every run counts';

const double _rowExtent = 84;

class DailyChallengeLeaderboardScreen extends StatefulWidget {
  const DailyChallengeLeaderboardScreen({super.key});

  @override
  State<DailyChallengeLeaderboardScreen> createState() =>
      _DailyChallengeLeaderboardScreenState();
}

class _DailyChallengeLeaderboardScreenState
    extends State<DailyChallengeLeaderboardScreen> {
  final _scrollController = ScrollController();
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToMyRank(int index) {
    if (!_scrollController.hasClients) return;
    final target = (index * _rowExtent)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(target,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: Text('daily_challenge_leaderboard'.tr)),
      body: StreamBuilder<List<UserStats>>(
        stream: UserStatsService.instance.watchDailyChallengeLeaderboard(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_outlined,
                      size: 72, color: _muted),
                  const SizedBox(height: 16),
                  Text('no_daily_challenge_runs'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: _muted)),
                ],
              ),
            );
          }

          final top3 = entries.take(3).toList();
          final meIndex = entries.indexWhere((e) => e.uid == _uid);
          final me = meIndex >= 0 ? entries[meIndex] : null;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  // +2 leading items: podium and the "RANKINGS" header.
                  itemCount: entries.length + 2,
                  itemBuilder: (_, i) {
                    if (i == 0) return _Podium(top3: top3);
                    if (i == 1) return _RankingsHeader(total: entries.length);
                    return SizedBox(
                      height: _rowExtent,
                      child: _RankRow(
                        stats: entries[i - 2],
                        isMe: entries[i - 2].uid == _uid,
                      ),
                    );
                  },
                ),
              ),
              if (me != null)
                _YouBar(
                  me: me,
                  total: entries.length,
                  // index in the ListView (offset by the 2 leading items)
                  onJump: () => _jumpToMyRank(meIndex + 2),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Podium (top 3) ──────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<UserStats> top3;
  const _Podium({required this.top3});

  @override
  Widget build(BuildContext context) {
    UserStats? at(int rank) => top3.firstWhereOrNull((e) => e.rank == rank);
    final first = at(1);
    final second = at(2);
    final third = at(3);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
              child: second != null
                  ? _PodiumItem(stats: second)
                  : const SizedBox()),
          Expanded(
              child: first != null
                  ? _PodiumItem(stats: first, isFirst: true)
                  : const SizedBox()),
          Expanded(
              child:
                  third != null ? _PodiumItem(stats: third) : const SizedBox()),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final UserStats stats;
  final bool isFirst;
  const _PodiumItem({required this.stats, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    final color = _medalColor(stats.rank);
    final avatarSize = isFirst ? 92.0 : 70.0;
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.userProfile, arguments: stats.uid),
      child: Column(
        children: [
          if (isFirst)
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text('🏆', style: TextStyle(fontSize: 24)),
            ),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
                child: UserAvatar(
                    label: stats.label,
                    photoUrl: stats.photoUrl,
                    size: avatarSize),
              ),
              Positioned(
                top: -10,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 2),
                  ),
                  child: Text('${stats.rank}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.black)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            stats.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                _statPill(
                    stats.dailyDistanceKm.toStringAsFixed(0), 'km', color),
                const SizedBox(height: 6),
                _statPill('${stats.dailyRuns}', 'runs', Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String value, String unit, Color valueColor) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(
            text: value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: valueColor)),
        TextSpan(
            text: ' $unit',
            style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
    );
  }
}

// ── Rankings header ───────────────────────────────────────────────────────────

class _RankingsHeader extends StatelessWidget {
  final int total;
  const _RankingsHeader({required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('RANKINGS',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Colors.white)),
          Text('$total runners',
              style: const TextStyle(fontSize: 13, color: _muted)),
        ],
      ),
    );
  }
}

// ── Ranking row ─────────────────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  final UserStats stats;
  final bool isMe;
  const _RankRow({required this.stats, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    final color = _medalColor(stats.rank);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: isMe ? _gold.withValues(alpha: 0.12) : _card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Get.toNamed(AppRoutes.userProfile, arguments: stats.uid),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text('${stats.rank}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: stats.rank <= 3 ? color : Colors.white)),
                ),
                const SizedBox(width: 8),
                UserAvatar(
                    label: stats.label, photoUrl: stats.photoUrl, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stats.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(_tierLabel(stats.rank),
                          style: const TextStyle(fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                            text: stats.dailyDistanceKm.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const TextSpan(
                            text: ' km',
                            style: TextStyle(fontSize: 11, color: _muted)),
                      ]),
                    ),
                    const SizedBox(height: 2),
                    Text('${stats.dailyRuns} runs',
                        style: const TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pinned "You" bar ──────────────────────────────────────────────────────────

class _YouBar extends StatelessWidget {
  final UserStats me;
  final int total;
  final VoidCallback onJump;
  const _YouBar({required this.me, required this.total, required this.onJump});

  @override
  Widget build(BuildContext context) {
    final percent =
        total > 0 ? ((me.rank / total) * 100).ceil().clamp(1, 100) : 100;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _gold.withValues(alpha: 0.6)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('#${me.rank}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _gold)),
              const SizedBox(width: 14),
              UserAvatar(label: me.label, photoUrl: me.photoUrl, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${'you_label'.tr} · ${me.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(_tierLabel(me.rank),
                        style: const TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: me.dailyDistanceKm.toStringAsFixed(2),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _gold)),
                      const TextSpan(
                          text: ' km',
                          style: TextStyle(fontSize: 11, color: _muted)),
                    ]),
                  ),
                  const SizedBox(height: 2),
                  Text('${me.dailyRuns} runs',
                      style: const TextStyle(fontSize: 12, color: _muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up,
                      size: 16, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 6),
                  Text('Top $percent% runner',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4CAF50))),
                ],
              ),
              GestureDetector(
                onTap: onJump,
                child: const Row(
                  children: [
                    Icon(Icons.keyboard_arrow_up, size: 18, color: _muted),
                    SizedBox(width: 4),
                    Text('Jump to my rank',
                        style: TextStyle(fontSize: 13, color: _muted)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
