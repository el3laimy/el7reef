import 'package:flutter/material.dart';

class MatchdaySubstitutionDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  const MatchdaySubstitutionDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: onChanged != null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

String? safeDropdownValue({
  required String? selectedValue,
  required Set<String> items,
}) {
  if (selectedValue == null || !items.contains(selectedValue)) {
    return null;
  }
  return selectedValue;
}
