import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/document_model.dart';
import '../providers/document_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/ad_service.dart';
import '../services/support_diagnostics_service.dart';
import 'paywall_screen.dart';
import 'scan_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  BannerAd? _bannerAd;
  final TextEditingController _questionController = TextEditingController();

  String _portfolioInsight =
      'AI insights are waiting. Generate one to summarize trends across your documents.';
  String _aiAnswer =
      'Ask a question like: "Which receipts are likely tax-deductible this month?"';

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    final adService = Provider.of<AdService>(context, listen: false);
    _bannerAd = adService.createBannerAd()?..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _generateInsight(List<DocumentModel> docs) async {
    final provider = context.read<DocumentProvider>();
    final insight = await provider.generatePortfolioInsight(docs);
    if (!mounted) return;
    setState(() => _portfolioInsight = insight);
  }

  Future<void> _askQuestion(List<DocumentModel> docs) async {
    final provider = context.read<DocumentProvider>();
    final answer = await provider.askQuestionAboutDocuments(
      docs,
      _questionController.text,
    );
    if (!mounted) return;
    setState(() => _aiAnswer = answer);
  }

  Future<void> _copySupportSnapshot(List<DocumentModel> docs) async {
    final diagnostics = SupportDiagnosticsService.instance;
    final totalAmount = docs.fold<double>(
      0,
      (sum, doc) => sum + (doc.totalAmount ?? 0),
    );
    final categories = docs.map((d) => d.documentType).toSet().toList()..sort();
    final report = '''DocuMind Support Snapshot
Timestamp: ${DateTime.now().toIso8601String()}
Platform: ${kIsWeb ? 'Web' : defaultTargetPlatform.name}
OpenAI configured: ${AppConstants.openAiApiKey.trim().isNotEmpty}
Last AI operation: ${diagnostics.lastAiOperation}
Last AI latency: ${diagnostics.lastAiLatencyMs == null ? 'N/A' : '${diagnostics.lastAiLatencyMs}ms'}
AI success rate: ${diagnostics.aiSuccessRate.toStringAsFixed(1)}%
Documents: ${docs.length}
Categories: ${categories.join(', ')}
Tracked total: ${totalAmount > 0 ? '\$${totalAmount.toStringAsFixed(2)}' : 'N/A'}
''';

    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Support snapshot copied to clipboard.')),
    );
  }

  void _showDiagnosticsLogViewer(BuildContext context) {
    final diagnostics = SupportDiagnosticsService.instance;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: AnimatedBuilder(
          animation: diagnostics,
          builder: (context, __) {
            final entries = diagnostics.entriesNewestFirst;
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Diagnostics Logs',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: diagnostics.clearLogs,
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (entries.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                              'No logs yet. Trigger AI actions to collect diagnostics.'),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final e = entries[index];
                            final isError = e.level == 'ERROR';
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isError
                                    ? const Color(0xFFFFE8E6)
                                    : const Color(0xFFEAF5FF),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e.level} • ${e.source} • ${e.timestamp.toIso8601String()}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(e.message),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final isPremium = subProvider.isPremium;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(decoration: _buildBackground(context)),
          ),
          SafeArea(
            child: Consumer<DocumentProvider>(
              builder: (context, docProvider, _) {
                return StreamBuilder<List<DocumentModel>>(
                  stream: docProvider.documentsStream,
                  builder: (context, snapshot) {
                    final docs = snapshot.data ?? const <DocumentModel>[];
                    final filteredDocs = _filterDocs(docs);

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 1100;
                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 18, 20, 12),
                                child: _TopHero(
                                  isPremium: isPremium,
                                  onUpgrade: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const PaywallScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: _buildSearchBar(),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: _buildFilterChips(),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 12, 20, 20),
                                child: _StatsStrip(
                                    docs: docs,
                                    filteredCount: filteredDocs.length),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                child: Column(
                                  children: [
                                    _SupportReadinessCard(
                                      openAiConfigured: AppConstants
                                          .openAiApiKey
                                          .trim()
                                          .isNotEmpty,
                                      onCopySnapshot: () =>
                                          _copySupportSnapshot(docs),
                                      onShowLogs: () =>
                                          _showDiagnosticsLogViewer(context),
                                    ),
                                    const SizedBox(height: 10),
                                    const _StatusLatencyCard(),
                                  ],
                                ),
                              ),
                            ),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else if (snapshot.hasError)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      'Something went wrong while loading documents.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              )
                            else if (docs.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _EmptyState(
                                  onAdd: () => _showAddDocumentSheet(context),
                                ),
                              )
                            else if (isDesktop)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 28),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 7,
                                        child: _buildDocumentGrid(filteredDocs),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 4,
                                        child: _AiPanel(
                                          docs: docs,
                                          insightText: _portfolioInsight,
                                          answerText: _aiAnswer,
                                          questionController:
                                              _questionController,
                                          isGeneratingInsight:
                                              docProvider.isGeneratingInsight,
                                          onGenerateInsight: () =>
                                              _generateInsight(docs),
                                          onAskQuestion: () =>
                                              _askQuestion(docs),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else ...[
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                sliver: SliverGrid.builder(
                                  itemCount: filteredDocs.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.78,
                                  ),
                                  itemBuilder: (context, index) {
                                    return _DocumentCard(
                                        document: filteredDocs[index]);
                                  },
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                  child: _AiPanel(
                                    docs: docs,
                                    insightText: _portfolioInsight,
                                    answerText: _aiAnswer,
                                    questionController: _questionController,
                                    isGeneratingInsight:
                                        docProvider.isGeneratingInsight,
                                    onGenerateInsight: () =>
                                        _generateInsight(docs),
                                    onAskQuestion: () => _askQuestion(docs),
                                  ),
                                ),
                              ),
                            ],
                            if (!isPremium && _bannerAd != null)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Center(
                                    child: SizedBox(
                                      width: _bannerAd!.size.width.toDouble(),
                                      height: _bannerAd!.size.height.toDouble(),
                                      child: AdWidget(ad: _bannerAd!),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDocumentSheet(context),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add Document'),
      ),
    );
  }

  BoxDecoration _buildBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF08131F), Color(0xFF102A43), Color(0xFF174A6B)]
            : const [Color(0xFFF2F8FF), Color(0xFFDDF0FF), Color(0xFFFFF4E6)],
      ),
    );
  }

  List<DocumentModel> _filterDocs(List<DocumentModel> docs) {
    return docs.where((doc) {
      final matchesCategory =
          _selectedCategory == 'All' || doc.documentType == _selectedCategory;
      final lowerSummary = doc.summary.toLowerCase();
      final lowerQuery = _searchQuery.trim().toLowerCase();
      final matchesSearch = lowerQuery.isEmpty ||
          lowerSummary.contains(lowerQuery) ||
          (doc.keyDate?.toLowerCase().contains(lowerQuery) ?? false) ||
          (doc.totalAmount?.toString().contains(lowerQuery) ?? false);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Widget _buildDocumentGrid(List<DocumentModel> docs) {
    if (docs.isEmpty) {
      return Card(
        child: SizedBox(
          height: 220,
          child: Center(
            child: Text(
              'No results for your current filters.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        return _AnimatedReveal(
          delayMs: 70 * (index % 8),
          child: _DocumentCard(document: docs[index]),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Search by summary, date, amount, or category context',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: AppConstants.documentCategories.length,
        itemBuilder: (context, index) {
          final category = AppConstants.documentCategories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: _selectedCategory == category,
              onSelected: (selected) {
                if (!selected) return;
                setState(() => _selectedCategory = category);
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddDocumentSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Document',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (!kIsWeb)
                ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.document_scanner)),
                  title: const Text('Scan from Camera'),
                  subtitle: const Text('Capture and analyze instantly'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScanScreen()),
                    );
                  },
                ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.upload_file)),
                title: const Text('Upload from Files / Gallery'),
                subtitle:
                    const Text('Upload image or PDF and let AI process it'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScanScreen(pickFileOnOpen: true),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopHero extends StatelessWidget {
  final bool isPremium;
  final VoidCallback onUpgrade;

  const _TopHero({required this.isPremium, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFF0B2D4A), Color(0xFF0A5664), Color(0xFF1E7C8B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                spreadRadius: 2,
                color: Colors.black.withValues(alpha: 0.18),
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DocuMind AI Dashboard',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Scan, summarize, and question your document archive with AI-powered context.',
                          style: TextStyle(color: Colors.white, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  if (!isPremium && !compact)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF95738),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onUpgrade,
                      icon: const Icon(Icons.stars),
                      label: const Text('Upgrade'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _HeroChip(
                    icon: Icons.travel_explore,
                    label: 'Semantic Search',
                  ),
                  _HeroChip(
                    icon: Icons.analytics_outlined,
                    label: 'Portfolio Insights',
                  ),
                  _HeroChip(
                    icon: Icons.flash_on_outlined,
                    label: 'One-Tap AI Summary',
                  ),
                ],
              ),
              if (!isPremium && compact) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF95738),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.stars),
                  label: const Text('Upgrade'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: Colors.white.withValues(alpha: 0.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final List<DocumentModel> docs;
  final int filteredCount;

  const _StatsStrip({required this.docs, required this.filteredCount});

  @override
  Widget build(BuildContext context) {
    final totalAmount = docs.fold<double>(
      0,
      (sum, doc) => sum + (doc.totalAmount ?? 0),
    );
    final uniqueTypes = docs.map((d) => d.documentType).toSet().length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 180,
          child: _StatCard(
            label: 'Documents',
            value: '${docs.length}',
            icon: Icons.description_outlined,
          ),
        ),
        SizedBox(
          width: 180,
          child: _StatCard(
            label: 'Visible',
            value: '$filteredCount',
            icon: Icons.filter_alt_outlined,
          ),
        ),
        SizedBox(
          width: 180,
          child: _StatCard(
            label: 'Categories',
            value: '$uniqueTypes',
            icon: Icons.category_outlined,
          ),
        ),
        SizedBox(
          width: 180,
          child: _StatCard(
            label: 'Tracked Total',
            value:
                totalAmount > 0 ? '\$${totalAmount.toStringAsFixed(0)}' : 'N/A',
            icon: Icons.savings_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.68),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportReadinessCard extends StatelessWidget {
  final bool openAiConfigured;
  final VoidCallback onCopySnapshot;
  final VoidCallback onShowLogs;

  const _SupportReadinessCard({
    required this.openAiConfigured,
    required this.onCopySnapshot,
    required this.onShowLogs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.68),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Support Readiness: ${openAiConfigured ? 'Production AI mode' : 'Fallback demo mode'}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onCopySnapshot,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy Health Snapshot'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onShowLogs,
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('View Logs'),
          ),
        ],
      ),
    );
  }
}

class _StatusLatencyCard extends StatelessWidget {
  const _StatusLatencyCard();

  @override
  Widget build(BuildContext context) {
    final diagnostics = SupportDiagnosticsService.instance;
    return AnimatedBuilder(
      animation: diagnostics,
      builder: (context, _) {
        final latencyText = diagnostics.lastAiLatencyMs == null
            ? 'N/A'
            : '${diagnostics.lastAiLatencyMs} ms';
        final mode = diagnostics.lastUsedFallback ? 'Fallback' : 'Live AI';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.68),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
          ),
          child: Row(
            children: [
              const Icon(Icons.monitor_heart_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Status: ${diagnostics.aiFailureCount == 0 ? 'Healthy' : 'Degraded'} | '
                  'Mode: $mode | '
                  'Last Op: ${diagnostics.lastAiOperation} | '
                  'Latency: $latencyText | '
                  'Success: ${diagnostics.aiSuccessRate.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiPanel extends StatelessWidget {
  final List<DocumentModel> docs;
  final String insightText;
  final String answerText;
  final TextEditingController questionController;
  final bool isGeneratingInsight;
  final VoidCallback onGenerateInsight;
  final VoidCallback onAskQuestion;

  const _AiPanel({
    required this.docs,
    required this.insightText,
    required this.answerText,
    required this.questionController,
    required this.isGeneratingInsight,
    required this.onGenerateInsight,
    required this.onAskQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_alt_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'AI Insights',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: isGeneratingInsight ? null : onGenerateInsight,
                  icon: const Icon(Icons.auto_graph),
                  label: const Text('Generate Portfolio Summary'),
                ),
                const SizedBox(height: 10),
                _PanelTextBox(text: insightText),
                const SizedBox(height: 14),
                TextField(
                  controller: questionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Ask a question about your scanned documents...',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isGeneratingInsight ? null : onAskQuestion,
                  icon: const Icon(Icons.question_answer_outlined),
                  label: const Text('Ask AI'),
                ),
                const SizedBox(height: 10),
                _PanelTextBox(text: answerText),
                if (isGeneratingInsight)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Powered by OpenAI. Verify important details before making decisions.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelTextBox extends StatelessWidget {
  final String text;

  const _PanelTextBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentModel document;

  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    document.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.image_not_supported),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        document.documentType,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0x30000000),
                              Color(0x70000000),
                            ],
                            stops: [0.45, 0.72, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.keyDate ?? 'No date detected',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (document.totalAmount != null)
                          Text(
                            '\$${document.totalAmount!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF0A7C4A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        document.summary,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.3),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedReveal extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _AnimatedReveal({required this.child, required this.delayMs});

  @override
  State<_AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<_AnimatedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future<void>.delayed(
        Duration(milliseconds: widget.delayMs), _controller.forward);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0D3B66).withValues(alpha: 0.15),
                      const Color(0xFF0FA3B1).withValues(alpha: 0.25),
                    ],
                  ),
                ),
                child: const Icon(Icons.auto_awesome_motion, size: 34),
              ),
              const SizedBox(height: 14),
              Text(
                'Build Your Intelligent Archive',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start by scanning or uploading your first document. DocuMind will classify, summarize, and index it for instant retrieval.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add First Document'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

