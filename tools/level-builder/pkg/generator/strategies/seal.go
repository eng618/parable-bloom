package strategies

import (
	"fmt"
	"math"
	"math/rand"
	"sort"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// SealHoles pulls sealed pockets into the vines that already border them.
// ExtendIntoGaps only grows a tail, so a pocket that does not touch a tail
// stays masked. Retracting that vine to the bordering cell and walking
// through the pocket can cover it. A move is kept only when the empty
// count falls and the length band, short-vine cap, free-vine share, and
// greedy solver still hold.
func SealHoles(vines []model.Vine, occupied map[string]string, w, h int, rng *rand.Rand, levelID int, minAvg, maxAvg float64) ([]model.Vine, map[string]string) {
	if len(vines) == 0 || w < 1 || h < 1 {
		return vines, occupied
	}
	if occupied == nil {
		occupied = map[string]string{}
	}
	if rng == nil {
		rng = rand.New(rand.NewSource(1))
	}
	budget := int(float64(w*h) * 0.03)
	if budget < 1 {
		budget = 1
	}
	minFree, maxFree, requireBlocked := freeShareBounds(levelID)
	for pass := 0; pass < 8; pass++ {
		if emptyCount(occupied, w, h) <= budget {
			break
		}
		// A board that is still mostly empty will not be repaired by a pocket walk.
		if emptyCount(occupied, w, h)*100 > w*h*12 {
			break
		}
		if !sealOnce(vines, occupied, w, h, rng, minAvg, maxAvg, minFree, maxFree, requireBlocked) {
			break
		}
	}
	return vines, occupied
}

func sealOnce(vines []model.Vine, occupied map[string]string, w, h int, rng *rand.Rand, minAvg, maxAvg, minFree, maxFree float64, requireBlocked bool) bool {
	comps := emptyComponents(occupied, w, h)
	sort.SliceStable(comps, func(i, j int) bool { return len(comps[i]) > len(comps[j]) })
	tried := 0
	for _, comp := range comps {
		if len(comp) == 0 {
			continue
		}
		borders := bordersOf(comp, vines)
		sort.SliceStable(borders, func(i, j int) bool {
			si := len(vines[borders[i].vine].OrderedPath) - borders[i].idx
			sj := len(vines[borders[j].vine].OrderedPath) - borders[j].idx
			if si != sj {
				return si < sj
			}
			return borders[i].vine < borders[j].vine
		})
		for _, b := range borders {
			if tried >= 10 {
				return false
			}
			tried++
			if sealBorder(vines, occupied, w, h, rng, b, comp, minAvg, maxAvg, minFree, maxFree, requireBlocked) {
				return true
			}
		}
	}
	return false
}

type pathBorder struct {
	vine int
	idx  int
}

func bordersOf(comp []model.Point, vines []model.Vine) []pathBorder {
	holes := map[string]bool{}
	for _, p := range comp {
		holes[cellKey(p)] = true
	}
	var out []pathBorder
	seen := map[string]bool{}
	for vi, v := range vines {
		// Keep at least the head and one cell, and do not treat the tail as a border.
		// ExtendIntoGaps already tried the tail.
		for i := 1; i < len(v.OrderedPath)-1; i++ {
			p := v.OrderedPath[i]
			if !touches(p, holes) {
				continue
			}
			k := fmt.Sprintf("%d:%d", vi, i)
			if seen[k] {
				continue
			}
			seen[k] = true
			out = append(out, pathBorder{vine: vi, idx: i})
		}
	}
	return out
}

func touches(p model.Point, holes map[string]bool) bool {
	for _, d := range []model.Point{{X: 1}, {X: -1}, {Y: 1}, {Y: -1}} {
		if holes[cellKey(model.Point{X: p.X + d.X, Y: p.Y + d.Y})] {
			return true
		}
	}
	return false
}

func sealBorder(vines []model.Vine, occupied map[string]string, w, h int, rng *rand.Rand, b pathBorder, comp []model.Point, minAvg, maxAvg, minFree, maxFree float64, requireBlocked bool) bool {
	path := vines[b.vine].OrderedPath
	if b.idx < 1 || b.idx >= len(path)-1 {
		return false
	}
	before := emptyCount(occupied, w, h)
	saved := snapshotPaths(vines)
	suffix := append([]model.Point{}, path[b.idx+1:]...)
	base := append([]model.Point{}, path[:b.idx+1]...)

	occ := cloneOcc(occupied)
	for _, p := range suffix {
		delete(occ, cellKey(p))
	}
	holes := map[string]bool{}
	for _, p := range comp {
		holes[cellKey(p)] = true
	}
	room := growthRoom(vines, len(suffix), maxAvg, w*h)
	if room < 1 {
		return false
	}
	vine := vines[b.vine]
	added := coverPocket(base, vine, occ, holes, w, h, room)
	if len(added) == 0 {
		return false
	}
	vines[b.vine].OrderedPath = append(append([]model.Point{}, base...), added...)
	for _, p := range added {
		occ[cellKey(p)] = vines[b.vine].ID
	}
	vines, occ = ExtendIntoGaps(vines, occ, w, h, rng, maxAvg)
	if emptyCount(occ, w, h) >= before || !sealAccept(vines, w, h, minAvg, maxAvg, minFree, maxFree, requireBlocked) || !greedySolvable(vines, w, h) {
		restorePaths(vines, saved)
		return false
	}
	// Copy the successful occupancy back into the caller's map.
	for k := range occupied {
		delete(occupied, k)
	}
	for k, v := range occ {
		occupied[k] = v
	}
	return true
}

func coverPocket(base []model.Point, vine model.Vine, occ map[string]string, holes map[string]bool, w, h, room int) []model.Point {
	empties := 0
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if _, ok := occ[fmt.Sprintf("%d,%d", x, y)]; !ok {
				empties++
			}
		}
	}
	if empties > 18 {
		return greedyCover(base, vine, occ, holes, w, h, room)
	}
	bestScore := -1
	var best []model.Point
	nodes := 0
	var rec func(path []model.Point, holeLeft int)
	rec = func(path []model.Point, holeLeft int) {
		if nodes > 6000 {
			return
		}
		nodes++
		added := len(path) - len(base)
		score := (len(holes)-holeLeft)*100 + added
		if score > bestScore && added > 0 && (len(holes) == 0 || holeLeft < len(holes)) {
			bestScore = score
			best = append([]model.Point{}, path[len(base):]...)
		}
		if added >= room {
			return
		}
		tail := path[len(path)-1]
		neigh := freeNeighbors(tail, w, h, occ)
		sort.SliceStable(neigh, func(i, j int) bool {
			hi := holes[cellKey(neigh[i])]
			hj := holes[cellKey(neigh[j])]
			if hi != hj {
				return hi
			}
			if neigh[i].X != neigh[j].X {
				return neigh[i].X < neigh[j].X
			}
			return neigh[i].Y < neigh[j].Y
		})
		for _, n := range neigh {
			k := cellKey(n)
			next := make([]model.Point, len(path)+1)
			copy(next, path)
			next[len(path)] = n
			occ[k] = vine.ID
			vine.OrderedPath = next
			blocked := vineSelfBlocks(vine, w, h)
			if !blocked {
				left := holeLeft
				if holes[k] {
					left--
				}
				rec(next, left)
			}
			delete(occ, k)
			if nodes > 6000 {
				return
			}
		}
	}
	vine.OrderedPath = base
	rec(append([]model.Point{}, base...), len(holes))
	return best
}

func greedyCover(base []model.Point, vine model.Vine, occ map[string]string, holes map[string]bool, w, h, room int) []model.Point {
	path := append([]model.Point{}, base...)
	var added []model.Point
	for len(added) < room {
		tail := path[len(path)-1]
		neigh := freeNeighbors(tail, w, h, occ)
		if len(neigh) == 0 {
			break
		}
		sort.SliceStable(neigh, func(i, j int) bool {
			hi := holes[cellKey(neigh[i])]
			hj := holes[cellKey(neigh[j])]
			if hi != hj {
				return hi
			}
			return false
		})
		placed := false
		for _, n := range neigh {
			next := append(append([]model.Point{}, path...), n)
			vine.OrderedPath = next
			if vineSelfBlocks(vine, w, h) {
				continue
			}
			occ[cellKey(n)] = vine.ID
			path = next
			added = append(added, n)
			placed = true
			break
		}
		if !placed {
			break
		}
	}
	covered := false
	for _, p := range added {
		if holes[cellKey(p)] {
			covered = true
			break
		}
	}
	if !covered {
		for _, p := range added {
			delete(occ, cellKey(p))
		}
		return nil
	}
	return added
}

func growthRoom(vines []model.Vine, suffix int, maxAvg float64, area int) int {
	total := 0
	for _, v := range vines {
		total += len(v.OrderedPath)
	}
	retracted := total - suffix
	maxCells := area
	if maxAvg > 0 {
		maxCells = int(math.Floor(maxAvg*float64(len(vines)) + 1e-9))
	}
	room := maxCells - retracted
	if room > area {
		room = area
	}
	return room
}

func sealAccept(vines []model.Vine, w, h int, minAvg, maxAvg, minFree, maxFree float64, requireBlocked bool) bool {
	if len(vines) == 0 {
		return false
	}
	minL, maxL := len(vines[0].OrderedPath), len(vines[0].OrderedPath)
	for _, v := range vines {
		n := len(v.OrderedPath)
		if n < 2 || vineSelfBlocks(v, w, h) {
			return false
		}
		if n < minL {
			minL = n
		}
		if n > maxL {
			maxL = n
		}
	}
	if len(vines) >= 6 && maxL-minL < 2 {
		return false
	}
	if len(vines) >= 6 && pocketShortShare(vines) > 0.15+1e-9 {
		return false
	}
	avg := averageLength(vines)
	if minAvg > 0 && avg+1e-9 < minAvg {
		return false
	}
	if maxAvg > 0 && avg > maxAvg+1e-9 {
		return false
	}
	free := countFreeHeads(vines, w, h)
	share := float64(free) / float64(len(vines))
	if share+1e-9 < minFree || share > maxFree+1e-9 {
		return false
	}
	if requireBlocked && free == len(vines) {
		return false
	}
	return true
}

func countFreeHeads(vines []model.Vine, w, h int) int {
	occ := map[string]bool{}
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			occ[cellKey(p)] = true
		}
	}
	free := 0
	for _, v := range vines {
		if len(v.OrderedPath) == 0 {
			continue
		}
		dx, dy := 0, 0
		switch v.HeadDirection {
		case "right":
			dx = 1
		case "left":
			dx = -1
		case "up":
			dy = 1
		case "down":
			dy = -1
		default:
			continue
		}
		x, y := v.OrderedPath[0].X+dx, v.OrderedPath[0].Y+dy
		clear := true
		for x >= 0 && x < w && y >= 0 && y < h {
			if occ[fmt.Sprintf("%d,%d", x, y)] {
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

func freeShareBounds(levelID int) (minShare, maxShare float64, requireBlocked bool) {
	if levelID <= 0 {
		return 0, 1, false
	}
	if common.IsChallengeLevel(levelID) {
		return 0, 0.20, true
	}
	switch common.SlotInTier(levelID) {
	case 0:
		return 0.40, 1, false
	case 1:
		return 0.30, 1, false
	case 2:
		return 0.20, 1, false
	case 3:
		return 0, 0.30, false
	default:
		return 0, 0.20, false
	}
}

func emptyComponents(occupied map[string]string, w, h int) [][]model.Point {
	seen := map[string]bool{}
	var comps [][]model.Point
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if _, ok := occupied[key]; ok || seen[key] {
				continue
			}
			var comp []model.Point
			q := []model.Point{{X: x, Y: y}}
			seen[key] = true
			for len(q) > 0 {
				p := q[0]
				q = q[1:]
				comp = append(comp, p)
				for _, d := range []model.Point{{X: 1}, {X: -1}, {Y: 1}, {Y: -1}} {
					n := model.Point{X: p.X + d.X, Y: p.Y + d.Y}
					if n.X < 0 || n.Y < 0 || n.X >= w || n.Y >= h {
						continue
					}
					nk := cellKey(n)
					if seen[nk] {
						continue
					}
					if _, ok := occupied[nk]; ok {
						continue
					}
					seen[nk] = true
					q = append(q, n)
				}
			}
			comps = append(comps, comp)
		}
	}
	return comps
}

func snapshotPaths(vines []model.Vine) [][]model.Point {
	saved := make([][]model.Point, len(vines))
	for i := range vines {
		saved[i] = append([]model.Point{}, vines[i].OrderedPath...)
	}
	return saved
}

func restorePaths(vines []model.Vine, saved [][]model.Point) {
	for i := range vines {
		vines[i].OrderedPath = saved[i]
	}
}

func cloneOcc(in map[string]string) map[string]string {
	out := make(map[string]string, len(in))
	for k, v := range in {
		out[k] = v
	}
	return out
}

func cellKey(p model.Point) string {
	return fmt.Sprintf("%d,%d", p.X, p.Y)
}
