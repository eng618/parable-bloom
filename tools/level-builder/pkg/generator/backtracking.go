package generator

import (
	"fmt"
	"math/rand"
	"sort"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// AttemptLocalBacktrack tries to recover from a per-vine placement failure by
// removing a bounded window of previously placed vines and retrying placement.
// Returns the placed vine, its occupied cells, updated vines and occupied maps, or an error.
func AttemptLocalBacktrack(
	vines []model.Vine,
	occupied map[string]string,
	vineID string,
	targetLen int,
	p *CenterOutPlacer,
	w, h int,
	rng *rand.Rand,
	config GenerationConfig,
	stats *GenerationStats,
) (model.Vine, map[string]string, []model.Vine, map[string]string, error) {
	backtrackWindow := config.BacktrackWindow
	if backtrackWindow == 0 {
		backtrackWindow = 3
	}
	maxBack := config.MaxBacktrackAttempts
	if maxBack == 0 {
		maxBack = 2
	}

	graph := BuildBlockingGraph(vines)

	// Prefer heuristic candidates first (direct blockers or high impact)
	cands := PickBacktrackCandidates(graph, vineID, backtrackWindow)
	for _, candidate := range cands {
		if stats != nil {
			stats.BacktracksAttempted++
		}
		common.Verbose("AttemptLocalBacktrack: trying heuristic candidate %s", candidate)
		// Remove the candidate vine specifically
		vCopy := make([]model.Vine, 0, len(vines))
		for _, v := range vines {
			if v.ID == candidate {
				continue
			}
			vCopy = append(vCopy, v)
		}
		occCopy := make(map[string]string)
		for k, v := range occupied {
			occCopy[k] = v
		}
		// remove candidate cells
		for _, v := range vines {
			if v.ID != candidate {
				continue
			}
			for _, pt := range v.OrderedPath {
				key := fmt.Sprintf("%d,%d", pt.X, pt.Y)
				delete(occCopy, key)
			}
		}

		vineAttempt, newOcc, err := p.placeVineWithExitGuarantee(vineID, targetLen, w, h, occCopy, rng, stats)
		if err == nil {
			// successful placement after removing candidate
			for k, v := range newOcc {
				occCopy[k] = v
			}
			vCopy = append(vCopy, vineAttempt)
			return vineAttempt, newOcc, vCopy, occCopy, nil
		}
	}

	// Fallback: original last-N-window approach
	for ba := 0; ba < maxBack; ba++ {
		if stats != nil {
			stats.BacktracksAttempted++
		}
		if len(vines) < 2 {
			break
		}
		common.Verbose("AttemptLocalBacktrack: removing %d vines (attempt %d/%d) to recover %s", backtrackWindow, ba+1, maxBack, vineID)
		vines, occupied = backtrackVines(vines, occupied, backtrackWindow)

		vine, newOcc, err := p.placeVineWithExitGuarantee(vineID, targetLen, w, h, occupied, rng, stats)
		if err == nil {
			// Successful recovery
			for k, v := range newOcc {
				occupied[k] = v
			}
			vines = append(vines, vine)
			return vine, newOcc, vines, occupied, nil
		}
	}

	// Cycle-breaker repair: analyze blocking graph for cycles and attempt targeted removals
	analyzer := &DFSBlockingAnalyzer{}
	analysis, aerr := analyzer.AnalyzeBlocking(vines, occupied)
	if aerr == nil && analysis.HasCircular {
		common.Verbose("AttemptLocalBacktrack: detected circular blocking chains: %+v", analysis.CircularChains)
		// For each circular chain, try removing one vine (prefer shortest) and re-attempt placement
		for _, chain := range analysis.CircularChains {
			// select candidate: shortest vine in chain
			var candidate string
			minLen := 1<<31 - 1
			for _, cid := range chain {
				for _, v := range vines {
					if v.ID == cid {
						if len(v.OrderedPath) < minLen {
							minLen = len(v.OrderedPath)
							candidate = cid
						}
					}
				}
			}

			if candidate == "" {
				continue
			}

			// First try: single vine removal (already handled earlier for heuristics, but try again here)
			common.Verbose("AttemptLocalBacktrack: trying cycle-breaker removal candidate %s from cycle %v", candidate, chain)
			if res, err := tryRemoveCandidatesAndPlace([]string{candidate}, vines, occupied, vineID, targetLen, p, w, h, rng, stats); err == nil {
				return res.vine, res.vineOcc, res.vines, res.occ, nil
			}

			// Multi-vine removal: build scored combos (pairs/triplets) and try high-impact ones first
			chainLen := len(chain)
			maxCombo := 2
			if chainLen >= 3 {
				maxCombo = 3
			}

			// Gather combos with scores
			type combo struct {
				ids   []string
				score int
			}
			var combos []combo
			graph := BuildBlockingGraph(vines)
			for sz := 2; sz <= maxCombo && sz <= chainLen; sz++ {
				// iterate combinations (simple lexicographic), compute score
				idx := make([]int, sz)
				for i := 0; i < sz; i++ {
					idx[i] = i
				}
				for {
					ids := make([]string, 0, sz)
					for _, k := range idx {
						ids = append(ids, chain[k])
					}
					sc := scoreCombination(ids, graph, vines)
					combos = append(combos, combo{ids: ids, score: sc})

					// next combination
					k := sz - 1
					for k >= 0 {
						if idx[k] < chainLen-(sz-k) {
							idx[k]++
							for j := k + 1; j < sz; j++ {
								idx[j] = idx[j-1] + 1
							}
							break
						}
						k--
					}
					if k < 0 {
						break
					}
				}
			}

			// sort combos by score desc and try top N
			sort.Slice(combos, func(i, j int) bool {
				if combos[i].score == combos[j].score {
					return len(combos[i].ids) < len(combos[j].ids)
				}
				return combos[i].score > combos[j].score
			})

			maxTry := 12
			if maxTry > len(combos) {
				maxTry = len(combos)
			}
			for i := 0; i < maxTry; i++ {
				c := combos[i]
				common.Verbose("AttemptLocalBacktrack: trying prioritized combo %v (score=%d)", c.ids, c.score)
				if stats != nil {
					stats.BacktracksAttempted++
				}
				if res, err := tryRemoveCandidatesAndPlace(c.ids, vines, occupied, vineID, targetLen, p, w, h, rng, stats); err == nil {
					return res.vine, res.vineOcc, res.vines, res.occ, nil
				}
			}
		}
	}

	_ = writeFailureDump(config, config.Seed, 0, fmt.Sprintf("Could not place vine %s after local backtracking and cycle-breaker repair", vineID), vines, occupied, stats)
	return model.Vine{}, nil, vines, occupied, fmt.Errorf("local backtracking failed for vine %s", vineID)
}

// tryRemoveCandidatesAndPlace attempts to remove the given candidate vine IDs from the current
// state and try placing the target vine. Returns successful state or error.
func tryRemoveCandidatesAndPlace(
	cands []string,
	vines []model.Vine,
	occupied map[string]string,
	vineID string,
	targetLen int,
	p *CenterOutPlacer,
	w, h int,
	rng *rand.Rand,
	stats *GenerationStats,
) (struct {
	vine    model.Vine
	vineOcc map[string]string
	vines   []model.Vine
	occ     map[string]string
}, error,
) {
	if stats != nil {
		stats.BacktracksAttempted++
	}
	// Build copies and remove candidate vines
	vCopy := make([]model.Vine, 0, len(vines))
	for _, v := range vines {
		skip := false
		for _, c := range cands {
			if v.ID == c {
				skip = true
				break
			}
		}
		if !skip {
			vCopy = append(vCopy, v)
		}
	}
	oCopy := make(map[string]string)
	for k, v := range occupied {
		oCopy[k] = v
	}
	for _, v := range vines {
		for _, c := range cands {
			if v.ID != c {
				continue
			}
			for _, pt := range v.OrderedPath {
				key := fmt.Sprintf("%d,%d", pt.X, pt.Y)
				delete(oCopy, key)
			}
		}
	}

	vineAttempt, newOcc, err := p.placeVineWithExitGuarantee(vineID, targetLen, w, h, oCopy, rng, stats)
	if err != nil {
		return struct {
			vine    model.Vine
			vineOcc map[string]string
			vines   []model.Vine
			occ     map[string]string
		}{}, fmt.Errorf("placement failed after removals: %v", err)
	}

	for k, v := range newOcc {
		oCopy[k] = v
	}
	vCopy = append(vCopy, vineAttempt)

	return struct {
		vine    model.Vine
		vineOcc map[string]string
		vines   []model.Vine
		occ     map[string]string
	}{vine: vineAttempt, vineOcc: newOcc, vines: vCopy, occ: oCopy}, nil
}

// scoreCombination computes a heuristic score for a candidate removal combination.
// Higher score indicates better candidate to remove (more blocking impact, frees more cells).
func scoreCombination(ids []string, graph map[string]map[string]bool, vines []model.Vine) int {
	blockingDegree := 0
	lenSum := 0
	for _, id := range ids {
		blockingDegree += len(graph[id])
		for _, v := range vines {
			if v.ID == id {
				lenSum += len(v.OrderedPath)
				break
			}
		}
	}
	return blockingDegree*10 + lenSum
}
