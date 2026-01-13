package validator

import (
	"container/heap"
	"fmt"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// priorityItem for A* queue
type priorityItem struct {
	mask     int
	priority int
	index    int
}

// priorityQueue implements heap.Interface
type priorityQueue []*priorityItem

func (pq priorityQueue) Len() int           { return len(pq) }
func (pq priorityQueue) Less(i, j int) bool { return pq[i].priority < pq[j].priority }
func (pq priorityQueue) Swap(i, j int)      { pq[i], pq[j] = pq[j], pq[i]; pq[i].index = i; pq[j].index = j }
func (pq *priorityQueue) Push(x interface{}) {
	n := len(*pq)
	item := x.(*priorityItem)
	item.index = n
	*pq = append(*pq, item)
}
func (pq *priorityQueue) Pop() interface{} {
	old := *pq
	n := len(old)
	item := old[n-1]
	old[n-1] = nil
	item.index = -1
	*pq = old[0 : n-1]
	return item
}

// isSolvableExactAStarWithStats runs an A* search over mask states using a simple heuristic
// that prefers states with fewer blocked vines. Returns solvable flag and SolvabilityStats.
func isSolvableExactAStarWithStats(lvl model.Level, maxStates int, astarWeight int) (bool, int) {
	vines := lvl.Vines
	vineCount := len(vines)

	// Precompute vine cells
	vineCells := make([]map[string]bool, vineCount)
	for i, v := range vines {
		m := map[string]bool{}
		for _, p := range v.OrderedPath {
			m[fmt.Sprintf("%d,%d", p.X, p.Y)] = true
		}
		vineCells[i] = m
	}

	fullMask := (1 << uint(vineCount)) - 1

	// A* structures
	visited := make(map[int]bool)
	pq := &priorityQueue{}
	heap.Init(pq)
	// push initial state with heuristic
	heap.Push(pq, &priorityItem{mask: fullMask, priority: heuristicPriority(fullMask, lvl, vineCells, astarWeight)})
	visited[fullMask] = true

	states := 0

	for pq.Len() > 0 {
		if states >= maxStates {
			return false, states
		}

		item := heap.Pop(pq).(*priorityItem)
		mask := item.mask
		states++
		if mask == 0 {
			return true, states
		}

		// build occupied using shared helper for consistency and efficiency
		occupied := computeOccupied(mask, vineCount, vineCells)

		// movable vines
		for i := 0; i < vineCount; i++ {
			if (mask & (1 << uint(i))) == 0 {
				continue
			}
			if canVineClearExact(lvl, i, occupied, vineCells[i]) {
				next := mask & ^(1 << uint(i))
				if !visited[next] {
					visited[next] = true
					priority := heuristicPriority(next, lvl, vineCells, astarWeight)
					heap.Push(pq, &priorityItem{mask: next, priority: priority})
				}
			}
		}
	}

	return false, states
}

// heuristicPriority computes a simple heuristic: blockedCount*weight + remainingVines
func heuristicPriority(mask int, lvl model.Level, vineCells []map[string]bool, weight int) int {
	// count remaining vines
	remaining := 0
	for i := 0; i < len(lvl.Vines); i++ {
		if (mask & (1 << uint(i))) != 0 {
			remaining++
		}
	}

	// count blocked vines (simple check using head cell occupancy)
	blocked := 0
	for i := 0; i < len(lvl.Vines); i++ {
		if (mask & (1 << uint(i))) == 0 {
			continue
		}
		head := lvl.Vines[i].OrderedPath[0]
		dx, dy := directionDelta(lvl.Vines[i].HeadDirection)
		nxt := fmt.Sprintf("%d,%d", head.X+dx, head.Y+dy)
		// if occupied by any active vine, count as blocked
		for j := 0; j < len(lvl.Vines); j++ {
			if (mask & (1 << uint(j))) == 0 {
				continue
			}
			if vineCells[j][nxt] {
				blocked++
				break
			}
		}
	}

	return blocked*weight + remaining
}
