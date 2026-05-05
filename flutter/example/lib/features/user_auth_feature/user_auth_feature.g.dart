// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_auth_feature.dart';

final class AuthStateComponent extends Component<AuthState> {
  AuthStateComponent() : super(AuthState.unknown);
}

final class LoginProcessComponent extends Component<AuthProcess<dynamic>> {
  LoginProcessComponent() : super(const AuthProcess.idle());
}

final class LogoutProcessComponent extends Component<AuthProcess<dynamic>> {
  LogoutProcessComponent() : super(const AuthProcess.idle());
}

final class ReloadProcessComponent extends Component<AuthProcess<dynamic>> {
  ReloadProcessComponent() : super(const AuthProcess.idle());
}

final class LogoutEvent extends Event {}

final class ReloadUserEvent extends Event {}

final class LoginEvent extends DataEvent<AuthCredentials> {}

final class LoginHandlerReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo {
    return const {LoginEvent};
  }

  @override
  Set<Type> get interactsWith {
    return const {LoginProcessComponent, AuthStateComponent};
  }

  @override
  bool get reactsIf {
    return get<LoginProcessComponent>().value.isRunning == false;
  }

  @override
  void react() {
    _performLogin(get<LoginEvent>().data);
  }

  void _performLogin(AuthCredentials credentials) async {
    try {
      get<LoginProcessComponent>().value = const AuthProcess.running();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('auth_state', AuthState.loggedIn.name);
      await Future.delayed(const Duration(seconds: 2));
      get<AuthStateComponent>().value = AuthState.loggedIn;
      get<LoginProcessComponent>().value = const AuthProcess.success('mock_token');
    } catch (e) {
      get<LoginProcessComponent>().value = AuthProcess.failure(e.toString());
    }
  }
}

final class LogoutHandlerReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo {
    return const {LogoutEvent};
  }

  @override
  Set<Type> get interactsWith {
    return const {LogoutProcessComponent, AuthStateComponent};
  }

  @override
  bool get reactsIf {
    return get<LogoutProcessComponent>().value.isRunning == false;
  }

  @override
  void react() {
    _performLogout();
  }

  void _performLogout() async {
    get<LogoutProcessComponent>().value = const AuthProcess.running();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('auth_state', AuthState.loggedOut.name);
      await Future.delayed(const Duration(seconds: 1));
      get<AuthStateComponent>().value = AuthState.loggedOut;
      get<LogoutProcessComponent>().value = const AuthProcess.success(null);
    } catch (e) {
      get<LogoutProcessComponent>().value = AuthProcess.failure(e.toString());
    }
  }
}

final class ReloadHandlerReactiveSystem extends ReactiveSystem {
  @override
  Set<Type> get reactsTo {
    return const {ReloadUserEvent};
  }

  @override
  Set<Type> get interactsWith {
    return const {ReloadProcessComponent, AuthStateComponent};
  }

  @override
  bool get reactsIf {
    return get<ReloadProcessComponent>().value.isRunning == false;
  }

  @override
  void react() {
    _performReload();
  }

  void _performReload() async {
    get<ReloadProcessComponent>().value = const AuthProcess.running();
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString('auth_state');
      get<AuthStateComponent>().value = value == null ? AuthState.loggedOut : AuthState.values.byName(value);
      get<ReloadProcessComponent>().value = const AuthProcess.success(null);
    } catch (e) {
      get<ReloadProcessComponent>().value = AuthProcess.failure(e.toString());
    }
  }
}

final class UserAuthFeatureOrchestration extends Orchestration {
  UserAuthFeatureOrchestration() {
    add(AuthStateComponent());
    add(LoginProcessComponent());
    add(LogoutProcessComponent());
    add(ReloadProcessComponent());
    add(LogoutEvent());
    add(ReloadUserEvent());
    add(LoginEvent());
    add(LoginHandlerReactiveSystem());
    add(LogoutHandlerReactiveSystem());
    add(ReloadHandlerReactiveSystem());
  }
}
