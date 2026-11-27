import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/app_language.dart';
import '../services/notification_service.dart';

class ReminderSettingsSheet extends StatefulWidget {
  const ReminderSettingsSheet({
    super.key,
    this.onSaved,
  });

  final VoidCallback? onSaved;

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReminderSettingsSheet(onSaved: onSaved),
    );
  }

  @override
  State<ReminderSettingsSheet> createState() => _ReminderSettingsSheetState();
}

class _ReminderSettingsSheetState extends State<ReminderSettingsSheet> {
  List<ReminderSlot> _slots = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    final slots = await NotificationService.instance.getSavedSlots();
    if (mounted) {
      setState(() {
        _slots = List.from(slots);
        _isLoading = false;
      });
    }
  }

  Future<void> _pickTime(int index) async {
    final slot = _slots[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: slot.hour, minute: slot.minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff1b4332),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xff1b4332),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        slot.hour = picked.hour;
        slot.minute = picked.minute;
      });
    }
  }

  void _addSlot() {
    if (_slots.length >= NotificationService.maxReminderSlots) {
      Get.snackbar(
        T.t('Reminder Limit'),
        T.t('Maximum 7 reminders can be added.'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xfffef3c7),
        colorText: const Color(0xff92400e),
      );
      return;
    }

    setState(() {
      _slots.add(
        ReminderSlot(
          id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
          hour: 18,
          minute: 0,
          type: 'check_ledger',
          isEnabled: true,
        ),
      );
    });
  }

  void _removeSlot(int index) {
    if (_slots.length <= 1) {
      Get.snackbar(
        T.t('Reminder'),
        T.t('At least one reminder slot should remain.'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    setState(() {
      _slots.removeAt(index);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final granted = await NotificationService.instance.requestPermissions();
      await NotificationService.instance.saveSlots(_slots);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved?.call();
      if (!granted) {
        Get.snackbar(
          T.t('Notification Permission Required'),
          T.t('Please enable notifications in phone settings so reminders can alert you on time.'),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xfffef3c7),
          colorText: const Color(0xff92400e),
          duration: const Duration(seconds: 5),
        );
      } else {
        Get.snackbar(
          T.t('Reminders Saved'),
          T.t('Daily reminders have been updated successfully.'),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xffdcfce7),
          colorText: const Color(0xff166534),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final atLimit = _slots.length >= NotificationService.maxReminderSlots;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffdcfce7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.bellRing,
                    color: Color(0xff16a34a),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              T.t('Daily Reminder Settings'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff0f172a),
                              ),
                            ),
                          ),
                          if (!_isLoading) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: atLimit
                                    ? const Color(0xfffef3c7)
                                    : const Color(0xffdcefe3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_slots.length}/${NotificationService.maxReminderSlots}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: atLimit
                                      ? const Color(0xff92400e)
                                      : const Color(0xff1b4332),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        T.t('Set reminder times & notifications'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _slots.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final slot = _slots[index];
                    final safeType = kReminderTypes.any((t) => t.id == slot.type)
                        ? slot.type
                        : kReminderTypes.first.id;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: slot.isEnabled
                            ? const Color(0xfff8fafc)
                            : const Color(0xfff1f5f9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: slot.isEnabled
                              ? const Color(0xffe2e8f0)
                              : const Color(0xffcbd5e1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () => _pickTime(index),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xff1b4332),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.clock,
                                        size: 16,
                                        color: Color(0xff1b4332),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        slot.formattedTime,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xff1b4332),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Switch.adaptive(
                                value: slot.isEnabled,
                                activeTrackColor: const Color(0xff1b4332),
                                onChanged: (val) {
                                  setState(() {
                                    slot.isEnabled = val;
                                  });
                                },
                              ),
                              if (_slots.length > 1) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    size: 20,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _removeSlot(index),
                                  tooltip: T.t('Delete'),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: safeType,
                                isExpanded: true,
                                icon: const Icon(LucideIcons.chevronDown, size: 18),
                                items: kReminderTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type.id,
                                    child: Text(
                                      type.label,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newType) {
                                  if (newType != null) {
                                    setState(() {
                                      slot.type = newType;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: atLimit ? null : _addSlot,
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(
                  atLimit
                      ? T.t('Maximum 7 reminders limit reached')
                      : T.t('Add Another Reminder'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff1b4332),
                  side: BorderSide(
                    color: atLimit ? Colors.grey.shade300 : const Color(0xff1b4332),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff1b4332),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  T.t('Save Reminders'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
