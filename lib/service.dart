import 'dart:convert';

import 'package:http/http.dart';

class HackService {
  Future<bool> onSendData(
      String device, double latitude, double longitude) async {
    String url =
        "https://beta.dadabayev.uz/hack/api.php?phoneName=$device&lat=$latitude&long=$longitude";

    var res = await get(Uri.parse(url));
    print(res.body);
    if (res.statusCode == 200) {
      var json = jsonDecode(res.body);
      return json['success'] || true;
    }
    return false;
  }
}
