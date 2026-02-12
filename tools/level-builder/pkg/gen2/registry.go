package gen2

import (
	"fmt"
	"sort"
	"sync"
)

// StrategyFactory is a function that creates a new instance of a VinePlacementStrategy
type StrategyFactory func() VinePlacementStrategy

// StrategyInfo contains metadata about a registered strategy
type StrategyInfo struct {
	Name        string
	Description string
	Factory     StrategyFactory
}

var (
	strategies     = make(map[string]StrategyInfo)
	strategiesLock sync.RWMutex
)

// RegisterStrategy registers a new placement strategy
func RegisterStrategy(name, description string, factory StrategyFactory) {
	strategiesLock.Lock()
	defer strategiesLock.Unlock()

	strategies[name] = StrategyInfo{
		Name:        name,
		Description: description,
		Factory:     factory,
	}
}

// GetStrategy returns a new instance of the requested strategy
func GetStrategy(name string) (VinePlacementStrategy, error) {
	strategiesLock.RLock()
	defer strategiesLock.RUnlock()

	info, ok := strategies[name]
	if !ok {
		return nil, fmt.Errorf("unknown strategy: %s", name)
	}

	return info.Factory(), nil
}

// ListStrategies returns a list of all registered strategies
func ListStrategies() []StrategyInfo {
	strategiesLock.RLock()
	defer strategiesLock.RUnlock()

	var list []StrategyInfo
	for _, info := range strategies {
		list = append(list, info)
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].Name < list[j].Name
	})

	return list
}

// init registers the core strategies
func init() {
	RegisterStrategy(StrategyCenterOut, "Center-out LIFO strategy (guaranteed solvable)", func() VinePlacementStrategy {
		return &CenterOutPlacer{} // Properly returns pointer to struct implementing interface
	})

	RegisterStrategy(StrategyDirectionFirst, "Direction-first strategy (organic looking)", func() VinePlacementStrategy {
		return &DirectionFirstPlacer{} 
	})

	// CircuitBoard is experimental/legacy but preserved
	RegisterStrategy("circuit-board", "Circuit-board aesthetic (experimental)", func() VinePlacementStrategy {
		return &CircuitBoardPlacer{}
	})
}
