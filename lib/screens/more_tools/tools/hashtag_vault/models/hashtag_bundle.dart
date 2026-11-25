/// Domain model representing a curated bundle of hashtags.
class HashtagBundle {
  final String title;
  final String category;
  final String tags;
  final String reachScore;

  const HashtagBundle({
    required this.title,
    required this.category,
    required this.tags,
    required this.reachScore,
  });

  static const List<HashtagBundle> defaultBundles = [
    HashtagBundle(
      title: 'Anime Reels & Viral Edits',
      category: 'Anime',
      tags: '#anime #animeedits #animerecs #otaku #manga #animecommunity #animelover #quickpost',
      reachScore: 'High Reach',
    ),
    HashtagBundle(
      title: 'Quotes & Growth Mindset',
      category: 'Motivation',
      tags: '#motivation #mindset #growth #quotes #dailymotivation #successmindset #wisdom #mindsetshift',
      reachScore: 'High Engagement',
    ),
    HashtagBundle(
      title: 'Shorts & Reels Creators',
      category: 'Reels',
      tags: '#contentcreator #reels #viralreels #creator #editing #reelsvideo #videotools #trending',
      reachScore: 'Viral Trend',
    ),
    HashtagBundle(
      title: 'Carousel Guides & Infographics',
      category: 'Carousels',
      tags: '#carousel #carouselpost #infographic #learn #educational #creatorhacks #businessgrowth #tips',
      reachScore: 'High Saves',
    ),
  ];
}

