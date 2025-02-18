import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:yana/router/tag/topic_map.dart';

import '../nostr/event_kind.dart' as kind;
import '../nostr/event.dart';
import '../nostr/nip02/contact.dart';
import '../nostr/nip02/cust_contact_list.dart';
import '../nostr/filter.dart';
import '../nostr/nostr.dart';
import '../main.dart';
import '../utils/string_util.dart';
import 'data_util.dart';

class ContactListProvider extends ChangeNotifier {
  static ContactListProvider? _contactListProvider;

  Event? _event;

  CustContactList? _contactList;

  static ContactListProvider getInstance() {
    if (_contactListProvider == null) {
      _contactListProvider = ContactListProvider();
      // _contactListProvider!.reload();
    }
    return _contactListProvider!;
  }

  void reload({Nostr? targetNostr}) {
    targetNostr ??= nostr;

    String? pubkey;
    if (targetNostr != null) {
      pubkey = targetNostr.publicKey;
    }

    var str = sharedPreferences.getString(DataKey.CONTACT_LISTS);
    if (StringUtil.isNotBlank(str)) {
      var jsonMap = jsonDecode(str!);

      if (jsonMap is Map<String, dynamic>) {
        String? eventStr;
        if (StringUtil.isNotBlank(pubkey)) {
          eventStr = jsonMap[pubkey];
        } else if (jsonMap.length == 1) {
          eventStr = jsonMap.entries.first.value as String;
        }

        if (eventStr != null) {
          var eventMap = jsonDecode(eventStr);
          _contactListProvider!._event = Event.fromJson(eventMap);
          _contactListProvider!._contactList =
              CustContactList.fromJson(_contactListProvider!._event!.tags);

          return;
        }
      }
    }

    _contactListProvider!._contactList = CustContactList();
  }

  void clearCurrentContactList() {
    var pubkey = nostr!.publicKey;
    var str = sharedPreferences.getString(DataKey.CONTACT_LISTS);
    if (StringUtil.isNotBlank(str)) {
      var jsonMap = jsonDecode(str!);
      if (jsonMap is Map) {
        jsonMap.remove(pubkey);

        var jsonStr = jsonEncode(jsonMap);
        sharedPreferences.setString(DataKey.CONTACT_LISTS, jsonStr);
      }
    }
  }

  var subscriptId = StringUtil.rndNameStr(16);

  void query({Nostr? targetNostr}) {
    targetNostr ??= nostr;
    subscriptId = StringUtil.rndNameStr(16);
    var filter = Filter(
        kinds: [kind.EventKind.CONTACT_LIST],
        limit: 1,
        authors: [targetNostr!.publicKey]);
    targetNostr.query([filter.toJson()], _onEvent, id: subscriptId);
  }

  void _onEvent(Event e) {
    if (e.kind == kind.EventKind.CONTACT_LIST) {
      if (_event == null || e.createdAt > _event!.createdAt) {
        _event = e;
        _contactList = CustContactList.fromJson(e.tags);
        _saveAndNotify();
      }
    }
  }

  void _saveAndNotify() {
    var eventJsonMap = _event!.toJson();
    var eventJsonStr = jsonEncode(eventJsonMap);

    var pubkey = nostr!.publicKey;
    Map<String, dynamic>? allJsonMap;

    var str = sharedPreferences.getString(DataKey.CONTACT_LISTS);
    if (StringUtil.isNotBlank(str)) {
      allJsonMap = jsonDecode(str!);
    }
    allJsonMap ??= {};

    allJsonMap[pubkey] = eventJsonStr;
    var jsonStr = jsonEncode(allJsonMap);

    sharedPreferences.setString(DataKey.CONTACT_LISTS, jsonStr);
    notifyListeners();

    followEventProvider.metadataUpdatedCallback(_contactList);
  }

  int total() {
    return _contactList!.total();
  }

  void addContact(Contact contact) {
    _contactList!.add(contact);
    _event = nostr!.sendContactList(_contactList!);

    _saveAndNotify();
  }

  void removeContact(String pubKey) {
    _contactList!.remove(pubKey);
    _event = nostr!.sendContactList(_contactList!);

    _saveAndNotify();
  }

  void updateContacts(CustContactList contactList) {
    _contactList = contactList;
    _event = nostr!.sendContactList(contactList);

    _saveAndNotify();
  }

  CustContactList? get contactList => _contactList;

  Iterable<Contact> list() {
    return _contactList!.list();
  }

  Contact? getContact(String pubKey) {
    return _contactList!.get(pubKey);
  }

  void clear() {
    _event = null;
    _contactList!.clear();
    clearCurrentContactList();

    notifyListeners();
  }

  bool containTag(String tag) {
    var list = TopicMap.getList(tag);
    if (list != null) {
      for (var t in list) {
        var exist = _contactList!.containsTag(t);
        if (exist) {
          return true;
        }
      }
      return false;
    } else {
      return _contactList!.containsTag(tag);
    }
  }

  void addTag(String tag) {
    _contactList!.addTag(tag);
    _event = nostr!.sendContactList(_contactList!);

    _saveAndNotify();
  }

  void removeTag(String tag) {
    _contactList!.removeTag(tag);
    _event = nostr!.sendContactList(_contactList!);

    _saveAndNotify();
  }

  int totalFollowedTags() {
    return _contactList!.totalFollowedTags();
  }

  Iterable<String> tagList() {
    return _contactList!.tagList();
  }

  bool containCommunity(String id) {
    return _contactList!.containsCommunity(id);
  }

  void addCommunity(String tag) {
    _contactList!.addCommunity(tag);
    _event = nostr!.sendContactList(_contactList!);

    _saveAndNotify();
  }

  void removeCommunity(String tag) {
    _contactList!.removeCommunity(tag);
    _event = nostr!.sendContactList(_contactList!);

    _saveAndNotify();
  }

  int totalfollowedCommunities() {
    return _contactList!.totalFollowedCommunities();
  }

  Iterable<String> followedCommunitiesList() {
    return _contactList!.followedCommunitiesList();
  }
}
