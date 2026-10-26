import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/settings_repository.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return Dio(BaseOptions(
    baseUrl: settings.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
  ));
});