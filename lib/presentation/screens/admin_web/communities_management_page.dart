import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/community_model.dart';
import '../../../data/models/community_member_model.dart';
import '../../../utils/app_theme.dart';
import '../../providers/community_provider.dart';

class CommunitiesManagementPage extends StatefulWidget {
  const CommunitiesManagementPage({super.key});

  @override
  State<CommunitiesManagementPage> createState() => _CommunitiesManagementPageState();
}

class _CommunitiesManagementPageState extends State<CommunitiesManagementPage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Start listening to communities
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().startListening();
    });
  }

  List<CommunityModel> _filterCommunities(List<CommunityModel> communities) {
    if (_searchQuery.isEmpty) return communities;

    final query = _searchQuery.toLowerCase();
    return communities.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.address.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final communityProvider = context.watch<CommunityProvider>();
    final allCommunities = communityProvider.communities;
    final communities = _filterCommunities(allCommunities);

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.cardBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search communities by name or location...',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorder,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${communities.length} communities',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Communities list
        Expanded(
          child: communityProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : communities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            size: 64,
                            color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No communities match your search'
                                : 'No communities found',
                            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: communities.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _CommunityCard(community: communities[index]);
                      },
                    ),
        ),
      ],
    );
  }
}

class _CommunityCard extends StatefulWidget {
  final CommunityModel community;

  const _CommunityCard({required this.community});

  @override
  State<_CommunityCard> createState() => _CommunityCardState();
}

class _CommunityCardState extends State<_CommunityCard> {
  bool _isExpanded = false;
  List<CommunityMemberModel>? _members;
  bool _loadingMembers = false;

  Future<void> _loadMembers() async {
    if (_members != null) return;

    setState(() => _loadingMembers = true);
    try {
      final members = await context
          .read<CommunityProvider>()
          .getCommunityMembers(widget.community.id);
      if (mounted) {
        setState(() {
          _members = members;
          _loadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMembers = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        children: [
          // Main row
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              if (_isExpanded && _members == null) {
                _loadMembers();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Community image/icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      image: widget.community.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.community.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: widget.community.imageUrl == null
                        ? const Icon(
                            Icons.groups,
                            color: AppTheme.accentBlue,
                            size: 28,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),

                  // Community info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.community.name,
                                style: AppTheme.headingSmall.copyWith(
                                  color: AppTheme.primaryDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!widget.community.isPublic) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningOrange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock,
                                      size: 10,
                                      color: AppTheme.warningOrange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Private',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.warningOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.community.address,
                                style: AppTheme.caption.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Stats
                  _StatBadge(
                    icon: Icons.people_outline,
                    value: '${widget.community.memberCount}',
                    label: 'Members',
                  ),
                  const SizedBox(width: 16),
                  _StatBadge(
                    icon: Icons.radar,
                    value: '${widget.community.radius.toStringAsFixed(1)}km',
                    label: 'Radius',
                  ),
                  const SizedBox(width: 16),

                  // Expand icon
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            Divider(
              height: 1,
              color: AppTheme.cardBorder,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (widget.community.description.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.community.description,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Members section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Members (${_members?.length ?? widget.community.memberCount})',
                        style: AppTheme.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (_loadingMembers)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_members != null && _members!.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _members!.take(10).map((member) {
                        return _MemberChip(member: member);
                      }).toList(),
                    )
                  else if (!_loadingMembers)
                    Text(
                      'No members yet',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),

                  if (_members != null && _members!.length > 10) ...[
                    const SizedBox(height: 8),
                    Text(
                      '+ ${_members!.length - 10} more members',
                      style: AppTheme.caption,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.primaryDark,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: AppTheme.caption.copyWith(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MemberChip extends StatelessWidget {
  final CommunityMemberModel member;

  const _MemberChip({required this.member});

  @override
  Widget build(BuildContext context) {
    final isAdmin = member.isAdmin;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppTheme.primaryRed.withValues(alpha: 0.1)
            : AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdmin
              ? AppTheme.primaryRed.withValues(alpha: 0.3)
              : (AppTheme.cardBorder),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdmin) ...[
            const Icon(
              Icons.shield,
              size: 12,
              color: AppTheme.primaryRed,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            member.userId.substring(0, 8),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: isAdmin ? FontWeight.w700 : FontWeight.w400,
              color: isAdmin
                  ? AppTheme.primaryRed
                  : (AppTheme.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}
