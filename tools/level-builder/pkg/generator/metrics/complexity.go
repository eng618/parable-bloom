package metrics

import (
	"strconv"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// QualityReport captures output-quality signals for a generated level.
type QualityReport struct {
	ComplexityScore  float64
	AvgVineLength    float64
	MinVineLength    int
	MaxVineLength    int
	LengthVariety    int // max-min; low values indicate flat/monotonous output
	DistinctColors   int
	PlayableCoverage float64
	VineCount        int
	BlockingDepth    int // longest first-step blocking chain; 0 = all immediately clearable
}

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

// AnalyzeQuality builds a QualityReport for a fully assembled level.
func AnalyzeQuality(level model.Level) QualityReport {
	rep := QualityReport{VineCount: len(level.Vines)}
	if len(level.Vines) == 0 {
		return rep
	}
	total := 0
	minL := len(level.Vines[0].OrderedPath)
	maxL := minL
	colors := make(map[int]struct{}, 8)
	for _, v := range level.Vines {
		l := len(v.OrderedPath)
		total += l
		if l < minL {
			minL = l
		}
		if l > maxL {
			maxL = l
		}
		colors[v.ColorIndex] = struct{}{}
	}
	rep.AvgVineLength = float64(total) / float64(len(level.Vines))
	rep.MinVineLength = minL
	rep.MaxVineLength = maxL
	rep.LengthVariety = maxL - minL
	rep.DistinctColors = len(colors)
	rep.ComplexityScore = EstimateComplexity(level.Vines)
	rep.PlayableCoverage = CalculatePlayableCoverage(level)
	rep.BlockingDepth = ComputeBlockingDepth(level)
	return rep
}

// ComputeBlockingDepth returns the longest chain of first-step blocks
// (A blocks B = B's head target cell is occupied by A). 0 means every vine
// is immediately clearable in the initial position.
func ComputeBlockingDepth(level model.Level) int {
	if len(level.Vines) == 0 {
		return 0
	}
	occupied := make(map[string]string, level.GetOccupiedCells())
	for _, v := range level.Vines {
		for _, p := range v.OrderedPath {
			occupied[pointKey(p)] = v.ID
		}
	}
	graph := make(map[string][]string, len(level.Vines))
	for _, blocked := range level.Vines {
		if len(blocked.OrderedPath) == 0 {
			continue
		}
		nx, ny := headTarget(blocked)
		headKey := pointKey(blocked.OrderedPath[0])
		headVine, ok := occupied[headKey]
		if !ok {
			continue
		}
		if blocker, hit := occupied[pointKeyXY(nx, ny)]; hit && blocker != headVine {
			graph[blocker] = append(graph[blocker], blocked.ID)
		}
	}
	cache := make(map[string]int, len(level.Vines))
	maxDepth := 0
	for _, v := range level.Vines {
		if d := longestFrom(v.ID, graph, make(map[string]bool), cache); d > maxDepth {
			maxDepth = d
		}
	}
	return maxDepth
}

func pointKey(p model.Point) string {
	return strconv.Itoa(p.X) + "," + strconv.Itoa(p.Y)
}

func pointKeyXY(x, y int) string {
	return strconv.Itoa(x) + "," + strconv.Itoa(y)
}

func headTarget(v model.Vine) (int, int) {
	head := v.OrderedPath[0]
	switch v.HeadDirection {
	case "right":
		return head.X + 1, head.Y
	case "left":
		return head.X - 1, head.Y
	case "up":
		return head.X, head.Y + 1
	case "down":
		return head.X, head.Y - 1
	default:
		return head.X, head.Y
	}
}

func longestFrom(id string, graph map[string][]string, visiting map[string]bool, cache map[string]int) int {
	if v, ok := cache[id]; ok {
		return v
	}
	if visiting[id] {
		return 0
	}
	visiting[id] = true
	defer func() { visiting[id] = false }()
	best := 0
	for _, next := range graph[id] {
		if d := longestFrom(next, graph, visiting, cache); d+1 > best {
			best = d + 1
		}
	}
	cache[id] = best
	return best
}
