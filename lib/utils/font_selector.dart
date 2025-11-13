import 'package:flutter/material.dart';

class FontInfo {
  final String family;
  final String displayName;
  final FontWeight? weight;
  final FontStyle? style;

  const FontInfo({
    required this.family,
    required this.displayName,
    this.weight,
    this.style,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontInfo &&
          runtimeType == other.runtimeType &&
          family == other.family &&
          weight == other.weight &&
          style == other.style;

  @override
  int get hashCode => family.hashCode ^ weight.hashCode ^ style.hashCode;
}

class FontSelector extends StatefulWidget {
  final FontInfo? selectedFont;
  final Function(FontInfo) onFontSelected;
  final String previewText;

  const FontSelector({
    super.key,
    this.selectedFont,
    required this.onFontSelected,
    this.previewText = 'The quick brown fox jumps',
  });

  @override
  State<FontSelector> createState() => _FontSelectorState();
}

class _FontSelectorState extends State<FontSelector> {
  FontInfo? _hoveredFont;
  static const List<FontInfo> availableFonts = [
    // Default system fonts
    FontInfo(family: 'Roboto', displayName: 'Roboto'),
    FontInfo(family: 'Roboto', displayName: 'Roboto Bold', weight: FontWeight.bold),
    FontInfo(family: 'Roboto', displayName: 'Roboto Italic', style: FontStyle.italic),
    FontInfo(family: 'Roboto', displayName: 'Roboto Bold Italic', weight: FontWeight.bold, style: FontStyle.italic),
    
    // Custom fonts
    FontInfo(family: 'Akony', displayName: 'Akony'),
    FontInfo(family: 'AllertaStencil', displayName: 'Allerta Stencil'),
    FontInfo(family: 'AlmendraDisplay', displayName: 'Almendra Display'),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans'),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans Bold', weight: FontWeight.bold),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans Black', weight: FontWeight.w900),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans Light', weight: FontWeight.w300),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans Medium', weight: FontWeight.w500),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans SemiBold', weight: FontWeight.w600),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans Thin', weight: FontWeight.w100),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans ExtraLight', weight: FontWeight.w200),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans ExtraBold', weight: FontWeight.w800),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans Italic', style: FontStyle.italic),
    FontInfo(family: 'AlumniSansPinstripe', displayName: 'Alumni Sans Pinstripe'),
    FontInfo(family: 'AlumniSansPinstripe', displayName: 'Alumni Sans Pinstripe Italic', style: FontStyle.italic),
    FontInfo(family: 'Barrio', displayName: 'Barrio'),
    FontInfo(family: 'Bellota', displayName: 'Bellota'),
    FontInfo(family: 'Bellota', displayName: 'Bellota Bold', weight: FontWeight.bold),
    FontInfo(family: 'Bellota', displayName: 'Bellota Light', weight: FontWeight.w300),
    FontInfo(family: 'Bellota', displayName: 'Bellota Italic', style: FontStyle.italic),
    FontInfo(family: 'BhuTukaExpandedOne', displayName: 'BhuTuka Expanded One'),
    FontInfo(family: 'Bokor', displayName: 'Bokor'),
    FontInfo(family: 'BungeeHairline', displayName: 'Bungee Hairline'),
    FontInfo(family: 'Caramel', displayName: 'Caramel'),
    FontInfo(family: 'Centralwell', displayName: 'Centralwell'),
    FontInfo(family: 'ChalkBoard', displayName: 'Chalk Board'),
    FontInfo(family: 'Explora', displayName: 'Explora'),
    FontInfo(family: 'GrandifloraOne', displayName: 'Grandiflora One'),
    FontInfo(family: 'KleeOne', displayName: 'Klee One SemiBold', weight: FontWeight.w600),
    FontInfo(family: 'Lacquer', displayName: 'Lacquer'),
    FontInfo(family: 'LibreBarcode39Text', displayName: 'Libre Barcode 39 Text'),
    FontInfo(family: 'LuckiestGuy', displayName: 'Luckiest Guy'),
    FontInfo(family: 'MajorMonoDisplay', displayName: 'Major Mono Display'),
    FontInfo(family: 'Metrophobic', displayName: 'Metrophobic'),
    FontInfo(family: 'Michroma', displayName: 'Michroma'),
    FontInfo(family: 'Milker', displayName: 'Milker'),
    FontInfo(family: 'Modernline', displayName: 'Modernline'),
    FontInfo(family: 'Modernline', displayName: 'Modernline Bold', weight: FontWeight.bold),
    FontInfo(family: 'NCLNeovibes', displayName: 'NCL Neovibes'),
    FontInfo(family: 'NewRocker', displayName: 'New Rocker'),
    FontInfo(family: 'NewTegomin', displayName: 'New Tegomin'),
    FontInfo(family: 'Poppins', displayName: 'Poppins'),
    FontInfo(family: 'Poppins', displayName: 'Poppins Bold', weight: FontWeight.bold),
    FontInfo(family: 'Poppins', displayName: 'Poppins Black', weight: FontWeight.w900),
    FontInfo(family: 'Poppins', displayName: 'Poppins Light', weight: FontWeight.w300),
    FontInfo(family: 'Poppins', displayName: 'Poppins Medium', weight: FontWeight.w500),
    FontInfo(family: 'Poppins', displayName: 'Poppins SemiBold', weight: FontWeight.w600),
    FontInfo(family: 'Poppins', displayName: 'Poppins Thin', weight: FontWeight.w100),
    FontInfo(family: 'Poppins', displayName: 'Poppins ExtraLight', weight: FontWeight.w200),
    FontInfo(family: 'Poppins', displayName: 'Poppins ExtraBold', weight: FontWeight.w800),
    FontInfo(family: 'Poppins', displayName: 'Poppins Italic', style: FontStyle.italic),
    FontInfo(family: 'ProtestRevolution', displayName: 'Protest Revolution'),
    FontInfo(family: 'Religath', displayName: 'Religath'),
    FontInfo(family: 'SourGummy', displayName: 'Sour Gummy'),
  ];

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: maxHeight,
            minHeight: 240,
          ),
          child: Container
          (
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.font_download, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Select Font',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Live Preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          widget.previewText,
                          style: TextStyle(
                            fontFamily: (_hoveredFont ?? widget.selectedFont)?.family,
                            fontWeight: (_hoveredFont ?? widget.selectedFont)?.weight ?? FontWeight.normal,
                            fontStyle: (_hoveredFont ?? widget.selectedFont)?.style ?? FontStyle.normal,
                            fontSize: 24,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          (_hoveredFont ?? widget.selectedFont)?.displayName ?? 'No font selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Font List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: availableFonts.length,
                    itemBuilder: (context, index) {
                      final font = availableFonts[index];
                      final isSelected = widget.selectedFont == font;
                      final isHovered = _hoveredFont == font;
                      
                      return MouseRegion(
                        onEnter: (_) {
                          setState(() {
                            _hoveredFont = font;
                          });
                        },
                        onExit: (_) {
                          setState(() {
                            _hoveredFont = null;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.blue.withOpacity(0.1),
                            hoverColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: isHovered 
                                  ? BorderSide(color: Colors.blue[300]!, width: 2)
                                  : BorderSide.none,
                            ),
                            title: Text(
                              font.displayName,
                              style: TextStyle(
                                fontFamily: font.family,
                                fontWeight: font.weight ?? FontWeight.normal,
                                fontStyle: font.style ?? FontStyle.normal,
                                color: isSelected ? Colors.blue : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check, color: Colors.blue)
                                : null,
                            onTap: () {
                              widget.onFontSelected(font);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Public helper to access fonts list outside this file
List<FontInfo> getAllFonts() => _FontSelectorState.availableFonts;

class FontSelectorButton extends StatelessWidget {
  final FontInfo? selectedFont;
  final Function(FontInfo) onFontSelected;
  final String previewText;

  const FontSelectorButton({
    super.key,
    this.selectedFont,
    required this.onFontSelected,
    this.previewText = 'The quick brown fox jumps',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: FontSelector(
              selectedFont: selectedFont,
              onFontSelected: onFontSelected,
              previewText: previewText,
            ),
          ),
        );
      },
      icon: const Icon(Icons.font_download),
      label: Text(
        selectedFont?.displayName ?? 'Select Font',
        style: TextStyle(
          fontFamily: selectedFont?.family,
          fontWeight: selectedFont?.weight ?? FontWeight.normal,
          fontStyle: selectedFont?.style ?? FontStyle.normal,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[50],
        foregroundColor: Colors.blue[700],
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.blue[200]!),
        ),
      ),
    );
  }
}
