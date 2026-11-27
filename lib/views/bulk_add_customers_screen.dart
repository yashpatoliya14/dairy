import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/api_service.dart';
import '../services/app_language.dart';

bool isValidBulkCustomerName(String raw) {
  final name = raw.trim();
  if (name.length < 2 || name.length > 60) return false;
  if (RegExp(r'^(?:customer|ગ્રાહક|ग्राहक)\s*#?\d*$', caseSensitive: false).hasMatch(name)) {
    return false;
  }
  final letters = name.replaceAll(RegExp(r'[^A-Za-z\u0A80-\u0AFF\u0900-\u097F]'), '');
  return letters.length >= 2;
}

String normalizeBulkPhoneDigits(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return digits;
}

String? validateBulkPhoneInput(String? raw) {
  final digits = normalizeBulkPhoneDigits(raw ?? '');
  if (digits.isEmpty) return null; // Optional if card had no phone
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
    return T.t('Enter a valid 10-digit mobile number');
  }
  return null;
}

class BulkCustomerDraft {
  BulkCustomerDraft({
    required this.uniqueNumber,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.litersCtrl,
    required this.priceCtrl,
    this.imagePath,
  });

  String uniqueNumber;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController litersCtrl;
  final TextEditingController priceCtrl;
  final String? imagePath;

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    litersCtrl.dispose();
    priceCtrl.dispose();
  }
}

class BulkAddCustomersScreen extends StatefulWidget {
  const BulkAddCustomersScreen({
    super.key,
    required this.api,
    this.onSuccess,
    this.initialDefaultLiters = 1.0,
    this.initialDefaultPrice = 0.0,
    this.existingCustomers = const [],
  });

  final ApiService api;
  final VoidCallback? onSuccess;
  final double initialDefaultLiters;
  final double initialDefaultPrice;
  final List<Map<String, dynamic>> existingCustomers;

  @override
  State<BulkAddCustomersScreen> createState() => _BulkAddCustomersScreenState();
}

class _BulkAddCustomersScreenState extends State<BulkAddCustomersScreen> {
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<BulkCustomerDraft> _drafts = [];

  bool _isAnalyzing = false;
  bool _isSaving = false;
  late double _dairyDefaultLiters;
  late double _dairyDefaultPrice;
  final Set<int> _existingNumbers = <int>{};
  int _baseNextNumber = 1;

  @override
  void initState() {
    super.initState();
    _dairyDefaultLiters =
        widget.initialDefaultLiters > 0 ? widget.initialDefaultLiters : 1.0;
    _dairyDefaultPrice =
        widget.initialDefaultPrice >= 0 ? widget.initialDefaultPrice : 0.0;
    _ingestExistingCustomers(widget.existingCustomers);
    _syncDairyMetadata();
  }

  void _ingestExistingCustomers(List<Map<String, dynamic>> customers) {
    _existingNumbers.clear();
    int highest = 0;
    for (final c in customers) {
      final raw = '${c['uniqueNumber'] ?? c['customerNumber'] ?? ''}'.trim();
      final numVal = int.tryParse(raw);
      if (numVal != null && numVal > 0) {
        _existingNumbers.add(numVal);
        if (numVal > highest) highest = numVal;
      }
    }
    _baseNextNumber = highest + 1;
    _resequenceDraftNumbers();
  }

  Future<void> _syncDairyMetadata() async {
    try {
      final results = await Future.wait([
        widget.api.getSettings().catchError((_) => <String, dynamic>{}),
        widget.api.getCustomers().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      final settings = results[0] as Map<String, dynamic>;
      final customers = results[1] as List<Map<String, dynamic>>;
      setState(() {
        final sLiters = double.tryParse('${settings['defaultLiters'] ?? ''}');
        final sPrice = double.tryParse('${settings['defaultPrice'] ?? ''}');
        if (sLiters != null && sLiters > 0) _dairyDefaultLiters = sLiters;
        if (sPrice != null && sPrice >= 0) _dairyDefaultPrice = sPrice;
        if (customers.isNotEmpty) {
          _ingestExistingCustomers(customers);
        }
      });
    } catch (_) {}
  }

  void _resequenceDraftNumbers() {
    int nextNum = _baseNextNumber;
    for (final draft in _drafts) {
      while (_existingNumbers.contains(nextNum)) {
        nextNum++;
      }
      draft.uniqueNumber = '$nextNum';
      nextNum++;
    }
  }

  String _formatDecimal(double val) {
    return val == val.truncateToDouble()
        ? val.toStringAsFixed(0)
        : val.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _pickGalleryImages() async {
    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 90,
        maxWidth: 1920,
      );
      if (images.isNotEmpty) {
        await _analyzeImages(images.take(100).toList());
      }
    } catch (e) {
      Get.snackbar(
        T.t('Error'),
        'Failed to select images: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _pickCameraImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1920,
      );
      if (image != null) {
        await _analyzeImages([image]);
      }
    } catch (e) {
      Get.snackbar(
        T.t('Error'),
        'Failed to capture image: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _analyzeImages(List<XFile> files) async {
    setState(() => _isAnalyzing = true);
    try {
      final List<String> base64Images = [];
      for (final file in files) {
        final bytes = await File(file.path).readAsBytes();
        final base64Str = base64Encode(bytes);
        base64Images.add('data:image/jpeg;base64,$base64Str');
      }

      final res = await widget.api.scanCustomerCards(base64Images);

      final dairyDefaults = res['dairyDefaults'];
      if (dairyDefaults is Map) {
        final dl = double.tryParse('${dairyDefaults['defaultLiters'] ?? ''}');
        final dp = double.tryParse('${dairyDefaults['defaultPrice'] ?? ''}');
        if (dl != null && dl > 0) _dairyDefaultLiters = dl;
        if (dp != null && dp >= 0) _dairyDefaultPrice = dp;
      }
      final serverNext = int.tryParse('${res['nextCustomerNumber'] ?? ''}');
      if (serverNext != null && serverNext > _baseNextNumber) {
        _baseNextNumber = serverNext;
      }

      if (res['success'] == false) {
        final msg = res['message']?.toString().trim().isNotEmpty == true
            ? res['message'].toString()
            : T.t('No customer records could be identified in the card image(s).');
        if (mounted) {
          Get.snackbar(
            T.t('No Customers Found'),
            msg,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xfffee2e2),
            colorText: const Color(0xff991b1b),
            duration: const Duration(seconds: 5),
          );
        }
        return;
      }

      final rawList = res['customers'] as List<dynamic>? ?? [];
      int rejectedCount = res['rejectedCount'] as int? ?? 0;
      int addedCount = 0;

      for (final item in rawList) {
        final Map<String, dynamic> c =
            item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);

        final name = '${c['name'] ?? ''}'.trim();
        if (!isValidBulkCustomerName(name)) {
          rejectedCount++;
          continue;
        }

        final phone = normalizeBulkPhoneDigits('${c['phoneNumber'] ?? ''}');
        final validPhone = RegExp(r'^[6-9]\d{9}$').hasMatch(phone) ? phone : '';

        final parsedLiters = double.tryParse('${c['liters'] ?? ''}');
        final litersVal = (parsedLiters != null && parsedLiters > 0 && parsedLiters <= 100)
            ? parsedLiters
            : _dairyDefaultLiters;

        final parsedPrice = double.tryParse('${c['price'] ?? ''}');
        final priceVal = (parsedPrice != null && parsedPrice >= 0 && parsedPrice <= 500)
            ? parsedPrice
            : _dairyDefaultPrice;

        _drafts.add(
          BulkCustomerDraft(
            uniqueNumber: '',
            nameCtrl: TextEditingController(text: name),
            phoneCtrl: TextEditingController(text: validPhone),
            litersCtrl: TextEditingController(text: _formatDecimal(litersVal)),
            priceCtrl: TextEditingController(text: _formatDecimal(priceVal)),
          ),
        );
        addedCount++;
      }

      _resequenceDraftNumbers();

      if (addedCount == 0) {
        if (mounted) {
          setState(() {});
          Get.snackbar(
            T.t('No Customers Found'),
            T.t('No customer records could be identified in the card image(s).'),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xfffee2e2),
            colorText: const Color(0xff991b1b),
            duration: const Duration(seconds: 5),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {});
        final successMsg = rejectedCount > 0
            ? '${T.t("Extracted Customers")}: $addedCount ($rejectedCount ${T.t("invalid/empty cards skipped")})'
            : '${T.t("Extracted Customers")}: $addedCount. ${T.t("Please review before adding.")}';
        Get.snackbar(
          T.t('Card Analysis Complete'),
          successMsg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xffdcfce7),
          colorText: const Color(0xff166534),
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          T.t('Error'),
          '${T.t("Could not extract customer details from cards.")} ($e)',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xfffee2e2),
          colorText: const Color(0xff991b1b),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _addNewDraftRow() {
    setState(() {
      _drafts.add(
        BulkCustomerDraft(
          uniqueNumber: '',
          nameCtrl: TextEditingController(),
          phoneCtrl: TextEditingController(),
          litersCtrl: TextEditingController(text: _formatDecimal(_dairyDefaultLiters)),
          priceCtrl: TextEditingController(text: _formatDecimal(_dairyDefaultPrice)),
        ),
      );
      _resequenceDraftNumbers();
    });
  }

  void _removeDraft(int index) {
    setState(() {
      final removed = _drafts.removeAt(index);
      removed.dispose();
      _resequenceDraftNumbers();
    });
  }

  Future<void> _submitAll() async {
    if (_drafts.isEmpty) {
      Get.snackbar(
        T.t('No Customers'),
        T.t('Please upload cards or add customer entries first.'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      Get.snackbar(
        T.t('Validation Error'),
        T.t('Please fix highlighted fields before saving.'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xfffee2e2),
        colorText: const Color(0xff991b1b),
      );
      return;
    }

    _resequenceDraftNumbers();

    final List<Map<String, dynamic>> payload = [];
    for (int i = 0; i < _drafts.length; i++) {
      final draft = _drafts[i];
      final name = draft.nameCtrl.text.trim();
      final phone = normalizeBulkPhoneDigits(draft.phoneCtrl.text);
      final liters = double.tryParse(draft.litersCtrl.text.trim().replaceAll(',', '.'));
      final price = double.tryParse(draft.priceCtrl.text.trim().replaceAll(',', '.'));

      if (!isValidBulkCustomerName(name)) {
        Get.snackbar(
          T.t('Validation Error'),
          '${T.t("Customer")} #${draft.uniqueNumber} ${T.t("must have a name")}.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xfffee2e2),
          colorText: const Color(0xff991b1b),
        );
        return;
      }

      if (phone.isNotEmpty && !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
        Get.snackbar(
          T.t('Validation Error'),
          '${T.t("Customer")} #${draft.uniqueNumber}: ${T.t("Enter a valid 10-digit mobile number")}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xfffee2e2),
          colorText: const Color(0xff991b1b),
        );
        return;
      }

      if (liters == null || liters <= 0 || liters > 100) {
        Get.snackbar(
          T.t('Validation Error'),
          '${T.t("Customer")} #${draft.uniqueNumber}: ${T.t("Enter a valid number")}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xfffee2e2),
          colorText: const Color(0xff991b1b),
        );
        return;
      }

      if (price == null || price < 0 || price > 500) {
        Get.snackbar(
          T.t('Validation Error'),
          '${T.t("Customer")} #${draft.uniqueNumber}: ${T.t("Enter a valid number")}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xfffee2e2),
          colorText: const Color(0xff991b1b),
        );
        return;
      }

      payload.add({
        'name': name,
        'uniqueNumber': draft.uniqueNumber,
        'phoneNumber': phone,
        'liters': liters,
        'price': price,
        'notificationChannel': 'whatsapp',
      });
    }

    setState(() => _isSaving = true);
    try {
      final res = await widget.api.bulkCreateCustomers(payload);
      final count = res['count'] ?? payload.length;

      if (mounted) {
        Get.snackbar(
          T.t('Success'),
          '$count ${T.t("customers added successfully")}! 🎉',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xffdcfce7),
          colorText: const Color(0xff166534),
        );
        widget.onSuccess?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          T.t('Failed to add customers'),
          '$e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xfffee2e2),
          colorText: const Color(0xff991b1b),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        title: Text(
          T.t('Bulk Milk Card Upload'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xff1b4d36),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus),
            tooltip: T.t('Add Row'),
            onPressed: _isAnalyzing || _isSaving ? null : _addNewDraftRow,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xffdcefe3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.images,
                          color: Color(0xff2d7a55),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              T.t('Scan Customer Cards'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              T.t(
                                'Upload 1 to 100 customer milk card images to automatically extract details.',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isAnalyzing ? null : _pickGalleryImages,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2d7a55),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(LucideIcons.imagePlus, size: 18),
                          label: Text(
                            T.t('Select Photos'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isAnalyzing ? null : _pickCameraImage,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff2d7a55),
                            side: const BorderSide(color: Color(0xff2d7a55), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(LucideIcons.camera, size: 18),
                          label: Text(
                            T.t('Take Photo'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isAnalyzing) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(
                      color: Color(0xff2d7a55),
                      backgroundColor: Color(0xffdcefe3),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        T.t('Analyzing milk cards... please wait'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xfff1f5f9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${T.t("Extracted Customers")}: ${_drafts.length} (${T.t("Next")} #$_baseNextNumber)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xff334155),
                    ),
                  ),
                  InkWell(
                    onTap: _isAnalyzing || _isSaving ? null : _addNewDraftRow,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.plus, size: 14, color: Color(0xff2d7a55)),
                        const SizedBox(width: 4),
                        Text(
                          T.t('Add Row'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: Color(0xff2d7a55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _drafts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.fileSpreadsheet,
                              size: 52,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              T.t('No cards uploaded yet'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              T.t(
                                'Tap "Select Photos" to pick customer milk cards, or take photos with camera.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                      itemCount: _drafts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final draft = _drafts[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xff1e293b).withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffdcefe3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${draft.uniqueNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: Color(0xff2d7a55),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${T.t("Customer")} #${draft.uniqueNumber}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      LucideIcons.trash2,
                                      size: 16,
                                      color: Color(0xffef4444),
                                    ),
                                    tooltip: T.t('Delete Row'),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _removeDraft(index),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: draft.nameCtrl,
                                      textCapitalization: TextCapitalization.words,
                                      autovalidateMode: AutovalidateMode.onUserInteraction,
                                      validator: (val) {
                                        if (!isValidBulkCustomerName(val ?? '')) {
                                          return T.t('Enter valid name');
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: T.t('Customer Name'),
                                        hintText: T.t('Full name'),
                                        labelStyle: const TextStyle(fontSize: 11.5),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: draft.phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      autovalidateMode: AutovalidateMode.onUserInteraction,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      validator: validateBulkPhoneInput,
                                      decoration: InputDecoration(
                                        labelText: T.t('Mobile Number'),
                                        hintText: '9876543210',
                                        labelStyle: const TextStyle(fontSize: 11.5),
                                        prefixText: '+91 ',
                                        prefixStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: draft.litersCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                      autovalidateMode: AutovalidateMode.onUserInteraction,
                                      validator: (val) {
                                        final d = double.tryParse(
                                            (val ?? '').trim().replaceAll(',', '.'));
                                        if (d == null || d <= 0 || d > 100) {
                                          return T.t('Enter a valid number');
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: T.t('Default Liters'),
                                        suffixText: 'L',
                                        labelStyle: const TextStyle(fontSize: 11.5),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: draft.priceCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                      autovalidateMode: AutovalidateMode.onUserInteraction,
                                      validator: (val) {
                                        final d = double.tryParse(
                                            (val ?? '').trim().replaceAll(',', '.'));
                                        if (d == null || d < 0 || d > 500) {
                                          return T.t('Enter a valid number');
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: T.t('Rate per Liter'),
                                        prefixText: '₹',
                                        labelStyle: const TextStyle(fontSize: 11.5),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: _drafts.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submitAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff1b4d36),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(LucideIcons.checkCheck, size: 20),
                    label: Text(
                      _isSaving
                          ? T.t('Saving customers...')
                          : '${T.t("Confirm & Add All")} (${_drafts.length} ${T.t("Customers")})',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
