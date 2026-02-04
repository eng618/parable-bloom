package validator

import (
	"container/heap"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// isSolvableExactAStarWithStats runs an A* search over mask states using a simple heuristic
// that prefers states with fewer blocked vines. Returns solvable flag and states explored.
func isSolvableExactAStarWithStats(lvl model.Level, maxStates int, astarWeight int) (bool, int) {
	vines := lvl.Vines
	vineCount := len(vines)
	w, h := lvl.GridSize[0], lvl.GridSize[1]
	gridArea := w * h

	// Precompute vine indices
	vineIndices := make([][]int, vineCount)
	for i, v := range vines {
		indices := make([]int, len(v.OrderedPath))
		for j, p := range v.OrderedPath {
			indices[j] = p.Y*w + p.X
		}
		vineIndices[i] = indices
	}

	fullMask := int64((1 << uint(vineCount)) - 1)
	if vineCount == 64 {
		fullMask = -1
	}

	// A* structures
	visited := make(map[int64]bool)
	pq := &priorityQueueMask{}
	heap.Init(pq)

	heap.Push(pq, &maskItem{
		mask:     fullMask,
		priority: heuristicPriorityFast(fullMask, lvl, vineIndices, astarWeight),
	})
	visited[fullMask] = true

	states := 0
	occupied := make([]bool, gridArea)

	for pq.Len() > 0 {
		if states >= maxStates {
			return false, states
		}

		item := heap.Pop(pq).(*maskItem)
		mask := item.mask
		states++
		if mask == 0 {
			return true, states
		}

		// Update occupancy
		for idx := 0; idx < gridArea; idx++ {
			occupied[idx] = false
		}
		for i := 0; i < vineCount; i++ {
			if (mask & (1 << uint(i))) != 0 {
				for _, idx := range vineIndices[i] {
					occupied[idx] = true
				}
			}
		}

		// movable vines
		for i := 0; i < vineCount; i++ {
			if (mask & (1 << uint(i))) == 0 {
				continue
			}
			if canVineClearFast(lvl, i, occupied, vineIndices[i]) {
				next := mask & ^(1 << uint(i))
				if !visited[next] {
					visited[next] = true
					priority := heuristicPriorityFast(next, lvl, vineIndices, astarWeight)
					heap.Push(pq, &maskItem{mask: next, priority: priority})
				}
			}
		}
	}

	return false, states
}

// heuristicPriorityFast computes a simple heuristic: blockedCount*weight + remainingVines
func heuristicPriorityFast(mask int64, lvl model.Level, vineIndices [][]int, weight int) int {
	w, h := lvl.GridSize[0], lvl.GridSize[1]
	remaining := 0
	blocked := 0

	for i := 0; i < len(lvl.Vines); i++ {
		if (mask & (1 << uint(i))) == 0 {
			continue
		}
		remaining++

		// count blocked vines
		v := lvl.Vines[i]
		head := v.OrderedPath[0]
		dx, dy := directionDelta(v.HeadDirection)
		nx, ny := head.X+dx, head.Y+dy

		if nx < 0 || nx >= w || ny < 0 || ny >= h {
			continue // can exit
		}

		nextIdx := ny*w + nx
		for j := 0; j < len(lvl.Vines); j++ {
			if (mask&(1<<uint(j))) == 0 || i == j {
				continue
			}
			for _, idx := range vineIndices[j] {
				if idx == nextIdx {
					blocked++
					goto nextVine
				}
			}
		}
	nextVine:
	}

	return blocked*weight + remaining
}
