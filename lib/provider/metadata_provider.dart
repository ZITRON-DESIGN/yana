import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:yana/nostr/nip05/nip05_validor.dart';
import 'package:yana/utils/nip05status.dart';

import '../main.dart';
import '../models/metadata.dart';
import '../models/metadata_db.dart';
import '../nostr/event.dart';
import '../nostr/event_kind.dart' as kind;
import '../nostr/filter.dart';
import '../utils/later_function.dart';
import '../utils/string_util.dart';

class MetadataProvider extends ChangeNotifier with LaterFunction {
  Map<String, Metadata> _metadataCache = {};

  Map<String, int> _handingPubkeys = {};

  static MetadataProvider? _metadataProvider;

  static Future<MetadataProvider> getInstance() async {
    if (_metadataProvider == null) {
      _metadataProvider = MetadataProvider();

      var list = await MetadataDB.all();
      for (var md in list) {
        if (md.valid == Nip05Status.NIP05_NOT_VALIDED) {
          md.valid = null;
        }
        _metadataProvider!._metadataCache[md.pubKey!] = md;
      }
      // lazyTimeMS begin bigger and request less
      _metadataProvider!.laterTimeMS = 2000;
    }

    return _metadataProvider!;
  }

  List<Metadata> findUser(String str, {int? limit = 5}) {
    List<Metadata> list = [];
    if (StringUtil.isNotBlank(str)) {
      var values = _metadataCache.values;
      for (var metadata in values) {
        if ((metadata.displayName != null &&
                metadata.displayName!.contains(str)) ||
            (metadata.name != null && metadata.name!.contains(str))) {
          list.add(metadata);

          if (limit != null && list.length >= limit) {
            break;
          }
        }
      }
    }
    return list;
  }

  void _laterCallback() {
    if (_needUpdatePubKeys.isNotEmpty) {
      _laterSearch();
    }

    if (_penddingEvents.isNotEmpty) {
      _handlePenddingEvents();
    }
  }

  List<String> _needUpdatePubKeys = [];

  void update(String pubkey) {
    if (!_needUpdatePubKeys.contains(pubkey)) {
      _needUpdatePubKeys.add(pubkey);
    }
    later(_laterCallback, null);
  }

  Metadata? getMetadata(String pubkey) {
    var metadata = _metadataCache[pubkey];
    if (metadata != null) {
      return metadata;
    }

    if (!_needUpdatePubKeys.contains(pubkey) &&
        !_handingPubkeys.containsKey(pubkey)) {
      _needUpdatePubKeys.add(pubkey);
    }
    later(_laterCallback, null);

    return null;
  }

  int getNip05Status(String pubkey) {
    var metadata = getMetadata(pubkey);
    if (metadata == null) {
      return Nip05Status.METADATA_NOT_FOUND;
    } else if (StringUtil.isBlank(metadata.nip05)) {
      return Nip05Status.NIP05_NOT_FOUND;
    } else if (metadata.valid == null) {
      Nip05Validor.valid(metadata.nip05!, pubkey).then((valid) async {
        if (valid != null) {
          if (valid) {
            metadata.valid = Nip05Status.NIP05_VALIDED;
            await MetadataDB.update(metadata);
          } else {
            // only update cache, next open app vill valid again
            metadata.valid = Nip05Status.NIP05_NOT_VALIDED;
          }
          notifyListeners();
        }
      });

      return Nip05Status.NIP05_NOT_VALIDED;
    } else if (metadata.valid! == Nip05Status.NIP05_VALIDED) {
      return Nip05Status.NIP05_VALIDED;
    }

    return Nip05Status.NIP05_NOT_FOUND;
  }

  List<Event> _penddingEvents = [];

  void _handlePenddingEvents() {
    for (var event in _penddingEvents) {
      if (StringUtil.isBlank(event.content)) {
        continue;
      }

      _handingPubkeys.remove(event.pubKey);

      var jsonObj = jsonDecode(event.content);
      var md = Metadata.fromJson(jsonObj);
      md.pubKey = event.pubKey;
      md.updated_at = event.createdAt;

      // check cache
      var oldMetadata = _metadataCache[md.pubKey];
      if (oldMetadata == null) {
        // db
        MetadataDB.insert(md);
        // cache
        _metadataCache[md.pubKey!] = md;
        // refresh
      } else if (oldMetadata.updated_at! < md.updated_at!) {
        // db
        MetadataDB.update(md);
        // cache
        _metadataCache[md.pubKey!] = md;
        // refresh
      }
    }
    _penddingEvents.clear();

    notifyListeners();
  }

  void _onEvent(Event event) {
    _penddingEvents.add(event);
    later(_laterCallback, null);
  }

  void _laterSearch() {
    if (_needUpdatePubKeys.isEmpty) {
      return;
    }

    List<Map<String, dynamic>> filters = [];
    for (var pubkey in _needUpdatePubKeys) {
      var filter =
          Filter(kinds: [kind.EventKind.METADATA], authors: [pubkey], limit: 1);
      filters.add(filter.toJson());
      if (filters.length > 11) {
        nostr!.query(filters, _onEvent);
        filters.clear();
      }
    }
    if (filters.isNotEmpty) {
      nostr!.query(filters, _onEvent);
    }

    for (var pubkey in _needUpdatePubKeys) {
      _handingPubkeys[pubkey] = 1;
    }
    _needUpdatePubKeys.clear();
  }

  void clear() {
    _metadataCache.clear();
    MetadataDB.deleteAll();
  }
}
