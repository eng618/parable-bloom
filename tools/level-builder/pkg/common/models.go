package common

// MinGridCoverage is the minimum grid coverage required for generated levels.
// This threshold balances between maximizing grid utilization and maintaining
// solvability. Lower values are more lenient and allow more generation attempts
// to succeed, while higher values create denser puzzles but may reduce success rates.
const MinGridCoverage = 0.90

// MinCoverageForDifficulty returns the minimum target grid coverage for each difficulty tier.
// These values are used by regulators during generation and in the final structural validation.
func MinCoverageForDifficulty(difficulty string) float64 {
	switch difficulty {
	case "Tutorial":
		return 0.70
	case "Seedling":
		return 0.85
	case "Sprout":
		return 0.80
	case "Nurturing":
		return 0.75
	case "Flourishing":
		return 0.70
	case "Transcendent":
		return 0.60
	default:
		return 0.75
	}
}

// HeadDirections defines valid head directions and their deltas.
var HeadDirections = map[string][2]int{
	"right": {1, 0},
	"left":  {-1, 0},
	"up":    {0, 1},
	"down":  {0, -1},
}

// This file previously contained both domain types and generation config.
// Domain types have been moved to pkg/model/*.go for better organization.
// Generation config has been moved to pkg/generator/config.go to colocate
// with generation logic, except for shared constants like MinGridCoverage and HeadDirections.
//
// This file is kept for shared constants and potential future utilities.
