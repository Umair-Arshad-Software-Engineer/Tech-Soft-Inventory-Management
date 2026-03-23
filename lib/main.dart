
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tech_soft/providers/CustomerPriceProvider.dart';
import 'package:tech_soft/providers/customer_ledger_provider.dart';
import 'package:tech_soft/providers/customer_provider.dart';
import 'package:tech_soft/providers/product_image_provider.dart';
import 'package:tech_soft/providers/product_provider.dart';
import 'package:tech_soft/providers/purchase_order_provider.dart';
import 'package:tech_soft/providers/purchase_receipt_provider.dart';
import 'package:tech_soft/providers/sale_provider.dart';
import 'package:tech_soft/providers/subcategory_provider.dart';
import 'package:tech_soft/providers/supplier_ledger_provider.dart';
import 'package:tech_soft/providers/supplier_provider.dart';
import 'package:tech_soft/providers/unit_provider.dart';
import 'package:tech_soft/screens/CategoryScreen.dart';
import 'package:tech_soft/screens/SupplierScreen.dart';
import 'package:tech_soft/screens/UnitScreen.dart';
import 'package:tech_soft/screens/customer_screen.dart';
import 'package:tech_soft/screens/dashboard.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/category_provider.dart';
import 'dart:io';


Future<void> startServer() async {
  try {
    await Process.start(
      'Tech-Soft-Server.exe',
      [],
      runInShell: true,
    );
  } catch (e) {
    print("Server start failed: $e");
  }
}
// void main() {
//   runApp(const MyApp());
// }
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await startServer(); // start Node.js server

  await Future.delayed(const Duration(seconds: 2)); // wait for server

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => UnitProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => SubcategoryProvider()),
        ChangeNotifierProvider(create: (_) => CustomerPriceProvider()),
        ChangeNotifierProvider(create: (_) => ProductImageProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseOrderProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseReceiptProvider()),
        ChangeNotifierProvider(create: (_) => SupplierLedgerProvider()),
        ChangeNotifierProvider(create: (_) => SaleProvider()),
        ChangeNotifierProvider(create: (_) => CustomerLedgerProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tech Soft',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C3AED),
            primary: const Color(0xFF7C3AED),
            secondary: const Color(0xFF6366F1),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF2D3142),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          dividerTheme: const DividerThemeData(
            color: Color(0xFFF0F0F5),
            thickness: 1,
            space: 0,
          ),
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const InventoryDashboardScreen(),
          '/categories': (context) => const CategoryScreen(), // Add category route
          '/units': (context) => const UnitScreen(), // Add this
          '/supplier': (context)=> const SupplierScreen(),
          '/customer': (context)=> const CustomerScreen(),

        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize auth provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading while initializing
        if (authProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFFFAFAFC),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF7C3AED),
              ),
            ),
          );
        }

        // Check if user is logged in
        if (authProvider.isLoggedIn) {
          return const InventoryDashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}//new