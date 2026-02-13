package generator

import (
	"fmt"
	"sort"
	"sync"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
)

// StrategyFactory is a function that creates a new instance of a VinePlacementStrategy
type StrategyFactory func() config.VinePlacementStrategy

// StrategyInfo contains metadata about a registered strategy
type StrategyInfo struct {
	Name        string
	Description string
	Factory     StrategyFactory
}

var (
	stMap          = make(map[string]StrategyInfo)
	strategiesLock sync.RWMutex
)

// RegisterStrategy registers a new placement strategy
func RegisterStrategy(name, description string, factory StrategyFactory) {
	strategiesLock.Lock()
	defer strategiesLock.Unlock()

	stMap[name] = StrategyInfo{
		Name:        name,
		Description: description,
		Factory:     factory,
	}
}

// GetStrategy returns a new instance of the requested strategy
func GetStrategy(name string) (config.VinePlacementStrategy, error) {
	strategiesLock.RLock()
	defer strategiesLock.RUnlock()

	info, ok := stMap[name]
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
	for _, info := range stMap {
		list = append(list, info)
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].Name < list[j].Name
	})

	return list
}

// init registers the core strategies
func init() {
	RegisterStrategy(config.StrategyCenterOut, "Center-out LIFO strategy (guaranteed solvable)", func() config.VinePlacementStrategy {
		return &strategies.CenterOutPlacer{}
	})

	RegisterStrategy(config.StrategyDirectionFirst, "Direction-first strategy (organic looking)", func() config.VinePlacementStrategy {
		return &strategies.DirectionFirstPlacer{}
	})

	// CircuitBoard is experimental/legacy but preserved
	RegisterStrategy("circuit-board", "Circuit-board aesthetic (experimental)", func() config.VinePlacementStrategy {
		return &strategies.CircuitBoardPlacer{}
	})

	// Legacy strategies
	RegisterStrategy(strategies.StrategyLegacyTiling, "Legacy Tiling (Standard)", func() config.VinePlacementStrategy {
		return &strategies.LegacyTilingStrategy{}
	})
	RegisterStrategy(strategies.StrategyLegacyClearable, "Legacy Clearable-First", func() config.VinePlacementStrategy {
		return &strategies.LegacyClearableStrategy{}
	})
	RegisterStrategy(strategies.StrategyLegacySolverAware, "Legacy Solver-Aware", func() config.VinePlacementStrategy {
		return &strategies.LegacySolverAwareStrategy{}
	})
}
