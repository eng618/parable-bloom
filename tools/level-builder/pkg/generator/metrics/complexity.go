package metrics

import (
	"fmt"
	"strconv"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
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
	ShortVineShare   float64
	MaskShare        float64
	MaskedCells      int
	FreeVineShare    float64
	FreeVineCount    int
	DirRight         int
	DirLeft          int
	DirUp            int
	DirDown          int
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

	short := 0
	occupied := make(map[string]struct{}, total)
	for _, v := range level.Vines {
		l := len(v.OrderedPath)
		if l <= 3 {
			short++
		}
		switch v.HeadDirection {
		case "right":
			rep.DirRight++
		case "left":
			rep.DirLeft++
		case "up":
			rep.DirUp++
		case "down":
			rep.DirDown++
		}
		for _, p := range v.OrderedPath {
			occupied[pointKey(p)] = struct{}{}
		}
	}
	rep.ShortVineShare = float64(short) / float64(len(level.Vines))
	rep.FreeVineCount = countFreeVines(level, occupied)
	rep.FreeVineShare = float64(rep.FreeVineCount) / float64(len(level.Vines))
	rep.MaskedCells = countMaskedHoles(level, occupied)
	if area := level.GetTotalCells(); area > 0 {
		rep.MaskShare = float64(rep.MaskedCells) / float64(area)
	}
	return rep
}

func countFreeVines(level model.Level, occupied map[string]struct{}) int {
	w, h := level.GetGridWidth(), level.GetGridHeight()
	free := 0
	for _, v := range level.Vines {
		if len(v.OrderedPath) == 0 {
			continue
		}
		dx, dy := headDelta(v.HeadDirection)
		x, y := v.OrderedPath[0].X+dx, v.OrderedPath[0].Y+dy
		clear := true
		for x >= 0 && x < w && y >= 0 && y < h {
			if _, hit := occupied[pointKeyXY(x, y)]; hit {
				clear = false
				break
			}
			x += dx
			y += dy
		}
		if clear {
			free++
		}
	}
	return free
}

func headDelta(dir string) (int, int) {
	switch dir {
	case "right":
		return 1, 0
	case "left":
		return -1, 0
	case "up":
		return 0, 1
	case "down":
		return 0, -1
	default:
		return 0, 0
	}
}

func countMaskedHoles(level model.Level, occupied map[string]struct{}) int {
	if level.Mask == nil || level.Mask.Mode != "hide" {
		return 0
	}
	n := 0
	w, h := level.GetGridWidth(), level.GetGridHeight()
	for _, p := range level.Mask.Points {
		if p.X < 0 || p.Y < 0 || p.X >= w || p.Y >= h {
			continue
		}
		if _, occ := occupied[pointKey(p)]; occ {
			continue
		}
		n++
	}
	return n
}

// CheckContract reports the first new-ladder rule a generated level misses.
// Shipped levels are not passed through this. The variety command only
// enforces it when asked.
func CheckContract(level model.Level, q QualityReport) error {
	spec, ok := config.DifficultySpecs[level.Difficulty]
	if !ok || level.Difficulty == "Tutorial" {
		return nil
	}
	if len(level.GridSize) != 2 {
		return fmt.Errorf("missing grid size")
	}
	wantW, wantH := common.ExpectedGrid(level.ID)
	if level.GridSize[0] != wantW || level.GridSize[1] != wantH {
		return fmt.Errorf("grid %dx%d does not match schedule %dx%d for level %d",
			level.GridSize[0], level.GridSize[1], wantW, wantH, level.ID)
	}
	if len(level.Vines) < spec.VineCountRange[0] || len(level.Vines) > spec.VineCountRange[1] {
		return fmt.Errorf("vine count %d outside spec range %v for %s", len(level.Vines), spec.VineCountRange, level.Difficulty)
	}
	if q.AvgVineLength+1e-9 < float64(spec.AvgLengthRange[0]) || q.AvgVineLength > float64(spec.AvgLengthRange[1])+1e-9 {
		return fmt.Errorf("average length %.1f outside %d-%d for %s", q.AvgVineLength, spec.AvgLengthRange[0], spec.AvgLengthRange[1], level.Difficulty)
	}
	if spec.ColorCountRange[1] > 1 && q.DistinctColors < 2 && len(level.Vines) >= 4 {
		return fmt.Errorf("degenerate palette: only %d distinct color(s) for %s (expected >1)", q.DistinctColors, level.Difficulty)
	}
	if len(level.Vines) >= 6 && q.LengthVariety < 2 {
		return fmt.Errorf("degenerate shapes: length variety %d (min %d, max %d) for %s", q.LengthVariety, q.MinVineLength, q.MaxVineLength, level.Difficulty)
	}
	if len(level.Vines) >= 6 && q.ShortVineShare > 0.15+1e-9 {
		return fmt.Errorf("short-vine share %.0f%% exceeds 15%%", q.ShortVineShare*100)
	}
	if q.MaskShare > 0.03+1e-9 {
		return fmt.Errorf("mask share %.1f%% exceeds 3%% (%d cells)", q.MaskShare*100, q.MaskedCells)
	}
	if len(level.Vines) >= 8 {
		for _, share := range []struct {
			name string
			n    int
		}{
			{"right", q.DirRight},
			{"left", q.DirLeft},
			{"up", q.DirUp},
			{"down", q.DirDown},
		} {
			if float64(share.n)/float64(len(level.Vines))+1e-9 < 0.15 {
				return fmt.Errorf("head direction %s is %.0f%% of vines (minimum 15%%)", share.name, 100*float64(share.n)/float64(len(level.Vines)))
			}
		}
	}
	if err := checkFreeShare(level, q); err != nil {
		return err
	}
	return nil
}

func checkFreeShare(level model.Level, q QualityReport) error {
	if common.IsChallengeLevel(level.ID) {
		if q.FreeVineShare > 0.20+1e-9 {
			return fmt.Errorf("boss free-vine share %.0f%% exceeds 20%%", q.FreeVineShare*100)
		}
		if q.FreeVineCount == len(level.Vines) {
			return fmt.Errorf("boss has every vine free")
		}
		return nil
	}
	switch common.SlotInTier(level.ID) {
	case 0:
		if q.FreeVineShare+1e-9 < 0.40 {
			return fmt.Errorf("slot 1 free-vine share %.0f%% is below 40%%", q.FreeVineShare*100)
		}
	case 1:
		if q.FreeVineShare+1e-9 < 0.30 {
			return fmt.Errorf("slot 2 free-vine share %.0f%% is below 30%%", q.FreeVineShare*100)
		}
	case 2:
		if q.FreeVineShare+1e-9 < 0.20 {
			return fmt.Errorf("slot 3 free-vine share %.0f%% is below 20%%", q.FreeVineShare*100)
		}
	case 3:
		if q.FreeVineShare > 0.30+1e-9 {
			return fmt.Errorf("slot 4 free-vine share %.0f%% exceeds 30%%", q.FreeVineShare*100)
		}
	default:
		if q.FreeVineShare > 0.20+1e-9 {
			return fmt.Errorf("slot 5 free-vine share %.0f%% exceeds 20%%", q.FreeVineShare*100)
		}
	}
	return nil
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
