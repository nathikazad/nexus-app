import 'package:flutter/material.dart';

class AttributeField extends StatelessWidget {
  final String attributeKey;
  final String valueType;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final bool required;

  const AttributeField({
    super.key,
    required this.attributeKey,
    required this.valueType,
    this.value,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (valueType) {
      case 'string':
        return TextFormField(
          initialValue: value as String?,
          decoration: InputDecoration(
            labelText: attributeKey,
            hintText: 'Enter $attributeKey',
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) => onChanged(val),
        );
      case 'number':
        return TextFormField(
          initialValue: value?.toString(),
          decoration: InputDecoration(
            labelText: attributeKey,
            hintText: 'Enter $attributeKey',
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (val) {
            final num = int.tryParse(val);
            onChanged(num);
          },
        );
      case 'boolean':
        return CheckboxListTile(
          title: Text(attributeKey),
          value: value as bool? ?? false,
          onChanged: (val) => onChanged(val ?? false),
        );
      case 'datetime':
        return ListTile(
          title: Text(attributeKey),
          subtitle: Text(value != null ? value.toString() : 'Not set'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value != null ? DateTime.parse(value.toString()) : DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              onChanged(date.toIso8601String());
            }
          },
        );
      default:
        return TextFormField(
          initialValue: value?.toString(),
          decoration: InputDecoration(
            labelText: attributeKey,
            hintText: 'Enter $attributeKey',
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) => onChanged(val),
        );
    }
  }
}

