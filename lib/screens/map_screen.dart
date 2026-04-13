import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/map_controller.dart';
import '../core/theme.dart';
import '../models/comment_model.dart';
import '../models/event_model.dart';
import '../services/comment_service.dart';
import '../widgets/user_avatar.dart';

class MapScreen extends GetView<MapController> {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('events_title'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr,
            onPressed: controller.fetchEvents,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMsg.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('error_loading'.tr,
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: controller.fetchEvents,
                  child: Text('refresh'.tr),
                ),
              ],
            ),
          );
        }
        if (controller.events.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined,
                    size: 64, color: Color(0xFFB0BEC5)),
                const SizedBox(height: 16),
                Text('no_events'.tr,
                    style: const TextStyle(
                        fontSize: 16, color: AppTheme.textSecondary)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.fetchEvents,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: controller.events.length,
            itemBuilder: (_, i) => _EventCard(event: controller.events[i]),
          ),
        );
      }),
    );
  }
}

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatefulWidget {
  final EventModel event;
  const _EventCard({required this.event});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String? _countdown() {
    final parts = widget.event.date.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    final eventDay = DateTime(year, month, day);
    final now = DateTime.now();
    final diff = eventDay.difference(DateTime(now.year, now.month, now.day));

    if (diff.isNegative) return 'finished';
    if (diff.inDays == 0) {
      final todayDiff = eventDay.difference(now);
      if (todayDiff.isNegative) return 'finished';
      final h = todayDiff.inHours;
      final m = todayDiff.inMinutes % 60;
      if (h == 0) return '$m min remaining';
      return '${h}h ${m}m remaining';
    }
    if (diff.inDays == 1) return '1 day remaining';
    return '${diff.inDays} days remaining';
  }

  bool get _isFinished {
    final parts = widget.event.date.split('-');
    if (parts.length != 3) return false;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return false;
    final eventDay = DateTime(year, month, day + 1); // day ends at midnight
    return DateTime.now().isAfter(eventDay);
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdown();
    final finished = _isFinished;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: finished ? null : () => _showCategoryPicker(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Banner with floating title / date / place overlay ──────
            _BannerWithOverlay(event: widget.event, finished: finished),

            // ── Countdown + category row ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  if (finished) ...[
                    const Icon(Icons.flag, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'event_finished'.tr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                      ),
                    ),
                  ] else if (countdown != null && countdown != 'finished') ...[
                    const Icon(Icons.timer_outlined,
                        size: 13, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      countdown,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'categories_label'.tr.replaceAll('@count', '${widget.event.categories.length}'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.textSecondary, size: 18),
                ],
              ),
            ),

            // ── Comment bar ────────────────────────────────────────────
            const Divider(height: 1, thickness: 1),
            _CommentBar(
                eventId: widget.event.id, eventName: widget.event.name),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    final cats = widget.event.categories.values.toList();

    if (cats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_categories'.tr),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // If only one category with KML, go directly
    final withKml =
        cats.where((c) => c.kmlUrl.isNotEmpty || c.kmlPath.isNotEmpty).toList();
    if (withKml.length == 1 && cats.length == 1) {
      _openMap(withKml.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryPickerSheet(
        eventName: widget.event.name,
        categories: cats,
        onSelect: (cat) {
          Navigator.pop(context);
          _openMap(cat);
        },
      ),
    );
  }

  void _openMap(RaceCategory cat) {
    Get.toNamed(
      AppRoutes.kmlMap,
      arguments: {
        'kmlUrl': cat.kmlUrl,
        'storagePath': cat.kmlPath,
        'label': '${widget.event.name} (${cat.label})',
      },
    );
  }
}

// ── Banner with floating title / date / place overlay ────────────────────────

class _BannerWithOverlay extends StatelessWidget {
  final EventModel event;
  final bool finished;
  const _BannerWithOverlay({required this.event, this.finished = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: cached network image or gradient fallback
          if (event.bannerUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: event.bannerUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => _gradientBg(),
              errorWidget: (_, __, ___) => _gradientBg(),
            )
          else
            _gradientBg(),

          // Dark gradient from bottom so text is always readable
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.35, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),

          // Finished dimming overlay
          if (finished)
            Container(color: Colors.black.withValues(alpha: 0.45)),

          // Finished badge top-right
          if (finished)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag, size: 13, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      'event_finished'.tr,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          // Title + date + location floating bottom-left
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black54),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(event.date,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientBg() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary,
              AppTheme.primary.withValues(alpha: 0.65),
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.directions_run,
              color: Colors.white54, size: 52),
        ),
      );
}

// ── Comment bar (bottom strip on each card) ───────────────────────────────────

class _CommentBar extends StatelessWidget {
  final String eventId;
  final String eventName;

  const _CommentBar({required this.eventId, required this.eventName});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: CommentService.instance.watchCommentCount(eventId),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return InkWell(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(14)),
          onTap: () => _openCommentSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  count == 0 ? 'add_comment_hint'.tr : 'comment_count'.tr.replaceAll('@count', '$count'),
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right,
                    size: 16, color: AppTheme.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentSheet(eventId: eventId, eventName: eventName),
    );
  }
}

// ── Comment sheet ─────────────────────────────────────────────────────────────

class _CommentSheet extends StatefulWidget {
  final String eventId;
  final String eventName;

  const _CommentSheet({required this.eventId, required this.eventName});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    await CommentService.instance.addComment(widget.eventId, text);
    _ctrl.clear();
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    widget.eventName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'comments'.tr,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Comment list
            Expanded(
              child: StreamBuilder<List<CommentModel>>(
                stream: CommentService.instance.watchComments(widget.eventId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snap.data ?? [];
                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 40, color: Color(0xFFB0BEC5)),
                          const SizedBox(height: 8),
                          Text('first_comment'.tr,
                              style: const TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _CommentTile(
                        comment: comments[i], eventId: widget.eventId),
                  );
                },
              ),
            ),

            // Input bar
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'comment_input_hint'.tr,
                        hintStyle: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const SizedBox(
                          width: 38,
                          height: 38,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send_rounded),
                          color: AppTheme.primary,
                          onPressed: _send,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single comment tile ───────────────────────────────────────────────────────

class _CommentTile extends StatefulWidget {
  final CommentModel comment;
  final String eventId;

  const _CommentTile({required this.comment, required this.eventId});

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _showReplies = false;
  bool _showReplyInput = false;
  final _replyCtrl = TextEditingController();
  bool _sendingReply = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isLiked => widget.comment.likes.containsKey(_uid);
  int get _likeCount => widget.comment.likes.length;

  Future<void> _toggleLike() async {
    await CommentService.instance
        .toggleLike(widget.eventId, widget.comment.commentId);
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingReply = true);
    await CommentService.instance
        .addReply(widget.eventId, widget.comment.commentId, text);
    _replyCtrl.clear();
    if (mounted) {
      setState(() {
        _sendingReply = false;
        _showReplyInput = false;
        _showReplies = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final isOwner = uid != null && uid == widget.comment.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main comment row ───────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              label: widget.comment.label,
              photoUrl: widget.comment.photoUrl,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + time + delete
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.comment.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        widget.comment.timeAgo,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => CommentService.instance.deleteComment(
                              widget.eventId, widget.comment.commentId),
                          child: const Icon(Icons.delete_outline,
                              size: 16, color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.comment.text,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  // ── Action row ─────────────────────────────────────
                  Row(
                    children: [
                      // Like
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(
                          children: [
                            Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 15,
                              color: _isLiked
                                  ? Colors.redAccent
                                  : AppTheme.textSecondary,
                            ),
                            if (_likeCount > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '$_likeCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isLiked
                                      ? Colors.redAccent
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Reply
                      GestureDetector(
                        onTap: () => setState(() {
                          _showReplyInput = !_showReplyInput;
                          if (_showReplyInput) _showReplies = true;
                        }),
                        child: const Row(
                          children: [
                            Icon(Icons.reply,
                                size: 15, color: AppTheme.textSecondary),
                            SizedBox(width: 3),
                            Text('Reply',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      // Toggle replies visibility
                      if (widget.comment.replies.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showReplies = !_showReplies),
                          child: Text(
                            _showReplies
                                ? 'Hide replies'
                                : '${widget.comment.replies.length} repl${widget.comment.replies.length == 1 ? 'y' : 'ies'}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.primary),
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

        // ── Replies ────────────────────────────────────────────────────
        if (_showReplies && widget.comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 8),
            child: Column(
              children: widget.comment.replies.map((reply) {
                final isReplyOwner = uid != null && uid == reply.uid;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(
                          label: reply.label,
                          photoUrl: reply.photoUrl,
                          size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    reply.label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(reply.timeAgo,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary)),
                                if (isReplyOwner) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => CommentService.instance
                                        .deleteReply(
                                            widget.eventId,
                                            widget.comment.commentId,
                                            reply.replyId),
                                    child: const Icon(Icons.delete_outline,
                                        size: 14, color: Colors.redAccent),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(reply.text,
                                style: const TextStyle(
                                    fontSize: 13, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        // ── Inline reply input ─────────────────────────────────────────
        if (_showReplyInput)
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'reply_input_hint'.tr,
                      hintStyle: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendReply(),
                  ),
                ),
                const SizedBox(width: 6),
                _sendingReply
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded),
                        iconSize: 20,
                        color: AppTheme.primary,
                        padding: EdgeInsets.zero,
                        onPressed: _sendReply,
                      ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Category picker bottom sheet ──────────────────────────────────────────────

class _CategoryPickerSheet extends StatelessWidget {
  final String eventName;
  final List<RaceCategory> categories;
  final void Function(RaceCategory) onSelect;

  const _CategoryPickerSheet({
    required this.eventName,
    required this.categories,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    eventName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'select_category'.tr,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            // Category list — all shown, disabled if no KML
            ...categories.map((cat) {
              final hasKml = cat.kmlUrl.isNotEmpty || cat.kmlPath.isNotEmpty;
              return InkWell(
                onTap: hasKml ? () => onSelect(cat) : null,
                child: Opacity(
                  opacity: hasKml ? 1.0 : 0.4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.directions_run,
                              color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (cat.cutoff.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Cut-Off: ${cat.cutoff}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                              if (!hasKml) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'no_route_set'.tr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (hasKml)
                          const Icon(Icons.chevron_right,
                              color: AppTheme.textSecondary)
                        else
                          const Icon(Icons.lock_outline,
                              size: 18, color: Colors.orange),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
