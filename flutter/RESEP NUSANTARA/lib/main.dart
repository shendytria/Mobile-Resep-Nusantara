import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'screens/landing_page.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/favorite_screen.dart';
import 'screens/add_recipe_screen.dart';
import 'screens/edit_recipe_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile/profile_page.dart';
import 'screens/profile/edit_profile_page.dart';
import 'screens/profile/collections_page.dart';
import 'screens/profile/collection_detail_page.dart';
import 'providers/recipe_provider.dart';
import 'providers/cart_provider.dart';
import 'themes/app_theme.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => RecipeProvider()),
        ChangeNotifierProvider(create: (ctx) => CartProvider()),
      ],
      child: const RecipeApp(),
    ),
  );
}

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Resep',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false, // Sudah nonaktif, tidak perlu ubah
      // Tambahkan debugPaintSizeEnabled: false untuk mencegah overlay debug
      debugShowMaterialGrid: false,
      showSemanticsDebugger: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Pastikan tidak ada overlay debug tambahan
          ),
          child: child!,
        );
      },
      initialRoute: '/landing',
      routes: {
        '/landing': (context) => const LandingPage(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return HomeScreen(username: args['username']);
        },
        '/recipe-detail': (context) => const RecipeDetailScreen(),
        '/cart': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return CartScreen(username: args['username']);
        },
        '/favorites': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return FavoriteScreen(username: args['username']);
        },
        '/add-recipe': (context) => const AddRecipeScreen(),
        '/profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ProfilePage(username: args['username']);
        },
        '/edit-profile': (context) => EditProfilePage(),
        '/edit-recipe': (context) => const EditRecipeScreen(),
      },
    );
  }
}