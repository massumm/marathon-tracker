import 'package:get/get.dart';

class AppStrings extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          // Navigation
          'nav_map': 'Events',
          'nav_friends': 'Friends',
          'nav_my_page': 'My Page',

          // Events
          'events_title': 'Events',
          'no_events': 'No events available',
          'view_map': 'View Map',

          // Comments
          'comments': 'Comments',
          'no_comments': 'No comments yet. Be the first!',
          'add_comment': 'Write a comment...',
          'send': 'Send',
          'delete_comment': 'Delete comment?',
          'add_comment_hint': 'Add a comment',
          'comment_count': '@count comments',
          'first_comment': 'Be the first to comment!',
          'comment_input_hint': 'Write a comment...',
          'reply_input_hint': 'Write a reply...',
          'select_category': 'Select a category',
          'no_categories': 'No categories available yet',
          'no_route_set': 'Route not set',
          'categories_label': '@count categories',

          // Auth
          'sign_in': 'Sign In',
          'sign_up': 'Create Account',
          'sign_in_google': 'Sign in with Google',
          'sign_up_google': 'Sign up with Google',

          // Friends
          'friends_title': 'Friends',
          'search_by_email': 'Search by email',
          'search': 'Search',
          'add': 'Add',
          'request_sent': 'Sent',
          'already_friends': 'Friends',
          'you_label': 'You',
          'accept': 'Accept',
          'reject': 'Reject',
          'remove_friend': 'Remove friend',
          'remove_friend_confirm': 'Remove @name from your friends?',
          'incoming_requests': 'Friend Requests',
          'friends_label': 'Friends',
          'user_not_found': 'User not found',
          'running_now': '🏃 Running now',
          'no_friends': 'No friends yet',
          'no_friends_subtitle': 'Search by email to add friends',

          // My Page
          'my_page_title': 'My Page',
          'my_routes': 'Records',
          'no_routes': 'No recorded routes',
          'no_routes_subtitle': 'Start a run to record your routes.',
          'sign_out': 'Sign Out',
          'sign_out_confirm': 'Are you sure you want to sign out?',
          'cancel': 'Cancel',
          'language': 'Language',

          // Map view
          'map_view_title': 'Map View',
          'saving': 'Saving...',
          'time_label': 'Time',
          'distance_label': 'Distance',
          'pace_label': 'Pace',
          'runners_live': 'runners live',
          'no_runners_live': 'No runners live',
          'no_runners_running': 'No one is running yet.',
          'live_leaderboard': 'Live Leaderboard',

          // Leaderboard / Profile
          'search_hint': 'Search by email or username',
          'my_qr_code': 'My QR Code',
          'qr_share_hint': 'Share this code so friends can add you',
          'scan_qr': 'Scan QR Code',
          'scan_qr_hint': 'Point at a friend\'s QR code to add them',
          'leaderboard': 'Leaderboard',
          'profile': 'Profile',
          'no_runners_yet': 'No runners yet',
          'runs': 'runs',
          'total_distance': 'Total Distance',
          'total_runs': 'Total Runs',
          'total_time': 'Total Time',
          'avg_pace': 'Avg Pace',
          'add_friend': 'Add Friend',
          'explore': 'EXPLORE',
          'edit_name': 'Edit Name',
          'your_name': 'Your name',
          'chat': 'Chat',
          'coming_soon': 'Coming soon!',

          // Location service / permission
          'location_off_title': 'Location is Off',
          'location_off_body': 'Please turn on your device\'s location (GPS) to track your run.',
          'location_permission_title': 'Location Permission Required',
          'location_permission_denied': 'Location permission was denied. Please allow location access to start tracking.',
          'location_permission_forever': 'Location permission is permanently denied. Please enable it in app settings.',
          'open_settings': 'Open Settings',

          // Proximity check
          'too_far_title': 'Too Far from Start',
          'too_far_body': 'You are @dist km from the event start point. Please move closer before starting.',
          'start_anyway': 'Start Anyway',

          // Common
          'runner': 'Runner',
          'refresh': 'Refresh',
          'delete': 'Delete',
          'confirm': 'Confirm',
          'loading': 'Loading...',
          'error_loading': 'Error loading data',
        },
        'ja_JP': {
          // Navigation
          'nav_map': 'イベント',
          'nav_friends': '友達',
          'nav_my_page': 'マイページ',

          // Events
          'events_title': 'イベント一覧',
          'no_events': 'イベントがありません',
          'view_map': '地図を見る',

          // Comments
          'comments': 'コメント',
          'no_comments': 'コメントはまだありません。最初にコメントしましょう！',
          'add_comment': 'コメントを入力...',
          'send': '送信',
          'delete_comment': 'コメントを削除しますか？',
          'add_comment_hint': 'コメントを追加',
          'comment_count': '@count コメント',
          'first_comment': '最初のコメントを投稿しよう',
          'comment_input_hint': 'コメントを入力...',
          'reply_input_hint': '返信を入力...',
          'select_category': 'カテゴリーを選択してください',
          'no_categories': 'このイベントにはカテゴリーがまだありません',
          'no_route_set': 'ルートマップ未設定',
          'categories_label': '@count カテゴリー',

          // Auth
          'sign_in': 'サインイン',
          'sign_up': 'アカウント作成',
          'sign_in_google': 'Googleでサインイン',
          'sign_up_google': 'Googleで登録',

          // Friends
          'friends_title': '友達',
          'search_by_email': 'メールアドレスで検索',
          'search': '検索',
          'add': '追加',
          'request_sent': '送信済み',
          'already_friends': '友達',
          'you_label': 'あなた',
          'accept': '承認',
          'reject': '拒否',
          'remove_friend': '友達を削除',
          'remove_friend_confirm': '@name を友達リストから削除しますか？',
          'incoming_requests': '受信したリクエスト',
          'friends_label': '友達',
          'user_not_found': 'ユーザーが見つかりませんでした',
          'running_now': '🏃 ランニング中',
          'no_friends': 'まだ友達がいません',
          'no_friends_subtitle': 'メールアドレスで友達を検索して追加しましょう',

          // My Page
          'my_page_title': 'マイページ',
          'my_routes': '記録',
          'no_routes': '記録されたルートはありません',
          'no_routes_subtitle': 'ランを開始してルートを記録しましょう。',
          'sign_out': 'サインアウト',
          'sign_out_confirm': 'サインアウトしますか？',
          'cancel': 'キャンセル',
          'language': '言語',

          // Map view
          'map_view_title': 'マップビュー',
          'saving': '保存中...',
          'time_label': '時間',
          'distance_label': '距離',
          'pace_label': 'ペース',
          'runners_live': '人 ライブ中',
          'no_runners_live': 'ライブランナーなし',
          'no_runners_running': 'まだ走っている人はいません',
          'live_leaderboard': 'ライブ順位',

          // Leaderboard / Profile
          'search_hint': 'メールまたはユーザー名で検索',
          'my_qr_code': 'マイQRコード',
          'qr_share_hint': 'このコードを友達に見せて追加してもらいましょう',
          'scan_qr': 'QRコードをスキャン',
          'scan_qr_hint': '友達のQRコードをカメラで読み取ってください',
          'leaderboard': 'ランキング',
          'profile': 'プロフィール',
          'no_runners_yet': 'まだランナーがいません',
          'runs': '回',
          'total_distance': '合計距離',
          'total_runs': '走行回数',
          'total_time': '合計時間',
          'avg_pace': '平均ペース',
          'add_friend': '友達追加',
          'explore': 'さがす',
          'edit_name': '名前を編集',
          'your_name': 'お名前',
          'chat': 'チャット',
          'coming_soon': '近日公開！',

          // Location service / permission
          'location_off_title': '位置情報がオフです',
          'location_off_body': 'ランの記録を開始するには、デバイスの位置情報（GPS）をオンにしてください。',
          'location_permission_title': '位置情報の許可が必要です',
          'location_permission_denied': '位置情報の許可が拒否されました。追跡を開始するには位置情報を許可してください。',
          'location_permission_forever': '位置情報の許可が永久に拒否されています。アプリ設定から有効にしてください。',
          'open_settings': '設定を開く',

          // Proximity check
          'too_far_title': 'スタート地点から離れすぎです',
          'too_far_body': 'イベントのスタート地点から @dist km 離れています。近づいてから開始してください。',
          'start_anyway': 'このまま開始',

          // Common
          'runner': 'ランナー',
          'refresh': '更新',
          'delete': '削除',
          'confirm': '確認',
          'loading': '読み込み中...',
          'error_loading': 'データの読み込みエラー',
        },
      };
}
