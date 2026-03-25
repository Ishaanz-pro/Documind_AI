import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/constants.dart';

class BillingService {
  bool get _isSupportedMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_isSupportedMobilePlatform) {
      await Purchases.setLogLevel(LogLevel.debug);

      final configuration = PurchasesConfiguration(AppConstants.revenueCatApiKey);
      await Purchases.configure(configuration);
    }
  }

  Future<bool> checkPremiumStatus() async {
    if (!_isSupportedMobilePlatform) return false;
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      // Assume "premium" is the entitlement ID configured in RevenueCat
      return customerInfo.entitlements.all["premium"]?.isActive ?? false;
    } catch (e) {
      print("Error fetching customer info: $e");
      return false;
    }
  }

  Future<List<Package>> getOfferings() async {
    if (!_isSupportedMobilePlatform) return [];
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return offerings.current!.availablePackages;
      }
      return [];
    } catch (e) {
      print("Error fetching offerings: $e");
      return [];
    }
  }

  Future<bool> purchasePackage(dynamic package) async {
    if (!_isSupportedMobilePlatform) return false;
    if (package is! Package) return false;
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      return customerInfo.entitlements.all["premium"]?.isActive ?? false;
    } catch (e) {
      print("Error purchasing package: $e");
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    if (!_isSupportedMobilePlatform) return false;
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all["premium"]?.isActive ?? false;
    } catch (e) {
      print("Error restoring purchases: $e");
      return false;
    }
  }
}
