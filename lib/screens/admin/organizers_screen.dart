import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../firebase_options.dart';
import '../../models/admin_user_model.dart';
import '../../models/event_model.dart';
import '../../services/admin_service.dart';
import 'event_form_screen.dart';

class OrganizersScreen extends StatelessWidget {
  const OrganizersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<AdminUser>>(
          stream: AdminService.instance.watchOrganizers(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final organizers = snap.data ?? [];
            if (organizers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.manage_accounts_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No organizers yet',
                        style: TextStyle(
                            fontSize: 16, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    const Text('Create organizer accounts below',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 100),
              itemCount: organizers.length,
              itemBuilder: (_, i) =>
                  _OrganizerExpandableCard(organizer: organizers[i]),
            );
          },
        ),
        Positioned(
          right: 28,
          bottom: 28,
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('New Organizer'),
            onPressed: () => _showCreateDialog(context),
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _CreateOrganizerDialog(),
    );
  }
}

// ── Expandable organizer card showing their events ──────────────────────────

class _OrganizerExpandableCard extends StatefulWidget {
  final AdminUser organizer;
  const _OrganizerExpandableCard({required this.organizer});

  @override
  State<_OrganizerExpandableCard> createState() =>
      _OrganizerExpandableCardState();
}

class _OrganizerExpandableCardState extends State<_OrganizerExpandableCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _expandAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.organizer;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                    child: Text(
                      (org.displayName.isNotEmpty ? org.displayName : org.email)
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(org.email,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Organizer',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Revoke access',
                    child: InkWell(
                      onTap: () => _confirmRevoke(context),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.person_remove_outlined,
                            size: 20, color: Colors.redAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded events list ─────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                const Divider(height: 1, indent: 20, endIndent: 20),
                _OrganizerEventsList(organizer: org),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRevoke(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revoke Access'),
        content: Text(
            'Remove organizer access for "${widget.organizer.displayName}"?\nThey will no longer be able to log in to this panel.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AdminService.instance.deleteOrganizer(widget.organizer.uid);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }
}

// ── Events list for one organizer ───────────────────────────────────────────

class _OrganizerEventsList extends StatelessWidget {
  final AdminUser organizer;
  const _OrganizerEventsList({required this.organizer});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventModel>>(
      stream:
          AdminService.instance.watchEvents(organizerUid: organizer.uid),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final events = snap.data ?? [];

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${events.length} Event${events.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventFormScreen(
                          organizerUid: organizer.uid,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Event',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.event_busy_outlined,
                          size: 18, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Text('No events yet',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade400)),
                    ],
                  ),
                )
              else
                ...events.map((e) => _EventRow(event: e, organizer: organizer)),
            ],
          ),
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  final EventModel event;
  final AdminUser organizer;
  const _EventRow({required this.event, required this.organizer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_run,
                color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 11, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(event.date,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(width: 10),
                    const Icon(Icons.location_on_outlined,
                        size: 11, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(event.location,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Category count badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.trackingGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${event.categories.length} cat.',
              style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.trackingGreen,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventFormScreen(
                  existing: event,
                  organizerUid: organizer.uid,
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.edit_outlined,
                  size: 16, color: AppTheme.textSecondary),
            ),
          ),
          InkWell(
            onTap: () => _confirmDelete(context),
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.delete_outline,
                  size: 16, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AdminService.instance.deleteEvent(event.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Create organizer dialog ──────────────────────────────────────────────────

class _CreateOrganizerDialog extends StatefulWidget {
  const _CreateOrganizerDialog();

  @override
  State<_CreateOrganizerDialog> createState() => _CreateOrganizerDialogState();
}

class _CreateOrganizerDialogState extends State<_CreateOrganizerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'organizer_creation',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(_nameCtrl.text.trim());
      await secondaryAuth.signOut();

      await AdminService.instance.registerOrganizerRecord(
        uid,
        _emailCtrl.text.trim(),
        _nameCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Organizer "${_nameCtrl.text.trim()}" created successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Failed to create organizer');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      await secondaryApp?.delete();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Organizer'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.red.shade700)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
