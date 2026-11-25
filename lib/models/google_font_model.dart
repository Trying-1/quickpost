class GoogleFontItem {
  final String family;
  final String category;
  final String downloadUrl;
  final String? assetPath;
  final List<String> tags;

  const GoogleFontItem({
    required this.family,
    required this.category,
    required this.downloadUrl,
    this.assetPath,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() => {
    'family': family,
    'category': category,
    'downloadUrl': downloadUrl,
    if (assetPath != null) 'assetPath': assetPath,
    'tags': tags,
  };

  factory GoogleFontItem.fromMap(Map<String, dynamic> map) => GoogleFontItem(
    family: map['family'] as String? ?? '',
    category: map['category'] as String? ?? 'Display',
    downloadUrl: map['downloadUrl'] as String? ?? '',
    assetPath: map['assetPath'] as String?,
    tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
  );

  String get sanitizedFileName => '${family.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.ttf';
}

/// Comprehensive curated catalog of 100+ top Google Fonts
/// optimized for kinetic typography, subtitles, social reels, shorts,
/// motion graphics, and graphic design.
const List<GoogleFontItem> kGoogleFontsCatalog = [
  // =========================================================================
  // 1. IMPACT & DISPLAY (Reels, Shorts, Viral Headers, Punchy Titles)
  // =========================================================================
  GoogleFontItem(
    family: 'Anton',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/anton/Anton-Regular.ttf',
    tags: ['bold', 'heavy', 'impact', 'reels', 'shorts', 'youtube'],
  ),
  GoogleFontItem(
    family: 'Bebas Neue',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/BebasNeue-Regular.ttf',
    tags: ['condensed', 'tall', 'poster', 'clean', 'caps'],
  ),
  GoogleFontItem(
    family: 'Oswald',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/oswald/Oswald%5Bwght%5D.ttf',
    tags: ['condensed', 'modern', 'headline', 'bold'],
  ),
  GoogleFontItem(
    family: 'Titan One',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/titanone/TitanOne-Regular.ttf',
    tags: ['chunky', 'cartoon', 'fat', 'punchy'],
  ),
  GoogleFontItem(
    family: 'Lilita One',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/lilitaone/LilitaOne-Regular.ttf',
    tags: ['bold', 'rounded', 'friendly', 'thumbnail'],
  ),
  GoogleFontItem(
    family: 'Ultra',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/apache/ultra/Ultra-Regular.ttf',
    tags: ['ultra bold', 'wood type', 'heavy'],
  ),
  GoogleFontItem(
    family: 'Bangers',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/bangers/Bangers-Regular.ttf',
    tags: ['comic', 'cartoon', 'fun', 'loud'],
  ),
  GoogleFontItem(
    family: 'Righteous',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/righteous/Righteous-Regular.ttf',
    tags: ['retro', 'modern', 'futuristic', 'groovy'],
  ),
  GoogleFontItem(
    family: 'Permanent Marker',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/permanentmarker/PermanentMarker-Regular.ttf',
    tags: ['marker', 'grunge', 'street', 'bold'],
  ),
  GoogleFontItem(
    family: 'Russo One',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/russoone/RussoOne-Regular.ttf',
    tags: ['block', 'gaming', 'tech', 'heavy'],
  ),
  GoogleFontItem(
    family: 'Alfa Slab One',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/alfaslabone/AlfaSlabOne-Regular.ttf',
    tags: ['slab', 'ultra-bold', 'fat', 'western'],
  ),
  GoogleFontItem(
    family: 'Rowdies',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/rowdies/Rowdies-Bold.ttf',
    tags: ['playful', 'chunky', 'bold', 'movie'],
  ),
  GoogleFontItem(
    family: 'Black Han Sans',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/blackhansans/BlackHanSans-Regular.ttf',
    tags: ['massive', 'block', 'sans', 'solid'],
  ),
  GoogleFontItem(
    family: 'Shrikhand',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/shrikhand/Shrikhand-Regular.ttf',
    tags: ['curvy', 'groovy', 'bold', '70s'],
  ),
  GoogleFontItem(
    family: 'Teko',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/teko/Teko%5Bwght%5D.ttf',
    tags: ['narrow', 'headline', 'caps', 'tall'],
  ),
  GoogleFontItem(
    family: 'Archivo Black',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/archivoblack/ArchivoBlack-Regular.ttf',
    tags: ['heavy', 'headline', 'grotesque'],
  ),
  GoogleFontItem(
    family: 'Syne',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/syne/Syne%5Bwght%5D.ttf',
    tags: ['trendy', 'fashion', 'kinetic', 'modern', 'brutalist'],
  ),
  GoogleFontItem(
    family: 'Passion One',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/passionone/PassionOne-Bold.ttf',
    tags: ['bold', 'tight', 'display'],
  ),
  GoogleFontItem(
    family: 'Paytone One',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/paytoneone/PaytoneOne-Regular.ttf',
    tags: ['casual', 'impact', 'sans'],
  ),
  GoogleFontItem(
    family: 'Fugaz One',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/fugazone/FugazOne-Regular.ttf',
    tags: ['italic', 'speed', 'energy', 'dynamic'],
  ),
  GoogleFontItem(
    family: 'Chango',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/chango/Chango-Regular.ttf',
    tags: ['chunky', 'caribbean', 'tribal', 'fat'],
  ),
  GoogleFontItem(
    family: 'Black Ops One',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/blackopsone/BlackOpsOne-Regular.ttf',
    tags: ['military', 'stencil', 'army', 'fps'],
  ),
  GoogleFontItem(
    family: 'Nosifer',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/nosifer/Nosifer-Regular.ttf',
    tags: ['dripping', 'blood', 'horror', 'spooky'],
  ),
  GoogleFontItem(
    family: 'Creepster',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/creepster/Creepster-Regular.ttf',
    tags: ['halloween', 'monster', 'horror', 'cartoon'],
  ),
  GoogleFontItem(
    family: 'Londrina Solid',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/londrinasolid/LondrinaSolid-Regular.ttf',
    tags: ['urban', 'poster', 'chunky'],
  ),
  GoogleFontItem(
    family: 'Spicy Rice',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/spicyrice/SpicyRice-Regular.ttf',
    tags: ['festive', 'fun', 'retro', 'curly'],
  ),
  GoogleFontItem(
    family: 'Modak',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/modak/Modak-Regular.ttf',
    tags: ['heavy', 'chubby', 'blob', 'cute'],
  ),
  GoogleFontItem(
    family: 'Bungee Shade',
    category: 'Display',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/bungeeshade/BungeeShade-Regular.ttf',
    tags: ['3d', 'shadow', 'retro', 'signage'],
  ),

  // =========================================================================
  // 2. MODERN SANS (Clean, Minimalist, Tech, Subtitles & Motion UI)
  // =========================================================================
  GoogleFontItem(
    family: 'Montserrat',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/Montserrat%5Bwght%5D.ttf',
    tags: ['geometric', 'clean', 'subtitles', 'popular', 'header'],
  ),
  GoogleFontItem(
    family: 'Inter',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf',
    tags: ['ui', 'crisp', 'modern', 'legible'],
  ),
  GoogleFontItem(
    family: 'Roboto',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/roboto/Roboto%5Bwdth%2Cwght%5D.ttf',
    tags: ['standard', 'crisp', 'universal'],
  ),
  GoogleFontItem(
    family: 'Raleway',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/raleway/Raleway%5Bwght%5D.ttf',
    tags: ['elegant', 'thin', 'modern', 'fashion'],
  ),
  GoogleFontItem(
    family: 'Kanit',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/kanit/Kanit-Bold.ttf',
    tags: ['bold', 'sleek', 'motion', 'youtube'],
  ),
  GoogleFontItem(
    family: 'Rubik',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/rubik/Rubik%5Bwght%5D.ttf',
    tags: ['rounded', 'friendly', 'modern'],
  ),
  GoogleFontItem(
    family: 'League Spartan',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/leaguespartan/LeagueSpartan%5Bwght%5D.ttf',
    tags: ['geometric', 'punchy', 'clean'],
  ),
  GoogleFontItem(
    family: 'Plus Jakarta Sans',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf',
    tags: ['premium', 'tech', 'startup', 'sleek'],
  ),
  GoogleFontItem(
    family: 'Outfit',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/outfit/Outfit%5Bwght%5D.ttf',
    tags: ['geometric', 'modern', 'branding'],
  ),
  GoogleFontItem(
    family: 'Work Sans',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/worksans/WorkSans%5Bwght%5D.ttf',
    tags: ['neutral', 'subtitles', 'editorial'],
  ),
  GoogleFontItem(
    family: 'DM Sans',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/dmsans/DMSans%5Bopsz%2Cwght%5D.ttf',
    tags: ['clean', 'neutral', 'minimal'],
  ),
  GoogleFontItem(
    family: 'Space Grotesk',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf',
    tags: ['quirky', 'tech', 'brutalist', 'future'],
  ),
  GoogleFontItem(
    family: 'Urbanist',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/urbanist/Urbanist%5Bwght%5D.ttf',
    tags: ['geometric', 'digital', 'clean'],
  ),
  GoogleFontItem(
    family: 'Sora',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/sora/Sora%5Bwght%5D.ttf',
    tags: ['crypto', 'web3', 'modern'],
  ),
  GoogleFontItem(
    family: 'Manrope',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/Manrope%5Bwght%5D.ttf',
    tags: ['semi-rounded', 'clean', 'subtitles'],
  ),
  GoogleFontItem(
    family: 'Fredoka',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/fredoka/Fredoka%5Bwdth%2Cwght%5D.ttf',
    tags: ['rounded', 'friendly', 'vlog', 'cute'],
  ),
  GoogleFontItem(
    family: 'Nunito',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf',
    tags: ['rounded', 'warm', 'approachable'],
  ),
  GoogleFontItem(
    family: 'Quicksand',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/quicksand/Quicksand%5Bwght%5D.ttf',
    tags: ['rounded', 'light', 'clean'],
  ),
  GoogleFontItem(
    family: 'Comfortaa',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/comfortaa/Comfortaa%5Bwght%5D.ttf',
    tags: ['round', 'geometric', 'aesthetic'],
  ),
  GoogleFontItem(
    family: 'Josefin Sans',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/josefinsans/JosefinSans%5Bwght%5D.ttf',
    tags: ['vintage', 'geometric', 'scandinavian'],
  ),
  GoogleFontItem(
    family: 'Exo 2',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/exo2/Exo2%5Bwght%5D.ttf',
    tags: ['futuristic', 'tech', 'sci-fi'],
  ),
  GoogleFontItem(
    family: 'Chivo',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/chivo/Chivo%5Bwght%5D.ttf',
    tags: ['grotesque', 'assertive', 'clear'],
  ),
  GoogleFontItem(
    family: 'Barlow',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/barlow/Barlow-Bold.ttf',
    tags: ['california', 'highway', 'condensed'],
  ),
  GoogleFontItem(
    family: 'Saira',
    category: 'Sans',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/saira/Saira%5Bwdth%2Cwght%5D.ttf',
    tags: ['condensed', 'bold', 'punchy'],
  ),

  // =========================================================================
  // 3. SCRIPT & HANDWRITING (Vlogs, Aesthetic, Personal, Quotes, Signatures)
  // =========================================================================
  GoogleFontItem(
    family: 'Pacifico',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/pacifico/Pacifico-Regular.ttf',
    tags: ['brush', 'surf', 'cute', 'retro'],
  ),
  GoogleFontItem(
    family: 'Lobster',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/lobster/Lobster-Regular.ttf',
    tags: ['bold', 'calligraphy', 'vintage'],
  ),
  GoogleFontItem(
    family: 'Caveat',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/caveat/Caveat%5Bwght%5D.ttf',
    tags: ['handwritten', 'casual', 'organic', 'notes'],
  ),
  GoogleFontItem(
    family: 'Dancing Script',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/dancingscript/DancingScript%5Bwght%5D.ttf',
    tags: ['bouncy', 'cursive', 'expressive'],
  ),
  GoogleFontItem(
    family: 'Satisfy',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/satisfy/Satisfy-Regular.ttf',
    tags: ['brush', 'smooth', 'elegant'],
  ),
  GoogleFontItem(
    family: 'Great Vibes',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/greatvibes/GreatVibes-Regular.ttf',
    tags: ['formal', 'wedding', 'luxury', 'cursive'],
  ),
  GoogleFontItem(
    family: 'Sacramento',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/sacramento/Sacramento-Regular.ttf',
    tags: ['monoline', 'chic', 'feminine'],
  ),
  GoogleFontItem(
    family: 'Allura',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/allura/Allura-Regular.ttf',
    tags: ['calligraphy', 'soft', 'flowing'],
  ),
  GoogleFontItem(
    family: 'Alex Brush',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/alexbrush/AlexBrush-Regular.ttf',
    tags: ['flowing', 'legible', 'script'],
  ),
  GoogleFontItem(
    family: 'Courgette',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/courgette/Courgette-Regular.ttf',
    tags: ['brush', 'medium-contrast', 'compact'],
  ),
  GoogleFontItem(
    family: 'Parisienne',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/parisienne/Parisienne-Regular.ttf',
    tags: ['french', 'chic', 'bouncy'],
  ),
  GoogleFontItem(
    family: 'Cookie',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/cookie/Cookie-Regular.ttf',
    tags: ['sweet', '50s', 'pinup'],
  ),
  GoogleFontItem(
    family: 'Yellowtail',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/yellowtail/Yellowtail-Regular.ttf',
    tags: ['flat brush', 'sign painting', 'warm'],
  ),
  GoogleFontItem(
    family: 'Kaushan Script',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/kaushanscript/KaushanScript-Regular.ttf',
    tags: ['fast', 'energetic', 'brush'],
  ),
  GoogleFontItem(
    family: 'Shadows Into Light',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/shadowsintolight/ShadowsIntoLight.ttf',
    tags: ['handwriting', 'neat', 'personal'],
  ),
  GoogleFontItem(
    family: 'Indie Flower',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/indieflower/IndieFlower-Regular.ttf',
    tags: ['carefree', 'handwritten', 'bubbly'],
  ),
  GoogleFontItem(
    family: 'Kalam',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/kalam/Kalam-Bold.ttf',
    tags: ['ballpoint', 'authentic', 'informal'],
  ),
  GoogleFontItem(
    family: 'Gochi Hand',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/gochihand/GochiHand-Regular.ttf',
    tags: ['teenage', 'doodle', 'friendly'],
  ),
  GoogleFontItem(
    family: 'Covered By Your Grace',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/coveredbyyourgrace/CoveredByYourGrace.ttf',
    tags: ['marker', 'tall', 'casual'],
  ),
  GoogleFontItem(
    family: 'Patrick Hand',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/patrickhand/PatrickHand-Regular.ttf',
    tags: ['felt pen', 'classroom', 'clean hand'],
  ),
  GoogleFontItem(
    family: 'Amatic SC',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/amaticsc/AmaticSC-Bold.ttf',
    tags: ['tall', 'skinny', 'caps', 'indie'],
  ),
  GoogleFontItem(
    family: 'Rock Salt',
    category: 'Script',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/apache/rocksalt/RockSalt-Regular.ttf',
    tags: ['felt-marker', 'edgy', 'punk', 'rock'],
  ),

  // =========================================================================
  // 4. GAMING, CYBERPUNK & RETRO (Sci-Fi, Arcade, 8-Bit, Neon, HUD)
  // =========================================================================
  GoogleFontItem(
    family: 'Orbitron',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/orbitron/Orbitron%5Bwght%5D.ttf',
    tags: ['cyberpunk', 'futuristic', 'hud', 'tech', 'gaming'],
  ),
  GoogleFontItem(
    family: 'Press Start 2P',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/PressStart2P-Regular.ttf',
    tags: ['pixel', '8-bit', 'arcade', 'retro', 'gameboy'],
  ),
  GoogleFontItem(
    family: 'Silkscreen',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Regular.ttf',
    tags: ['pixel', 'clean pixel', 'terminal', 'minecraft'],
  ),
  GoogleFontItem(
    family: 'VT323',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/vt323/VT323-Regular.ttf',
    tags: ['terminal', 'dos', 'matrix', 'crt'],
  ),
  GoogleFontItem(
    family: 'Monoton',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/monoton/Monoton-Regular.ttf',
    tags: ['disco', 'lines', 'neon', '80s', 'synthwave'],
  ),
  GoogleFontItem(
    family: 'Audiowide',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/audiowide/Audiowide-Regular.ttf',
    tags: ['techno', 'wide', 'synthwave', 'space'],
  ),
  GoogleFontItem(
    family: 'Bungee',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/bungee/Bungee-Regular.ttf',
    tags: ['urban', 'signage', 'block', 'vertical'],
  ),
  GoogleFontItem(
    family: 'Share Tech Mono',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/sharetechmono/ShareTechMono-Regular.ttf',
    tags: ['code', 'hacker', 'military', 'mono'],
  ),
  GoogleFontItem(
    family: 'Kode Mono',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/kodemono/KodeMono%5BROND%2Cwdth%2Cwght%5D.ttf',
    tags: ['code', 'developer', 'monospace', 'terminal', 'cyberpunk', 'modern'],
  ),
  GoogleFontItem(
    family: 'Chakra Petch',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/chakrapetch/ChakraPetch-Bold.ttf',
    tags: ['mecha', 'anime', 'esports', 'robot'],
  ),
  GoogleFontItem(
    family: 'Electrolize',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/electrolize/Electrolize-Regular.ttf',
    tags: ['circuit', 'electronic', 'square'],
  ),
  GoogleFontItem(
    family: 'Goldman',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/goldman/Goldman-Bold.ttf',
    tags: ['esports', 'streamer', 'heavy gaming'],
  ),
  GoogleFontItem(
    family: 'Oxanium',
    category: 'Gaming',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/oxanium/Oxanium%5Bwght%5D.ttf',
    tags: ['hexagonal', 'mech', 'clean sci-fi'],
  ),

  // =========================================================================
  // 5. CINEMATIC & EDITORIAL SERIF (Fashion, Vogue, Movie, Drama, Luxury)
  // =========================================================================
  GoogleFontItem(
    family: 'Playfair Display',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/playfairdisplay/PlayfairDisplay%5Bital%2Cwght%5D.ttf',
    tags: ['luxury', 'editorial', 'vogue', 'cinematic', 'magazine'],
  ),
  GoogleFontItem(
    family: 'Cinzel',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf',
    tags: ['roman', 'epic', 'movie', 'classic', 'trailer'],
  ),
  GoogleFontItem(
    family: 'Abril Fatface',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/abrilfatface/AbrilFatface-Regular.ttf',
    tags: ['dramatic', 'contrast', 'titling', 'heavy serif'],
  ),
  GoogleFontItem(
    family: 'DM Serif Display',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/dmserifdisplay/DMSerifDisplay-Regular.ttf',
    tags: ['high contrast', 'modern serif', 'poster'],
  ),
  GoogleFontItem(
    family: 'Cormorant Garamond',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/cormorantgaramond/CormorantGaramond-Bold.ttf',
    tags: ['graceful', 'book', 'refined', 'delicate'],
  ),
  GoogleFontItem(
    family: 'Prata',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/prata/Prata-Regular.ttf',
    tags: ['teardrop', 'didone', 'aesthetic', 'vogue'],
  ),
  GoogleFontItem(
    family: 'Bodoni Moda',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/bodonimoda/BodoniModa%5Bopsz%2Cwght%5D.ttf',
    tags: ['haute couture', 'extreme contrast', 'fashion'],
  ),
  GoogleFontItem(
    family: 'Italiana',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/italiana/Italiana-Regular.ttf',
    tags: ['italian', 'architecture', 'calligraphic serif'],
  ),
  GoogleFontItem(
    family: 'Yeseva One',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/yesevaone/YesevaOne-Regular.ttf',
    tags: ['graceful', 'curvy serif', 'feminine'],
  ),
  GoogleFontItem(
    family: 'Spectral',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/spectral/Spectral-Bold.ttf',
    tags: ['crisp', 'screen serif', 'modern classic'],
  ),
  GoogleFontItem(
    family: 'Marcellus',
    category: 'Serif',
    downloadUrl: 'https://raw.githubusercontent.com/google/fonts/main/ofl/marcellus/Marcellus-Regular.ttf',
    tags: ['trajan', 'roman flare', 'monumental'],
  ),
];
