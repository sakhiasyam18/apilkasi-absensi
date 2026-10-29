import 'package:dio/dio.dart';

class ErrorUtils {
  static String getErrorMessage(dynamic e, [String fallback = 'Terjadi kesalahan']) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map) {
          return detail['message']?.toString() ?? detail['code']?.toString() ?? fallback;
        } else if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first.containsKey('msg')) {
            return first['msg'].toString();
          }
          return detail.toString();
        } else if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      } else if (data is String && data.isNotEmpty) {
        return data;
      }
      return e.message ?? fallback;
    }
    return e?.toString() ?? fallback;
  }
}
