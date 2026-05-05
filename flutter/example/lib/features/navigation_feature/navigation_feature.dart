import 'package:flutter/material.dart';
import 'package:orchestra/orchestra.dart';

import '../user_auth_feature/user_auth_feature.dart';

part 'models/app_routes.dart';
part 'navigation_feature.g.dart';

final navigationFeature = Composer.createOrchestration();

final appRoute = navigationFeature.addComponent(AppRoutes.home);

final selectedRoute = navigationFeature.addComponent(AppRoutes.home);

final navigatorKey = navigationFeature.addDependency(GlobalKey<NavigatorState>());

final navigateToDashboardWhenLoggedIn = navigationFeature.addReactiveSystem(
  reactsTo: {authState},
  reactsIf: () {
    return authState.value == AuthState.loggedIn;
  },
  react: () {
    selectedRoute.value = AppRoutes.dashboard;
  },
);

final handleNavigateToLoginWhenLoggedOut = navigationFeature.addReactiveSystem(
  reactsTo: {authState},
  reactsIf: () {
    return authState.value == AuthState.loggedOut;
  },
  react: () {
    selectedRoute.value = AppRoutes.login;
  },
);

final handleNavigateToSelectedRoute = navigationFeature.addReactiveSystem(
  reactsTo: {selectedRoute},
  react: () {
    final route = selectedRoute.value.path;
    final key = navigatorKey.value.currentState!;
    key.pushReplacementNamed(route);
  },
);

