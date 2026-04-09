import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../services/admin_service.dart';
import 'event_form_screen.dart';

class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<EventModel>>(
          stream: AdminService.instance.watchEvents(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 12),
                    const Text('Failed to load events',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              );
            }
            final events = snap.data ?? [];
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No events yet',
                        style: TextStyle(
                            fontSize: 16, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    const Text('Create your first marathon event',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 100),
              itemCount: events.length,
              itemBuilder: (_, i) => _EventCard(event: events[i]),
            );
          },
        ),

        // FAB
        Positioned(
          right: 28,
          bottom: 28,
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('New Event'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EventFormScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final uploadedCats =
        event.categories.values.where((c) => c.kmlPath.isNotEmpty).length;
    final totalCats = event.categories.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          if (event.bannerUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                event.bannerUrl,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary,
                        AppTheme.primary.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                  child: const Center(
                    child: Icon(Icons.directions_run,
                        color: Colors.white, size: 36),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary,
                    AppTheme.primary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.directions_run,
                    color: Colors.white, size: 36),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    _ActionIcon(
                      icon: Icons.edit_outlined,
                      color: AppTheme.textSecondary,
                      tooltip: 'Edit',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EventFormScreen(existing: event),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ActionIcon(
                      icon: Icons.delete_outline,
                      color: Colors.redAccent,
                      tooltip: 'Delete',
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Date + location
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(event.date,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(width: 20),
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(event.location,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),

                const SizedBox(height: 16),

                // Categories chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: event.categories.values.map((cat) {
                    final hasKml = cat.kmlPath.isNotEmpty;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasKml
                            ? AppTheme.trackingGreen.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasKml
                              ? AppTheme.trackingGreen.withValues(alpha: 0.4)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasKml
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            size: 13,
                            color: hasKml
                                ? AppTheme.trackingGreen
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasKml
                                  ? AppTheme.trackingGreen
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          if (cat.cutoff.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${cat.cutoff})',
                              style: TextStyle(
                                fontSize: 10,
                                color: hasKml
                                    ? AppTheme.trackingGreen.withValues(alpha: 0.7)
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),
                Text(
                  '$uploadedCats / $totalCats KML files uploaded',
                  style: TextStyle(
                    fontSize: 12,
                    color: uploadedCats == totalCats && totalCats > 0
                        ? AppTheme.trackingGreen
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
