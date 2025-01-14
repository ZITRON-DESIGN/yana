import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/metadata.dart';
import '../../provider/metadata_provider.dart';
import '../../utils/router_path.dart';
import '../../utils/router_util.dart';
import '../simple_name_component.dart';
import 'content_str_link_component.dart';

class ContentMentionUserComponent extends StatefulWidget {
  String pubkey;

  ContentMentionUserComponent({super.key, required this.pubkey});

  @override
  State<StatefulWidget> createState() {
    return _ContentMentionUserComponent();
  }
}

class _ContentMentionUserComponent extends State<ContentMentionUserComponent> {
  @override
  Widget build(BuildContext context) {
    return Selector<MetadataProvider, Metadata?>(
      builder: (context, metadata, child) {
        String name =
            SimpleNameComponent.getSimpleName(widget.pubkey, metadata);

        return ContentStrLinkComponent(
          str: "@$name",
          showUnderline: false,
          onTap: () {
            RouterUtil.router(context, RouterPath.USER, widget.pubkey);
          },
        );
      },
      selector: (context, _provider) {
        return _provider.getMetadata(widget.pubkey);
      },
    );
  }
}
