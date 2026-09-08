
import '../../data_sources/remote/api_endpoints.dart';
import '../../data_sources/remote/api_service.dart';
import '../../../models/city_model.dart';
import '../base_service.dart';

class ShippingService extends BaseService {
  final ApiService _apiService;

  ShippingService(this._apiService);

  Future<CityResultModel?> getCities() async {
    return getService(
      apiService: _apiService,
      endpoint: ApiEndpoints.getCities,
      fromJson: (json) => CityResultModel.fromJson(json),
    );
  }
}