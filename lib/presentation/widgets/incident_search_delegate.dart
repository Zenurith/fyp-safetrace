import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../utils/app_theme.dart';
import '../providers/category_provider.dart';
import '../providers/incident_provider.dart';

class IncidentSearchDelegate extends SearchDelegate<IncidentModel?> {
  final Function(IncidentModel) onIncidentSelected;

  IncidentSearchDelegate({required this.onIncidentSelected});

  @override
  String get searchFieldLabel => 'Search incidents...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryDark,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: AppTheme.textSecondary,
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return _buildEmptyState(context, 'Enter a search term to find incidents');
    }

    final provider = context.watch<IncidentProvider>();
    final incidents = provider.allIncidents;
    final queryLower = query.toLowerCase();

    final results = incidents.where((incident) {
      return incident.title.toLowerCase().contains(queryLower) ||
          incident.address.toLowerCase().contains(queryLower) ||
          incident.description.toLowerCase().contains(queryLower) ||
          incident.categoryLabel.toLowerCase().contains(queryLower);
    }).toList();

    if (results.isEmpty) {
      return _buildEmptyState(context, 'No incidents found for "$query"');
    }

    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final incident = results[index];
        return _IncidentSearchTile(
          incident: incident,
          query: query,
          onTap: () {
            close(context, incident);
            onIncidentSelected(incident);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _IncidentSearchTile extends StatelessWidget {
  final IncidentModel incident;
  final String query;
  final VoidCallback onTap;

  const _IncidentSearchTile({
    required this.incident,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final resolvedIcon = _resolvedIcon(categoryProvider);
    final resolvedColor = _resolvedColor(categoryProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: resolvedColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  resolvedIcon,
                  color: resolvedColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHighlightedText(
                      incident.title,
                      query,
                      TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _severityColor(incident.severity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            incident.severityLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            incident.address,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (incident.description.isNotEmpty &&
                        incident.description.toLowerCase().contains(query.toLowerCase()) &&
                        !incident.title.toLowerCase().contains(query.toLowerCase())) ...[
                      const SizedBox(height: 4),
                      _buildHighlightedText(
                        _descriptionSnippet(incident.description, query),
                        query,
                        TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      incident.timeAgo,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _descriptionSnippet(String description, String query) {
    final index = description.toLowerCase().indexOf(query.toLowerCase());
    if (index < 0) return description;
    final start = (index - 30).clamp(0, description.length);
    final end = (index + query.length + 40).clamp(0, description.length);
    final snippet = description.substring(start, end);
    return '${start > 0 ? '…' : ''}$snippet${end < description.length ? '…' : ''}';
  }

  Widget _buildHighlightedText(String text, String query, TextStyle style) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final index = textLower.indexOf(queryLower);

    if (index < 0) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: style.copyWith(
              backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.2),
              color: AppTheme.primaryRed,
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }

  IconData _resolvedIcon(CategoryProvider categoryProvider) {
    if (incident.category == IncidentCategory.other &&
        incident.customCategoryName != null) {
      final model =
          categoryProvider.getCategoryByName(incident.customCategoryName!);
      if (model != null) return model.icon;
    }
    return _categoryIcon(incident.category);
  }

  Color _resolvedColor(CategoryProvider categoryProvider) {
    if (incident.category == IncidentCategory.other &&
        incident.customCategoryName != null) {
      final model =
          categoryProvider.getCategoryByName(incident.customCategoryName!);
      if (model != null) return model.color;
    }
    return _categoryColor(incident.category);
  }

  Color _categoryColor(IncidentCategory category) {
    switch (category) {
      case IncidentCategory.crime:
        return AppTheme.primaryRed;
      case IncidentCategory.traffic:
        return AppTheme.warningOrange;
      case IncidentCategory.emergency:
        return AppTheme.primaryRed;
      case IncidentCategory.infrastructure:
        return AppTheme.primaryDark;
      case IncidentCategory.environmental:
        return AppTheme.successGreen;
      case IncidentCategory.suspicious:
        return AppTheme.textSecondary;
      case IncidentCategory.other:
        return AppTheme.textSecondary;
    }
  }

  IconData _categoryIcon(IncidentCategory category) {
    switch (category) {
      case IncidentCategory.crime:
        return Icons.warning;
      case IncidentCategory.traffic:
        return Icons.traffic;
      case IncidentCategory.emergency:
        return Icons.emergency;
      case IncidentCategory.infrastructure:
        return Icons.construction;
      case IncidentCategory.environmental:
        return Icons.eco;
      case IncidentCategory.suspicious:
        return Icons.visibility;
      case IncidentCategory.other:
        return Icons.category;
    }
  }

  Color _severityColor(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return AppTheme.successGreen;
      case SeverityLevel.moderate:
        return AppTheme.warningOrange;
      case SeverityLevel.high:
        return AppTheme.primaryRed;
    }
  }
}
