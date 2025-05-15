import 'package:flutter/material.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MagicHomeApp());
}

class MagicHomeApp extends StatefulWidget {
  const MagicHomeApp({super.key});

  @override
  State<MagicHomeApp> createState() => _MagicHomeAppState();
}

class _MagicHomeAppState extends State<MagicHomeApp> {
  final AuthService _authService = AuthService();
  User? _currentUser;
  
  @override
  void initState() {
    super.initState();
    _authService.userStream.listen((user) {
      setState(() {
        _currentUser = user;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magic Home',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFBB04C)),
        useMaterial3: true,
      ),
      home: _currentUser != null ? const HomeScreen() : const WelcomeScreen(),
    );
  }
  
  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const DevicesScreen(),
    const RoutinesScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Magic Home'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Devices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Routines',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lightbulb, size: 100, color: Colors.amber),
          const SizedBox(height: 20),
          const Text(
            'Your Smart Devices',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Device'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add device functionality will be implemented soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule, size: 100, color: Colors.purple),
          const SizedBox(height: 20),
          const Text(
            'Automation Routines',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create Routine'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Routine creation will be implemented soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const ListTile(
          title: Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          leading: Icon(Icons.person),
        ),
        const Divider(),
        ListTile(
          title: const Text('App Theme'),
          subtitle: const Text('Light'),
          leading: const Icon(Icons.brightness_6),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        ),
        ListTile(
          title: const Text('Notifications'),
          subtitle: const Text('Enabled'),
          leading: const Icon(Icons.notifications),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        ),
        const Divider(),
        const ListTile(
          title: Text('About', style: TextStyle(fontWeight: FontWeight.bold)),
          leading: Icon(Icons.info),
        ),
        ListTile(
          title: const Text('Version'),
          subtitle: const Text('1.0.0'),
          leading: const Icon(Icons.numbers),
          onTap: () {},
        ),
        ListTile(
          title: const Text('Privacy Policy'),
          leading: const Icon(Icons.privacy_tip),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        ),
      ],
    );
  }
}
