import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/api_service.dart';
import '../services/app_language.dart';

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
  });

  final ApiService api;
  final VoidCallback? onSuccess;

  @override
  State<BulkAddCustomersScreen> createState() => _BulkAddCustomersScreenState();
}

class _BulkAddCustomersScreenState extends State<BulkAddCustomersScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedFiles = [];
  final List<BulkCustomerDraft> _drafts = [];
  bool _isAnalyzing = false;
  bool _isSaving = false;

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
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(images);
        });
        await _analyzeImages(images);
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
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (image != null) {
        setState(() {
          _selectedFiles.add(image);
        });
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

      if (res['success'] == false) {
        final msg = res['message'] ?? 'Could not extract customer details from cards.';
        if (mounted) {
          Get.snackbar(
            T.t('Card Scanning Note'),
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
      if (rawList.isEmpty) {
        if (mounted) {
          Get.snackbar(
            T.t('No Customers Found'),
            'No customer records could be identified in the card image(s).',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return;
      }

      int startIdx = _drafts.length + 1;
      for (final item in rawList) {
        final Map<String, dynamic> c =
            item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);

        final name = '${c['name'] ?? 'Customer #$startIdx'}'.trim();
        final phone = '${c['phoneNumber'] ?? ''}'.trim();
        final liters = '${c['liters'] ?? 1.0}'.trim();
        final price = '${c['price'] ?? 60.0}'.trim();
        final number = '${c['uniqueNumber'] ?? startIdx}'.trim();

        _drafts.add(
          BulkCustomerDraft(
            uniqueNumber: number,
            nameCtrl: TextEditingController(text: name),
            phoneCtrl: TextEditingController(text: phone),
            litersCtrl: TextEditingController(text: liters),
            priceCtrl: TextEditingController(text: price),
          ),
        );
        startIdx++;
      }

      if (mounted) {
        setState(() {});
        Get.snackbar(
          T.t('Card Analysis Complete'),
          'Extracted ${rawList.length} customer records. Please review before adding.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xffdcfce7),
          colorText: const Color(0xff166534),
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          T.t('Error'),
          'Failed to analyze cards: $e',
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
    final idx = _drafts.length + 1;
    setState(() {
      _drafts.add(
        BulkCustomerDraft(
          uniqueNumber: '$idx',
          nameCtrl: TextEditingController(text: 'Customer #$idx'),
          phoneCtrl: TextEditingController(text: ''),
          litersCtrl: TextEditingController(text: '1.0'),
          priceCtrl: TextEditingController(text: '60.0'),
        ),
      );
    });
  }

  void _removeDraft(int index) {
    setState(() {
      final removed = _drafts.removeAt(index);
      removed.dispose();
      // Re-index remaining drafts
      for (int i = 0; i < _drafts.length; i++) {
        _drafts[i].uniqueNumber = '${i + 1}';
      }
    });
  }

  Future<void> _submitAll() async {
    if (_drafts.isEmpty) {
      Get.snackbar(
        T.t('No Customers'),
        'Please upload cards or add customer entries first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Prepare list
    final List<Map<String, dynamic>> payload = [];
    for (int i = 0; i < _drafts.length; i++) {
      final draft = _drafts[i];
      final name = draft.nameCtrl.text.trim();
      final phone = draft.phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
      final liters = double.tryParse(draft.litersCtrl.text.trim()) ?? 1.0;
      final price = double.tryParse(draft.priceCtrl.text.trim()) ?? 60.0;

      if (name.isEmpty) {
        Get.snackbar(
          T.t('Validation Error'),
          'Customer #${i + 1} must have a name.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      payload.add({
        'name': name,
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
          if (_drafts.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.userPlus),
              tooltip: T.t('Add Row'),
              onPressed: _addNewDraftRow,
            ),
        ],
      ),
      body: Column(
        children: [
          // Header / Upload Action Card
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

          // Count Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xfff1f5f9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${T.t("Extracted Customers")}: ${_drafts.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xff334155),
                  ),
                ),
                if (_drafts.isNotEmpty)
                  InkWell(
                    onTap: _addNewDraftRow,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.plus, size: 14, color: Color(0xff2d7a55)),
                        const SizedBox(width: 4),
                        Text(
                          T.t('+ Add Row'),
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

          // Customer Cards Review List
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
                            // Top Row: Card # + Delete Icon
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
                                    'Customer #${draft.uniqueNumber}',
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

                            // Fields Row 1: Name & Phone
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: draft.nameCtrl,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: InputDecoration(
                                      labelText: T.t('Customer Name'),
                                      labelStyle: const TextStyle(fontSize: 11.5),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
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
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    decoration: InputDecoration(
                                      labelText: T.t('Mobile Number'),
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
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Fields Row 2: Liters & Price
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: draft.litersCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(decimal: true),
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

      // Bottom Bar with Confirm & Add All Button
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
