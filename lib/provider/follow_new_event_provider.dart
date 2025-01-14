import 'package:flutter/material.dart';

import '../nostr/event.dart';
import '../nostr/filter.dart';
import '../nostr/nip02/contact.dart';
import '../models/event_mem_box.dart';
import '../main.dart';
import '../utils/peddingevents_later_function.dart';
import '../utils/string_util.dart';
import 'follow_event_provider.dart';

class FollowNewEventProvider extends ChangeNotifier
    with PenddingEventsLaterFunction {
  EventMemBox eventPostsMemBox = EventMemBox(sortAfterAdd: false);
  EventMemBox eventPostsAndRepliesMemBox = EventMemBox();

  int? _localSince;

  List<String> _subscribeIds = [];

  void doUnscribe() {
    if (_subscribeIds.isNotEmpty) {
      for (var subscribeId in _subscribeIds) {
        try {
          nostr!.unsubscribe(subscribeId);
        } catch (e) {}
      }
      _subscribeIds.clear();
    }
  }

  void queryNew() {
    doUnscribe();

    bool queriedTags = false;
    _localSince =
        _localSince == null || followEventProvider.lastTime() > _localSince!
            ? followEventProvider.lastTime()
            : _localSince;
    var filter = Filter(
        since: _localSince! + 1, kinds: followEventProvider.queryEventKinds());

    List<String> subscribeIds = [];
    Iterable<Contact> contactList = contactListProvider.list();
    List<String> ids = [];
    for (Contact contact in contactList) {
      ids.add(contact.publicKey);
      if (ids.length > 100) {
        filter.authors = ids;
        var subscribeId = _doQueryFunc(filter, queriyTags: queriedTags);
        subscribeIds.add(subscribeId);
        ids = [];
        queriedTags = true;
      }
    }
    if (ids.isNotEmpty) {
      filter.authors = ids;
      var subscribeId = _doQueryFunc(filter, queriyTags: queriedTags);
      subscribeIds.add(subscribeId);
    }

    _subscribeIds = subscribeIds;
  }

  String _doQueryFunc(Filter filter, {bool queriyTags = false}) {
    var subscribeId = StringUtil.rndNameStr(12);
    nostr!.query(
        FollowEventProvider.addTagCommunityFilter(
            [filter.toJson()], queriyTags), (event) {
      later(event, handleEvents, null);
    }, id: subscribeId);
    return subscribeId;
  }

  void clear() {
    eventPostsMemBox.clear();
    eventPostsAndRepliesMemBox.clear();

    notifyListeners();
  }

  void clearReplies() {
    eventPostsAndRepliesMemBox.clear();
    notifyListeners();
  }

  void clearPosts() {
    eventPostsMemBox.clear();
    notifyListeners();
  }

  handleEvents(List<Event> events) {
    if (eventPostsAndRepliesMemBox.newestEvent != null) {
      _localSince = eventPostsAndRepliesMemBox.newestEvent!.createdAt;
    }

    for (var event in events) {
      bool isPosts = FollowEventProvider.eventIsPost(event);
      if (isPosts) {
        eventPostsMemBox.add(event);
      } else {
        eventPostsAndRepliesMemBox.add(event);
      }
    }
    notifyListeners();
  }
}
