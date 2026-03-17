import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Archive'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search papers, authors, topics...',
                hintStyle: const TextStyle(color: AppColors.textSubtle),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Browse by category
            Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  color: const AppColors.slatePrimary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Browse by Category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
                children: [
                  _buildCategoryCard('Computer Science', Icons.computer),
                  _buildCategoryCard('Physics', Icons.science),
                  _buildCategoryCard('Mathematics', Icons.functions),
                  _buildCategoryCard('Biology', Icons.biotech),
                  _buildCategoryCard('Chemistry', Icons.science_outlined),
                  _buildCategoryCard('Economics', Icons.show_chart),
                  _buildCategoryCard('Psychology', Icons.psychology),
                  _buildCategoryCard('Engineering', Icons.engineering),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const AppColors.slatePrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}