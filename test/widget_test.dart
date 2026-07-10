import 'package:flutter_test/flutter_test.dart';

import 'package:ash_rise/core/constants.dart';
import 'package:ash_rise/model/channel_mode.dart';
import 'package:ash_rise/model/verdict.dart';

void main() {
  test('ChannelMode round-trips through encode/decode', () {
    expect(ChannelMode.decode('remote'), ChannelMode.remote);
    expect(ChannelMode.decode('local'), ChannelMode.local);
    expect(ChannelMode.decode(null), ChannelMode.fresh);
    expect(ChannelMode.decode('garbage'), ChannelMode.fresh);
    expect(ChannelMode.remote.encode(), 'remote');
  });

  test('Verdict maps the backend contract verbatim', () {
    final Verdict ok = Verdict.fromMap(<String, dynamic>{
      'ok': true,
      'url': 'https://example.com/x',
      'expires': 1700000000,
    });
    expect(ok.allowed, isTrue);
    expect(ok.hasLink, isTrue);
    expect(ok.ttl, 1700000000);

    final Verdict deny = Verdict.fromMap(<String, dynamic>{'ok': false});
    expect(deny.allowed, isFalse);
    expect(deny.hasLink, isFalse);
  });

  test('Ember gradient is defined for shell buttons', () {
    expect(AppColors.emberGradient, isNotEmpty);
  });
}
