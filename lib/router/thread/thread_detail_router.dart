import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:widget_size/widget_size.dart';
import 'package:yana/provider/single_event_provider.dart';

import '../../main.dart';
import '../../models/event_mem_box.dart';
import '../../nostr/event.dart';
import '../../nostr/event_kind.dart' as kind;
import '../../nostr/event_relation.dart';
import '../../nostr/filter.dart';
import '../../ui/cust_state.dart';
import '../../ui/event/event_list_component.dart';
import '../../ui/event/event_load_list_component.dart';
import '../../ui/event_reply_callback.dart';
import '../../ui/simple_name_component.dart';
import '../../utils/base.dart';
import '../../utils/peddingevents_later_function.dart';
import '../../utils/platform_util.dart';
import '../../utils/router_util.dart';
import '../../utils/string_util.dart';
import '../../utils/when_stop_function.dart';
import 'thread_detail_event.dart';
import 'thread_detail_event_main_component.dart';
import 'thread_detail_item_component.dart';

class ThreadDetailRouter extends StatefulWidget {
  const ThreadDetailRouter({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ThreadDetailRouter();
  }

  static Widget detailAppBarTitle(Event event, ThemeData themeData) {
    var bodyLargeFontSize = themeData.textTheme.bodyLarge!.fontSize;

    List<Widget> appBarTitleList = [];
    var nameComponnet = SimpleNameComponent(
      pubkey: event.pubKey,
      textStyle: TextStyle(
        fontSize: bodyLargeFontSize,
        color: themeData.appBarTheme.titleTextStyle!.color,
      ),
    );
    appBarTitleList.add(nameComponnet);
    appBarTitleList.add(Text(" : "));
    appBarTitleList.add(Expanded(
        child: Text(
      event.content.replaceAll("\n", " ").replaceAll("\r", " "),
      style: TextStyle(
        overflow: TextOverflow.ellipsis,
        fontSize: bodyLargeFontSize,
      ),
    )));
    return Container(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: appBarTitleList,
      ),
    );
  }
}

class _ThreadDetailRouter extends CustState<ThreadDetailRouter>
    with PenddingEventsLaterFunction, WhenStopFunction {
  EventMemBox box = EventMemBox();

  Event? sourceEvent;

  bool showTitle = false;

  ScrollController _controller = ScrollController();

  double rootEventHeight = 120;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.offset > rootEventHeight * 0.8 && !showTitle) {
        setState(() {
          showTitle = true;
        });
      } else if (_controller.offset < rootEventHeight * 0.8 && showTitle) {
        setState(() {
          showTitle = false;
        });
      }
    });
  }

  GlobalKey sourceEventKey = GlobalKey();

  void initFromArgs() {
    // do some init oper
    var eventRelation = EventRelation.fromEvent(sourceEvent!);
    rootId = eventRelation.rootId;
    if (rootId == null) {
      // source event is root event
      rootId = sourceEvent!.id;
      rootEvent = sourceEvent!;
    }

    // load sourceEvent replies and avoid blank page
    var eventReactions = eventReactionsProvider.get(sourceEvent!.id);
    if (eventReactions != null && eventReactions.replies.isNotEmpty) {
      box.addList(eventReactions.replies);
    } else if (rootEvent == null) {
      box.add(sourceEvent!);
    }
    listToTree(refresh: false);
  }

  @override
  Widget doBuild(BuildContext context) {
    if (sourceEvent == null) {
      var obj = RouterUtil.routerArgs(context);
      if (obj != null && obj is Event) {
        sourceEvent = obj;
      }
      if (sourceEvent == null) {
        RouterUtil.back(context);
        return Container();
      }

      initFromArgs();
    } else {
      var obj = RouterUtil.routerArgs(context);
      if (obj != null && obj is Event) {
        if (obj.id != sourceEvent!.id) {
          // arg change! reset.
          sourceEvent = null;
          rootId = null;
          rootEvent = null;
          box = EventMemBox();
          rootSubList = [];

          sourceEvent = obj;
          initFromArgs();
          doQuery();
        }
      }
    }

    var themeData = Theme.of(context);
    var bodyLargeFontSize = themeData.textTheme.bodyLarge!.fontSize;
    var titleTextColor = themeData.appBarTheme.titleTextStyle!.color;
    var cardColor = themeData.cardColor;

    Widget? appBarTitle;
    if (showTitle && rootEvent != null) {
      appBarTitle = ThreadDetailRouter.detailAppBarTitle(rootEvent!, themeData);
    }

    Widget? rootEventWidget;
    if (rootEvent == null) {
      rootEventWidget = Selector<SingleEventProvider, Event?>(
          builder: (context, event, child) {
        if (event == null) {
          return EventLoadListComponent();
        }

        return EventListComponent(
          event: event,
          jumpable: false,
          showVideo: true,
          imageListMode: false,
          showLongContent: true,
        );
      }, selector: (context, provider) {
        return provider.getEvent(rootId!);
      });
    } else {
      rootEventWidget = EventListComponent(
        event: rootEvent!,
        jumpable: false,
        showVideo: true,
        imageListMode: false,
        showLongContent: true,
      );
    }

    List<Widget> mainList = [];

    mainList.add(WidgetSize(
      child: rootEventWidget,
      onChange: (size) {
        rootEventHeight = size.height;
      },
    ));

    for (var item in rootSubList!) {
      var totalLevelNum = item.totalLevelNum;
      var needWidth = (totalLevelNum - 1) *
              (Base.BASE_PADDING +
                  ThreadDetailItemMainComponent.BORDER_LEFT_WIDTH) +
          ThreadDetailItemMainComponent.EVENT_MAIN_MIN_WIDTH;
      if (needWidth > mediaDataCache.size.width) {
        mainList.add(SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: needWidth,
            child: ThreadDetailItemComponent(
              item: item,
              totalMaxWidth: needWidth,
              sourceEventId: sourceEvent!.id,
              sourceEventKey: sourceEventKey,
            ),
          ),
        ));
      } else {
        mainList.add(ThreadDetailItemComponent(
          item: item,
          totalMaxWidth: needWidth,
          sourceEventId: sourceEvent!.id,
          sourceEventKey: sourceEventKey,
        ));
      }
    }

    Widget main = ListView(
      controller: _controller,
      children: mainList,
    );

    if (PlatformUtil.isTableMode()) {
      main = GestureDetector(
        onVerticalDragUpdate: (detail) {
          _controller.jumpTo(_controller.offset - detail.delta.dy);
        },
        behavior: HitTestBehavior.translucent,
        child: main,
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () {
            RouterUtil.back(context);
          },
          child: Icon(
            Icons.arrow_back_ios,
            color: themeData.appBarTheme.titleTextStyle!.color,
          ),
        ),
        // actions: [
        //   IconButton(
        //     onPressed: () {},
        //     icon: Icon(Icons.more_horiz),
        //   ),
        // ],
        title: appBarTitle,
      ),
      body: EventReplyCallback(
        child: main,
        onReplyCallback: onReplyCallback,
      ),
    );
  }

  @override
  Future<void> onReady(BuildContext context) async {
    doQuery();
  }

  void doQuery() {
    if (StringUtil.isNotBlank(rootId)) {
      // if (rootEvent == null) {
      //   // source event isn't root event，query root event
      //   var filter = Filter(ids: [rootId!]);
      //   nostr!.query([filter.toJson()], onRootEvent);
      // }

      // query sub events
      var filter = Filter(e: [
        rootId!
      ], kinds: [
        kind.EventKind.TEXT_NOTE,
        kind.EventKind.FILE_HEADER,
        kind.EventKind.POLL,
        kind.EventKind.ZAP,
      ]);
      nostr!.query([filter.toJson()], onEvent);
    }
  }

  String? rootId;

  Event? rootEvent;

  List<ThreadDetailEvent>? rootSubList = [];

  // void onRootEvent(Event event) {
  //   setState(() {
  //     rootEvent = event;
  //   });
  // }

  void onEvent(Event event) {
    if (event.kind == kind.EventKind.ZAP && StringUtil.isBlank(event.content)) {
      return;
    }

    later(event, (list) {
      box.addList(list);
      listToTree();
      eventReactionsProvider.onEvents(list);
    }, null);
  }

  void listToTree({bool refresh = true}) {
    // event in box had been sorted. The last one is the oldest.
    var all = box.all();
    var length = all.length;
    List<ThreadDetailEvent> _rootSubList = [];
    // key - id, value - item
    Map<String, ThreadDetailEvent> itemMap = {};
    for (var i = length - 1; i > -1; i--) {
      var event = all[i];
      var item = ThreadDetailEvent(event: event);
      itemMap[event.id] = item;
    }

    for (var i = length - 1; i > -1; i--) {
      var event = all[i];
      var relation = EventRelation.fromEvent(event);
      var item = itemMap[event.id]!;

      if (relation.replyId == null) {
        _rootSubList.add(item);
      } else {
        var replyItem = itemMap[relation.replyId];
        if (replyItem == null) {
          _rootSubList.add(item);
        } else {
          replyItem.subItems.add(item);
        }
      }
    }

    rootSubList = _rootSubList;
    for (var rootSub in rootSubList!) {
      rootSub.handleTotalLevelNum(0);
    }

    if (refresh) {
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   Scrollable.ensureVisible(sourceEventKey.currentContext!);
      // });
      whenStop(() {
        if (sourceEventKey.currentContext != null) {
          Scrollable.ensureVisible(sourceEventKey.currentContext!);
        }
      });

      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
    disposeLater();
  }

  onReplyCallback(Event event) {
    onEvent(event);
  }
}
