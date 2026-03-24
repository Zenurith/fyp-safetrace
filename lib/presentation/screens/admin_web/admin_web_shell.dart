import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../providers/flag_provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/system_config_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/admin_web/admin_sidebar.dart';
import '../../widgets/admin_web/admin_header.dart';
import '../../widgets/admin_web/responsive_layout.dart';
import 'admin_dashboard_page.dart';
import 'users_management_page.dart';
import 'incidents_management_page.dart';
import 'categories_management_page.dart';
import 'communities_management_page.dart';
import 'flags_management_page.dart';
import 'analytics_page.dart';
import 'system_config_page.dart';

class AdminWebShell extends StatefulWidget {
  const AdminWebShell({super.key});

  @override
  State<AdminWebShell> createState() => _AdminWebShellState();
}

class _AdminWebShellState extends State<AdminWebShell> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  final List<String> _pageTitles = [
    'Dashboard',
    'User Management',
    'Incident Management',
    'Category Management',
    'Community Management',
    'Flag Management',
    'Analytics',
    'System Configuration',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize all providers for admin panel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start listening to ALL incidents (including old ones) for admin
      context.read<IncidentProvider>().startListeningAll();
      // Start listening to communities
      context.read<CommunityProvider>().startListening();
      // Start listening to flags for badge count
      context.read<FlagProvider>().startListeningPending();
      context.read<FlagProvider>().startListening();
      context.read<SystemConfigProvider>().startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    if (user == null || !user.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access denied.',
            style: TextStyle(fontFamily: AppTheme.fontFamily),
          ),
        ),
      );
    }

    final isMobile = ResponsiveLayout.isMobile(context);

    // Auto-collapse sidebar on mobile
    if (isMobile && _sidebarExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _sidebarExpanded = false);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Row(
        children: [
          // Sidebar
          AdminSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            expanded: _sidebarExpanded,
            onToggleExpanded: () {
              setState(() => _sidebarExpanded = !_sidebarExpanded);
            },
          ),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Header
                AdminHeader(title: _pageTitles[_selectedIndex]),

                // Page content with IndexedStack to preserve state
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      AdminDashboardPage(
                        onNavigate: (index) => setState(() => _selectedIndex = index),
                      ),
                      const UsersManagementPage(),
                      const IncidentsManagementPage(),
                      const CategoriesManagementPage(),
                      const CommunitiesManagementPage(),
                      const FlagsManagementPage(),
                      const AnalyticsPage(),
                      const SystemConfigPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
