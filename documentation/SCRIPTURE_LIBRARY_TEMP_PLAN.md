# Temporary Plan: Randomized Scripture Library & KJV Fallback

This document details the adjusted implementation plan for integrating scripture translations into **Parable Bloom** based on randomized translation delivery and local KJV fallbacks.

---

## 1. Adjusted Core Concept

Instead of allowing the user to select their preferred translation in a settings menu:

1. **Randomized Unlock:** When a player completes a module and unlocks a parable, the game **randomly selects** a translation from our active translations pool (KJV, WEB, NET, ESV, CSB).
2. **API Fetch with KJV Fallback:**
    * If the selected version is online-only (e.g., ESV or CSB), the app attempts to fetch the text from the API.
    * If the fetch fails (due to network issues) or if the device is offline, the app **automatically falls back to the KJV version** stored in our local database.
3. **Journal Persistence:** The specific translation that was successfully loaded and displayed is saved to the user's local journal entry. When viewing the journal later, they will see that exact translation.
4. **No User Configuration:** There is no translation preference dropdown in Settings. The translation is determined dynamically at the time of unlock/viewing.

---

## 2. Directory & Database Setup (Completed)

* **Registry:** [`scripture_metadata.json`](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/assets/data/scripture_metadata.json) maps all translations and defines which ones are active vs. pending commercial license.
* **Local KJV Database:** [`scripture_library.json`](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/assets/data/scripture_library.json) contains the offline KJV texts for the five current parables:
    1. `Matthew 13:1-23`
    2. `Matthew 13:31-32`
    3. `Mark 4:26-29`
    4. `John 15:1-8`
    5. `Matthew 9:37-38`

---

## 3. Implementation Steps

### Step 1: Create a Scripture Service (`scripture_service.dart`)

We will create a service class in `lib/services/scripture_service.dart` that:

* Loads the local `scripture_library.json` database.
* Provides a method to randomly pick an active translation ID from `scripture_metadata.json` (filtering out pending ones).
* Provides a method `fetchScriptureText(String reference, String translationId)` that loads the KJV text locally or makes an online API call.
* Handles network connectivity checks and falls back to KJV on error.

### Step 2: Update the Journal / Parable Unlock Flow in UI

* In [`game_screen.dart`](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/game/presentation/screens/game_screen.dart):
  * When a module is unlocked, the game calls the `ScriptureService` to select a translation and load the text.
  * The loaded text and the selected translation ID are displayed in the dialog.
  * The selected translation ID is saved into the user's progress/journal database so it remains locked to that version.

* In [`journal_screen.dart`](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/journal/presentation/screens/journal_screen.dart):
  * Load the scripture text using the saved translation ID.
  * Fall back to KJV if there is a retrieval issue.

### Step 3: Implement Build-Time Validation Guards

* Set up tests to guarantee that any scripture referenced in `modules.json` has a corresponding offline KJV backup in `scripture_library.json`.
