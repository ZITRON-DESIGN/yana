import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yana/nostr/nip19/nip19.dart';
import 'package:yana/main.dart';
import 'package:yana/provider/filter_provider.dart';
import 'package:provider/provider.dart';

import '../../utils/base.dart';
import '../../i18n/i18n.dart';

class BlockedProfilesComponent extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _FilterBlockComponent();
  }
}

class _FilterBlockComponent extends State<BlockedProfilesComponent> {
  @override
  Widget build(BuildContext context) {
    var _filterProvider = Provider.of<FilterProvider>(context);
    var blockMap = _filterProvider.blocks;
    var blocks = blockMap.keys.toList();
    // print(blocks);
    return Container(
      child: ListView.builder(
        itemBuilder: (context, index) {
          var pubkey = blocks[index];
          return FilterBlockItemComponent(pubkey: pubkey);
        },
        itemCount: blocks.length,
      ),
    );
  }
}

class FilterBlockItemComponent extends StatelessWidget {
  String pubkey;

  FilterBlockItemComponent({required this.pubkey});

  @override
  Widget build(BuildContext context) {
    var s = I18n.of(context);
    var themeData = Theme.of(context);
    var cardColor = themeData.cardColor;

    var nip19Pubkey = Nip19.encodePubKey(pubkey);
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: nip19Pubkey)).then((_) {
          BotToast.showText(text: s.key_has_been_copy);
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: Base.BASE_PADDING_HALF),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.all(Base.BASE_PADDING),
        child: Row(children: [
          Expanded(child: Text(nip19Pubkey)),
          GestureDetector(
            onTap: delBlock,
            child: Container(
              margin: EdgeInsets.only(left: Base.BASE_PADDING_HALF),
              child: Icon(
                Icons.delete,
              ),
            ),
          )
        ]),
      ),
    );
  }

  void delBlock() {
    filterProvider.removeBlock(pubkey);
  }
}
