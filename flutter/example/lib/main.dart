import 'package:flutter/material.dart';
import 'package:orchestra_flutter/orchestra_flutter.dart';

import 'features/navigation_feature/navigation_feature.dart';
import 'features/timer_feature/timer_feature.dart';
import 'features/user_auth_feature/user_auth_feature.dart';
import 'pages/dashboard_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(_Application());
}

final class _Application extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OrchestraScope(
      name: 'ApplicationScope',
      orchestrations: {
        NavigationFeatureOrchestration(),
        UserAuthFeatureOrchestration(),
        TimerFeatureOrchestration(),
      },
      child: OrchestraBuilder(
        builder: (context, orchestra) {
          return MaterialApp(
            navigatorKey: orchestra.get<NavigatorKeyDependency>().value,
            routes: {
              '/': (context) => const HomePage(),
              '/dashboard': (context) => const DashboardPage(),
              '/login': (context) => const LoginPage(),
            },
          );
        },
      ),
    );
  }
}
