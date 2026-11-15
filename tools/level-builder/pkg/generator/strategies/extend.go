package strategies

import (
	"fmt"
	"math/rand"
	"sort"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// ExtendIntoGaps appends empty cells onto existing tails before any new vine
// is spawned. Each append must keep the level greedy-solvable. Growth stops
// once the average length reaches maxAvg so a board does not become one snake.
func ExtendIntoGaps(vines []model.Vine, occupied map[string]string, w, h int, rng *rand.Rand, maxAvg float64) ([]model.Vine, map[string]string) {
	if len(vines) == 0 || w < 1 || h < 1 {
		return vines, occupied
	}
	if occupied == nil {
		occupied = make(map[string]string)
		for _, v := range vines {
			for _, p := range v.OrderedPath {
				occupied[common.PointKey(p)] = v.ID
			}
		}
	}

	maxPasses := w + h
	for pass := 0; pass < maxPasses; pass++ {
		if maxAvg > 0 && averageLength(vines) >= maxAvg {
			break
		}
		order := make([]int, len(vines))
		for i := range order {
			order[i] = i
		}
		sort.SliceStable(order, func(i, j int) bool {
			return len(vines[order[i]].OrderedPath) < len(vines[order[j]].OrderedPath)
		})

		progress := false
		for _, idx := range order {
			if maxAvg > 0 && averageLength(vines) >= maxAvg {
				break
			}
			if tryExtendVine(vines, idx, occupied, w, h, rng) {
				progress = true
			}
		}
		if !progress {
			break
		}
	}
	return vines, occupied
}

func averageLength(vines []model.Vine) float64 {
	if len(vines) == 0 {
		return 0
	}
	total := 0
	for _, v := range vines {
		total += len(v.OrderedPath)
	}
	return float64(total) / float64(len(vines))
}

func tryExtendVine(vines []model.Vine, idx int, occupied map[string]string, w, h int, rng *rand.Rand) bool {
	path := vines[idx].OrderedPath
	if len(path) == 0 {
		return false
	}
	tail := path[len(path)-1]
	neighbors := freeNeighbors(tail, w, h, occupied)
	if len(neighbors) == 0 {
		return false
	}
	if len(path) >= 2 {
		prev := path[len(path)-2]
		straight := model.Point{X: tail.X + (tail.X - prev.X), Y: tail.Y + (tail.Y - prev.Y)}
		sort.SliceStable(neighbors, func(i, j int) bool {
			return neighbors[i] == straight && neighbors[j] != straight
		})
	}
	if len(neighbors) > 1 {
		// Shuffle the non-straight tail so seeds still diverge.
		rng.Shuffle(len(neighbors)-0, func(i, j int) {
			if len(path) >= 2 && (i == 0 || j == 0) {
				return
			}
			neighbors[i], neighbors[j] = neighbors[j], neighbors[i]
		})
	}

	for _, next := range neighbors {
		key := common.PointKey(next)
		vines[idx].OrderedPath = append(vines[idx].OrderedPath, next)
		occupied[key] = vines[idx].ID
		// Greedy slides a vine forward and will accept a body that sits on
		// its own exit ray. The structural check does not, so reject those.
		if greedySolvable(vines, w, h) && !vineSelfBlocks(vines[idx], w, h) {
			return true
		}
		vines[idx].OrderedPath = vines[idx].OrderedPath[:len(vines[idx].OrderedPath)-1]
		delete(occupied, key)
	}
	return false
}

func freeNeighbors(p model.Point, w, h int, occupied map[string]string) []model.Point {
	deltas := []model.Point{{X: 0, Y: 1}, {X: 0, Y: -1}, {X: 1, Y: 0}, {X: -1, Y: 0}}
	var out []model.Point
	for _, d := range deltas {
		nx, ny := p.X+d.X, p.Y+d.Y
		if nx < 0 || ny < 0 || nx >= w || ny >= h {
			continue
		}
		if _, occ := occupied[common.PointKey(model.Point{X: nx, Y: ny})]; occ {
			continue
		}
		out = append(out, model.Point{X: nx, Y: ny})
	}
	return out
}

// vineSelfBlocks reports a body cell sitting on the head's exit ray.
func vineSelfBlocks(vine model.Vine, w, h int) bool {
	if len(vine.OrderedPath) == 0 {
		return false
	}
	dx, dy := 0, 0
	switch vine.HeadDirection {
	case "right":
		dx = 1
	case "left":
		dx = -1
	case "up":
		dy = 1
	case "down":
		dy = -1
	default:
		return false
	}
	head := vine.OrderedPath[0]
	ray := map[string]bool{}
	x, y := head.X+dx, head.Y+dy
	for x >= 0 && x < w && y >= 0 && y < h {
		ray[common.PointKey(model.Point{X: x, Y: y})] = true
		x += dx
		y += dy
	}
	for i := 1; i < len(vine.OrderedPath); i++ {
		p := vine.OrderedPath[i]
		if ray[common.PointKey(p)] {
			return true
		}
	}
	return false
}

// AbsorbPockets places 2-cell vines in leftover adjacent holes when that
// keeps the length band, the short-vine cap, and greedy solvability.
// The gap filler only plants a vine whose ray is already clear, so interior
// pockets otherwise become mask.
func AbsorbPockets(vines []model.Vine, occupied map[string]string, w, h int, minAvg float64) ([]model.Vine, map[string]string) {
	if w < 1 || h < 1 {
		return vines, occupied
	}
	if occupied == nil {
		occupied = map[string]string{}
	}
	budget := int(float64(w*h) * 0.03)
	if budget < 1 {
		budget = 1
	}
	failed := map[string]bool{}
	nextID := len(vines) + 1
	for tries := 0; tries < w*h; tries++ {
		if emptyCount(occupied, w, h) <= budget {
			break
		}
		a, b, ok := nextPocket(occupied, w, h, failed)
		if !ok {
			break
		}
		placed := false
		for _, orient := range [][2]model.Point{{a, b}, {b, a}} {
			head, neck := orient[0], orient[1]
			vine := model.Vine{
				ID:            fmt.Sprintf("pocket_%d", nextID),
				HeadDirection: common.DirectionFromPoints(neck, head),
				OrderedPath:   []model.Point{head, neck},
			}
			if vineSelfBlocks(vine, w, h) {
				continue
			}
			trial := append(append([]model.Vine{}, vines...), vine)
			if minAvg > 0 && averageLength(trial)+1e-9 < minAvg {
				continue
			}
			if pocketShortShare(trial) > 0.15+1e-9 {
				continue
			}
			if !greedySolvable(trial, w, h) {
				continue
			}
			vines = append(vines, vine)
			occupied[common.PointKey(head)] = vine.ID
			occupied[common.PointKey(neck)] = vine.ID
			nextID++
			placed = true
			break
		}
		if !placed {
			failed[pocketKey(a, b)] = true
		}
	}
	return vines, occupied
}

func emptyCount(occupied map[string]string, w, h int) int {
	n := 0
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if _, occ := occupied[common.PointKey(model.Point{X: x, Y: y})]; !occ {
				n++
			}
		}
	}
	return n
}

func nextPocket(occupied map[string]string, w, h int, failed map[string]bool) (model.Point, model.Point, bool) {
	deltas := []model.Point{{X: 1, Y: 0}, {X: -1, Y: 0}, {X: 0, Y: 1}, {X: 0, Y: -1}}
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if _, occ := occupied[common.PointKey(model.Point{X: x, Y: y})]; occ {
				continue
			}
			a := model.Point{X: x, Y: y}
			for _, d := range deltas {
				b := model.Point{X: x + d.X, Y: y + d.Y}
				if b.X < 0 || b.Y < 0 || b.X >= w || b.Y >= h {
					continue
				}
				if _, occ := occupied[common.PointKey(b)]; occ {
					continue
				}
				if failed[pocketKey(a, b)] {
					continue
				}
				return a, b, true
			}
		}
	}
	return model.Point{}, model.Point{}, false
}

func pocketKey(a, b model.Point) string {
	if a.X > b.X || (a.X == b.X && a.Y > b.Y) {
		a, b = b, a
	}
	return fmt.Sprintf("%d,%d:%d,%d", a.X, a.Y, b.X, b.Y)
}

func pocketShortShare(vines []model.Vine) float64 {
	if len(vines) == 0 {
		return 0
	}
	n := 0
	for _, v := range vines {
		if len(v.OrderedPath) <= 3 {
			n++
		}
	}
	return float64(n) / float64(len(vines))
}

func greedySolvable(vines []model.Vine, w, h int) bool {
	level := &model.Level{
		GridSize: []int{w, h},
		Vines:    vines,
	}
	return common.NewSolver(level).IsSolvableGreedy()
}
