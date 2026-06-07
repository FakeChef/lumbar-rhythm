import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDataRefreshProvider = StateProvider<int>((ref) => 0);

void notifyAppDataChanged(Ref ref) {
  ref.read(appDataRefreshProvider.notifier).state++;
}
