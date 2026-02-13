package metrics

import (
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// EstimateComplexity calculates a rough complexity score based on vine count and length.
// This is a heuristic and not a precise measure of difficulty.
func EstimateComplexity(vines []model.Vine) float64 {
	if len(vines) == 0 {
		return 0
	}

	totalLen := 0
	for _, v := range vines {
		totalLen += len(v.OrderedPath)
	}

	avgLen := float64(totalLen) / float64(len(vines))

	// Example formula: count + avgLen/2
	return float64(len(vines)) + avgLen/2.0
}
