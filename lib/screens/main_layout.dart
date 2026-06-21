import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.provider.dart';
import 'dashboard_screen.dart';
import 'pos_screen.dart';
import 'cash_collection_screen.dart';
import 'ledger_screen.dart';
import 'settings_screen.dart';
import 'inventory_screen.dart';
import 'sites_screen.dart';
import 'profiles_screen.dart';
import 'users_screen.dart';
import 'wallets_screen.dart';
import 'apiconsole_screen.dart';
import 'sales_log_screen.dart';
import 'sales_analytics_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _LoginFlickerGuard extends StatelessWidget {
  final Widget child;
  const _LoginFlickerGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _MainLayoutState extends State<MainLayout> {
  String _activePage = 'dashboard';

  Widget _getScreen(String page) {
    switch (page) {
      case 'dashboard':
        return const DashboardScreen();
      case 'sites':
        return const SitesScreen();
      case 'profiles':
        return const ProfilesScreen();
      case 'inventory':
        return const InventoryScreen();
      case 'sales_pos':
        return const PosScreen();
      case 'sales_log':
        return const SalesLogScreen();
      case 'collections':
        return const CashCollectionScreen();
      case 'wallets':
        return const WalletsScreen(initialTab: 0);
      case 'cashinhand':
        return const WalletsScreen(initialTab: 1);
      case 'ledger':
        return const LedgerScreen();
      case 'users':
        return const UsersScreen();
      case 'sales_analytics':
        return const SalesAnalyticsScreen();

      case 'settings':
        return const SettingsScreen();
      case 'apiconsole':
        return const ApiConsoleScreen();
      default:
        return const DashboardScreen();
    }
  }

  String _getPageTitle(String page, String role) {
    switch (page) {
      case 'dashboard':
        return 'Dashboard';
      case 'sites':
        return 'Sites';
      case 'profiles':
        return 'Coupon Profiles';
      case 'inventory':
        if (role == 'Staff') return 'Available Coupons';
        if (role == 'Super Staff') return 'My Coupons Stock';
        return 'Coupons Inventory';
      case 'sales_pos':
        return role == 'Admin' ? 'Sales Records' : 'Sell Coupons';
      case 'sales_log':
        return role == 'Staff' ? 'My Sales History' : 'Sales Log';
      case 'collections':
        if (role == 'Admin' || role == 'Manager') return 'Cash Collections';
        if (role == 'Owner') return 'Collections Logs';
        if (role == 'Super Staff') return 'Collect from Staff';
        return 'Collect Cash (Splits)';
      case 'wallets':
        if (role == 'Admin') return 'Wallets Overview';
        if (role == 'Accountant') return 'Sites Balances';
        if (role == 'Super Staff') return 'My Wallets';
        return 'My Wallet';
      case 'cashinhand':
        return 'Cash In Hand';
      case 'ledger':
        return 'Financial Ledger';
      case 'users':
        return 'User Directory';
      case 'sales_analytics':
        return role == 'Admin' ? 'Analytics Reports' : 'Sales Analytics';

      case 'settings':
        return 'Settings';
      case 'apiconsole':
        return 'REST API Console';
      default:
        return 'CouponOS';
    }
  }

  void _showNotificationsDialog(BuildContext context, AppStateProvider appState) {
    appState.clearUnreadNotifications();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: const EdgeInsets.only(top: 60, right: 16),
            child: Material(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 320,
                constraints: const BoxConstraints(maxHeight: 400),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Notifications Feed',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: appState.notifications.isEmpty
                          ? const Center(
                              child: Text(
                                'No recent notifications',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              itemCount: appState.notifications.length,
                              itemBuilder: (context, index) {
                                final n = appState.notifications[index];
                                final isWarning = n.type == 'WARNING';
                                
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isWarning ? Colors.amber.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isWarning ? Icons.warning_amber : Icons.notifications_none,
                                          size: 16,
                                          color: isWarning ? Colors.amber[700] : Colors.blue[700],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              n.message,
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              n.timestamp.substring(11, 16), // HH:MM
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final user = appState.currentUser;
    if (user == null) return const SizedBox();

    final accessibleSites = appState.getAccessibleSites();
    final isSeller = ['Staff', 'Super Staff'].contains(user.role);
    final isDark = appState.theme == 'dark';

    // Dynamic drawer menu structure grouped by role-based schema from Sidebar.jsx
    final List<Map<String, dynamic>> menuItems = [];

    final String role = user.role;

    // 1. Overview Group
    menuItems.add({'id': 'dashboard', 'title': 'Dashboard', 'icon': Icons.home, 'group': 'Overview'});
    if (role == 'Admin') {
      menuItems.add({'id': 'sites', 'title': 'Sites', 'icon': Icons.business, 'group': 'Overview'});
    }

    // 2. Coupons Group
    if (role == 'Admin') {
      menuItems.add({'id': 'profiles', 'title': 'Coupon Profiles', 'icon': Icons.layers_outlined, 'group': 'Coupons'});
      menuItems.add({'id': 'inventory', 'title': 'Coupons Inventory', 'icon': Icons.confirmation_number_outlined, 'group': 'Coupons'});
    } else if (role == 'Super Staff') {
      menuItems.add({'id': 'inventory', 'title': 'My Coupons Stock', 'icon': Icons.confirmation_number_outlined, 'group': 'Inventory'});
    } else if (role == 'Staff') {
      menuItems.add({'id': 'inventory', 'title': 'Available Coupons', 'icon': Icons.confirmation_number_outlined, 'group': 'Inventory'});
    }

    // 3. Operations / Performance / Monitoring / Treasury Group
    if (role == 'Admin') {
      menuItems.add({'id': 'wallets', 'title': 'Wallets Overview', 'icon': Icons.wallet, 'group': 'Financials'});
      menuItems.add({'id': 'collections', 'title': 'Cash Collections', 'icon': Icons.monetization_on_outlined, 'group': 'Financials'});
      menuItems.add({'id': 'ledger', 'title': 'Financial Ledger', 'icon': Icons.book_outlined, 'group': 'Financials'});
      
      menuItems.add({'id': 'users', 'title': 'User Directory', 'icon': Icons.people_outline, 'group': 'People & Sales'});
      menuItems.add({'id': 'sales_pos', 'title': 'Sales Records', 'icon': Icons.receipt, 'group': 'People & Sales'});
      menuItems.add({'id': 'sales_log', 'title': 'Sales Log', 'icon': Icons.book_outlined, 'group': 'People & Sales'});
    } else if (role == 'Owner') {
      menuItems.add({'id': 'sales_analytics', 'title': 'Sales Analytics', 'icon': Icons.receipt, 'group': 'Performance'});
      menuItems.add({'id': 'sales_log', 'title': 'Sales Log', 'icon': Icons.book_outlined, 'group': 'Performance'});
      menuItems.add({'id': 'collections', 'title': 'Collections Logs', 'icon': Icons.monetization_on_outlined, 'group': 'Performance'});
      menuItems.add({'id': 'cashinhand', 'title': 'Cash In Hand', 'icon': Icons.wallet, 'group': 'Performance'});
    } else if (role == 'Manager') {
      menuItems.add({'id': 'sales_analytics', 'title': 'Sales Analytics', 'icon': Icons.receipt, 'group': 'Monitoring'});
      menuItems.add({'id': 'sales_log', 'title': 'Sales Log', 'icon': Icons.book_outlined, 'group': 'Monitoring'});
      menuItems.add({'id': 'collections', 'title': 'Cash Collections', 'icon': Icons.monetization_on_outlined, 'group': 'Monitoring'});
      menuItems.add({'id': 'cashinhand', 'title': 'Cash In Hand', 'icon': Icons.wallet, 'group': 'Monitoring'});
    } else if (role == 'Super Staff') {
      menuItems.add({'id': 'sales_pos', 'title': 'Sell Coupons', 'icon': Icons.receipt, 'group': 'My Operations'});
      menuItems.add({'id': 'sales_log', 'title': 'Sales Log', 'icon': Icons.book_outlined, 'group': 'My Operations'});
      menuItems.add({'id': 'collections', 'title': 'Collect from Staff', 'icon': Icons.monetization_on_outlined, 'group': 'My Operations'});
      menuItems.add({'id': 'cashinhand', 'title': 'Cash In Hand', 'icon': Icons.wallet, 'group': 'My Operations'});
      menuItems.add({'id': 'wallets', 'title': 'My Wallets', 'icon': Icons.wallet, 'group': 'My Wallet'});
    } else if (role == 'Staff') {
      menuItems.add({'id': 'sales_pos', 'title': 'Sell Coupons', 'icon': Icons.receipt, 'group': 'My Work'});
      menuItems.add({'id': 'sales_log', 'title': 'My Sales History', 'icon': Icons.book_outlined, 'group': 'My Work'});
      menuItems.add({'id': 'wallets', 'title': 'My Wallet', 'icon': Icons.wallet, 'group': 'My Balance'});
    } else if (role == 'Accountant') {
      menuItems.add({'id': 'collections', 'title': 'Collect Cash (Splits)', 'icon': Icons.monetization_on_outlined, 'group': 'Treasury'});
      menuItems.add({'id': 'wallets', 'title': 'Sites Balances', 'icon': Icons.wallet, 'group': 'Treasury'});
      menuItems.add({'id': 'ledger', 'title': 'Financial Ledger', 'icon': Icons.book_outlined, 'group': 'Treasury'});
      menuItems.add({'id': 'sales_analytics', 'title': 'Sales Analytics', 'icon': Icons.receipt, 'group': 'Treasury'});
      menuItems.add({'id': 'cashinhand', 'title': 'Cash In Hand', 'icon': Icons.wallet, 'group': 'Treasury'});
    }

    // 4. System Logs Group
    if (role == 'Admin') {
      menuItems.add({'id': 'sales_analytics', 'title': 'Analytics Reports', 'icon': Icons.bar_chart, 'group': 'System Logs'});
      menuItems.add({'id': 'settings', 'title': 'Settings', 'icon': Icons.settings_outlined, 'group': 'System Logs'});
      menuItems.add({'id': 'apiconsole', 'title': 'REST API Console', 'icon': Icons.terminal, 'group': 'System Logs'});
    }

    // Group items by group label for UI rendering
    final Map<String, List<Map<String, dynamic>>> groupedMenu = {};
    for (var item in menuItems) {
      final String g = item['group'] as String;
      groupedMenu.putIfAbsent(g, () => []).add(item);
    }

    // Determine bottom nav items based on role (matching Dashboard, POS, Collection, Ledger/History if accessible)
    final List<BottomNavigationBarItem> bottomNavItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Dashboard'),
    ];

    if (isSeller) {
      bottomNavItems.add(const BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: 'POS'));
    } else {
      bottomNavItems.add(const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Sales'));
    }

    bottomNavItems.add(const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Collect'));

    if (role == 'Staff' || role == 'Super Staff') {
      bottomNavItems.add(const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'));
    } else {
      bottomNavItems.add(const BottomNavigationBarItem(icon: Icon(Icons.history_edu), label: 'Ledger'));
    }

    // Map activePage string to bottom nav index
    int bottomNavIndex = -1;
    if (_activePage == 'dashboard') {
      bottomNavIndex = 0;
    } else if (role == 'Staff' || role == 'Super Staff') {
      if (_activePage == 'sales_pos') {
        bottomNavIndex = 1;
      } else if (_activePage == 'collections') {
        bottomNavIndex = 2;
      } else if (_activePage == 'sales_log') {
        bottomNavIndex = 3;
      }
    } else {
      if (_activePage == 'sales_pos' || _activePage == 'sales_log') {
        bottomNavIndex = 1;
      } else if (_activePage == 'collections') {
        bottomNavIndex = 2;
      } else if (_activePage == 'ledger') {
        bottomNavIndex = 3;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getPageTitle(_activePage, role),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          // Site Selector dropdown in AppBar (if Admin/Global role or has multiple sites)
          if (accessibleSites.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: appState.selectedSiteId,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                      dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      items: [
                        if (AppStateProvider.globalRoles.contains(user.role))
                          const DropdownMenuItem(value: 'all', child: Text('All Sites')),
                        if (!AppStateProvider.globalRoles.contains(user.role) && accessibleSites.isEmpty)
                          const DropdownMenuItem(value: 'none', child: Text('No Assigned Site')),
                        ...accessibleSites.map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            )),
                      ],
                      onChanged: (val) {
                        if (val != null) appState.setSelectedSiteId(val);
                      },
                    ),
                  ),
                ),
              ),
            ),

          // Theme Toggle
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
            onPressed: appState.toggleTheme,
          ),

          // Notifications Feed
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, size: 20),
                onPressed: () => _showNotificationsDialog(context, appState),
              ),
              if (appState.unreadNotifications)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // Drawer Header with User details
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.black87],
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
              accountName: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                'Role: ${user.role}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            
            // Drawer Items Grouped
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: groupedMenu.keys.map((groupName) {
                  final items = groupedMenu[groupName]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 4.0),
                        child: Text(
                          groupName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[600],
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      ...items.map((item) {
                        final isSelected = _activePage == item['id'];
                        return ListTile(
                          dense: true,
                          selectedTileColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.07),
                          selectedColor: isDark ? Colors.white : Colors.black,
                          leading: Icon(
                            item['icon'] as IconData,
                            color: isSelected ? (isDark ? Colors.white : Colors.black) : null,
                            size: 20,
                          ),
                          title: Text(
                            item['title'] as String,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? (isDark ? Colors.white : Colors.black) : null,
                            ),
                          ),
                          selected: isSelected,
                          onTap: () {
                            setState(() => _activePage = item['id'] as String);
                            Navigator.of(context).pop();
                          },
                        );
                      }).toList(),
                      const Divider(height: 12),
                    ],
                  );
                }).toList(),
              ),
            ),
            
            // Drawer Footer
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_outlined, color: Colors.redAccent),
              title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.of(context).pop();
                appState.logoutUser();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: _LoginFlickerGuard(
        child: _getScreen(_activePage),
      ),
      bottomNavigationBar: bottomNavIndex >= 0
          ? BottomNavigationBar(
              currentIndex: bottomNavIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontSize: 10),
              items: bottomNavItems,
              onTap: (index) {
                String page = 'dashboard';
                if (index == 0) {
                  page = 'dashboard';
                } else if (index == 1) {
                  page = isSeller ? 'sales_pos' : 'sales_log';
                } else if (index == 2) {
                  page = 'collections';
                } else if (index == 3) {
                  page = (role == 'Staff' || role == 'Super Staff') ? 'sales_log' : 'ledger';
                }
                setState(() => _activePage = page);
              },
            )
          : null,
    );
  }
}
