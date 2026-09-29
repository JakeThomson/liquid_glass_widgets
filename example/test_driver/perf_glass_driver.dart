// Driver for integration_test/perf_glass_test.dart: turns every traced scene
// into a timeline summary and writes them all to build/glass-perf/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    timeout: const Duration(minutes: 45),
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      if (data == null) return;
      final directory = Directory('build/glass-perf');
      await directory.create(recursive: true);
      final summaries = <String, Object?>{};
      for (final entry in data.entries) {
        final timeline = Timeline.fromJson(
          (entry.value as Map).cast<String, dynamic>(),
        );
        summaries[entry.key] = TimelineSummary.summarize(timeline).summaryJson;
      }
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      await File('${directory.path}/summary-$stamp.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(summaries),
      );
    },
  );
}
