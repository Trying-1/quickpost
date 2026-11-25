/// Prompt templates users can paste into ChatGPT / Gemini / Claude to
/// generate anime database JSON that the app can import directly.
class AnimeDbLlmPrompt {
  AnimeDbLlmPrompt._();

  /// Builds a catalog/list prompt (e.g. Top 30, 2024 hits, Shounen, etc.).
  static String build({String request = 'the 50 most popular anime of all time'}) {
    final cleanReq = request.trim().isEmpty ? 'the 50 most popular anime of all time' : request.trim();
    return '''
Generate an anime database as JSON for $cleanReq.

CRITICAL FORMATTING INSTRUCTIONS:
1. Output the JSON STRICTLY inside a markdown ```json ``` codeblock so I can copy it with 1 click using the "Copy code" button.
2. Do not write any explanations, greetings, or notes outside the ```json codeblock.
3. Return a single JSON array containing the anime entries.

Structure to follow:
```json
[
  {
    "name": "English Title",
    "japaneseName": "Romaji / Kanji Title",
    "rating": "8.5 / 10",
    "seasons": "2 Seasons",
    "episodes": "24 Episodes",
    "studio": "Studio Name",
    "genres": "Action, Adventure, Fantasy",
    "characters": "Main Character 1, Character 2, Character 3",
    "synopsis": "One or two sentence hook, no spoilers.",
    "year": 2024
  }
]
```

Rules:
- Use the common English title for "name".
- Under "characters", include 3-5 main or popular characters separated by commas.
- Keep "synopsis" under 160 characters.
- Use real, accurate data. If unsure about a field, leave it as an empty string.
- Do not repeat anime.
'''.trim();
  }

  /// Builds a prompt specifically tailored to fetch/generate rich details for a SINGLE anime.
  static String buildSingle(String animeName) {
    final clean = animeName.trim().isEmpty ? 'the anime series' : animeName.trim();
    return '''
Generate accurate, comprehensive anime details as JSON for "$clean".

CRITICAL FORMATTING INSTRUCTIONS:
1. Output the JSON STRICTLY inside a markdown ```json ``` codeblock so I can copy it with 1 click using the "Copy code" button.
2. Do not write any explanations, greetings, or notes outside the ```json codeblock.
3. Return a single JSON array with this 1 anime entry.

Structure to follow:
```json
[
  {
    "name": "Common English Title",
    "japaneseName": "Romaji / Japanese Title",
    "rating": "8.8 / 10",
    "seasons": "2 Seasons",
    "episodes": "24 Episodes",
    "studio": "Animation Studio",
    "genres": "Action, Dark Fantasy, Supernatural",
    "characters": "Main Character 1, Main Character 2, Popular Character 3, Popular Character 4",
    "synopsis": "Compelling 1-2 sentence hook without spoilers.",
    "year": 2023
  }
]
```

Rules:
- Fill in real, accurate metadata for "$clean".
- Under "characters", list 4 to 6 main and popular character names separated by commas.
- Keep "synopsis" under 180 characters.
'''.trim();
  }
}
