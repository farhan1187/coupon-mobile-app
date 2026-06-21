import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.provider.dart';
import '../models/site.dart';
import '../models/user.dart';
import '../models/coupon_profile.dart';

class SitesScreen extends StatefulWidget {
  const SitesScreen({super.key});

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  final _linkFormKey = GlobalKey<FormState>();
  AppUser? _linkTargetUser;
  Site? _linkTargetSite;

  bool _isCreating = false;
  bool _isLinking = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _handleCreateSite(AppStateProvider appState) async {
    if (!_createFormKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    try {
      await appState.addSite(
        _nameController.text.trim(),
        _locationController.text.trim(),
      );
      _nameController.clear();
      _locationController.clear();
    } catch (e) {
      // handled by provider toast
    } finally {
      setState(() => _isCreating = false);
    }
  }

  void _handleLinkUser(AppStateProvider appState) async {
    if (!_linkFormKey.currentState!.validate() || _linkTargetUser == null || _linkTargetSite == null) return;
    setState(() => _isLinking = true);

    try {
      await appState.linkUserToSite(_linkTargetUser!.id, _linkTargetSite!.id);
      setState(() {
        _linkTargetUser = null;
        _linkTargetSite = null;
      });
    } catch (e) {
      // handled by provider toast
    } finally {
      setState(() => _isLinking = false);
    }
  }

  void _confirmDeleteSite(BuildContext context, AppStateProvider appState, Site site) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Site', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${site.name}"? All associated data will be deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(context).pop();
              await appState.deleteSite(site.id);
            },
            child: const Text('Delete'),
          )
        ],
      ),
    );
  }

  Map<String, List<AppUser>> _getAssignedUsers(AppStateProvider appState, String siteId) {
    final userAssignments = appState.userSites.where((us) => us['siteId'] == siteId);
    final List<AppUser> list = userAssignments
        .map((us) => appState.users.firstWhere((u) => u.id == us['userId'], orElse: () => AppUser(id: '', username: '', password: '', role: '', name: '', twoFAEnabled: false)))
        .where((u) => u.id.isNotEmpty)
        .toList();

    final Map<String, List<AppUser>> grouped = {
      'Owner': [],
      'Manager': [],
      'Super Staff': [],
      'Staff': [],
      'Accountant': []
    };

    for (var u in list) {
      if (grouped.containsKey(u.role)) {
        grouped[u.role]!.add(u);
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final user = appState.currentUser;
    if (user == null) return const SizedBox();

    final isAdmin = user.role == 'Admin';
    final sitesList = appState.sites;

    // Filter team members excluding Admin for dropdown assignment
    final nonAdminUsers = appState.users.where((u) => u.role != 'Admin').toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Admin management widgets
            if (isAdmin) ...[
              // Create site & link members grids
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _createFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add New Site', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Site Name', hintText: 'e.g. Site D'),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Name required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(labelText: 'Location Address', hintText: 'e.g. Fujairah, UAE'),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Address required' : null,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isCreating ? null : () => _handleCreateSite(appState),
                          icon: _isCreating
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                              : const Icon(Icons.add, size: 16),
                          label: const Text('Create Site', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _linkFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Link User to Site', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AppUser>(
                          decoration: const InputDecoration(labelText: 'Select Team Member', border: OutlineInputBorder()),
                          value: _linkTargetUser,
                          items: nonAdminUsers.map((u) => DropdownMenuItem(value: u, child: Text('${u.name} (${u.role})'))).toList(),
                          onChanged: (val) => setState(() => _linkTargetUser = val),
                          validator: (val) => val == null ? 'Select a user' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Site>(
                          decoration: const InputDecoration(labelText: 'Select Destination Site', border: OutlineInputBorder()),
                          value: _linkTargetSite,
                          items: sitesList.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                          onChanged: (val) => setState(() => _linkTargetSite = val),
                          validator: (val) => val == null ? 'Select a site' : null,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isLinking ? null : () => _handleLinkUser(appState),
                          icon: _isLinking
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                              : const Icon(Icons.link, size: 16),
                          label: const Text('Link Member', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            const Text(
              'Active Site Tenancies',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (sitesList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Text('No sites configured yet.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...sitesList.map((site) {
                final groupedUsers = _getAssignedUsers(appState, site.id);
                final sitePricesList = appState.sitePrices.where((sp) => sp['siteId'] == site.id).toList();
                final assignedProfileIds = sitePricesList.map((sp) => sp['profileId'] as String).toSet();
                
                final unassignedProfiles = appState.couponProfiles.where((p) => !assignedProfileIds.contains(p.id)).toList();

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.business, size: 18, color: Color(0xFF6366F1)),
                                const SizedBox(width: 8),
                                Text(
                                  site.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Active', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                    onPressed: () => _confirmDeleteSite(context, appState, site),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  )
                                ]
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(site.location, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                          ],
                        ),
                        const Divider(height: 20),

                        // SMS Notification Toggle
                        if (isAdmin) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('SMS after sale', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Send coupon details to customer mobile', style: TextStyle(fontSize: 10.5)),
                            value: site.smsEnabled,
                            activeColor: Colors.green,
                            onChanged: (val) => appState.updateSiteSmsEnabled(site.id, val),
                          ),
                          const Divider(height: 16),
                        ],

                        // Linked members by role list
                        const Text('Linked Staff & Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        ...groupedUsers.keys.map((roleKey) {
                          final List<AppUser> users = groupedUsers[roleKey]!;
                          if (users.isEmpty) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  roleKey.toUpperCase(),
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.indigo),
                                ),
                                ...users.map((u) => Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(u.name, style: const TextStyle(fontSize: 12)),
                                        if (isAdmin)
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                            onPressed: () => appState.unlinkUserFromSite(u.id, site.id),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                          )
                                      ],
                                    )),
                              ],
                            ),
                          );
                        }).toList(),

                        const Divider(height: 20),

                        // Assigned Profiles Section
                        const Text('Assigned Coupon Profiles', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),

                        // Assign profile row
                        if (unassignedProfiles.isNotEmpty && isAdmin) ...[
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'Add profile to site',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: unassignedProfiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: (val) async {
                                      if (val != null) {
                                        await appState.assignProfileToSite(site.id, val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Profiles override list
                        if (sitePricesList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('No profiles assigned to this site.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                          )
                        else
                          ...sitePricesList.map((sp) {
                            final profId = sp['profileId'] as String;
                            final prof = appState.couponProfiles.firstWhere(
                              (p) => p.id == profId,
                              orElse: () => CouponProfile(id: profId, name: profId, validityDays: 0, price: 0, salePrice: 0, costPrice: 0, description: '', status: ''),
                            );
                            
                            final costController = TextEditingController(text: '${(sp['costPrice'] as double).toInt()}');
                            final saleController = TextEditingController(text: '${(sp['salePrice'] as double).toInt()}');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(prof.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 50,
                                    height: 30,
                                    child: TextField(
                                      controller: costController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 11),
                                      decoration: const InputDecoration(labelText: 'Cost', contentPadding: EdgeInsets.all(4)),
                                      onSubmitted: (val) {
                                        final newCost = double.tryParse(val) ?? sp['costPrice'] as double;
                                        appState.updateSitePrice(site.id, prof.id, sp['salePrice'] as double, newCost);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 50,
                                    height: 30,
                                    child: TextField(
                                      controller: saleController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 11),
                                      decoration: const InputDecoration(labelText: 'Sale', contentPadding: EdgeInsets.all(4)),
                                      onSubmitted: (val) {
                                        final newSale = double.tryParse(val) ?? sp['salePrice'] as double;
                                        appState.updateSitePrice(site.id, prof.id, newSale, sp['costPrice'] as double);
                                      },
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                      onPressed: () => appState.unassignProfileFromSite(site.id, prof.id),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    )
                                  ]
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
