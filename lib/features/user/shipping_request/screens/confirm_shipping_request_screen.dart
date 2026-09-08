import 'package:car_mediator_mobile/core/helpers/helpers.dart';
import 'package:car_mediator_mobile/core/utils/connection_utils.dart';
import 'package:car_mediator_mobile/widgets/arrow_back_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/providers/orders/create_order_provider.dart';
import '../../../../../core/providers/shipping_provider.dart';
import '../../../../../core/styles/styles.dart';
import '../../../../../core/utils/constants/colors_constants.dart';
import '../../../../../core/utils/constants/constants.dart';
import '../../../../../core/utils/dialogUtils.dart';
import '../../../../../core/utils/size_config.dart';
import '../../../../../widgets/card_container_widget.dart';
import '../../../../../widgets/custom_button.dart';
import '../../../../core/localization/app_language_provider.dart';
import '../../../../core/providers/cache_provider.dart';
import '../../../../core/utils/form_validator.dart';
import '../../../../models/city_model.dart';
import '../../../../widgets/components.dart';
import '../../../../widgets/custom_textfield.dart';
import '../../orders/widgets/confirm_pledge_dialog.dart';
import '../../../../core/services/shared/customer_shipping_info_storage.dart';
import '../../../../../widgets/map_picker_screen.dart';

class ConfirmShippingRequestScreen extends StatefulWidget {
  const ConfirmShippingRequestScreen(
      {super.key,
      required this.requestId,
      required this.responseId,
      required this.vendorId});
  final int requestId;
  final int responseId;
  final int vendorId;

  @override
  State<ConfirmShippingRequestScreen> createState() =>
      _ConfirmShippingRequestScreenState();
}

class _ConfirmShippingRequestScreenState
    extends State<ConfirmShippingRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  double? _lat;
  double? _lng;
  CityModel? _selectedCity;
  String _savedCityEn = '';

  @override
  void initState() {
    super.initState();
    _loadSavedInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ShippingProvider>(context, listen: false).loadCities();
    });
  }

  Future<void> _loadSavedInfo() async {
    final saved = await CustomerShippingInfoStorage.load();
    if (saved != null) {
      setState(() {
        _nameController.text = saved['name'] ?? '';
        _phoneController.text = saved['phone'] ?? '';
        _addressController.text = saved['address'] ?? '';
        _lat = (saved['lat'] as num?)?.toDouble();
        _lng = (saved['lng'] as num?)?.toDouble();
        _savedCityEn = saved['city_en'] ?? saved['city'] ?? '';
      });
    }
  }

  void _tryRestoreCity(List<CityModel> cities) {
    if (_selectedCity == null && _savedCityEn.isNotEmpty) {
      final match =
          cities.where((c) => c.cityNameEn == _savedCityEn).toList();
      if (match.isNotEmpty) {
        setState(() => _selectedCity = match.first);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _provider = Provider.of<CreateOrderProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: ArrowBackWidget(myContext: context),
        title: Text('شحن الطلب : ${widget.requestId}', style: txtBold04),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          physics: const ScrollPhysics(),
          padding: const EdgeInsets.all(paddingConst),
          children: [
            const SizedBox(height: 20),
            CardContainerWidget(
              children: [
                const SizedBox(height: 10),
                Text(
                  'بيانات الشحن',
                  textAlign: TextAlign.center,
                  style: txtBold04,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  label: 'اسم المستخدم',
                  hint: 'أدخل اسمك',
                  controller: _nameController,
                  validator: (value) => FormValidatorUtils.textValidator(value,
                      isRequired: true),
                ),
                const SizedBox(height: 20),
                // Dropdown اختيار المدينة للزبون
                Consumer<ShippingProvider>(
                  builder: (context, shippingProvider, _) {
                    _tryRestoreCity(shippingProvider.cities);
                    return DropdownButtonFormField<CityModel>(
                      value: _selectedCity,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'مدينة التوصيل',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      hint: shippingProvider.isLoadingCities
                          ? const Text('جاري تحميل المدن...')
                          : const Text('اختر مدينة التوصيل'),
                      items: shippingProvider.cities.map((city) {
                        return DropdownMenuItem<CityModel>(
                          value: city,
                          child: Text(city.cityNameAr,
                              textAlign: TextAlign.right),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCity = val),
                      validator: (_) => _selectedCity == null
                          ? 'يرجى اختيار مدينة التوصيل'
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapPickerScreen(),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _lat = result['lat'];
                        _lng = result['lng'];
                        _addressController.text = result['address'] ?? '';
                        // لا نأخذ المدينة من الخريطة بعد الآن
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: CustomTextField(
                      label: 'العنوان التفصيلي (اختياري)',
                      hint: 'اختر موقعك على الخريطة',
                      controller: _addressController,
                      maxLines: null,
                      validator: (value) =>
                          FormValidatorUtils.textValidator(value,
                              isRequired: true, maxLength: 255),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  label: 'رقم الجوال',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      FormValidatorUtils.phoneValidator(value,
                          isRequired: true),
                ),
                const SizedBox(height: 20),
              ],
            )
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: CustomButton(
            label: 'تأكيد الشحن',
            txtSize: SizeConfig.widthResponsive(0.04),
            loading: _provider.isLoading,
            onTap: () {
              Helper.dismissKeyBoard();
              if (_formKey.currentState!.validate()) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => ConfirmPledgeDialog(
                    onConfirm: () async {
                      Helper.dismissKeyBoard();
                      if (!await ConnectionUtils.hasInternetConnection()) {
                        DialogUtils().showNoInternetDialog(context);
                        return;
                      }

                      // حفظ البيانات محلياً
                      CustomerShippingInfoStorage.save(
                        name: _nameController.text.trim(),
                        phone: _phoneController.text.trim(),
                        address: _addressController.text.trim(),
                        city: _selectedCity?.cityNameEn ?? '',
                        lat: _lat,
                        lng: _lng,
                      );

                      String mapUrl = _lat != null && _lng != null
                          ? ' - https://www.google.com/maps/search/?api=1&query=$_lat,$_lng'
                          : '';

                      await _provider.ConfirmShippingRequest(context, body: {
                        'requestId': widget.requestId,
                        'responseId': widget.responseId,
                        'vendorId': widget.vendorId,
                        'idNumberUser': '0000000000',
                        'cityOriginDimensions': _selectedCity?.cityNameEn ?? 'Riyadh',
                        'addressOriginDimensions':
                            'الاسم: ${_nameController.text.trim()} - ${_addressController.text.trim()}$mapUrl',
                        'phoneOriginDimensions': _phoneController.text.trim(),
                      });
                    },
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
