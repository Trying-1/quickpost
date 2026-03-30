import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../../models/quote_item.dart';
import '../../services/my_quotes_service.dart';

class MyQuotesScreen extends StatefulWidget {
  final bool selectMode;
  final bool multiSelectMode;

  const MyQuotesScreen({Key? key, this.selectMode = false, this.multiSelectMode = false}) : super(key: key);

  @override
  State<MyQuotesScreen> createState() => _MyQuotesScreenState();
}

class _MyQuotesScreenState extends State<MyQuotesScreen> {
  bool _isLoading = true;
  List<QuoteItem> _quotes = [];
  List<String> _categories = [];
  String _selectedCategory = 'All';
  Set<String> _selectedIds = {};

  static const List<String> _predefinedCategories = [
    'Stoic', 'Workout', 'Anime', 'Sad', 'Love', 'Motivation', 'Success', 'Funny', 'Life'
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await MyQuotesService.init();
    _loadQuotes();
  }

  void _loadQuotes() {
    final all = MyQuotesService.getAllQuotes();
    setState(() {
      final customCategories = MyQuotesService.getAllCategories();
      final allCats = <String>{..._predefinedCategories, ...customCategories};
      final sortedCats = allCats.toList()..sort();
      
      _categories = ['All', ...sortedCats];
      
      if (_selectedCategory == 'All') {
        _quotes = all;
      } else {
        _quotes = all.where((q) => q.category == _selectedCategory).toList();
      }
      _isLoading = false;
    });
  }

  void _showAddQuoteDialog() {
    final textController = TextEditingController();
    final authorController = TextEditingController();
    String dialogCategory = '';
    final customCategoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allDialogCats = <String>{..._predefinedCategories, ...MyQuotesService.getAllCategories()};

            return AlertDialog(
              title: const Text('Add Quote'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: textController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Quote Text', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: authorController,
                      decoration: const InputDecoration(labelText: 'Author (optional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tag / Category:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allDialogCats.map((cat) {
                        return ChoiceChip(
                          label: Text(cat),
                          selected: dialogCategory == cat,
                          onSelected: (selected) {
                            setDialogState(() {
                              dialogCategory = selected ? cat : '';
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customCategoryController,
                      decoration: const InputDecoration(labelText: 'Or type custom category', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final text = textController.text.trim();
                    if (text.isEmpty) return;

                    final finalCategory = customCategoryController.text.trim().isNotEmpty 
                        ? customCategoryController.text.trim()
                        : dialogCategory;

                    final newItem = QuoteItem(
                      id: const Uuid().v4(),
                      text: text,
                      author: authorController.text.trim(),
                      category: finalCategory,
                      createdAt: DateTime.now(),
                    );

                    await MyQuotesService.saveQuote(newItem);
                    if (mounted) {
                      Navigator.pop(context);
                      _loadQuotes();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _deleteQuote(String id) async {
    await MyQuotesService.deleteQuote(id);
    _loadQuotes();
  }

  void _showChangeTagDialog(QuoteItem quote) {
    String dialogCategory = quote.category;
    final customCategoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allDialogCats = <String>{..._predefinedCategories, ...MyQuotesService.getAllCategories()};

            return AlertDialog(
              title: const Text('Change Tag'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select a new tag for this quote:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allDialogCats.map((cat) {
                        return ChoiceChip(
                          label: Text(cat),
                          selected: dialogCategory == cat,
                          onSelected: (selected) {
                            setDialogState(() {
                              dialogCategory = selected ? cat : '';
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customCategoryController,
                      decoration: const InputDecoration(labelText: 'Or type custom category', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final finalCategory = customCategoryController.text.trim().isNotEmpty 
                        ? customCategoryController.text.trim()
                        : dialogCategory;

                    final updatedItem = QuoteItem(
                      id: quote.id,
                      text: quote.text,
                      author: quote.author,
                      category: finalCategory,
                      createdAt: quote.createdAt,
                    );

                    await MyQuotesService.saveQuote(updatedItem);
                    if (mounted) {
                      Navigator.pop(context);
                      _loadQuotes();
                    }
                  },
                  child: const Text('Update Tag'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.create),
            title: const Text('Add Single Quote'),
            onTap: () {
              Navigator.pop(context);
              _showAddQuoteDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.paste),
            title: const Text('Paste Multiple Quotes'),
            onTap: () {
              Navigator.pop(context);
              _pasteBulkText();
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import CSV file'),
            onTap: () {
              Navigator.pop(context);
              _importCsv();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _pasteBulkText() {
    final textController = TextEditingController();
    String dialogCategory = '';
    final customCategoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final allDialogCats = <String>{..._predefinedCategories, ...MyQuotesService.getAllCategories()};

          return AlertDialog(
            title: const Text('Paste Multiple Quotes'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'Format: Quote | Author (one per line)\nOr just Quote per line.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tag / Category for all:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allDialogCats.map((cat) {
                      return ChoiceChip(
                        label: Text(cat),
                        selected: dialogCategory == cat,
                        onSelected: (selected) {
                          setDialogState(() {
                            dialogCategory = selected ? cat : '';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customCategoryController,
                    decoration: const InputDecoration(labelText: 'Or type custom category', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final lines = textController.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
                  final finalCategory = customCategoryController.text.trim().isNotEmpty 
                        ? customCategoryController.text.trim()
                        : dialogCategory;
                        
                  if (lines.isNotEmpty) {
                    for (var line in lines) {
                      String qText = line.trim();
                      String qAuthor = '';
                      if (line.contains('|')) {
                        final parts = line.split('|');
                        qText = parts[0].trim();
                        if (parts.length > 1) {
                          qAuthor = parts[1].trim();
                        }
                      }
                      final newItem = QuoteItem(
                        id: const Uuid().v4(),
                        text: qText,
                        author: qAuthor,
                        category: finalCategory,
                        createdAt: DateTime.now(),
                      );
                      await MyQuotesService.saveQuote(newItem);
                    }
                    if (mounted) {
                      _loadQuotes();
                    }
                  }
                  Navigator.pop(context);
                },
                child: const Text('Import'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _importCsv() async {
    String dialogCategory = '';
    final customCategoryController = TextEditingController();

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final allDialogCats = <String>{..._predefinedCategories, ...MyQuotesService.getAllCategories()};

          return AlertDialog(
            title: const Text('Import CSV'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CSV should have Quote in 1st column, Author (optional) in 2nd.'),
                  const SizedBox(height: 16),
                  const Text('Tag / Category for all:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allDialogCats.map((cat) {
                      return ChoiceChip(
                        label: Text(cat),
                        selected: dialogCategory == cat,
                        onSelected: (selected) {
                          setDialogState(() {
                            dialogCategory = selected ? cat : '';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customCategoryController,
                    decoration: const InputDecoration(labelText: 'Or type custom category', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Select File')),
            ],
          );
        }
      ),
    );

    if (proceed != true) return;

    final finalCategory = customCategoryController.text.trim().isNotEmpty 
                        ? customCategoryController.text.trim()
                        : dialogCategory;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final input = await file.readAsString();
        List<List<dynamic>> rows = const CsvToListConverter().convert(input, fieldDelimiter: ',');

        for (var row in rows) {
          if (row.isNotEmpty) {
            final String qText = row[0].toString().trim();
            final String qAuthor = row.length > 1 ? row[1].toString().trim() : '';
            if (qText.isNotEmpty) {
              final newItem = QuoteItem(
                id: const Uuid().v4(),
                text: qText,
                author: qAuthor,
                category: finalCategory,
                createdAt: DateTime.now(),
              );
              await MyQuotesService.saveQuote(newItem);
            }
          }
        }

        if (mounted) {
          _loadQuotes();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imported quotes successfully')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error importing file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isSelecting = widget.selectMode || widget.multiSelectMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Quotes'),
        actions: isSelecting ? [
          if (widget.multiSelectMode && _selectedIds.isNotEmpty)
            TextButton(
              onPressed: () {
                final selectedQuotes = _quotes.where((q) => _selectedIds.contains(q.id)).toList();
                Navigator.pop(context, selectedQuotes);
              },
              child: Text('Import (${_selectedIds.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ] : [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                      )
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedCategory = cat;
                          _loadQuotes();
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _quotes.isEmpty
                ? const Center(child: Text('No quotes found. Add some!'))
                : ListView.builder(
                    itemCount: _quotes.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final q = _quotes[index];
                      final isSelected = _selectedIds.contains(q.id);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          onTap: widget.multiSelectMode
                            ? () => _toggleSelection(q.id)
                            : (widget.selectMode
                                ? () => Navigator.pop(context, q)
                                : null),
                          leading: widget.multiSelectMode ? Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(q.id),
                          ) : null,
                          title: Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [
                              if (q.author.isNotEmpty) '- ${q.author}',
                              if (q.category.isNotEmpty) '[${q.category}]'
                            ].join('   '),
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          trailing: isSelecting ? null : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.label_outline, color: Colors.blue),
                                onPressed: () => _showChangeTagDialog(q),
                                tooltip: 'Change Tag',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteQuote(q.id),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: isSelecting ? null : FloatingActionButton(
        onPressed: _showAddOptions,
        child: const Icon(Icons.add),
      ),
    );
  }
}
