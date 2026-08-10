import 'package:flutter/widgets.dart';

import 'app/app_controller.dart';
import 'app/user_manager.dart';
import 'ui/adapty_recipes_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(AdaptyRecipesApp(controller: AppController(userManager: UserManager())));
}
