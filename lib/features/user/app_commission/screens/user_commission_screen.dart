
import 'package:car_mediator_mobile/core/utils/constants/assets_path.dart';
import 'package:car_mediator_mobile/core/utils/constants/colors_constants.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/helpers/helpers.dart';
import '../../../../core/localization/app_language_provider.dart';
import '../../../../core/providers/cache_provider.dart';
import '../../../../core/styles/styles.dart';
import '../../../../core/utils/form_validator.dart';
import '../../../../core/utils/size_config.dart';
import '../../../../models/category_model.dart';
import '../../../../widgets/arrow_back_widget.dart';
import '../../../../widgets/components.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../widgets/custom_container_listtile_widget.dart';
import '../../../../widgets/info_widget.dart';

class UserCommissionScreen extends StatefulWidget {
  const UserCommissionScreen({super.key});

  @override
  State<UserCommissionScreen> createState() => _UserCommissionScreenState();
}

class _UserCommissionScreenState extends State<UserCommissionScreen> {
  static const double _feePerPurchase = 5;
  static const int _maxPurchases = 10;

  final _formKey = GlobalKey<FormState>();
  final List<int> _purchaseCounts = List.generate(_maxPurchases, (i) => i + 1);

  CategoryModel? _categorySelected;
  int? _purchasesSelected;
  double _commissionFees = 0;

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    final _isArabic = context.read<AppLanguageProvider>().isArabic;
    final _cacheProvider = context.read<CacheProvider>();

    return Scaffold(
      backgroundColor: AppColor.secondaryColor,
      appBar: AppBar(
        title: Text('سداد العمولة', style: txtBold05,),
        centerTitle: true,
        elevation: 0,
        leading: ArrowBackWidget(myContext: context),
      ),

      body: Form(
        key: _formKey,
          child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          const InfoWidget(text: 'رسوم الخدمة 5 ريال عن كل عملية شراء تتم عن طريق التطبيق. اختر عدد عمليات الشراء لتعرف المبلغ المستحق عليك.',),
          const SizedBox(height: 20,),
          Container(
            padding:  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 3,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('حساب الرسوم', style: txtBold04,),
                const SizedBox(height: 10,),
                DropdownSearch<CategoryModel>(
                  dropdownDecoratorProps: customDropdownDecoratorProps(
                      label: 'القسم', hint: 'إختر القسم'),
                  popupProps: popupPropsBottomSheet<CategoryModel>(
                    titleBottomSheet: 'القسم',
                    itemBuilder: (BuildContext context, CategoryModel item,
                        bool isSelected) {
                      return CustomContainerListTileWidget(
                        title:
                        _isArabic ? item.catNameAr : item.catNameEn,
                      );
                    },
                  ),
                  items: _cacheProvider.categoriesList,
                  selectedItem: _categorySelected,
                  itemAsString: (CategoryModel? u) =>
                  (_isArabic ? u?.catNameAr : u?.catNameEn) ?? '',
                  validator: FormValidatorUtils.objectValidator,
                  onChanged: (CategoryModel? selection) =>
                      setState(() => _categorySelected = selection),
                ),
                const SizedBox(height: 20,),
                DropdownSearch<int>(
                  dropdownDecoratorProps: customDropdownDecoratorProps(
                      label: 'عدد عمليات الشراء', hint: 'اختر عدد عمليات الشراء'),
                  popupProps: popupPropsBottomSheet<int>(
                    showSearchBox: false,
                    titleBottomSheet: 'عدد عمليات الشراء',
                    itemBuilder: (BuildContext context, int item, bool isSelected) {
                      return CustomContainerListTileWidget(title: '$item',);
                    },
                  ),
                  items: _purchaseCounts,
                  selectedItem: _purchasesSelected,
                  itemAsString: (int? n) => n?.toString() ?? '',
                  validator: FormValidatorUtils.objectValidator,
                  onChanged: (int? selection) =>
                      setState(() => _purchasesSelected = selection),
                ),
                const SizedBox(height: 20,),
                CustomButton(
                  label: 'إحسب',
                  primaryColor: AppColor.primaryColor,
                  txtSize: SizeConfig.widthResponsive(0.05),
                  loading: false,
                  onTap: () {
                    Helper.dismissKeyBoard();
                    if (_formKey.currentState!.validate()) {
                      setState(() => _commissionFees = _purchasesSelected! * _feePerPurchase);
                    }
                  }
                ),

                const SizedBox(height: 50,),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('الرسوم المستحقة   : ', style: txtBold04,),
                    const SizedBox(width: 10,),
                    Text('$_commissionFees', style: TextStyle(fontSize: 32),),
                    const SizedBox(width: 10,),
                    Image.asset(AssetsPath.icon_riyal, height: 20, width: 20,),
                  ],
                ),
                const SizedBox(height: 60,),
                CustomButton(
                    label: 'الدفع البنكي لسداد العمولة',
                    primaryColor: AppColor.primaryColor,
                    txtSize: SizeConfig.widthResponsive(0.05),
                    loading: false,
                    onTap: () {
                      Helper.dismissKeyBoard();
                      // TODO: ربط الدفع البنكي بـ API الدفع عند إضافته
                    }
                ),
              ],
            ),
          ),
        ],
      )),
    );
  }
}
