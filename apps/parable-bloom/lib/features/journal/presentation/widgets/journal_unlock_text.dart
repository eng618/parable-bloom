/// Shared unlock hint text, extracted from the legacy list UI so the
/// book layout and tests render identical copy.
String formatJournalTriggerText(String triggerLevel) {
  if (triggerLevel.isEmpty) return "Complete Milestone to Unlock";
  if (triggerLevel == "lesson_10" ||
      triggerLevel == "lesson_5" ||
      triggerLevel == "lesson_1") {
    return "Unlocks after Tutorial";
  }
  // Generic scheme: lvl_mNN_challenge or lvl_mNN_MM.
  final match =
      RegExp(r"^lvl_m(\d\d)_(challenge|\d\d)$").firstMatch(triggerLevel);
  if (match != null) {
    final module = int.tryParse(match.group(1)!) ?? 0;
    if (match.group(2) == "challenge") {
      return "Unlocks at Module $module Challenge";
    }
    final level = int.tryParse(match.group(2)!) ?? 0;
    final global = (module - 1) * 21 + level;
    return "Unlocks at Level $global (Module $module)";
  }

  return "Unlocks at Level $triggerLevel";
}
