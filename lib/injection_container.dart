import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import 'core/network/api_client.dart';
import 'core/utils/logger.dart';
import 'injection_container.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  await getIt.reset();
  await getIt.init();
}

@module
abstract class ExternalModule {
  @lazySingleton
  Connectivity get connectivity => Connectivity();

  @lazySingleton
  Dio dio(AppLogger logger) {
    final dio = Dio(buildBaseOptions());
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        logPrint: (value) => logger.info(value.toString()),
      ),
    );
    return dio;
  }

  @lazySingleton
  Logger logger() => Logger();

  @lazySingleton
  Battery battery() => Battery();

  @preResolve
  Future<HiveInterface> hive() async {
    await Hive.initFlutter();
    return Hive;
  }
}
