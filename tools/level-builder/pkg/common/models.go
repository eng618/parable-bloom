package common

// MinGridCoverage is the minimum grid coverage required for generated levels.
// This threshold balances between maximizing grid utilization and maintaining
// solvability. Lower values are more lenient and allow more generation attempts
// to succeed, while higher values create denser puzzles but may reduce success rates.
const MinGridCoverage = 0.90

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
