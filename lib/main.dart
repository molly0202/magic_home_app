import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Initializing Firebase...');
  await Firebase.initializeApp();
  print('Firebase initialized successfully');
  runApp(const MagicHomeApp());
}

class MagicHomeApp extends StatefulWidget {
  const MagicHomeApp({super.key});

  @override
  State<MagicHomeApp> createState() => _MagicHomeAppState();
}

class _MagicHomeAppState extends State<MagicHomeApp> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '441732602904-ib5itb3on72gkv6qffdjv6g58kgvmpnf.apps.googleusercontent.com',
  );
  GoogleSignInAccount? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('MagicHomeApp initState called');
    // Check if user is already signed in
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    print('Checking current user...');
    try {
      _user = await _googleSignIn.signInSilently();
      print('User already signed in: ${_user?.displayName}');
    } catch (error) {
      print('Error checking current user: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void updateUser(GoogleSignInAccount? user) {
    setState(() {
      _user = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('Building MagicHomeApp');
    return MaterialApp(
      title: 'Magic Home',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFBB04C)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFBB04C),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFBB04C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      home: _isLoading ? const LoadingScreen() : const WelcomeScreen(),
      onGenerateRoute: (settings) {
        print('Generating route for: ${settings.name}');
        if (settings.name == '/home') {
          final args = settings.arguments as Map<String, dynamic>?;
          print('Home route args: $args');
          return MaterialPageRoute(
            builder: (context) => HomeScreen(
              firebaseUser: args?['firebaseUser'],
              googleUser: args?['googleUser'],
              googleSignIn: args?['googleSignIn'],
            ),
          );
        }
        // Add other routes as needed
        return null;
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFBB04C),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final GoogleSignIn googleSignIn;
  final Function(GoogleSignInAccount?) onSignIn;

  const AuthScreen({
    super.key,
    required this.googleSignIn,
    required this.onSignIn,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _handleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });
    
    try {
      final account = await widget.googleSignIn.signIn();
      
      if (account == null) {
        // User canceled sign-in
        setState(() {
          _isSigningIn = false;
          _errorMessage = 'Sign in was canceled';
        });
        return;
      }
      
      widget.onSignIn(account);
      
      print('Successfully signed in: ${account.displayName}');
      
    } catch (error) {
      setState(() {
        _isSigningIn = false;
        _errorMessage = 'Sign in error: $error';
      });
      print('Error signing in with Google: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.home,
                size: 120,
                color: Color(0xFFFBB04C),
              ),
              const SizedBox(height: 20),
              const Text(
                'Magic Home',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your Smart Home Solution',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 60),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSigningIn ? null : _handleSignIn,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: _isSigningIn
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login),
                      SizedBox(width: 8),
                      Text('Sign in with Google'),
                    ],
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final firebase_auth.User? firebaseUser;
  final GoogleSignInAccount? googleUser;
  final GoogleSignIn? googleSignIn;

  const HomeScreen({
    super.key,
    this.firebaseUser,
    this.googleUser,
    this.googleSignIn,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  Future<void> _handleSignOut() async {
    try {
      if (widget.googleSignIn != null) {
        await widget.googleSignIn!.signOut();
      }
      if (widget.firebaseUser != null) {
        await firebase_auth.FirebaseAuth.instance.signOut();
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } catch (error) {
      print('Error signing out: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Magic Home (${widget.firebaseUser?.email ?? widget.googleUser?.email ?? "No user"})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFFBB04C),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    backgroundImage: widget.googleUser?.photoUrl != null 
                      ? NetworkImage(widget.googleUser!.photoUrl!) 
                      : null,
                    child: widget.googleUser?.photoUrl == null
                      ? Text(
                          (widget.googleUser?.displayName ?? widget.firebaseUser?.displayName ?? '?').substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        )
                      : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.googleUser?.displayName ?? widget.firebaseUser?.displayName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.googleUser?.email ?? widget.firebaseUser?.email ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() {
                  _selectedIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Devices'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() {
                  _selectedIndex = 1;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Routines'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() {
                  _selectedIndex = 2;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() {
                  _selectedIndex = 3;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                _handleSignOut();
              },
            ),
          ],
        ),
      ),
      body: _getScreenForIndex(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFBB04C),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
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
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
  
  Widget _getScreenForIndex(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const DevicesScreen();
      case 2:
        return const RoutinesScreen();
      case 3:
        return SettingsScreen(
          firebaseUser: widget.firebaseUser,
          googleUser: widget.googleUser,
        );
      default:
        return const DashboardScreen();
    }
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to Magic Home',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sunny, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Home Status',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusItem(
                          context,
                          'Temperature',
                          '23°C',
                          Icons.thermostat,
                          Colors.red,
                        ),
                      ),
                      Expanded(
                        child: _buildStatusItem(
                          context,
                          'Humidity',
                          '45%',
                          Icons.water_drop,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusItem(
                          context,
                          'Lights',
                          'On (4)',
                          Icons.lightbulb,
                          Colors.amber,
                        ),
                      ),
                      Expanded(
                        child: _buildStatusItem(
                          context,
                          'Security',
                          'Armed',
                          Icons.security,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Quick Controls',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  'All Lights',
                  Icons.lightbulb_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  'Thermostat',
                  Icons.thermostat,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  'Security',
                  Icons.shield,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Scenes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSceneCard('Good Morning', 'Activate your morning routine', Icons.wb_sunny),
          const SizedBox(height: 8),
          _buildSceneCard('Good Night', 'Prepare your home for bedtime', Icons.nights_stay),
          const SizedBox(height: 8),
          _buildSceneCard('Away', 'Set the home to away mode', Icons.directions_walk),
        ],
      ),
    );
  }
  
  Widget _buildStatusItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  
  Widget _buildQuickActionButton(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: 8),
          Text(title),
        ],
      ),
    );
  }
  
  Widget _buildSceneCard(String title, String subtitle, IconData icon) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFBB04C).withOpacity(0.2),
          child: Icon(icon, color: const Color(0xFFFBB04C)),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.play_circle_filled),
        onTap: () {},
      ),
    );
  }
}

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Your Devices',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildDeviceCategory('Lights', [
          DeviceItem('Living Room Light', true, Icons.lightbulb),
          DeviceItem('Kitchen Light', false, Icons.lightbulb),
          DeviceItem('Bedroom Light', false, Icons.lightbulb),
          DeviceItem('Bathroom Light', false, Icons.lightbulb),
        ]),
        const SizedBox(height: 16),
        _buildDeviceCategory('Climate', [
          DeviceItem('Thermostat', true, Icons.thermostat),
          DeviceItem('Air Purifier', true, Icons.air),
        ]),
        const SizedBox(height: 16),
        _buildDeviceCategory('Entertainment', [
          DeviceItem('Living Room TV', false, Icons.tv),
          DeviceItem('Smart Speaker', true, Icons.speaker),
        ]),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Device'),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
  
  Widget _buildDeviceCategory(String title, List<DeviceItem> devices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: devices.map((device) => _buildDeviceListTile(device)).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDeviceListTile(DeviceItem device) {
    return ListTile(
      leading: Icon(
        device.icon,
        color: device.isOn ? const Color(0xFFFBB04C) : Colors.grey,
      ),
      title: Text(device.name),
      trailing: Switch(
        value: device.isOn,
        activeColor: const Color(0xFFFBB04C),
        onChanged: (value) {},
      ),
    );
  }
}

class DeviceItem {
  final String name;
  final bool isOn;
  final IconData icon;
  
  DeviceItem(this.name, this.isOn, this.icon);
}

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Your Routines',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildRoutineCard(
          'Good Morning',
          'Every day at 7:00 AM',
          [
            'Turn on bedroom lights',
            'Adjust thermostat to 22°C',
            'Play morning news',
          ],
          Icons.wb_sunny,
          true,
        ),
        const SizedBox(height: 12),
        _buildRoutineCard(
          'Good Night',
          'Every day at 11:00 PM',
          [
            'Turn off all lights',
            'Lock all doors',
            'Set thermostat to 20°C',
          ],
          Icons.nights_stay,
          true,
        ),
        const SizedBox(height: 12),
        _buildRoutineCard(
          'Arrive Home',
          'When I arrive home',
          [
            'Turn on entryway lights',
            'Adjust thermostat to comfort mode',
            'Turn off security system',
          ],
          Icons.home,
          false,
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create Routine'),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
  
  Widget _buildRoutineCard(
    String title,
    String schedule,
    List<String> actions,
    IconData icon,
    bool isActive,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFBB04C).withOpacity(0.2),
                  child: Icon(icon, color: const Color(0xFFFBB04C)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            Text(
                        schedule,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  activeColor: const Color(0xFFFBB04C),
                  onChanged: (value) {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Actions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...actions.map((action) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFFFBB04C)),
                  const SizedBox(width: 8),
                  Text(action),
                ],
              ),
            )),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Run Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final GoogleSignInAccount? googleUser;
  final firebase_auth.User? firebaseUser;
  
  const SettingsScreen({super.key, this.googleUser, this.firebaseUser});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Account'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(googleUser?.email ?? firebaseUser?.email ?? ''),
                  ],
                ),
                isThreeLine: false,
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: googleUser?.photoUrl != null ? NetworkImage(googleUser!.photoUrl!) : null,
                  child: googleUser?.photoUrl == null
                    ? Text(
                        (googleUser?.displayName ?? firebaseUser?.displayName ?? '?').substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      )
                    : null,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Notifications'),
                subtitle: const Text('On'),
                leading: const Icon(Icons.notifications),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Language'),
                subtitle: const Text('English'),
                leading: const Icon(Icons.language),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Theme'),
                subtitle: const Text('Light'),
                leading: const Icon(Icons.brush),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Device Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Location Services'),
                subtitle: const Text('On'),
                leading: const Icon(Icons.location_on),
                trailing: Switch(
                  value: true,
                  activeColor: const Color(0xFFFBB04C),
                  onChanged: (value) {},
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Background Refresh'),
                subtitle: const Text('On'),
                leading: const Icon(Icons.refresh),
                trailing: Switch(
                  value: true,
                  activeColor: const Color(0xFFFBB04C),
                  onChanged: (value) {},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'About',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('App Version'),
                subtitle: const Text('1.0.0'),
                leading: const Icon(Icons.info),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Privacy Policy'),
                leading: const Icon(Icons.privacy_tip),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Terms of Service'),
                leading: const Icon(Icons.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Help & Support'),
                leading: const Icon(Icons.help),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
