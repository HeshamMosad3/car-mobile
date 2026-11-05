import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/data_sources/local/secure_storage.dart';
import '../../../../core/data_sources/remote/api_endpoints.dart';
import '../../../../core/data_sources/remote/api_path.dart';
import '../../../../core/providers/shipping_provider.dart';
import '../../../../core/styles/styles.dart';
import '../../../../core/utils/constants/assets_path.dart';
import '../../../../core/utils/constants/colors_constants.dart';
import '../../../../core/utils/constants/constants.dart';
import '../../../../core/utils/dialogUtils.dart';
import '../../../../core/utils/size_config.dart';
import '../../../../models/shipping_status_model.dart';
import '../../../../widgets/arrow_back_widget.dart';
import '../../../../widgets/card_container_widget.dart';
import '../../../../widgets/components.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../widgets/custom_empty_widget.dart';
import '../../../../widgets/custom_loading.dart';
import '../../../user/shipping_request/screens/confirm_shipping_request_screen.dart';

/// Where the customer and the vendor follow a shipment, and where the customer approves,
/// pays for, or cancels it.
class ShippingStatusScreen extends StatefulWidget {
  const ShippingStatusScreen({
    super.key,
    required this.requestId,
    required this.responseId,
    required this.vendorId,
    this.isVendor = false,
  });

  final int requestId;
  final int responseId;
  final int vendorId;
  final bool isVendor;

  @override
  State<ShippingStatusScreen> createState() => _ShippingStatusScreenState();
}

class _ShippingStatusScreenState extends State<ShippingStatusScreen> {
  /// The happy path, in order. Waiting-for-data counts as the first step.
  static const List<MapEntry<String, String>> _steps = [
    MapEntry('AwaitingCustomerApproval', 'موافقة الزبون وبياناته'),
    MapEntry('ReadyForReview', 'مراجعة الإدارة'),
    MapEntry('SearchingCarrier', 'البحث عن شركة شحن'),
    MapEntry('AwaitingPayment', 'دفع رسوم الشحن'),
    MapEntry('Paid', 'تم دفع الرسوم'),
    MapEntry('BookingConfirmed', 'تأكيد الشحن'),
    MapEntry('PickedUp', 'استلام الشحنة'),
    MapEntry('InTransit', 'في الطريق'),
    MapEntry('Delivered', 'تم التسليم'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    return context
        .read<ShippingProvider>()
        .loadStatus(requestId: widget.requestId, responseId: widget.responseId);
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    final provider = context.watch<ShippingProvider>();
    final shipping = provider.current;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: ArrowBackWidget(myContext: context),
        title: Text('شحن الطلب : ${widget.requestId}', style: txtBold04),
      ),
      body: provider.isLoadingStatus && shipping == null
          ? const CustomLoading()
          : shipping == null
              ? const CustomEmptyWidget(label: 'لا يوجد طلب شحن')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(paddingConst),
                    children: [
                      _buildStatusCard(shipping),
                      const SizedBox(height: 12),
                      if (!widget.isVendor && shipping.needsData) _buildApproveButton(),
                      if (!widget.isVendor && shipping.status == 'AwaitingPayment') ...[
                        _buildPaymentCard(shipping, provider),
                        const SizedBox(height: 12),
                      ],
                      if (!widget.isVendor && shipping.paymentStatus == 'paid' && !shipping.isClosed) ...[
                        _buildInfoCard('تم دفع رسوم الشحن، وجارٍ تأكيد الشحن.'),
                        const SizedBox(height: 12),
                      ],
                      if (_hasCarrierInfo(shipping)) ...[
                        _buildCarrierCard(shipping),
                        const SizedBox(height: 12),
                      ],
                      if (shipping.hasWaybill) ...[
                        _buildWaybillCard(shipping, provider),
                        const SizedBox(height: 12),
                      ],
                      // A delivered shipment keeps its steps, all marked done. Only a canceled or unavailable
                      // one hides them: there is no record of how far it got.
                      if (shipping.status != 'Canceled' && shipping.status != 'Unavailable') ...[
                        _buildStepsCard(shipping),
                        const SizedBox(height: 12),
                      ],
                      if (!widget.isVendor && shipping.canCancel) _buildCancelButton(provider),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard(ShippingStatusModel shipping) {
    final closedBad = shipping.status == 'Canceled' || shipping.status == 'Unavailable';
    final color = closedBad
        ? Colors.redAccent
        : (shipping.status == 'Delivered' ? Colors.green : AppColor.primaryColor);

    return CardContainerWidget(children: [
      Text('حالة الشحن', style: txtLightSemiBold035),
      const SizedBox(height: 6),
      Text(
        shipping.statusLabel.isNotEmpty ? shipping.statusLabel : shippingStatusLabel(shipping.status),
        style: txtBold05.copyWith(color: color),
      ),
      if (closedBad && shipping.cancelReason.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(shipping.cancelReason, style: txtMedium04),
      ],
      if (shipping.status == 'Unavailable') ...[
        const SizedBox(height: 8),
        Text('يمكنكما ترتيب الشحن بأنفسكما.', style: txtMedium04),
      ],
    ]);
  }

  Widget _buildApproveButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomButton(
        label: 'الموافقة على عملية الشحن',
        txtSize: SizeConfig.widthResponsive(0.04),
        onTap: () async {
          await navigationPush(
            context,
            ConfirmShippingRequestScreen(
              requestId: widget.requestId,
              responseId: widget.responseId,
              vendorId: widget.vendorId,
            ),
          );
          if (mounted) _load();
        },
      ),
    );
  }

  Widget _buildPaymentCard(ShippingStatusModel shipping, ShippingProvider provider) {
    return CardContainerWidget(children: [
      Text('تكلفة الشحن', style: txtLightSemiBold035),
      const SizedBox(height: 6),
      Row(
        children: [
          Text(
            shipping.shippingCost?.toStringAsFixed(2) ?? '-',
            style: txtBold05.copyWith(fontSize: 28),
          ),
          const SizedBox(width: 8),
          Image.asset(AssetsPath.icon_riyal, width: 18, height: 18, color: AppColor.primaryColor),
        ],
      ),
      if (shipping.paymentDueAt.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('آخر موعد للدفع : ${shipping.paymentDueAt}', style: txtMedium04),
      ],
      const SizedBox(height: 12),
      CustomButton(
        label: 'ادفع تكلفة الشحن',
        txtSize: SizeConfig.widthResponsive(0.04),
        loading: provider.isActing,
        onTap: shipping.canPay ? () => provider.pay() : null,
      ),
      if (!shipping.canPay) ...[
        const SizedBox(height: 6),
        Text('لا يمكن الدفع حالياً، يرجى التواصل مع الدعم.', style: txtLightSemiBold035),
      ],
    ]);
  }

  bool _hasCarrierInfo(ShippingStatusModel shipping) =>
      shipping.carrierName.isNotEmpty || shipping.trackingNumber.isNotEmpty || shipping.pickupDetails.isNotEmpty;

  Widget _buildCarrierCard(ShippingStatusModel shipping) {
    Widget row(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label : ', style: txtLightSemiBold035),
                Expanded(child: Text(value, style: txtMedium04)),
              ],
            ),
          );

    return CardContainerWidget(children: [
      Text('بيانات تأكيد الشحن', style: txtBold04),
      const SizedBox(height: 8),
      row('شركة الشحن', shipping.carrierName),
      row('رقم التتبع', shipping.trackingNumber),
      row('طريقة التسليم للشركة', shipping.pickupMethodLabel),
      row('بيانات الاستلام', shipping.pickupDetails),
    ]);
  }

  /// The carrier's waybill: a picture shown right here (tap to zoom) or a PDF tile, plus a button
  /// that downloads it and opens the share sheet so it can be saved or sent.
  Widget _buildWaybillCard(ShippingStatusModel shipping, ShippingProvider provider) {
    final url = '${ApiPath.baseUrl}${ApiEndpoints.shippingWaybill(shipping.id)}?v=${shipping.waybillVersion}';

    return CardContainerWidget(children: [
      Text('بوليصة الشحن', style: txtBold04),
      const SizedBox(height: 10),
      if (shipping.waybillType == 'pdf')
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: AppColor.primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              const Icon(Icons.picture_as_pdf, size: 44, color: Colors.redAccent),
              const SizedBox(height: 6),
              Text('ملف PDF', style: txtMedium04),
            ],
          ),
        )
      else
        FutureBuilder<String?>(
          future: SecureStorage.getToken(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(height: 180, child: CustomLoading(radius: 18));
            final headers = {'Authorization': 'Bearer ${snapshot.data ?? ''}'};

            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _WaybillViewer(url: url, headers: headers)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: url,
                  httpHeaders: headers,
                  width: double.infinity,
                  height: SizeConfig.heightResponsive(0.30),
                  fit: BoxFit.contain,
                  placeholder: (context, _) => const CustomLoading(radius: 18),
                  errorWidget: (context, _, __) => const SizedBox(height: 120, child: Icon(Icons.broken_image, size: 40)),
                ),
              ),
            );
          },
        ),
      const SizedBox(height: 12),
      CustomButton(
        label: 'تحميل / مشاركة البوليصة',
        txtSize: SizeConfig.widthResponsive(0.04),
        loading: provider.isSharingWaybill,
        onTap: () => provider.shareWaybill(),
      ),
    ]);
  }

  Widget _buildInfoCard(String text) => CardContainerWidget(children: [Text(text, style: txtMedium04)]);

  Widget _buildStepsCard(ShippingStatusModel shipping) {
    // Waiting for the customer's data is still the first step.
    final key = shipping.status == 'AwaitingCustomerData' ? 'AwaitingCustomerApproval' : shipping.status;
    final current = _steps.indexWhere((s) => s.key == key);
    // Delivered is the last step and nothing comes after it, so every step, itself included, is done.
    final delivered = shipping.status == 'Delivered';
    const doneColor = Color(0xFF2E7D32);

    return CardContainerWidget(children: [
      Text('مراحل الشحن', style: txtBold04),
      const SizedBox(height: 8),
      for (var i = 0; i < _steps.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                (i < current || delivered)
                    ? Icons.check_circle
                    : (i == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                size: 20,
                color: (i < current || delivered)
                    ? doneColor
                    : (i == current ? AppColor.primaryColor : AppColor.greyColor),
              ),
              const SizedBox(width: 10),
              Text(
                _steps[i].value,
                style: delivered
                    ? txtMedium04.copyWith(color: doneColor)
                    : (i == current ? txtBold04 : txtMedium04.copyWith(color: i < current ? doneColor : AppColor.greyColor)),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _buildCancelButton(ShippingProvider provider) {
    return CustomButton(
      label: 'إلغاء طلب الشحن',
      txtSize: SizeConfig.widthResponsive(0.04),
      primaryColor: Colors.transparent,
      textColor: Colors.redAccent,
      borderColor: Colors.redAccent,
      loading: provider.isActing,
      onTap: () {
        DialogUtils().showConfirmDialog(
          context,
          message: 'هل تريد إلغاء طلب الشحن؟',
          confirm: () async {
            await provider.cancel();
          },
        );
      },
    );
  }
}

/// Full-screen, zoomable view of the waybill picture.
class _WaybillViewer extends StatelessWidget {
  const _WaybillViewer({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: url,
            httpHeaders: headers,
            fit: BoxFit.contain,
            placeholder: (context, _) => const CustomLoading(radius: 18),
          ),
        ),
      ),
    );
  }
}