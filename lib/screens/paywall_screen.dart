import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Note: In a real app, you would fetch packages from BillingService
    // and display them here.

    return Scaffold(
      appBar: AppBar(
        title: const Text('DocuMind Premium'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.verified, size: 100, color: Colors.amber),
              const SizedBox(height: 24),
              Text(
                'Unlock Unlimited Scans',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const _FeatureRow(icon: Icons.block, text: 'No more Ads'),
              const SizedBox(height: 8),
              const _FeatureRow(icon: Icons.all_inclusive, text: 'Unlimited Document Scans'),
              const SizedBox(height: 8),
              const _FeatureRow(icon: Icons.cloud_done, text: 'Enhanced AI Precision'),
              if (kIsWeb)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Premium purchases are currently available on iOS and Android.',
                    textAlign: TextAlign.center,
                  ),
                ),
              
              const Spacer(),
              
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (kIsWeb) return;
                  // Final implementation would fetch the package and pass to purchasePremium
                  final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
                  // Mocking purchase for layout purposes
                  bool success = await subProvider.purchasePremium(null); 
                  if (success && context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Subscribe for \$2.99 / month',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
                  await subProvider.restorePurchases();
                },
                child: const Text('Restore Purchases'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal),
        const SizedBox(width: 16),
        Text(text, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
