import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';

class IncidentSearchDelegate extends SearchDelegate<IncidentModel?> {
  final Function(IncidentModel) onIncidentSelected;

  IncidentSearchDelegate({required this.onIncidentSelected});

  @override
  String get searchFieldLabel => 'Search incidents...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _categoryColor(incident.category).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _categoryIcon(incident.category),
                  color: _categoryColor(incident.category),
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
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
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
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      incident.timeAgo,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
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

  Color _categoryColor(IncidentCategory category) {
    switch (category) {
      case IncidentCategory.crime:
        return AppTheme.primaryRed;
      case IncidentCategory.traffic:
        return AppTheme.warningOrange;
      case IncidentCategory.emergency:
        return AppTheme.primaryRed;
      case IncidentCategory.infrastructure:
        return AppTheme.accentBlue;
      case IncidentCategory.environmental:
        return AppTheme.successGreen;
      case IncidentCategory.suspicious:
        return AppTheme.profilePurple;
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
