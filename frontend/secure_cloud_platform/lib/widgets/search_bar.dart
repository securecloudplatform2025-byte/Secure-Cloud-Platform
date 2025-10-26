import 'package:flutter/material.dart';
import '../models/drive_model.dart';
import '../services/search_service.dart';

class SearchBar extends StatefulWidget {
  final Function(List<FileItem>) onSearchResults;
  final VoidCallback onClearSearch;

  const SearchBar({
    super.key,
    required this.onSearchResults,
    required this.onClearSearch,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      widget.onClearSearch();
      return;
    }

    setState(() => _isSearching = true);
    
    try {
      final results = await SearchService.searchFiles(query);
      widget.onSearchResults(results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search files across all drives...',
          prefixIcon: _isSearching 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    widget.onClearSearch();
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {});
          if (value.length > 2) {
            _performSearch(value);
          } else if (value.isEmpty) {
            widget.onClearSearch();
          }
        },
        onSubmitted: _performSearch,
      ),
    );
  }
}