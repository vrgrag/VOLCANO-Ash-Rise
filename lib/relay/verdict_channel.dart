import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../model/verdict.dart';
import '../wire/app_facade.dart';
import 'agent_client.dart';
import 'locker.dart';

// ============================================================
// VERDICT CHANNEL — posts the attribution body, reads the reply
// ============================================================
// Sends the merged body to the config endpoint. On an allowed reply the
// content link + ttl are cached so returning launches can fall back to it
// if the network later fails. A missing endpoint or any error yields a
// denied verdict, which routes the user to the native game.
// ============================================================

class VerdictChannel {
  VerdictChannel(this._locker);

  final Locker _locker;

  Future<Verdict> query(Map<String, dynamic> body) async {
    final String endpoint = AshFacade.gateEndpoint;
    if (endpoint.isEmpty) {
      return Verdict.denied('no-endpoint');
    }

    try {
      final response = await agentClient
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('[VerdictChannel] ${response.statusCode} ${response.body}');
      }

      if (response.statusCode != 200) {
        return Verdict.denied('http-${response.statusCode}');
      }

      final Map<String, dynamic> map =
          jsonDecode(response.body) as Map<String, dynamic>;
      final Verdict verdict = Verdict.fromMap(map);

      if (verdict.allowed && verdict.hasLink) {
        await _locker.writeCachedLink(verdict.link!);
        if (verdict.ttl != null) {
          await _locker.writeLinkTtl(verdict.ttl!);
        }
      }
      return verdict;
    } catch (e) {
      return Verdict.denied(e.toString());
    }
  }

  Future<String?> cachedLink() => _locker.readCachedLink();
}
