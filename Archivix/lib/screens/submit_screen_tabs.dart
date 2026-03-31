import 'package:flutter/material.dart';
import 'papers/submit_paper_tab.dart';
import 'posts/submit_post_tab.dart';

class SubmitScreen extends StatefulWidget {
  const SubmitScreen({Key? key}) : super(key: key);

  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.article, size: 20),
              text: 'Submit Paper',
            ),
            Tab(
              icon: Icon(Icons.question_answer, size: 20),
              text: 'Ask Question',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SubmitPaperTab(),
          SubmitPostTab(),
        ],
      ),
    );
  }
}