import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yana/models/event_find_util.dart';
import 'package:yana/models/metadata.dart';
import 'package:yana/router/search/search_action_item_component.dart';
import 'package:yana/router/search/search_actions.dart';
import 'package:yana/ui/user/metadata_top_component.dart';
import 'package:yana/utils/when_stop_function.dart';

import '../../i18n/i18n.dart';
import '../../main.dart';
import '../../models/event_mem_box.dart';
import '../../nostr/client_utils/keys.dart';
import '../../nostr/event.dart';
import '../../nostr/event_kind.dart' as kind;
import '../../nostr/filter.dart';
import '../../nostr/nip19/nip19.dart';
import '../../provider/setting_provider.dart';
import '../../ui/cust_state.dart';
import '../../ui/event/event_list_component.dart';
import '../../ui/event_delete_callback.dart';
import '../../utils/base_consts.dart';
import '../../utils/load_more_event.dart';
import '../../utils/peddingevents_later_function.dart';
import '../../utils/platform_util.dart';
import '../../utils/router_path.dart';
import '../../utils/router_util.dart';
import '../../utils/string_util.dart';

class SearchRouter extends StatefulWidget {
  const SearchRouter({super.key});

  @override
  State<StatefulWidget> createState() {
    return _SearchRouter();
  }
}

class _SearchRouter extends CustState<SearchRouter>
    with PenddingEventsLaterFunction, LoadMoreEvent, WhenStopFunction {
  TextEditingController controller = TextEditingController();

  ScrollController loadableScrollController = ScrollController();

  ScrollController scrollController = ScrollController();

  @override
  Future<void> onReady(BuildContext context) async {
    bindLoadMoreScroll(loadableScrollController);

    controller.addListener(() {
      var hasText = StringUtil.isNotBlank(controller.text);
      if (!showSuffix && hasText) {
        setState(() {
          showSuffix = true;
        });
        return;
      } else if (showSuffix && !hasText) {
        setState(() {
          showSuffix = false;
        });
      }

      whenStop(checkInput);
    });
  }

  bool showSuffix = false;

  @override
  Widget doBuild(BuildContext context) {
    var s = I18n.of(context);
    var _settingProvider = Provider.of<SettingProvider>(context);
    preBuild();

    Widget? suffixWidget;
    if (showSuffix) {
      suffixWidget = GestureDetector(
        onTap: () {
          controller.text = "";
        },
        child: Icon(Icons.close),
      );
    }

    bool? loadable;
    Widget? body;
    if (searchAction == null && searchAbles.isNotEmpty) {
      // no searchAction, show searchAbles
      List<Widget> list = [];
      for (var action in searchAbles) {
        if (action == SearchActions.openPubkey) {
          list.add(SearchActionItemComponent(
              title: s.Open_User_page, onTap: openPubkey));
        } else if (action == SearchActions.openNoteId) {
          list.add(SearchActionItemComponent(
              title: s.Open_Note_detail, onTap: openNoteId));
        } else if (action == SearchActions.searchMetadataFromCache) {
          list.add(SearchActionItemComponent(
              title: s.Search_User_from_cache, onTap: searchMetadataFromCache));
        } else if (action == SearchActions.searchEventFromCache) {
          list.add(SearchActionItemComponent(
              title: s.Open_Event_from_cache, onTap: searchEventFromCache));
        } else if (action == SearchActions.searchPubkeyEvent) {
          list.add(SearchActionItemComponent(
              title: s.Search_pubkey_event, onTap: onEditingComplete));
        } else if (action == SearchActions.searchNoteContent) {
          list.add(SearchActionItemComponent(
              title: "${s.Search_note_content} NIP-50",
              onTap: searchNoteContent));
        }
      }
      body = Container(
        // width: double.infinity,
        // height: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: list,
        ),
      );
    } else {
      if (searchAction == SearchActions.searchMetadataFromCache) {
        loadable = false;
        body = Container(
          child: ListView.builder(
            controller: scrollController,
            itemBuilder: (BuildContext context, int index) {
              var metadata = metadatas[index];

              return GestureDetector(
                onTap: () {
                  RouterUtil.router(context, RouterPath.USER, metadata.pubKey);
                },
                child: MetadataTopComponent(
                  pubkey: metadata.pubKey!,
                  metadata: metadata,
                ),
              );
            },
            itemCount: metadatas.length,
          ),
        );
      } else if (searchAction == SearchActions.searchEventFromCache) {
        loadable = false;
        body = Container(
          child: ListView.builder(
            controller: scrollController,
            itemBuilder: (BuildContext context, int index) {
              var event = events[index];

              return EventListComponent(
                event: event,
                showVideo:
                    _settingProvider.videoPreviewInList == OpenStatus.OPEN,
              );
            },
            itemCount: events.length,
          ),
        );
      } else if (searchAction == SearchActions.searchPubkeyEvent) {
        loadable = true;
        var events = eventMemBox.all();
        body = Container(
          child: ListView.builder(
            controller: loadableScrollController,
            itemBuilder: (BuildContext context, int index) {
              var event = events[index];

              return EventListComponent(
                event: event,
                showVideo:
                    _settingProvider.videoPreviewInList == OpenStatus.OPEN,
              );
            },
            itemCount: itemLength,
          ),
        );
      }
    }
    if (body != null) {
      if (loadable != null && PlatformUtil.isTableMode()) {
        body = GestureDetector(
          onVerticalDragUpdate: (detail) {
            if (loadable == true) {
              loadableScrollController
                  .jumpTo(loadableScrollController.offset - detail.delta.dy);
            } else {
              scrollController
                  .jumpTo(scrollController.offset - detail.delta.dy);
            }
          },
          behavior: HitTestBehavior.translucent,
          child: body,
        );
      }
    } else {
      body = Container();
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: EventDeleteCallback(
        onDeleteCallback: onDeletedCallback,
        child: Container(
          child: Column(children: [
            Container(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: s.Please_input_search_content,
                  suffixIcon: suffixWidget,
                ),
                onEditingComplete: onEditingComplete,
              ),
            ),
            Expanded(
              child: body,
            ),
          ]),
        ),
      ),
    );
  }

  List<int> searchEventKinds = [
    kind.EventKind.TEXT_NOTE,
    kind.EventKind.REPOST,
    kind.EventKind.GENERIC_REPOST,
    kind.EventKind.LONG_FORM,
    kind.EventKind.FILE_HEADER,
    kind.EventKind.POLL,
  ];

  String? subscribeId;

  EventMemBox eventMemBox = EventMemBox();

  // Filter? filter;
  Map<String, dynamic>? filterMap;

  @override
  void doQuery() {
    preQuery();

    if (subscribeId != null) {
      unSubscribe();
    }
    subscribeId = generatePrivateKey();

    if (!eventMemBox.isEmpty()) {
      var activeRelays = nostr!.activeRelays();
      var oldestCreatedAts = eventMemBox.oldestCreatedAtByRelay(activeRelays);
      Map<String, List<Map<String, dynamic>>> filtersMap = {};
      for (var relay in activeRelays) {
        var oldestCreatedAt = oldestCreatedAts.createdAtMap[relay.url];
        if (oldestCreatedAt != null) {
          filterMap!["until"] = oldestCreatedAt;
        }
        Map<String, dynamic> fm = {};
        for (var entry in filterMap!.entries) {
          fm[entry.key] = entry.value;
        }
        filtersMap[relay.url] = [fm];
      }
      nostr!.queryByFilters(filtersMap, onQueryEvent, id: subscribeId);
    } else {
      if (until != null) {
        filterMap!["until"] = until;
      }
      nostr!.query([filterMap!], onQueryEvent, id: subscribeId);
    }
  }

  void onQueryEvent(Event event) {
    later(event, (list) {
      var addResult = eventMemBox.addList(list);
      if (addResult) {
        setState(() {});
      }
    }, null);
  }

  void unSubscribe() {
    nostr!.unsubscribe(subscribeId!);
    subscribeId = null;
  }

  void onEditingComplete() {
    hideKeyBoard();
    searchAction = SearchActions.searchPubkeyEvent;

    var value = controller.text;
    value = value.trim();
    // if (StringUtil.isBlank(value)) {
    //   BotToast.showText(text: S.of(context).Empty_text_may_be_ban_by_relays);
    // }

    List<String>? authors;
    if (StringUtil.isNotBlank(value) && value.indexOf("npub") == 0) {
      try {
        var result = Nip19.decode(value);
        authors = [result];
      } catch (e) {
        log(e.toString());
        // TODO handle error
        return;
      }
    } else {
      if (StringUtil.isNotBlank(value)) {
        authors = [value];
      }
    }

    eventMemBox = EventMemBox();
    until = null;
    filterMap =
        Filter(kinds: searchEventKinds, authors: authors, limit: queryLimit)
            .toJson();
    filterMap!.remove("search");
    penddingEvents.clear;
    doQuery();
  }

  void hideKeyBoard() {
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  EventMemBox getEventBox() {
    return eventMemBox;
  }

  @override
  void dispose() {
    super.dispose();
    disposeLater();
    disposeWhenStop();
  }

  static const int searchMemLimit = 100;

  onDeletedCallback(Event event) {
    eventMemBox.delete(event.id);
    setState(() {});
  }

  openPubkey() {
    hideKeyBoard();
    var text = controller.text;
    if (StringUtil.isNotBlank(text)) {
      String pubkey = text;
      if (Nip19.isPubkey(text)) {
        pubkey = Nip19.decode(text);
      }

      RouterUtil.router(context, RouterPath.USER, pubkey);
    }
  }

  openNoteId() {
    hideKeyBoard();
    var text = controller.text;
    if (StringUtil.isNotBlank(text)) {
      String noteId = text;
      if (Nip19.isNoteId(text)) {
        noteId = Nip19.decode(text);
      }

      RouterUtil.router(context, RouterPath.EVENT_DETAIL, noteId);
    }
  }

  List<Metadata> metadatas = [];

  searchMetadataFromCache() {
    hideKeyBoard();
    metadatas.clear();
    searchAction = SearchActions.searchMetadataFromCache;

    var text = controller.text;
    if (StringUtil.isNotBlank(text)) {
      var list = metadataProvider.findUser(text, limit: searchMemLimit);

      setState(() {
        metadatas = list;
      });
    }
  }

  List<Event> events = [];

  searchEventFromCache() {
    hideKeyBoard();
    events.clear();
    searchAction = SearchActions.searchEventFromCache;

    var text = controller.text;
    if (StringUtil.isNotBlank(text)) {
      var list = EventFindUtil.findEvent(text, limit: searchMemLimit);
      setState(() {
        events = list;
      });
    }
  }

  String? searchAction;

  List<String> searchAbles = [];

  String lastText = "";

  checkInput() {
    searchAction = null;
    searchAbles.clear();

    var text = controller.text;
    if (text == lastText) {
      return;
    }

    if (StringUtil.isNotBlank(text)) {
      if (Nip19.isPubkey(text)) {
        searchAbles.add(SearchActions.openPubkey);
      }
      if (Nip19.isNoteId(text)) {
        searchAbles.add(SearchActions.openNoteId);
      }
      searchAbles.add(SearchActions.searchMetadataFromCache);
      searchAbles.add(SearchActions.searchEventFromCache);
      searchAbles.add(SearchActions.searchPubkeyEvent);
      searchAbles.add(SearchActions.searchNoteContent);
    }

    lastText = text;
    setState(() {});
  }

  searchNoteContent() {
    hideKeyBoard();
    searchAction = SearchActions.searchPubkeyEvent;

    var value = controller.text;
    value = value.trim();
    // if (StringUtil.isBlank(value)) {
    //   BotToast.showText(text: S.of(context).Empty_text_may_be_ban_by_relays);
    // }

    eventMemBox = EventMemBox();
    until = null;
    filterMap = Filter(kinds: searchEventKinds, limit: queryLimit).toJson();
    filterMap!.remove("authors");
    filterMap!["search"] = value;
    penddingEvents.clear;
    doQuery();
  }
}
