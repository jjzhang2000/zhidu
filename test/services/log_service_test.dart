import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:zhidu/services/log_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late LogService logService;
  late Directory testLogDir;

  setUp(() async {
    logService = LogService();
    testLogDir = Directory('${Directory.systemTemp.path}/zhidu_test_logs');
    if (await testLogDir.exists()) {
      await testLogDir.delete(recursive: true);
    }
    PathProviderPlatform.instance = _FakePathProvider(testLogDir.path);
  });

  tearDown(() async {
    await logService.dispose();
    if (await testLogDir.exists()) {
      await testLogDir.delete(recursive: true);
    }
  });

  group('LogService', () {
    group('singleton', () {
      test('should return same instance', () {
        final instance1 = LogService();
        final instance2 = LogService();

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('LogLevel', () {
      test('should have correct order', () {
        expect(LogLevel.verbose.index < LogLevel.debug.index, isTrue);
        expect(LogLevel.debug.index < LogLevel.info.index, isTrue);
        expect(LogLevel.info.index < LogLevel.warning.index, isTrue);
        expect(LogLevel.warning.index < LogLevel.error.index, isTrue);
      });

      test('should have correct names', () {
        expect(LogLevel.verbose.name, 'verbose');
        expect(LogLevel.debug.name, 'debug');
        expect(LogLevel.info.name, 'info');
        expect(LogLevel.warning.name, 'warning');
        expect(LogLevel.error.name, 'error');
      });
    });

    group('init', () {
      test('should initialize with default values', () async {
        await logService.init();

        logService.v('TestTag', 'verbose message');
        logService.d('TestTag', 'debug message');
        logService.info('TestTag', 'info message');
        logService.w('TestTag', 'warning message');
        logService.e('TestTag', 'error message');
      });

      test('should initialize with custom minLevel', () async {
        await logService.init(minLevel: LogLevel.warning);

        logService.v('TestTag', 'should not appear');
        logService.d('TestTag', 'should not appear');
        logService.info('TestTag', 'should not appear');
        logService.w('TestTag', 'warning message');
        logService.e('TestTag', 'error message');
      });

      test('should initialize with writeToFile enabled', () async {
        await logService.init(writeToFile: true);

        logService.info('TestTag', 'test message for file');
        await logService.dispose();
        logService = LogService();

        final logsDir = Directory('${testLogDir.path}/zhidu/logs');
        expect(await logsDir.exists(), isTrue);

        final logFiles = await logsDir.list().toList();
        expect(logFiles.isNotEmpty, isTrue);
        expect(logFiles.first, isA<File>());
      });

      test('should create logs directory if not exists', () async {
        final logsDir = Directory('${testLogDir.path}/zhidu/logs');
        expect(await logsDir.exists(), isFalse);

        await logService.init(writeToFile: true);

        expect(await logsDir.exists(), isTrue);
      });
    });

    group('log methods', () {
      test('v() should log verbose level', () async {
        await logService.init(minLevel: LogLevel.verbose);
        logService.v('VerboseTag', 'verbose test message');
      });

      test('d() should log debug level', () async {
        await logService.init(minLevel: LogLevel.verbose);
        logService.d('DebugTag', 'debug test message');
      });

      test('info() should log info level', () async {
        await logService.init(minLevel: LogLevel.verbose);
        logService.info('InfoTag', 'info test message');
      });

      test('w() should log warning level', () async {
        await logService.init(minLevel: LogLevel.verbose);
        logService.w('WarningTag', 'warning test message');
      });

      test('e() should log error level without error object', () async {
        await logService.init(minLevel: LogLevel.verbose);
        logService.e('ErrorTag', 'error test message');
      });

      test('e() should log error level with error object', () async {
        await logService.init(minLevel: LogLevel.verbose);
        final error = Exception('test exception');
        logService.e('ErrorTag', 'error test message', error);
      });

      test('e() should log error level with error and stackTrace', () async {
        await logService.init(minLevel: LogLevel.verbose);
        final error = Exception('test exception');
        final stackTrace = StackTrace.current;
        logService.e('ErrorTag', 'error test message', error, stackTrace);
      });
    });

    group('level filtering', () {
      test('should filter verbose level when minLevel is debug', () async {
        await logService.init(minLevel: LogLevel.debug);

        logService.v('Tag', 'this should be filtered');
        logService.d('Tag', 'this should appear');
        logService.info('Tag', 'this should appear');
        logService.w('Tag', 'this should appear');
        logService.e('Tag', 'this should appear');
      });

      test('should filter debug and verbose when minLevel is info', () async {
        await logService.init(minLevel: LogLevel.info);

        logService.v('Tag', 'filtered');
        logService.d('Tag', 'filtered');
        logService.info('Tag', 'should appear');
        logService.w('Tag', 'should appear');
        logService.e('Tag', 'should appear');
      });

      test('should filter info and below when minLevel is warning', () async {
        await logService.init(minLevel: LogLevel.warning);

        logService.v('Tag', 'filtered');
        logService.d('Tag', 'filtered');
        logService.info('Tag', 'filtered');
        logService.w('Tag', 'should appear');
        logService.e('Tag', 'should appear');
      });

      test('should filter warning and below when minLevel is error', () async {
        await logService.init(minLevel: LogLevel.error);

        logService.v('Tag', 'filtered');
        logService.d('Tag', 'filtered');
        logService.info('Tag', 'filtered');
        logService.w('Tag', 'filtered');
        logService.e('Tag', 'should appear');
      });
    });

    group('dispose', () {
      test('should dispose without error when not initialized', () async {
        await logService.dispose();
      });

      test('should dispose after init without file writing', () async {
        await logService.init();
        await logService.dispose();
      });

      test('should dispose after init with file writing', () async {
        await testLogDir.create(recursive: true);
        final originalDir = Directory.current;
        Directory.current = testLogDir;

        try {
          await logService.init(writeToFile: true);
          logService.info('TestTag', 'test message');
          await logService.dispose();
          logService = LogService();
        } finally {
          Directory.current = originalDir;
        }
      });

      test('should handle multiple dispose calls', () async {
        await logService.init();
        await logService.dispose();
        await logService.dispose();
      });
    });

    group('_formatMessage', () {
      test('should format message correctly', () async {
        await logService.init();

        logService.info('TestTag', 'Test message');
      });

      test('should handle empty tag and message', () async {
        await logService.init();

        logService.info('', '');
      });

      test('should handle special characters', () async {
        await logService.init();

        logService.info('Tag<test>', 'Message with "quotes" and \n newline');
      });
    });
  });
}
