import 'package:flutter/material.dart';

import '../../core/utils/date_helpers.dart';

/// Campo de seleção de data reutilizável.
class DateField extends StatelessWidget {
  final DateTime value;
  final String label;
  final ValueChanged<DateTime> onChanged;

  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Data',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Text(DateHelpers.fullDate.format(value)),
      ),
    );
  }
}
