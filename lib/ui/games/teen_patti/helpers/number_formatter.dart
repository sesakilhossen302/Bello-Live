class NumberFormatter {
  static String format(int number) {
    if (number >= 1000000) {
      final millions = number / 1000000;
      if (millions == millions.toInt()) {
        return '${millions.toInt()}M';
      }
      return '${millions.toStringAsFixed(1)}M';
    } else if (number >= 10000) {
      final thousands = number / 1000;
      if (thousands == thousands.toInt()) {
        return '${thousands.toInt()}k';
      }
      return '${thousands.toStringAsFixed(1)}k';
    } else if (number >= 1000) {
      final thousands = number / 1000;
      if (thousands == thousands.toInt()) {
        return '${thousands.toInt()}k';
      }
      return '${thousands.toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}
