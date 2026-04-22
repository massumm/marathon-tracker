import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/group_controller.dart';
import '../core/theme.dart';
import '../models/comment_model.dart';
import '../screens/group_management_screen.dart';
import '../services/comment_service.dart';
import '../widgets/user_avatar.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<GroupDetailController>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(ctrl.group.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'group_qr'.tr,
              onPressed: () => GroupQrSheet.show(ctrl.group),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'scan_to_join'.tr,
              onPressed: () => Get.toNamed(
                AppRoutes.qrScanner,
                arguments: {'mode': 'group'},
              ),
            ),
            if (ctrl.isAdmin)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'delete_group'.tr,
                onPressed: () => _confirmDelete(ctrl),
              ),
            if (!ctrl.isAdmin)
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'leave_group'.tr,
                onPressed: () => _confirmLeave(ctrl),
              ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'tab_members'.tr),
              Tab(text: 'tab_comments'.tr),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MembersListView(ctrl: ctrl),
            _GroupCommentsTab(groupId: ctrl.group.id),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(GroupDetailController ctrl) {
    Get.dialog(AlertDialog(
      title: Text('delete_group'.tr),
      content: Text(
          'delete_group_confirm'.tr.replaceAll('@name', ctrl.group.name)),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            Get.back();
            ctrl.deleteGroup();
          },
          child: Text('delete'.tr,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    ));
  }

  void _confirmLeave(GroupDetailController ctrl) {
    Get.dialog(AlertDialog(
      title: Text('leave_group'.tr),
      content: Text('leave_group_confirm'.tr),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            Get.back();
            ctrl.leaveGroup();
          },
          child: Text('leave'.tr,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    ));
  }
}

// ── Members list ──────────────────────────────────────────────────────────────

class _MembersListView extends StatelessWidget {
  final GroupDetailController ctrl;
  const _MembersListView({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final members = ctrl.members;
      if (members.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: members.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = members[i];
          final isSelf = m.uid == ctrl.myUid;
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            leading: UserAvatar(
                label: m.label, photoUrl: m.photoUrl, size: 44),
            title: Row(
              children: [
                Text(m.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (m.isAdmin) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('admin'.tr,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade800)),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              m.email,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
            trailing: ctrl.isAdmin && !isSelf && !m.isAdmin
                ? IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.redAccent, size: 20),
                    onPressed: () => _confirmRemove(m.uid, m.label),
                  )
                : null,
          );
        },
      );
    });
  }

  void _confirmRemove(String uid, String label) {
    Get.dialog(AlertDialog(
      title: Text('remove_member'.tr),
      content:
          Text('remove_member_confirm'.tr.replaceAll('@name', label)),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            Get.back();
            ctrl.removeMember(uid);
          },
          child: Text('remove'.tr,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    ));
  }
}

// ── Comments tab ──────────────────────────────────────────────────────────────

class _GroupCommentsTab extends StatefulWidget {
  final String groupId;
  const _GroupCommentsTab({required this.groupId});

  @override
  State<_GroupCommentsTab> createState() => _GroupCommentsTabState();
}

class _GroupCommentsTabState extends State<_GroupCommentsTab> {
  final _inputCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    await CommentService.instance.addGroupComment(widget.groupId, text);
    _inputCtrl.clear();
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<CommentModel>>(
            stream:
                CommentService.instance.watchGroupComments(widget.groupId),
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
                          style: const TextStyle(
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: comments.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                itemBuilder: (_, i) => _GroupCommentTile(
                    comment: comments[i], groupId: widget.groupId),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.fromLTRB(
              12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
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
    );
  }
}

// ── Single group comment tile ─────────────────────────────────────────────────

class _GroupCommentTile extends StatefulWidget {
  final CommentModel comment;
  final String groupId;

  const _GroupCommentTile({required this.comment, required this.groupId});

  @override
  State<_GroupCommentTile> createState() => _GroupCommentTileState();
}

class _GroupCommentTileState extends State<_GroupCommentTile> {
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
        .toggleGroupLike(widget.groupId, widget.comment.commentId);
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingReply = true);
    await CommentService.instance
        .addGroupReply(widget.groupId, widget.comment.commentId, text);
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
                          onTap: () =>
                              CommentService.instance.deleteGroupComment(
                                  widget.groupId, widget.comment.commentId),
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
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(
                          children: [
                            Icon(
                              _isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
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
                      GestureDetector(
                        onTap: () => setState(() {
                          _showReplyInput = !_showReplyInput;
                          if (_showReplyInput) _showReplies = true;
                        }),
                        child: Row(
                          children: [
                            const Icon(Icons.reply,
                                size: 15, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Text('reply'.tr,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      if (widget.comment.replies.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => setState(
                              () => _showReplies = !_showReplies),
                          child: Text(
                            _showReplies
                                ? 'hide_replies'.tr
                                : 'show_replies'.tr.replaceAll(
                                    '@count',
                                    '${widget.comment.replies.length}'),
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
                                    onTap: () =>
                                        CommentService.instance
                                            .deleteGroupReply(
                                                widget.groupId,
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
                                    fontSize: 13,
                                    color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
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
