import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The listen counts the API answered with after this user played an echo
/// or a voice reply, by id. Each card shows its own copy of the echo (the
/// feed's list, the map card's fetch, the thread page's argument), so the
/// new count is kept here once for all of them (GC-67).
class ListenCounts extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  /// Keeps [count] for [id] unless a higher one is already known: answers
  /// can arrive out of order.
  void record(String id, int count) {
    if ((state[id] ?? -1) >= count) return;
    state = {...state, id: count};
  }
}

final listenCountsProvider =
    NotifierProvider<ListenCounts, Map<String, int>>(ListenCounts.new);

/// The listen count a card shows for [id]: the higher of its own copy
/// ([own]) and the last count the API answered with.
int watchListens(WidgetRef ref, String id, int own) {
  final recorded =
      ref.watch(listenCountsProvider.select((counts) => counts[id]));
  return recorded == null ? own : math.max(own, recorded);
}
