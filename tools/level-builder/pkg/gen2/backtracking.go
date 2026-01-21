package gen2

import (
	"fmt"
	"math/rand"

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

		vineAttempt, newOcc, err := p.placeVineWithExitGuarantee(vineID, targetLen, w, h, occCopy, rng)
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
		if len(vines) < 2 {
			break
		}
		common.Verbose("AttemptLocalBacktrack: removing %d vines (attempt %d/%d) to recover %s", backtrackWindow, ba+1, maxBack, vineID)
		vines, occupied = backtrackVines(vines, occupied, backtrackWindow)

		vine, newOcc, err := p.placeVineWithExitGuarantee(vineID, targetLen, w, h, occupied, rng)
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

			common.Verbose("AttemptLocalBacktrack: trying cycle-breaker removal candidate %s from cycle %v", candidate, chain)
			// remove candidate cells
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
			for _, v := range vines {
				if v.ID != candidate {
					continue
				}
				for _, pt := range v.OrderedPath {
					key := fmt.Sprintf("%d,%d", pt.X, pt.Y)
					delete(occCopy, key)
				}
			}

			vineAttempt, newOcc, err := p.placeVineWithExitGuarantee(vineID, targetLen, w, h, occCopy, rng)
			if err == nil {
				// successful placement after cycle-breaker removal
				for k, v := range newOcc {
					occCopy[k] = v
				}
				vCopy = append(vCopy, vineAttempt)
				return vineAttempt, newOcc, vCopy, occCopy, nil
			}
		}
	}

	_ = writeFailureDump(config, config.Seed, 0, fmt.Sprintf("Could not place vine %s after local backtracking and cycle-breaker repair", vineID), vines, occupied)
	return model.Vine{}, nil, vines, occupied, fmt.Errorf("local backtracking failed for vine %s", vineID)
}
