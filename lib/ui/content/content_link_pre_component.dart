import 'package:flutter/material.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart';
import 'package:yana/main.dart';
import 'package:yana/provider/link_preview_data_provider.dart';
import 'package:provider/provider.dart';

import '../../utils/base.dart';
import '../webview_router.dart';

class ContentLinkPreComponent extends StatefulWidget {
  String link;

  ContentLinkPreComponent({required this.link});

  @override
  State<StatefulWidget> createState() {
    return _ContentLinkPreComponent();
  }
}

class _ContentLinkPreComponent extends State<ContentLinkPreComponent> {
  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    var cardColor = themeData.cardColor;

    return Selector<LinkPreviewDataProvider, PreviewData?>(
      builder: (context, data, child) {
        return Container(
          margin: const EdgeInsets.all(Base.BASE_PADDING),
          decoration: BoxDecoration(
            color: cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 0),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: LinkPreview(
            enableAnimation: true,
            onPreviewDataFetched: (data) {
              // Save preview data
              linkPreviewDataProvider.set(widget.link, data);
            },
            previewData: data,
            text: widget.link,
            width: mediaDataCache.size.width,
            onLinkPressed: (link) {
              WebViewRouter.open(context, link);
            },
          ),
        );
      },
      selector: (context, _provider) {
        return _provider.getPreviewData(widget.link);
      },
    );
  }
}
