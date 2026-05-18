import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Entry point for the foreground service isolate.
/// The handler does nothing — we only need the service alive to prevent
/// Android from killing the main Flutter isolate during a run.
@pragma('vm:entry-point')
void startRunTrackingCallback() {
  FlutterForegroundTask.setTaskHandler(_RunTrackingHandler());
}

class _RunTrackingHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
