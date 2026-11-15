package common

// Canonical 21-per-module progression: single source of truth for difficulty locks.
//
// Each module holds 21 levels: 5 Seedling, 5 Sprout, 5 Nurturing,
// 5 Flourishing, then 1 Transcendent challenge. For module N,
// level IDs are (N-1)*21+1 .. (N-1)*21+21 (modules 1-24 = levels 1-504).
//
// This must stay in sync with:
//   - pkg/batch GenerateModule levelsToGen
//   - pkg/generator legacy generateModule difficultyProgression
//   - apps/parable-bloom/assets/data/modules.json
//   - validator difficulty-lock check
const LevelsPerModule = 21

// Ordered non-challenge tiers.
var orderedTiers = []string{"Seedling", "Sprout", "Nurturing", "Flourishing"}

// DifficultyForModuleLevel returns the expected difficulty for the
// indexInModule (0-20) within a module.
func DifficultyForModuleLevel(indexInModule int) string {
	if indexInModule < 0 {
		return "Seedling"
	}
	if indexInModule < 20 {
		return orderedTiers[indexInModule/5]
	}
	return "Transcendent"
}

// ExpectedDifficulty returns the expected difficulty for a global levelID
// under the 5x21 scheme: ((levelID-1) % 21) maps onto the tier pattern.
func ExpectedDifficulty(levelID int) string {
	if levelID <= 0 {
		return "Seedling"
	}
	return DifficultyForModuleLevel((levelID - 1) % LevelsPerModule)
}

// ModuleForLevel returns the 1-based module number for a levelID.
func ModuleForLevel(levelID int) int {
	if levelID <= 0 {
		return 1
	}
	return (levelID-1)/LevelsPerModule + 1
}

// IndexInModule returns the 0-based index within its module.
func IndexInModule(levelID int) int {
	if levelID <= 0 {
		return 0
	}
	return (levelID - 1) % LevelsPerModule
}

// IsChallengeLevel reports whether the level is the Transcendent boss (index 20).
func IsChallengeLevel(levelID int) bool {
	return IndexInModule(levelID) == LevelsPerModule-1
}

// tierGrids is the raised board schedule. Five sizes per tier, one boss size.
// The same schedule repeats in every module. Widths stay near boards the
// camera already fits; the boss grows one step past today's 20×34.
var tierGrids = map[string][][2]int{
	"Seedling":     {{9, 12}, {9, 14}, {10, 14}, {10, 16}, {12, 16}},
	"Sprout":       {{12, 16}, {12, 18}, {14, 18}, {14, 20}, {14, 22}},
	"Nurturing":    {{14, 20}, {14, 22}, {16, 22}, {16, 24}, {16, 26}},
	"Flourishing":  {{16, 24}, {16, 26}, {18, 26}, {18, 28}, {18, 30}},
	"Transcendent": {{22, 36}},
}

// SlotInTier returns the 0-based index within the five levels of a tier.
// The Transcendent boss is slot 0 of its own one-size schedule.
func SlotInTier(levelID int) int {
	idx := IndexInModule(levelID)
	if idx < 0 {
		return 0
	}
	if idx >= 20 {
		return 0
	}
	return idx % 5
}

// ExpectedGrid returns the scheduled width and height for a level ID.
func ExpectedGrid(levelID int) (int, int) {
	difficulty := ExpectedDifficulty(levelID)
	sizes := tierGrids[difficulty]
	if len(sizes) == 0 {
		return 9, 12
	}
	slot := SlotInTier(levelID)
	if slot >= len(sizes) {
		slot = len(sizes) - 1
	}
	return sizes[slot][0], sizes[slot][1]
}
