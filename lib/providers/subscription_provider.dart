import 'package:flutter/material.dart';
import '../services/billing_service.dart';

class SubscriptionProvider with ChangeNotifier {
  final BillingService _billingService = BillingService();
  bool _isPremium = false;

  bool get isPremium => _isPremium;

  Future<void> init() async {
    await _billingService.initialize();
    await checkStatus();
  }

  Future<void> checkStatus() async {
    _isPremium = await _billingService.checkPremiumStatus();
    notifyListeners();
  }

  Future<bool> purchasePremium(dynamic package) async {
    final success = await _billingService.purchasePackage(package);
    if (success) {
      _isPremium = true;
      notifyListeners();
    }
    return success;
  }

  Future<bool> restorePurchases() async {
    final success = await _billingService.restorePurchases();
    if (success) {
      _isPremium = true;
      notifyListeners();
    }
    return success;
  }
}
