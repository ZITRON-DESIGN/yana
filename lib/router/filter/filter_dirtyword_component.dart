import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:yana/main.dart';
import 'package:yana/provider/filter_provider.dart';
import 'package:provider/provider.dart';

import '../../utils/base.dart';
import '../../i18n/i18n.dart';
import '../../utils/string_util.dart';

class BlockedWordsComponent extends StatefulWidget {
  const BlockedWordsComponent({super.key});

  @override
  State<StatefulWidget> createState() {
    return _FilterDirtywordComponent();
  }
}

class _FilterDirtywordComponent extends State<BlockedWordsComponent> {
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var s = I18n.of(context);
    var _filterProvider = Provider.of<FilterProvider>(context);
    var dirtywordList = _filterProvider.dirtywordList;

    List<Widget> list = [];
    for (var dirtyword in dirtywordList) {
      list.add(FilterDirtywordItemComponent(word: dirtyword));
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.maxFinite,
            padding: EdgeInsets.all(Base.BASE_PADDING),
            child: Wrap(
              children: list,
              spacing: Base.BASE_PADDING,
              runSpacing: Base.BASE_PADDING,
            ),
          ),
        ),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.abc),
            hintText: s.Input_word,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: addDirtyWord,
            ),
          ),
        ),
      ],
    );
  }

  void addDirtyWord() {
    var word = controller.text;
    word = word.trim();
    if (StringUtil.isBlank(word)) {
      BotToast.showText(text: I18n.of(context).Word_can_t_be_null);
      return;
    }

    filterProvider.addDirtyword(word);
    controller.clear();
    FocusScope.of(context).unfocus();
  }
}

class FilterDirtywordItemComponent extends StatefulWidget {
  String word;

  FilterDirtywordItemComponent({super.key, required this.word});

  @override
  State<StatefulWidget> createState() {
    return _FilterDirtywordItemComponent();
  }
}

class _FilterDirtywordItemComponent
    extends State<FilterDirtywordItemComponent> {
  bool showDel = false;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    var cardColor = themeData.cardColor;
    var mainColor = themeData.primaryColor;
    var fontColor = themeData.appBarTheme.titleTextStyle!.color;

    List<Widget> list = [
      GestureDetector(
        onTap: () {
          setState(() {
            showDel = true;
          });
        },
        child: Container(
          padding: EdgeInsets.only(
            left: Base.BASE_PADDING_HALF,
            right: Base.BASE_PADDING_HALF,
            top: 4,
            bottom: 4,
          ),
          decoration: BoxDecoration(
            color: mainColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.word,
            style: TextStyle(
              color: fontColor,
            ),
          ),
        ),
      )
    ];

    if (showDel) {
      list.add(GestureDetector(
        onTap: () {
          filterProvider.removeDirtyword(widget.word);
        },
        child: Icon(
          Icons.delete,
          color: Colors.red,
        ),
      ));
    }

    return Stack(
      alignment: Alignment.center,
      children: list,
    );
  }
}
