import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:yana/provider/dm_provider.dart';
import 'package:yana/provider/pc_router_fake_provider.dart';
import 'package:yana/router/follow/notifications_router.dart';
import 'package:yana/ui/cust_state.dart';
import 'package:yana/ui/pc_router_fake.dart';
import 'package:yana/utils/base_consts.dart';
import 'package:yana/utils/index_taps.dart';
import 'package:yana/utils/platform_util.dart';
import 'package:yana/utils/string_util.dart';

import '../../i18n/i18n.dart';
import '../../main.dart';
import '../../models/event_mem_box.dart';
import '../../provider/follow_event_provider.dart';
import '../../provider/follow_new_event_provider.dart';
import '../../provider/index_provider.dart';
import '../../provider/setting_provider.dart';
import '../../utils/auth_util.dart';
import '../dm/dm_router.dart';
import '../edit/editor_router.dart';
import '../follow/follow_index_router.dart';
import '../login/login_router.dart';
import '../search/search_router.dart';
import 'index_app_bar.dart';
import 'index_bottom_bar.dart';
import 'index_drawer_content.dart';

class IndexRouter extends StatefulWidget {
  Function reload;

  IndexRouter({super.key, required this.reload});

  @override
  State<StatefulWidget> createState() {
    return _IndexRouter();
  }
}

class _IndexRouter extends CustState<IndexRouter>
    with TickerProviderStateMixin {
  static double PC_MAX_COLUMN_0 = 200;

  static double PC_MAX_COLUMN_1 = 550;

  late TabController followTabController;

  late TabController dmTabController;

  bool _scrollingDown = false;

  @override
  void initState() {
    super.initState();
    int followInitTab = 0;
    int globalsInitTab = 0;

    if (settingProvider.defaultTab != null) {
      if (settingProvider.defaultIndex == 1) {
        globalsInitTab = settingProvider.defaultTab!;
      } else {
        followInitTab = settingProvider.defaultTab!;
      }
    }

    followTabController =
        TabController(initialIndex: followInitTab, length: 3, vsync: this);
    dmTabController = TabController(length: 3, vsync: this);
  }

  @override
  Future<void> onReady(BuildContext context) async {
    if (settingProvider.lockOpen == OpenStatus.OPEN && !unlock) {
      doAuth();
    } else {
      setState(() {
        unlock = true;
      });
    }
  }

  bool unlock = false;

  @override
  Widget doBuild(BuildContext context) {
    mediaDataCache.update(context);
    var s = I18n.of(context);

    var _settingProvider = Provider.of<SettingProvider>(context);
    var _followEventProvider = Provider.of<FollowEventProvider>(context);
    var _followEventNewProvider = Provider.of<FollowNewEventProvider>(context);
    var _indexProvider = Provider.of<IndexProvider>(context);

    if (nostr == null) {
      return LoginRouter();
    }

    if (!unlock) {
      return Scaffold();
    }

    _indexProvider.setFollowTabController(followTabController);

    scrollDirectionCallback(direction) {
      if (direction == ScrollDirection.idle && _scrollingDown) {
        _scrollingDown = false;
      }
      if (direction == ScrollDirection.reverse && !_scrollingDown) {
        setState(() {
          _scrollingDown = true;
        });
      }
      if (direction == ScrollDirection.forward && _scrollingDown) {
        setState(() {
          _scrollingDown = false;
        });
      }
    }

    _indexProvider.addScrollListener(scrollDirectionCallback);

    var themeData = Theme.of(context);
    var titleTextColor = themeData.appBarTheme.titleTextStyle!.color;
    var titleTextStyle = TextStyle(
      fontWeight: FontWeight.normal,
      color: titleTextColor,
    );
    Color? indicatorColor = titleTextColor;
    if (PlatformUtil.isPC()) {
      indicatorColor = themeData.primaryColor;
    }

    dmTabController.addListener(() {
      setState(() {
        _scrollingDown = false;
      });
    });

    Widget? appBarCenter;
    if (_indexProvider.currentTap == IndexTaps.FOLLOW) {
      appBarCenter = TabBar(
        indicatorColor: const Color(0xFF6A1B9A),
        indicatorWeight: 2,
        tabs: [
          Container(
            height: IndexAppBar.height,
            alignment: Alignment.center,
            child: Selector<FollowNewEventProvider, EventMemBox>(
              builder: (context, eventMemBox, child) {
                Text text = Text(
                  s.Posts,
                  style: titleTextStyle,
                );
                if (eventMemBox.length() <= 0) {
                  return text;
                }
                return Badge(
                    offset: const Offset(16, -4),
                    label: Text(eventMemBox.length().toString(),
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: const Color(0xFF6A1B9A),
                    child: text);
              },
              selector: (context, _provider) {
                return _provider.eventPostsMemBox;
              },
            ),
          ),
          Container(
            height: IndexAppBar.height,
            alignment: Alignment.center,
            child: Selector<FollowNewEventProvider, EventMemBox>(
              builder: (context, eventMemBox, child) {
                Text text = Text(
                  s.Following_replies,
                  style: titleTextStyle,
                );
                if (eventMemBox.length() <= 0) {
                  return text;
                }
                return Badge(
                    offset: const Offset(16, -4),
                    label: Text(eventMemBox.length().toString(),
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: const Color(0xFF6A1B9A),
                    child: text);
              },
              selector: (context, _provider) {
                return _provider.eventPostsAndRepliesMemBox;
              },
            ),
          ),
          Container(
            height: IndexAppBar.height,
            alignment: Alignment.center,
            child: Text(
              s.Global,
              style: titleTextStyle,
            ),
          ),
        ],
        controller: followTabController,
      );
    } else if (_indexProvider.currentTap == IndexTaps.NOTIFICATIONS) {
      appBarCenter = Center(
        child: Text(
          s.Notifications,
          style: titleTextStyle,
        ),
      );
    } else if (_indexProvider.currentTap == IndexTaps.SEARCH) {
      appBarCenter = Center(
        child: Text(
          s.Search,
          style: titleTextStyle,
        ),
      );
    } else if (_indexProvider.currentTap == IndexTaps.DM) {
      appBarCenter = TabBar(
        controller: dmTabController,
        indicatorColor: const Color(0xFF6A1B9A),
        indicatorWeight: 2,
        tabs: [
          Container(
            height: IndexAppBar.height,
            alignment: Alignment.center,
            child: Selector<DMProvider, int>(
              builder: (context, count, child) {
                Text text = Text(
                  s.Following,
                  style: themeData.appBarTheme.titleTextStyle,
                );
                if (count <= 0) {
                  return text;
                }
                return Badge(
                    offset: const Offset(16, -4),
                    label: Text(count.toString(),
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: const Color(0xFF6A1B9A),
                    child: text);
              },
              selector: (context, _provider) {
                return _provider.howManyNewDMSessionsWithNewMessages(
                    _provider.followingList);
              },
            ),
          ),
          Container(
              height: IndexAppBar.height,
              alignment: Alignment.center,
              child: Selector<DMProvider, int>(
                builder: (context, count, child) {
                  Text text = Text(
                    s.Others,
                    style: themeData.appBarTheme.titleTextStyle,
                  );
                  if (count <= 0) {
                    return text;
                  }
                  return Badge(
                      offset: const Offset(16, -4),
                      label: Text(count.toString(),
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: const Color(0xFF6A1B9A),
                      child: text);
                },
                selector: (context, _provider) {
                  return _provider
                      .howManyNewDMSessionsWithNewMessages(_provider.knownList);
                },
              )),
          Container(
              height: IndexAppBar.height,
              alignment: Alignment.center,
              child: Selector<DMProvider, int>(
                builder: (context, count, child) {
                  Text text = Text(
                    s.Requests,
                    style: themeData.appBarTheme.titleTextStyle,
                  );
                  if (count <= 0) {
                    return text;
                  }
                  return Badge(
                      offset: const Offset(16, -4),
                      label: Text(count.toString(),
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: const Color(0xFF6A1B9A),
                      child: text);
                },
                selector: (context, _provider) {
                  return _provider.howManyNewDMSessionsWithNewMessages(
                      _provider.unknownList);
                },
              )),
        ],
      );
    }

    var addBtn = FloatingActionButton(
      backgroundColor: themeData.primaryColor,
      child: Icon(Icons.add),
      onPressed: () {
        EditorRouter.open(context);
      },
    );

    var mainCenterWidget = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Expanded(
          child: IndexedStack(
        index: _indexProvider.currentTap,
        children: [
          FollowIndexRouter(
            tabController: followTabController,
          ),
          SearchRouter(),
          DMRouter(
            tabController: dmTabController,
            scrollCallback: scrollDirectionCallback,
          ),
          NotificationsRouter(),
          // NoticeRouter(),
        ],
      )),
    );

    var mainIndex = Column(
      children: [
        // AnimatedContainer(
        //     duration: const Duration(milliseconds: 300),
        //     curve: Curves.ease,
        //     height: _scrollingDown ? 0.0 : 80,
        //     child:
        IndexAppBar(
          center: appBarCenter,
          // )
        ),
        mainCenterWidget,
      ],
    );

    if (PlatformUtil.isTableMode()) {
      var maxWidth = mediaDataCache.size.width;
      double column0Width = maxWidth * 1 / 5;
      double column1Width = maxWidth * 2 / 5;
      if (column0Width > PC_MAX_COLUMN_0) {
        column0Width = PC_MAX_COLUMN_0;
      }
      if (column1Width > PC_MAX_COLUMN_1) {
        column1Width = PC_MAX_COLUMN_1;
      }

      return Scaffold(
        extendBody: true,
        floatingActionButton: addBtn,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Row(children: [
          SizedBox(
            width: column0Width,
            child: IndexDrawerContentComponent(reload: widget.reload),
          ),
          Container(
            width: column1Width,
            margin: const EdgeInsets.only(
              // left: 1,
              right: 1,
            ),
            child: mainIndex,
          ),
          Expanded(
            child: Selector<PcRouterFakeProvider, List<RouterFakeInfo>>(
              builder: (context, infos, child) {
                if (infos.isEmpty) {
                  return const Center();
                }

                List<Widget> pages = [];
                for (var info in infos) {
                  if (StringUtil.isNotBlank(info.routerPath) &&
                      routes[info.routerPath] != null) {
                    var builder = routes[info.routerPath];
                    if (builder != null) {
                      pages.add(PcRouterFake(
                        info: info,
                        child: builder(context),
                      ));
                    }
                  } else if (info.buildContent != null) {
                    pages.add(PcRouterFake(
                      info: info,
                      child: info.buildContent!(context),
                    ));
                  }
                }

                return IndexedStack(
                  index: pages.length - 1,
                  children: pages,
                );
              },
              selector: (context, _provider) {
                return _provider.routerFakeInfos;
              },
              shouldRebuild: (previous, next) {
                if (previous != next) {
                  return true;
                }
                return false;
              },
            ),
          )
        ]),
      );
    } else {
      return Scaffold(
          body: mainIndex,
          extendBody: true,
          floatingActionButton: AnimatedOpacity(
            opacity: _scrollingDown ? 0 : 1,
            curve: Curves.fastOutSlowIn,
            duration: const Duration(milliseconds: 400),
            child: addBtn,
          )
          //
          //     AnimatedContainer(
          //         curve: Curves.ease,
          //         duration: const Duration(milliseconds: 200),
          //         height: _scrollingDown ? 0.0 : 100,
          //         child:
          //     addBtn
          // )
          ,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          drawer: Drawer(
            child: IndexDrawerContentComponent(reload: widget.reload),
          ),
          //       extendBodyBehindAppBar: true,
          bottomNavigationBar: AnimatedOpacity(
              opacity: _scrollingDown ? 0 : 1,
              curve: Curves.fastOutSlowIn,
              duration: const Duration(milliseconds: 400),
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.ease,
                  height: _scrollingDown ? 0.0 : 50,
                  child: IndexBottomBar())));
    }
  }

  void doAuth() {
    AuthUtil.authenticate(
            context, I18n.of(context).Please_authenticate_to_use_app)
        .then((didAuthenticate) {
      if (didAuthenticate) {
        setState(() {
          unlock = true;
        });
      } else {
        doAuth();
      }
    });
  }
}
