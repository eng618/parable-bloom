package metrics

import (
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// CalculateCoverage computes the fraction of grid cells occupied by vines (0-1).
func CalculateCoverage(gridSize []int, vines []model.Vine) float64 {
	totalCells := gridSize[0] * gridSize[1]
	if totalCells == 0 {
		return 0
	}

	occupied := make(map[string]struct{}, len(vines)*8)
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			occupied[common.PointKey(p)] = struct{}{}
		}
	}

	return float64(len(occupied)) / float64(totalCells)
}

// CalculatePlayableCoverage computes (vine cells + masked cells) / total (0-1).
func CalculatePlayableCoverage(level model.Level) float64 {
	total := level.GetTotalCells()
	if total == 0 {
		return 0
	}
	occupied := make(map[string]struct{}, level.GetOccupiedCells())
	for _, v := range level.Vines {
		for _, p := range v.OrderedPath {
			occupied[common.PointKey(p)] = struct{}{}
		}
	}
	masked := 0
	if level.Mask != nil {
		for _, p := range level.Mask.Points {
			if _, ok := occupied[common.PointKey(p)]; !ok {
				masked++
			}
		}
	}
	return float64(len(occupied)+masked) / float64(total)
}
