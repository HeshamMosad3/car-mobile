
import '../../data_sources/remote/api_endpoints.dart';
import '../../data_sources/remote/api_service.dart';
import '../../../models/city_model.dart';
import '../../../models/shipping_status_model.dart';
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

  Future<ShippingResultModel?> getShippingByResponse({required int requestId, required int responseId}) {
    return getService(
      apiService: _apiService,
      endpoint: ApiEndpoints.shippingByResponse(requestId, responseId),
      fromJson: (json) => ShippingResultModel.fromJson(json),
    );
  }

  Future<ShippingResultModel?> approveShipping(int shippingId) => _post(ApiEndpoints.shippingApprove(shippingId));

  Future<ShippingResultModel?> cancelShipping(int shippingId) => _post(ApiEndpoints.shippingCancel(shippingId));

  Future<ShippingResultModel?> payShipping(int shippingId) => _post(ApiEndpoints.shippingPay(shippingId));

  Future<ShippingResultModel?> getStoreAddress() {
    return getService(
      apiService: _apiService,
      endpoint: ApiEndpoints.shippingStoreAddress,
      fromJson: (json) => ShippingResultModel.fromJson(json),
    );
  }

  Future<ShippingResultModel?> _post(String endpoint) {
    return postService(
      apiService: _apiService,
      endpoint: endpoint,
      body: {},
      fromJson: (json) => ShippingResultModel.fromJson(json),
    );
  }
}