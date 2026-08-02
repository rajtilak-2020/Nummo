import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'theme.dart';
import 'models.dart';

class SettingsScreen extends StatefulWidget {
  final bool isLocalAuthEnabled;
  final List<String> tags;
  final VoidCallback onSecuritySetupTap;
  final Future<void> Function() onResetApp;
  final Future<void> Function(List<String> updatedTags) onTagsUpdated;
  final List<Transaction> transactions;

  const SettingsScreen({
    super.key,
    required this.isLocalAuthEnabled,
    required this.tags,
    required this.onSecuritySetupTap,
    required this.onResetApp,
    required this.onTagsUpdated,
    this.transactions = const [],
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _resetClickCount = 0;
  DateTime? _lastResetClickTime;
  late List<String> _currentTags;

  @override
  void initState() {
    super.initState();
    _currentTags = List.from(widget.tags);
  }

  void _handleResetTap() {
    final now = DateTime.now();
    if (_lastResetClickTime == null ||
        now.difference(_lastResetClickTime!) > const Duration(seconds: 2)) {
      _resetClickCount = 1;
    } else {
      _resetClickCount++;
    }
    _lastResetClickTime = now;

    if (_resetClickCount >= 5) {
      HapticFeedback.heavyImpact();
      _resetClickCount = 0;
      _showResetAppDialog(context);
    } else {
      HapticFeedback.selectionClick();
      final remaining = 5 - _resetClickCount;
      ScaffoldMessenger.of(context).clearSnackBars();
      final isDark = Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'YOU ARE NOW $remaining CLICK${remaining > 1 ? 'S' : ''} AWAY FROM RESETTING.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          backgroundColor: isDark ? const Color(0xFF1E2026) : const Color(0xFFE2E8F0),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.debit(context), width: 1.5),
          ),
        ),
      );
    }
  }

  void _openEmojiLibraryModal(
      BuildContext context, Function(String) onEmojiSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final accent = Theme.of(context).colorScheme.primary;

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EMOJI LIBRARY',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: AppColors.textPrimary(context), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: TagHelper.emojiCategories.entries.map((entry) {
                      final categoryName = entry.key;
                      final emojis = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              categoryName.toUpperCase(),
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: emojis.map((emoji) {
                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onEmojiSelected(emoji);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.scaffold(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.cardBorder(context),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddTagDialog(BuildContext context) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedEmoji = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final accent = Theme.of(context).colorScheme.primary;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.label_outline_rounded,
                            color: accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'New Category Tag',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Create a custom category badge',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: AppColors.textSecondary(context),
                              size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Form
                    Form(
                      key: formKey,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon Selection Tile Button (Same Line Before Tag Name)
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _openEmojiLibraryModal(context, (emoji) {
                                setDialogState(() {
                                  selectedEmoji = emoji;
                                });
                              });
                            },
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedEmoji.isNotEmpty
                                      ? accent
                                      : AppColors.cardBorder(context),
                                  width: selectedEmoji.isNotEmpty ? 1.5 : 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                selectedEmoji.isEmpty ? '😀' : selectedEmoji,
                                style: TextStyle(
                                  fontSize: 24,
                                  color: selectedEmoji.isEmpty
                                      ? AppColors.textPrimary(context)
                                          .withValues(alpha: 0.3)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Tag Name Input Field
                          Expanded(
                            child: TextFormField(
                              controller: nameController,
                              autofocus: true,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                              decoration: const InputDecoration(
                                labelText: 'Tag Name',
                                hintText: 'e.g. SHOPPING, RENT',
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              onChanged: (val) {
                                setDialogState(() {});
                              },
                              validator: (value) {
                                final clean =
                                    TagHelper.getCleanName(value ?? '')
                                        .toUpperCase();
                                if (clean.isEmpty) {
                                  return 'Tag name is required';
                                }
                                final existingCleanTags = _currentTags
                                    .map((t) => TagHelper.getCleanName(t)
                                        .toUpperCase())
                                    .toList();
                                if (existingCleanTags.contains(clean)) {
                                  return 'Tag name already exists';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Minimal Floating Live Preview Pill
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selectedEmoji.isNotEmpty) ...[
                              Text(
                                selectedEmoji,
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              nameController.text.trim().isEmpty
                                  ? 'TAG PREVIEW'
                                  : TagHelper.getCleanName(
                                          nameController.text)
                                      .toUpperCase(),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          HapticFeedback.mediumImpact();
                          final cleanName =
                              TagHelper.getCleanName(nameController.text)
                                  .toUpperCase();
                          final finalEmoji = selectedEmoji.trim();
                          final formattedTag =
                              TagHelper.formatTag(cleanName, finalEmoji);

                          setState(() {
                            _currentTags.add(formattedTag);
                          });
                          await widget.onTagsUpdated(_currentTags);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tag "$formattedTag" added',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              backgroundColor: AppColors.credit(context),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'CREATE TAG',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditTagDialog(BuildContext context, String currentTag) {
    final cleanName = TagHelper.getCleanName(currentTag).toUpperCase();
    final currentEmoji = TagHelper.getEmoji(currentTag);

    final nameController = TextEditingController(text: cleanName);
    final formKey = GlobalKey<FormState>();
    String selectedEmoji = currentEmoji;

    final isLinkedToTransactions = widget.transactions.any((tx) {
      final txClean = TagHelper.getCleanName(tx.tag ?? '').toUpperCase();
      return txClean == cleanName;
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final accent = Theme.of(context).colorScheme.primary;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.edit_note_rounded,
                            color: accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLinkedToTransactions
                                    ? 'Edit Tag Icon'
                                    : 'Edit Tag',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isLinkedToTransactions
                                    ? 'Icon customizable only'
                                    : 'Update tag details',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: AppColors.textSecondary(context),
                              size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (isLinkedToTransactions) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBorder(context)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.cardBorder(context)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 18, color: accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tag name locked (used in past transactions). You can edit its icon.',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Form
                    Form(
                      key: formKey,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon Selection Tile Button (Same Line Before Tag Name)
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _openEmojiLibraryModal(context, (emoji) {
                                setDialogState(() {
                                  selectedEmoji = emoji;
                                });
                              });
                            },
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedEmoji.isNotEmpty
                                      ? accent
                                      : AppColors.cardBorder(context),
                                  width: selectedEmoji.isNotEmpty ? 1.5 : 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                selectedEmoji.isEmpty ? '😀' : selectedEmoji,
                                style: TextStyle(
                                  fontSize: 24,
                                  color: selectedEmoji.isEmpty
                                      ? AppColors.textPrimary(context)
                                          .withValues(alpha: 0.3)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Tag Name Input Field
                          Expanded(
                            child: TextFormField(
                              controller: nameController,
                              enabled: !isLinkedToTransactions,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'Tag Name',
                                hintText: 'e.g. SHOPPING, RENT',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: AppColors.cardBorder(context),
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                setDialogState(() {});
                              },
                              validator: (value) {
                                final clean =
                                    TagHelper.getCleanName(value ?? '')
                                        .toUpperCase();
                                if (clean.isEmpty) {
                                  return 'Tag name is required';
                                }
                                if (clean != cleanName) {
                                  final existingCleanTags = _currentTags
                                      .where((t) =>
                                          TagHelper.getCleanName(t)
                                              .toUpperCase() !=
                                          cleanName)
                                      .map((t) => TagHelper.getCleanName(t)
                                          .toUpperCase())
                                      .toList();
                                  if (existingCleanTags.contains(clean)) {
                                    return 'Tag name already exists';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Minimal Floating Live Preview Pill
                    Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selectedEmoji.isNotEmpty) ...[
                              Text(
                                selectedEmoji,
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              nameController.text.trim().isEmpty
                                  ? 'TAG PREVIEW'
                                  : TagHelper.getCleanName(
                                          nameController.text)
                                      .toUpperCase(),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          HapticFeedback.mediumImpact();
                          final newCleanName =
                              TagHelper.getCleanName(nameController.text)
                                  .toUpperCase();
                          final newEmoji = selectedEmoji.trim();
                          final updatedFormattedTag =
                              TagHelper.formatTag(newCleanName, newEmoji);

                          setState(() {
                            final index = _currentTags.indexOf(currentTag);
                            if (index != -1) {
                              _currentTags[index] = updatedFormattedTag;
                            }
                          });
                          await widget.onTagsUpdated(_currentTags);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tag "$updatedFormattedTag" saved',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              backgroundColor: AppColors.credit(context),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'SAVE TAG',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteTagDialog(BuildContext context, String tagToDelete) {
    final debitColor = AppColors.debit(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: debitColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline, color: debitColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Tag',
                  style: TextStyle(
                    color: debitColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete tag "$tagToDelete"?',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Past transactions tagged as "$tagToDelete" will retain their category in history & analytics.',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: debitColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                HapticFeedback.heavyImpact();
                setState(() {
                  _currentTags.remove(tagToDelete);
                });
                await widget.onTagsUpdated(_currentTags);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tag "$tagToDelete" deleted',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: debitColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showResetAppDialog(BuildContext context) {
    final confirmationController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isConfirmEnabled =
                confirmationController.text.trim().toLowerCase() == 'yes delete';
            final debitColor = AppColors.debit(context);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: debitColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.warning_amber_rounded,
                        color: debitColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Reset App Data',
                    style: TextStyle(
                      color: debitColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Are you sure you want to completely erase all of your transactions and settings? This action cannot be undone.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: confirmationController,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Type "yes delete" to confirm',
                        hintText: 'yes delete',
                      ),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                      validator: (value) {
                        if (value == null ||
                            value.trim().toLowerCase() != 'yes delete') {
                          return 'Confirmation text mismatch';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConfirmEnabled
                            ? debitColor
                            : Theme.of(context).disabledColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isConfirmEnabled
                          ? () async {
                              final navigator = Navigator.of(context);
                              final scaffoldMessenger =
                                  ScaffoldMessenger.of(context);
                              await widget.onResetApp();
                              navigator.pop(); // Pop dialog
                              navigator.pop(); // Pop Settings screen
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'ALL FINANCE DATA ERASED',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: debitColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                      child: const Text(
                        'RESET',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeController,
        builder: (context, currentMode, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            children: [
              // APPEARANCE SECTION
              _buildSectionHeader(context, 'APPEARANCE & THEME'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Mode',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select Light, Dark, or System mode',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto_outlined, size: 18),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_outlined, size: 18),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_outlined, size: 18),
                          ),
                        ],
                        selected: {currentMode},
                        onSelectionChanged: (Set<ThemeMode> newSelection) {
                          HapticFeedback.selectionClick();
                          themeController.setThemeMode(newSelection.first);
                        },
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Accent Theme Preset',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Curated color palettes crafted for luxury legibility',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPresetGrid(context),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // CATEGORIES & TAGS SECTION
              _buildSectionHeader(context, 'CATEGORIES & TAGS'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Expense Tags',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_currentTags.length} Active Tags',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: theme.colorScheme.primary, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                            onPressed: () => _showAddTagDialog(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              'ADD TAG',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _currentTags.map((tag) {
                          final emoji = TagHelper.getEmoji(tag);
                          final clean = TagHelper.getCleanName(tag);
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _showEditTagDialog(context, tag);
                            },
                            onLongPress: () =>
                                _showDeleteTagDialog(context, tag),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: AppColors.cardBorder(context),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (emoji.isNotEmpty) ...[
                                    Text(emoji, style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    clean,
                                    style: TextStyle(
                                      color: AppColors.textPrimary(context),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14,
                              color: AppColors.textSecondary(context)),
                          const SizedBox(width: 6),
                          Text(
                            'Tap any tag to edit • Long press to delete.',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // SECURITY SECTION
              _buildSectionHeader(context, 'SECURITY & PRIVACY'),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isLocalAuthEnabled
                          ? AppColors.creditFill(context)
                          : AppColors.cardBorder(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.isLocalAuthEnabled
                          ? Icons.lock_outlined
                          : Icons.lock_open_outlined,
                      color: widget.isLocalAuthEnabled
                          ? AppColors.credit(context)
                          : AppColors.textSecondary(context),
                    ),
                  ),
                  title: const Text(
                    'App PIN & Biometrics',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    widget.isLocalAuthEnabled
                        ? (kIsWeb
                            ? 'PIN Protection Active'
                            : 'PIN & Fingerprint Lock Active')
                        : 'Protect app with compulsory PIN',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onSecuritySetupTap();
                  },
                ),
              ),

              const SizedBox(height: 28),

              // DANGER ZONE SECTION
              _buildSectionHeader(context, 'DANGER ZONE', isDanger: true),
              const SizedBox(height: 10),
              Card(
                color: AppColors.debitFill(context),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.debit(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.debit(context),
                    ),
                  ),
                  title: Text(
                    'Reset All Finance Data',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.debit(context),
                    ),
                  ),
                  subtitle: Text(
                    'Tap 5 times to confirm reset and erase all transactions',
                    style: TextStyle(
                      color: AppColors.debit(context).withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  onTap: _handleResetTap,
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPresetGrid(BuildContext context) {
    final presets = [
      {'preset': ThemePreset.uber, 'name': 'Uber Platinum', 'color': const Color(0xFF38BDF8)},
      {'preset': ThemePreset.matrix, 'name': 'Emerald Mint', 'color': const Color(0xFF10B981)},
      {'preset': ThemePreset.cyber, 'name': 'Electric Cyan', 'color': const Color(0xFF06B6D4)},
      {'preset': ThemePreset.amber, 'name': 'Gold Amber', 'color': const Color(0xFFF59E0B)},
      {'preset': ThemePreset.crimson, 'name': 'Coral Crimson', 'color': const Color(0xFFF43F5E)},
      {'preset': ThemePreset.violet, 'name': 'Royal Violet', 'color': const Color(0xFF8B5CF6)},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: presets.map((item) {
        final preset = item['preset'] as ThemePreset;
        final name = item['name'] as String;
        final color = item['color'] as Color;
        final isSelected = themeController.preset == preset;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            themeController.setPreset(preset);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : AppColors.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? color : AppColors.cardBorder(context),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 6,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                    color: isSelected
                        ? color
                        : AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title,
      {bool isDanger = false}) {
    final color = isDanger
      ? AppColors.debit(context)
      : AppColors.textSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }
}
