
import 'package:flutter/material.dart';

import '../../models/city_model.dart';
import '../services/shared/shipping_service.dart';

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
}