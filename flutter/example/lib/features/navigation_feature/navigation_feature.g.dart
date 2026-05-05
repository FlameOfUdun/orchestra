// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_feature.dart';

final class AppRouteComponent extends Component<AppRoutes> {
  AppRouteComponent() : super(AppRoutes.home);
}

final class SelectedRouteComponent extends Component<AppRoutes> {
  SelectedRouteComponent() : super(AppRoutes.home);
}

final class NavigatorKeyDependency extends Dependency<GlobalKey<NavigatorState>> {
  NavigatorKeyDependency() : super(GlobalKey<NavigatorState>());
}

final class NavigateToDashboardWhenLoggedInReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo {
    return const {AuthStateComponent};
  }

  @override
  Set<Type> get interactsWith {
    return const {SelectedRouteComponent};
  }

  @override
  bool get reactsIf {
    return get<AuthStateComponent>().value == AuthState.loggedIn;
  }

  @override
  void react() {
    get<SelectedRouteComponent>().value = AppRoutes.dashboard;
  }
}

final class HandleNavigateToLoginWhenLoggedOutReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo {
    return const {AuthStateComponent};
  }

  @override
  Set<Type> get interactsWith {
    return const {SelectedRouteComponent};
  }

  @override
  bool get reactsIf {
    return get<AuthStateComponent>().value == AuthState.loggedOut;
  }

  @override
  void react() {
    get<SelectedRouteComponent>().value = AppRoutes.login;
  }
}

final class HandleNavigateToSelectedRouteReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo {
    return const {SelectedRouteComponent};
  }

  @override
  void react() {
    final route = get<SelectedRouteComponent>().value.path;
    final key = get<NavigatorKeyDependency>().value.currentState!;
    key.pushReplacementNamed(route);
  }
}

final class NavigationFeatureOrchestration extends Orchestration {
  NavigationFeatureOrchestration() {
    add(AppRouteComponent());
    add(SelectedRouteComponent());
    add(NavigatorKeyDependency());
    add(NavigateToDashboardWhenLoggedInReactiveSystem());
    add(HandleNavigateToLoginWhenLoggedOutReactiveSystem());
    add(HandleNavigateToSelectedRouteReactiveSystem());
  }
}
