import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/hotel_screen.dart';
import 'screens/deals_screen.dart';
import 'screens/profile_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://mrulzaiktzljosdgfivt.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ydWx6YWlrdHpsam9zZGdmaXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3MTIyMDMsImV4cCI6MjA5ODI4ODIwM30.oNLeGVXQ6TwIsGFtLAl5VXrGyKHVn-BGN2yvLBADVUA',
  );
  
  // Seed initial categories & places in Supabase if empty
  await DatabaseService().checkAndSeedData();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CLOUDMOOD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primary,
          primary: AppTheme.primary,
        ),
        scaffoldBackgroundColor: AppTheme.background,
        useMaterial3: true,
      ),
      home: const CloudmoodMainShell(),
    );
  }
}

class CloudmoodMainShell extends StatefulWidget {
  const CloudmoodMainShell({super.key});

  @override
  State<CloudmoodMainShell> createState() => _CloudmoodMainShellState();
}

class _CloudmoodMainShellState extends State<CloudmoodMainShell> {
  int _currentIndex = 0;

  // Render current body based on bottom navigation index
  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return CloudmoodHomeScreen(
          onProfileTap: () {
            setState(() {
              _currentIndex = 4; // Switch to profile tab
            });
          },
        );
      case 1:
        return const CloudmoodHotelScreen();
      case 3:
        return const CloudmoodDealsScreen();
      case 4:
        return const CloudmoodProfileScreen();
      default:
        return CloudmoodHomeScreen(
          onProfileTap: () {
            setState(() {
              _currentIndex = 4;
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
