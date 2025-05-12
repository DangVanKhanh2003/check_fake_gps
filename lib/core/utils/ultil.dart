class  Util {
  // Hàm đếm số lần xuất hiện nhiều nhất trong list double
  static int countMostFrequentOccurrences(List<double> values) {
    // Tạo một Map để đếm số lần xuất hiện của từng giá trị
    Map<double, int> frequencyMap = {};

    // Duyệt qua từng giá trị trong list và đếm tần suất xuất hiện
    for (var value in values) {
      frequencyMap[value] = (frequencyMap[value] ?? 0) + 1;
    }

    // Tìm số lần xuất hiện lớn nhất
    int maxFrequency = 0;

    frequencyMap.forEach((key, value) {
      if (value > maxFrequency) {
        maxFrequency = value;
      }
    });

    return maxFrequency;
  }
   static T? getMostFrequentValue<T>(List<T> list) {
    if (list.isEmpty) {
      return null;
    }

    final counts = <T, int>{};
    for (final item in list) {
      counts[item] = (counts[item] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return null;
    }

    T? mostFrequentItem;
    int maxCount = 0;

    counts.forEach((item, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequentItem = item;
      }
    });

    return mostFrequentItem;
  }
}
