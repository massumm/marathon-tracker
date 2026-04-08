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
