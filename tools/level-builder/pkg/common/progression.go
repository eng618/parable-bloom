package common

// Canonical 5x21 progression: single source of truth for difficulty locks.
//
// Each module holds 21 levels: 5 Seedling, 5 Sprout, 5 Nurturing,
// 5 Flourishing, then 1 Transcendent challenge. For module N,
// level IDs are (N-1)*21+1 .. (N-1)*21+21.
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
