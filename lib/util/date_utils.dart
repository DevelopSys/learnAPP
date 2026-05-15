import 'package:intl/intl.dart';

String formatDateEs(String? date) {
  if (date == null || date.isEmpty) return '-';

  try {
    final parsed = DateTime.parse(date);
    return DateFormat('dd/MM/yyyy').format(parsed);
  } catch (e) {
    return date;
  }
}