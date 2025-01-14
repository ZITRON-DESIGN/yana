import 'package:flutter/material.dart';
import 'package:yana/ui/community_info_component.dart';
import 'package:yana/utils/base.dart';
import 'package:yana/provider/community_info_provider.dart';
import 'package:provider/provider.dart';
import 'package:widget_size/widget_size.dart';

import '../../nostr/event.dart';
import '../../nostr/filter.dart';
import '../../nostr/nip172/community_id.dart';
import '../../nostr/nip172/community_info.dart';
import '../../ui/cust_state.dart';
import '../../ui/event/event_list_component.dart';
import '../../ui/event_delete_callback.dart';
import '../../utils/base_consts.dart';
import '../../models/event_mem_box.dart';
import '../../main.dart';
import '../../provider/setting_provider.dart';
import '../../utils/peddingevents_later_function.dart';
import '../../utils/router_util.dart';
import '../../nostr/event_kind.dart' as kind;
import '../../utils/string_util.dart';
import '../edit/editor_router.dart';

class CommunityDetailRouter extends StatefulWidget {
  const CommunityDetailRouter({super.key});

  @override
  State<StatefulWidget> createState() {
    return _CommunityDetailRouter();
  }
}

class _CommunityDetailRouter extends CustState<CommunityDetailRouter>
    with PenddingEventsLaterFunction {
  EventMemBox box = EventMemBox();

  CommunityId? communityId;

  ScrollController _controller = ScrollController();

  bool showTitle = false;

  double infoHeight = 80;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.offset > infoHeight * 0.8 && !showTitle) {
        setState(() {
          showTitle = true;
        });
      } else if (_controller.offset < infoHeight * 0.8 && showTitle) {
        setState(() {
          showTitle = false;
        });
      }
    });
  }

  @override
  Widget doBuild(BuildContext context) {
    if (communityId == null) {
      var arg = RouterUtil.routerArgs(context);
      if (arg != null) {
        communityId = arg as CommunityId;
      }
    }
    if (communityId == null) {
      RouterUtil.back(context);
      return Container();
    }
    var _settingProvider = Provider.of<SettingProvider>(context);
    var themeData = Theme.of(context);
    var bodyLargeFontSize = themeData.textTheme.bodyLarge!.fontSize;

    Widget? appBarTitle;
    if (showTitle) {
      appBarTitle = Text(
        communityId!.title,
        style: TextStyle(
          fontSize: bodyLargeFontSize,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    Widget main = EventDeleteCallback(
      onDeleteCallback: onDeleteCallback,
      child: ListView.builder(
        controller: _controller,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Selector<CommunityInfoProvider, CommunityInfo?>(
                builder: (context, info, child) {
              if (info == null) {
                return Container();
              }

              return WidgetSize(
                onChange: (s) {
                  infoHeight = s.height;
                },
                child: CommunityInfoComponent(info: info!),
              );
            }, selector: (context, _provider) {
              return _provider.getCommunity(communityId!.toAString());
            });
          }

          var event = box.get(index - 1);
          if (event == null) {
            return null;
          }

          return EventListComponent(
            event: event,
            showVideo: _settingProvider.videoPreviewInList == OpenStatus.OPEN,
            showCommunity: false,
          );
        },
        itemCount: box.length() + 1,
      ),
    );

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
        actions: [
          GestureDetector(
            onTap: addToCommunity,
            child: Container(
              margin: const EdgeInsets.only(
                left: Base.BASE_PADDING,
                right: Base.BASE_PADDING,
              ),
              child: Icon(
                Icons.add,
                color: themeData.appBarTheme.titleTextStyle!.color,
              ),
            ),
          )
        ],
        title: appBarTitle,
      ),
      body: main,
    );
  }

  var infoSubscribeId = StringUtil.rndNameStr(16);

  var subscribeId = StringUtil.rndNameStr(16);

  // CommunityInfo? communityInfo;

  @override
  Future<void> onReady(BuildContext context) async {
    if (communityId != null) {
      // {
      //   var filter = Filter(kinds: [
      //     kind.EventKind.COMMUNITY_DEFINITION,
      //   ], authors: [
      //     communityId!.pubkey
      //   ], limit: 1);
      //   var queryArg = filter.toJson();
      //   queryArg["#d"] = [communityId!.title];
      //   nostr!.query([queryArg], (e) {
      //     if (communityInfo == null || communityInfo!.createdAt < e.createdAt) {
      //       var ci = CommunityInfo.fromEvent(e);
      //       if (ci != null) {
      //         setState(() {
      //           communityInfo = ci;
      //         });
      //       }
      //     }
      //   }, id: infoSubscribeId);
      // }
      queryEvents();
    }
  }

  void queryEvents() {
    var filter = Filter(kinds: [
      kind.EventKind.TEXT_NOTE,
      kind.EventKind.LONG_FORM,
      kind.EventKind.FILE_HEADER,
      kind.EventKind.POLL,
    ], limit: 100);
    var queryArg = filter.toJson();
    queryArg["#a"] = [communityId!.toAString()];
    nostr!.query([queryArg], onEvent, id: subscribeId);
  }

  void onEvent(Event event) {
    later(event, (list) {
      box.addList(list);
      setState(() {});
    }, null);
  }

  @override
  void dispose() {
    super.dispose();
    disposeLater();

    try {
      nostr!.unsubscribe(subscribeId);
    } catch (e) {}
  }

  onDeleteCallback(Event event) {
    box.delete(event.id);
    setState(() {});
  }

  Future<void> addToCommunity() async {
    if (communityId != null) {
      List<String> aTag = ["a", communityId!.toAString()];
      if (relayProvider.relayAddrs.isNotEmpty) {
        aTag.add(relayProvider.relayAddrs[0]);
      }

      var event = await EditorRouter.open(context, tags: [aTag]);
      if (event != null) {
        queryEvents();
      }
    }
  }
}
