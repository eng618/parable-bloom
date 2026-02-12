package generator

import (
	"fmt"
	"sort"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// BuildBlockingGraph returns a map where graph[a][b] == true means vine a blocks vine b.
// A vine A is considered to block vine B if any cell of A occupies the target head cell
// that B would move into on its next move (head cell + headDirection delta).
func BuildBlockingGraph(vines []model.Vine) map[string]map[string]bool {
	occ := make(map[string]string)
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			key := fmt.Sprintf("%d,%d", p.X, p.Y)
			occ[key] = v.ID
		}
	}

	graph := make(map[string]map[string]bool)
	for _, a := range vines {
		graph[a.ID] = make(map[string]bool)
	}

	for _, b := range vines {
		// compute the cell b's head would move to
		if len(b.OrderedPath) == 0 {
			continue
		}
		head := b.OrderedPath[0]
		dx, dy := deltaForDirection(b.HeadDirection)
		tx := head.X + dx
		ty := head.Y + dy
		key := fmt.Sprintf("%d,%d", tx, ty)
		if blocker, ok := occ[key]; ok && blocker != b.ID {
			graph[blocker][b.ID] = true
		}
	}

	return graph
}

// PickBacktrackCandidates returns up to 'window' vine IDs which are good candidates
// to remove when attempting to recover a failing vine. Preference is given to vines
// that block the failing vine or that block many other vines (higher out-degree).
func PickBacktrackCandidates(graph map[string]map[string]bool, failingVine string, window int) []string {
	candidates := make(map[string]int)

	// First, prefer direct blockers (those with edge -> failingVine)
	for a, outs := range graph {
		if outs[failingVine] {
			candidates[a] += 1000 // boost for direct blockers
		}
		// also consider out-degree as measure of "impact"
		candidates[a] += len(outs)
	}

	// Convert to slice and sort by score desc
	type kv struct {
		id    string
		score int
	}
	var list []kv
	for id, sc := range candidates {
		list = append(list, kv{id: id, score: sc})
	}

	sort.Slice(list, func(i, j int) bool {
		if list[i].score == list[j].score {
			return list[i].id < list[j].id
		}
		return list[i].score > list[j].score
	})

	out := make([]string, 0, window)
	for i := 0; i < len(list) && len(out) < window; i++ {
		out = append(out, list[i].id)
	}
	return out
}
