class JournalPassage {
  final String id;
  final String themeId;
  final String title;
  final String reference;
  final String type; // 'starter' | 'micro' | 'parable'
  final String triggerLevel;
  final List<String> reflectionPrompts;
  final String? defaultContent;

  const JournalPassage({
    required this.id,
    required this.themeId,
    required this.title,
    required this.reference,
    required this.type,
    required this.triggerLevel,
    required this.reflectionPrompts,
    this.defaultContent,
  });

  factory JournalPassage.fromJson(
    Map<String, dynamic> json, {
    String themeId = '',
  }) {
    return JournalPassage(
      id: json['id'] as String,
      themeId: (json['theme_id'] as String?) ?? themeId,
      title: json['title'] as String,
      reference: json['reference'] as String,
      type: (json['type'] as String?) ?? 'micro',
      triggerLevel: (json['trigger_level'] as String?) ?? '',
      reflectionPrompts: (json['reflection_prompts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      defaultContent: json['default_content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'theme_id': themeId,
      'title': title,
      'reference': reference,
      'type': type,
      'trigger_level': triggerLevel,
      'reflection_prompts': reflectionPrompts,
      if (defaultContent != null) 'default_content': defaultContent,
    };
  }
}

class JournalTheme {
  final String id;
  final String name;
  final String description;
  final String icon;
  final List<JournalPassage> passages;

  const JournalTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.passages,
  });

  factory JournalTheme.fromJson(Map<String, dynamic> json) {
    final themeId = json['id'] as String;
    final rawPassages = (json['passages'] as List<dynamic>?) ?? [];
    return JournalTheme(
      id: themeId,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      icon: (json['icon'] as String?) ?? 'spa',
      passages: rawPassages
          .map((p) => JournalPassage.fromJson(
                p as Map<String, dynamic>,
                themeId: themeId,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'passages': passages.map((p) => p.toJson()).toList(),
    };
  }
}
