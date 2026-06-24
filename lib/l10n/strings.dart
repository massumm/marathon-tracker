import 'package:get/get.dart';

import 'bn_strings.dart';
import 'en_strings.dart';
import 'jp_strings.dart';

class AppStrings extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': enStrings,
        'ja_JP': jaStrings,
        'bn_BD': bnStrings,
      };
}
