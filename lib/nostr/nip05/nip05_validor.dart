import 'package:dio/dio.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';

class Nip05Validor {
  static Map<String, int> _checking = {};

  static var dio = Dio();

  static Future<bool?> valid(String nip05Address, String pubkey) async {
    if (_checking[nip05Address] != null) {
      return null;
    }

    try {
      _checking[nip05Address] = 1;
      return _doValid(nip05Address, pubkey);
    } finally {
      _checking.remove(nip05Address);
    }
  }

  static Future<bool> _doValid(String nip05Address, String pubkey) async {
    var name = "_";
    var address = nip05Address;
    var strs = nip05Address.split("@");
    if (strs.length > 1) {
      name = strs[0];
      address = strs[1];
    }

    var url = "https://$address/.well-known/nostr.json?name=$name";
    try {
      var response = await dio.get(url);

      if (response.data != null) {
        Map<String, dynamic> data;
        if (response.data is! Map && response.data is String) {
          data = json.decode(response.data);
        } else {
          data = response.data;
        }
        if (data["names"] != null) {
          var dataPubkey = data["names"][name];
          if (dataPubkey != null && dataPubkey == pubkey) {
            return true;
          }
        }
      }
    } on DioException catch (ex) {
      if (kDebugMode) {
        print(ex.error);
      }
    }

    return false;
  }
}
