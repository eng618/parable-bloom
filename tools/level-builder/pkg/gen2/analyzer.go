package gen2

import (
	"fmt"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// DFSBlockingAnalyzer implements BlockingAnalyzer using DFS cycle detection
type DFSBlockingAnalyzer struct{}

// AnalyzeBlocking analyzes blocking relationships and detects circular dependencies
func (a *DFSBlockingAnalyzer) AnalyzeBlocking(vines []model.Vine, occupied map[string]string) (BlockingAnalysis, error) {
	// Build blocking graph: A -> B means "A blocks B"
	graph := a.buildBlockingGraph(vines, occupied)

	// Calculate maximum blocking depth
	maxDepth := a.calculateMaxBlockingDepth(graph, vines)

	// Detect circular dependencies
	hasCircular, circularChains := a.detectCircularBlocking(graph)

	analysis := BlockingAnalysis{
		MaxDepth:       maxDepth,
		HasCircular:    hasCircular,
		CircularChains: circularChains,
	}

	return analysis, nil
}

// buildBlockingGraph creates a graph where A -> B means "A blocks B"
func (a *DFSBlockingAnalyzer) buildBlockingGraph(vines []model.Vine, occupied map[string]string) map[string][]string {
	graph := make(map[string][]string)

	// Convert vines to model format for blocking analysis
	modelVines := make([]model.Vine, len(vines))
	copy(modelVines, vines)

	// Check each pair of vines for blocking relationships
	for i := range modelVines {
		for j := range modelVines {
			if i == j {
				continue
			}

			if a.vineBlocksVine(modelVines[i], modelVines[j], occupied) {
				blockerID := modelVines[i].ID
				blockedID := modelVines[j].ID
				graph[blockerID] = append(graph[blockerID], blockedID)
			}
		}
	}

	return graph
}

// calculateMaxBlockingDepth finds the longest chain of blocking relationships
func (a *DFSBlockingAnalyzer) calculateMaxBlockingDepth(graph map[string][]string, vines []model.Vine) int {
	maxDepth := 0

	// For each vine, find the longest path starting from it
	for _, vine := range vines {
		depth := a.findMaxDepthFromVine(vine.ID, graph, make(map[string]bool))
		if depth > maxDepth {
			maxDepth = depth
		}
	}

	return maxDepth
}

// findMaxDepthFromVine finds the maximum blocking depth starting from a vine
func (a *DFSBlockingAnalyzer) findMaxDepthFromVine(vineID string, graph map[string][]string, visited map[string]bool) int {
	if visited[vineID] {
		return 0 // Prevent infinite recursion in cycles (though we check for cycles separately)
	}

	visited[vineID] = true
	defer func() { visited[vineID] = false }()

	blockedVines := graph[vineID]
	if len(blockedVines) == 0 {
		return 0
	}

	maxChildDepth := 0
	for _, blockedID := range blockedVines {
		childDepth := a.findMaxDepthFromVine(blockedID, graph, visited)
		if childDepth > maxChildDepth {
			maxChildDepth = childDepth
		}
	}

	return 1 + maxChildDepth
}

// detectCircularBlocking uses DFS to detect cycles in the blocking graph
func (a *DFSBlockingAnalyzer) detectCircularBlocking(graph map[string][]string) (bool, [][]string) {
	visited := make(map[string]bool)
	recStack := make(map[string]bool)
	var circularChains [][]string

	var hasCycle func(string, []string) bool
	hasCycle = func(nodeID string, path []string) bool {
		// Add current node to path
		currentPath := append(path, nodeID)

		if recStack[nodeID] {
			// Found a cycle - extract the cycle from current path
			cycleStart := -1
			for i, id := range currentPath {
				if id == nodeID && i < len(currentPath)-1 {
					cycleStart = i
					break
				}
			}
			if cycleStart >= 0 {
				cycle := append(currentPath[cycleStart:], nodeID) // Close the cycle
				circularChains = append(circularChains, cycle)
			}
			return true
		}

		if visited[nodeID] {
			return false
		}

		visited[nodeID] = true
		recStack[nodeID] = true

		for _, neighbor := range graph[nodeID] {
			if hasCycle(neighbor, currentPath) {
				return true
			}
		}

		recStack[nodeID] = false
		return false
	}

	// Check each node for cycles
	for nodeID := range graph {
		if !visited[nodeID] {
			if hasCycle(nodeID, []string{}) {
				return true, circularChains
			}
		}
	}

	return false, nil
}

// vineBlocksVine checks if blocker prevents blocked from moving
func (a *DFSBlockingAnalyzer) vineBlocksVine(blocker, blocked model.Vine, occupied map[string]string) bool {
	if len(blocked.OrderedPath) == 0 {
		return false
	}

	head := blocked.OrderedPath[0]
	targetX, targetY := head.X, head.Y

	// Calculate where blocked vine's head would move
	switch blocked.HeadDirection {
	case "right":
		targetX++
	case "left":
		targetX--
	case "up":
		targetY++
	case "down":
		targetY--
	default:
		return false
	}

	key := fmt.Sprintf("%d,%d", targetX, targetY)
	blockingVine, targetOccupied := occupied[key]
	headVine, headOccupied := occupied[fmt.Sprintf("%d,%d", head.X, head.Y)]
	return targetOccupied && headOccupied && blockingVine != headVine
}
