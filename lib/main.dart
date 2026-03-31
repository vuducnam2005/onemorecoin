import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:onemorecoin/model/GroupModel.dart';
import 'package:onemorecoin/model/StorageStage.dart';
import 'package:onemorecoin/model/WalletModel.dart';
import 'package:onemorecoin/model/LoanModel.dart';

import 'package:onemorecoin/navigations/NavigationBottom_2.dart';
import 'package:onemorecoin/pages/Budget/editbudget/ListTransactionInBudget.dart';
import 'package:onemorecoin/pages/Budget/editbudget/DetailBudget.dart';
import 'package:onemorecoin/pages/HomeScreen.dart';
import 'package:onemorecoin/pages/LoginScreen.dart';
import 'package:onemorecoin/pages/RegisterScreen.dart';
import 'package:onemorecoin/pages/RootScreen.dart';
import 'package:onemorecoin/pages/Loan/LoanListScreen.dart';
import 'package:onemorecoin/pages/Loan/AddLoanScreen.dart';
import 'package:onemorecoin/pages/Loan/LoanDetailScreen.dart';
import 'package:onemorecoin/utils/theme_provider.dart';
import 'package:onemorecoin/utils/currency_provider.dart';
import 'package:onemorecoin/utils/language_provider.dart';
import 'package:onemorecoin/utils/app_localizations.dart';

import 'package:onemorecoin/pages/Transaction/edittransaction/DetailTransaction.dart';
import 'package:provider/provider.dart';
import 'model/BudgetModel.dart';
import 'model/TransactionModel.dart';
import 'model/ReminderModel.dart';
import 'model/AppNotificationModel.dart';
import 'utils/notification_helper.dart';
import 'services/background_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Cannot load .env file: $e");
  }
  await NotificationHelper.instance.init();
  BackgroundSync.instance.init();
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}



class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalLoaderOverlay(
      overlayWidgetBuilder: (_) {
        return Center(
          child: SpinKitCubeGrid(
            color: Colors.yellow,
            size: 50.0,
          ),
        );
      },
      overlayColor: Colors.grey.withValues(alpha: 0.8),
      child: MultiProvider(
          providers: [
            Provider(create: (context) => TransactionModelProxy()),
            Provider(create: (context) => BudgetModelProxy()),
            ChangeNotifierProvider(create: (context) => TransactionModelProxy()),
            ChangeNotifierProvider(create: (context) => BudgetModelProxy()),
            ChangeNotifierProvider(create: (context) => WalletModelProxy()),
            ChangeNotifierProvider(create: (context) => GroupModelProxy()),
            ChangeNotifierProvider(create: (context) => StorageStageProxy()),
            ChangeNotifierProvider(create: (context) => CurrencyProvider()),
            ChangeNotifierProvider(create: (context) => LanguageProvider()),
            ChangeNotifierProvider(create: (context) => ReminderProvider()),
            ChangeNotifierProvider(create: (context) => LoanProvider()),
            ChangeNotifierProvider(create: (context) => AppNotificationProvider()),
          ],
          child: Consumer2<ThemeProvider, LanguageProvider>(
            builder: (context, themeProvider, languageProvider, child) {
              return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'OnMoreCoin',
            initialRoute: '/',
            onGenerateRoute: (RouteSettings settings) {
              switch (settings.name) {
                case RootScreen.routeName:
                  return MaterialWithModalsPageRoute(
                    builder: (context) => const RootScreen(),
                    settings: settings,
                  );
                case LoginScreen.routeName:
                  return MaterialWithModalsPageRoute(
                    builder: (context) => const LoginScreen(),
                    settings: settings,
                  );
                case RegisterScreen.routeName:
                  return MaterialWithModalsPageRoute(
                    builder: (context) => const RegisterScreen(),
                    settings: settings,
                  );
                case '/home':
                  return MaterialWithModalsPageRoute(
                    builder: (context) => const NavigationBottom2(),
                    settings: settings,
                  );
                case '/HomeScreen':
                  return MaterialWithModalsPageRoute(
                    builder: (context) => const HomeScreen(
                      title: "HomeScreen",
                    ),
                    settings: settings,
                  );
                case '/DetailTransaction':
                  final args = settings.arguments as TransactionModel;
                  return MaterialWithModalsPageRoute(
                    builder: (context) =>  DetailTransaction(
                        transactionModel: args
                    ),
                    settings: settings,
                  );
                case '/DetailBudget':
                  final args = settings.arguments as BudgetModel;
                  return MaterialWithModalsPageRoute(
                    builder: (context) => DetailBudget(
                      budgetModel: args,
                    ),
                    settings: settings,
                  );
                case '/ListTransactionInBudget':
                  final args = settings.arguments as BudgetModel;
                  return MaterialWithModalsPageRoute(
                    builder: (context) => ListTransactionInBudget(
                      budgetModel: args,
                    ),
                    settings: settings,
                  );
                case '/LoanList':
                  return MaterialWithModalsPageRoute(
                    builder: (context) => const LoanListScreen(),
                    settings: settings,
                  );
                case '/AddLoan':
                  final args = settings.arguments;
                  if (args is LoanModel) {
                    return MaterialWithModalsPageRoute(
                      builder: (context) => AddLoanScreen(editLoan: args),
                      settings: settings,
                    );
                  }
                  return MaterialWithModalsPageRoute(
                    builder: (context) => AddLoanScreen(
                      defaultType: args is String ? args : 'borrow',
                    ),
                    settings: settings,
                  );
                case '/LoanDetail':
                  final args = settings.arguments as LoanModel;
                  return MaterialWithModalsPageRoute(
                    builder: (context) => LoanDetailScreen(loan: args),
                    settings: settings,
                  );

              }
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Center(
                    child: Text('No path for ${settings.name}'),
                  ),
                ),
                settings: settings,
              );
            },

            navigatorObservers: [ClearFocusOnPush()],
            theme: themeProvider.themeData,

            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('vi'),
              Locale('en'),
            ],
            locale: languageProvider.locale,
          );
        }
      )
      )
    );
  }
}

class ClearFocusOnPush extends NavigatorObserver{
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
