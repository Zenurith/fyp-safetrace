import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../widgets/admin/admin_users_tab.dart';
import '../widgets/admin/admin_incidents_tab.dart';
import '../widgets/admin/admin_categories_tab.dart';
import '../widgets/admin/admin_analytics_tab.dart';
import '../widgets/export_dialog.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundGrey,
        appBar: AppBar(
          title: Text(
            'Admin Dashboard',
            style: AppTheme.headingMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export Reports',
              onPressed: () => ExportDialog.show(context),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppTheme.primaryRed,
            indicatorWeight: 3,
            isScrollable: true,
            labelStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Users'),
              Tab(text: 'Incidents'),
              Tab(text: 'Categories'),
              Tab(text: 'Analytics'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminUsersTab(),
            AdminIncidentsTab(),
            AdminCategoriesTab(),
            AdminAnalyticsTab(),
          ],
        ),
      ),
    );
  }
}
