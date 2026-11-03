
import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/city_model.dart';
import '../../models/shipping_status_model.dart';
import '../data_sources/remote/reverb_service.dart';
import '../helpers/toast_helper.dart';
import '../services/shared/shipping_service.dart';
import '../utils/launcher_url_utils.dart';

class ShippingProvider extends ChangeNotifier {
  final ShippingService _service;

  ShippingProvider(this._service);

  List<CityModel> cities = [];
  bool isLoadingCities = false;
  CityModel? myCitySelectedModel;

  void selectedMyCity(CityModel? model) {
    myCitySelectedModel = model;
    notifyListeners();
  }

  Future<void> loadCities() async {
    if (cities.isNotEmpty) return; // already loaded, skip
    isLoadingCities = true;
    notifyListeners();

    final result = await _service.getCities();
    if (result != null && result.success) {
      cities = result.cityModelList;
    }

    isLoadingCities = false;
    notifyListeners();
  }

  // ---- shipment of one request/response (shared by customer and vendor) ----
  ShippingStatusModel? current;
  bool isLoadingStatus = false;
  bool isActing = false;

  // The shipment last opened, so a live update can re-read exactly that one.
  int? _watchedRequestId;
  int? _watchedResponseId;

  /// [silent] is for automatic refreshes: no spinner and no error toast, the screen just updates.
  Future<void> loadStatus({required int requestId, required int responseId, bool silent = false}) async {
    _watchedRequestId = requestId;
    _watchedResponseId = responseId;
    if (!silent) {
      isLoadingStatus = true;
      notifyListeners();
    }

    final result = await _service.getShippingByResponse(requestId: requestId, responseId: responseId);
    if (result != null && result.success) {
      current = result.shipping;
    } else if (result != null && !silent) {
      ToastHelper.showError(result.message);
    }

    isLoadingStatus = false;
    notifyListeners();
  }

  // ---- live updates: the server pushes "shipping.status.changed" on the user's private channel ----
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  int? _listeningUserId;

  Future<void> startRealtime(int userId) async {
    if (_statusSub != null && _listeningUserId == userId) return;
    await stopRealtime();
    _listeningUserId = userId;

    final stream = await ReverbService.instance.listenToPrivateChannel('user.$userId');
    _statusSub = stream.listen((message) {
      if (message['event'] == 'shipping.status.changed') refresh();
    });
  }

  Future<void> stopRealtime() async {
    await _statusSub?.cancel();
    _statusSub = null;
    _listeningUserId = null;
  }

  /// Re-reads everything that depends on a shipment's status: the "next step" text and, if one is
  /// open, that shipment (its chat buttons and status screen).
  Future<void> refresh() async {
    await loadPendingActions();
    final requestId = _watchedRequestId;
    final responseId = _watchedResponseId;
    if (requestId != null && responseId != null) {
      await loadStatus(requestId: requestId, responseId: responseId, silent: true);
    }
  }

  /// [silent] skips the success toast, for the automatic call made when the approval form opens.
  Future<bool> approve({bool silent = false}) async {
    final shipping = current;
    if (shipping == null) return false;
    return _act(() => _service.approveShipping(shipping.id), successToast: !silent);
  }

  Future<bool> cancel() async {
    final shipping = current;
    if (shipping == null) return false;
    return _act(() => _service.cancelShipping(shipping.id), successToast: true);
  }

  /// Starts the online payment. The shipment is only ever marked paid by the server, after the
  /// gateway confirms the charge, so a successful call here just opens the checkout.
  Future<void> pay() async {
    final shipping = current;
    if (shipping == null || isActing) return;

    isActing = true;
    notifyListeners();

    final result = await _service.payShipping(shipping.id);
    if (result == null) {
      // The service already showed the error.
    } else if (!result.success) {
      ToastHelper.showError(result.message);
    } else {
      final url = result.raw['checkout_url'];
      if (result.raw['paid'] == true) {
        // Demo gateway: the server marked it paid straight away, nothing to open.
        current = result.shipping ?? current;
        ToastHelper.showSuccess(result.message);
        loadPendingActions();
      } else if (url is String && url.isNotEmpty) {
        await LauncherUrlUtils.openUrl(url);
      } else {
        ToastHelper.showInfo(result.message);
      }
    }

    isActing = false;
    notifyListeners();
  }

  // ---- shipments waiting on the customer (shown as a short text in the home app bar) ----
  List<PendingShippingAction> pendingActions = [];

  Future<void> loadPendingActions() async {
    final result = await _service.getPendingActions();
    if (result == null || !result.success) return;

    final items = result.raw['items'];
    pendingActions = items is List
        ? items.whereType<Map>().map((e) => PendingShippingAction.fromJson(Map<String, dynamic>.from(e))).toList()
        : [];
    notifyListeners();
  }

  Future<ShippingStoreAddress?> loadStoreAddress() async {
    final result = await _service.getStoreAddress();
    if (result == null || !result.success) return null;

    final raw = result.raw;
    if (raw['address'] == null && raw['lat'] == null) return null;
    return ShippingStoreAddress(
      name: raw['name']?.toString() ?? '',
      city: raw['city']?.toString() ?? '',
      address: raw['address']?.toString() ?? '',
      phone: raw['phone']?.toString() ?? '',
      lat: double.tryParse(raw['lat']?.toString() ?? ''),
      lng: double.tryParse(raw['lng']?.toString() ?? ''),
    );
  }

  Future<bool> _act(Future<ShippingResultModel?> Function() call, {required bool successToast}) async {
    if (isActing) return false;

    isActing = true;
    notifyListeners();

    final result = await call();
    var ok = false;
    if (result != null) {
      ok = result.success;
      if (ok) {
        if (result.shipping != null) current = result.shipping;
        if (successToast) ToastHelper.showSuccess(result.message);
      } else {
        ToastHelper.showError(result.message);
      }
    }

    isActing = false;
    notifyListeners();
    return ok;
  }
}

/// The vendor's saved pickup point, used to pre-fill the shipping form.
class ShippingStoreAddress {
  final String name;
  final String city;
  final String address;
  final String phone;
  final double? lat;
  final double? lng;

  const ShippingStoreAddress({
    this.name = '',
    this.city = '',
    this.address = '',
    this.phone = '',
    this.lat,
    this.lng,
  });
}