import 'package:flutter/material.dart';

class TemplateSelector extends StatelessWidget {
  final Map<String, Map<String, dynamic>> templates;
  final String selectedTemplateKey;
  final bool isExpanded;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<String> onTemplateChanged;

  const TemplateSelector({
    super.key,
    required this.templates,
    required this.selectedTemplateKey,
    required this.isExpanded,
    required this.onExpandedChanged,
    required this.onTemplateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentTemplate = templates[selectedTemplateKey]!;

    return Column(
      children: [
        InkWell(
          onTap: () => onExpandedChanged(!isExpanded),
          child: Row(
            children: [
              Icon(Icons.grid_view, color: Colors.purple[600], size: 20),
              const SizedBox(width: 12),
              const Text(
                'Template:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentTemplate['icon'],
                        size: 18,
                        color: currentTemplate['color'],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentTemplate['name'],
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Spacer(),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final templateKey = templates.keys.elementAt(index);
                final template = templates[templateKey]!;
                final isSelected = selectedTemplateKey == templateKey;

                return GestureDetector(
                  onTap: () => onTemplateChanged(templateKey),
                  child: Container(
                    width: 100,
                    height: 120,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? template['color'].withOpacity(0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? template['color'] : Colors.grey[200]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          template['icon'],
                          size: 24,
                          color: isSelected ? template['color'] : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            template['name'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? template['color'] : Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
