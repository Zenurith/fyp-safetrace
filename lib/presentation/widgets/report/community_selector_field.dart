import 'package:flutter/material.dart';
import '../../../data/models/community_model.dart';
import '../../../utils/app_theme.dart';

class CommunitySelectorField extends StatelessWidget {
  final List<CommunityModel> communities;
  final String? selectedCommunityId;
  final ValueChanged<String?> onCommunitySelected;

  const CommunitySelectorField({
    super.key,
    required this.communities,
    required this.selectedCommunityId,
    required this.onCommunitySelected,
  });

  String get _selectedLabel {
    if (selectedCommunityId == null) return 'Public';
    final match = communities.where((c) => c.id == selectedCommunityId);
    return match.isNotEmpty ? match.first.name : 'Public';
  }

  void _showSheet(BuildContext context) {
    String query = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = communities.where((c) {
              return query.isEmpty ||
                  c.name.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search communities...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.cardBorder),
                        ),
                      ),
                      onChanged: (v) => setSheetState(() => query = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (query.isEmpty ||
                            'public'.contains(query.toLowerCase()))
                          ListTile(
                            leading: const Icon(Icons.public),
                            title: const Text('Public'),
                            selected: selectedCommunityId == null,
                            selectedColor: AppTheme.primaryRed,
                            onTap: () {
                              onCommunitySelected(null);
                              Navigator.pop(ctx);
                            },
                          ),
                        ...filtered.map((community) => ListTile(
                              leading: const Icon(Icons.group),
                              title: Text(community.name),
                              selected: selectedCommunityId == community.id,
                              selectedColor: AppTheme.primaryRed,
                              onTap: () {
                                onCommunitySelected(community.id);
                                Navigator.pop(ctx);
                              },
                            )),
                        if (filtered.isEmpty &&
                            !('public'.contains(query.toLowerCase())))
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No communities found.',
                              style: AppTheme.caption,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Share to Communities',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showSheet(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.cardBorder),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  selectedCommunityId == null ? Icons.public : Icons.group,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down,
                    color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
