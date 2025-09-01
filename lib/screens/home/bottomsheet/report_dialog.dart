import 'package:flutter/material.dart';

import '../../../utils/utils.dart';

typedef ReportSubmitCallback = Future<String> Function({
required String reason,
String? description,
});

class ReportDialog extends StatefulWidget {
  final String title;
  final Map<String, String> reasons;
  final bool isDescriptionRequired;
  final ReportSubmitCallback onSubmit;
  final BuildContext scaffoldContext;

  const ReportDialog({
    super.key,
    required this.title,
    required this.reasons,
    required this.onSubmit,
    this.isDescriptionRequired = false, required this.scaffoldContext,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? selectedReason;
  final TextEditingController descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      backgroundColor: Theme.of(context).colorScheme.onSecondary,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you reporting this?'),
              const SizedBox(height: 16),
              ...widget.reasons.keys.map(
                    (reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) => setState(() {
                    selectedReason = value;
                  }),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: widget.isDescriptionRequired
                      ? 'Description (required)'
                      : 'Description (optional)',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (selectedReason == null ||
              descriptionController.text.trim().isEmpty)
              ? null
              : () async {
            final reasonApi = widget.reasons[selectedReason!]!;
            final description = descriptionController.text.trim();
            await Utils.showLoaderWhile(
              context,
                  () async {
                try {
                  final message = await widget.onSubmit(
                    reason: reasonApi,
                    description: description,
                  );

                  print('Report submitted: $message');

                  if (mounted) Navigator.pop(context, message);
                } catch (e) {
                  if (mounted) Navigator.pop(context, 'Failed to submit report: $e');
                }
              },
            );
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
