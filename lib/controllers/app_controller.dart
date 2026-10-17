import 'package:get/get.dart';

import '../services/api_service.dart';

class AppController extends GetxController {
  AppController(this.api);

  final ApiService api;
  final ready = false.obs;

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      await api.loadSession();
    } finally {
      ready.value = true;
    }
  }
}
