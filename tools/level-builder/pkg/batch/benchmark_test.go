package batch

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// benchLevels are the opener, the last flourishing board, and the boss.
// Grids come from the schedule: 9×12, 18×30, and 22×36.
var benchLevels = []struct {
	name   string
	id     int
	width  int
	height int
}{
	{"Seedling", 1, 9, 12},
	{"Flourishing", 20, 18, 30},
	{"Transcendent", 21, 22, 36},
}

// BenchmarkGenerateRobust times one production attempt of GenerateRobust.
// It does not write a level file. Dumps, if a seed fails closed, stay in a temp dir.
func BenchmarkGenerateRobust(b *testing.B) {
	dump := b.TempDir()
	for _, tc := range benchLevels {
		b.Run(tc.name, func(b *testing.B) {
			benchGrid(b, tc.id, tc.width, tc.height)
			cfg := benchConfig(b, tc.id, 0, dump)
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				level, _, err := generator.GenerateRobust(cfg)
				if err != nil {
					b.Fatalf("level %d: %v", tc.id, err)
				}
				if len(level.Vines) < 2 {
					b.Fatalf("level %d produced %d vines", tc.id, len(level.Vines))
				}
			}
		})
	}
}

// BenchmarkGreedySolvable times the greedy solver on one generated board.
// Generation happens outside the timer. The board is the first greedy
// success from the batch's motif and fallback order.
func BenchmarkGreedySolvable(b *testing.B) {
	dump := b.TempDir()
	for _, tc := range benchLevels {
		b.Run(tc.name, func(b *testing.B) {
			benchGrid(b, tc.id, tc.width, tc.height)
			level := benchSolvableLevel(b, tc.id, dump)
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				if !common.NewSolver(&level).IsSolvableGreedy() {
					b.Fatalf("level %d is not greedily solvable", tc.id)
				}
			}
		})
	}
}

func benchConfig(b *testing.B, levelID, retry int, dump string) config.GenerationConfig {
	b.Helper()
	difficulty := common.ExpectedDifficulty(levelID)
	cfg, err := buildGenerationConfig(levelID, difficulty, Config{
		OutputDir: b.TempDir(),
		DumpDir:   dump,
	})
	if err != nil {
		b.Fatal(err)
	}
	// Match the batch's first-attempt seed: level*31337 + retry*12345 + len(strategy).
	cfg.Seed = int64(levelID)*31337 + int64(retry*12345) + int64(len(cfg.Strategy))
	return cfg
}

func benchGrid(b *testing.B, levelID, width, height int) {
	b.Helper()
	gotW, gotH := common.ExpectedGrid(levelID)
	if gotW != width || gotH != height {
		b.Fatalf("level %d grid = %dx%d, want %dx%d", levelID, gotW, gotH, width, height)
	}
}

func benchSolvableLevel(b *testing.B, levelID int, dump string) model.Level {
	b.Helper()
	// The slot motif is not always the placer that wins. Walk the same
	// fallback order the batch uses, and keep the first greedy board.
	primary := benchConfig(b, levelID, 0, dump)
	strategies := []string{primary.Strategy}
	for _, extra := range []string{config.StrategyLegacyClearable, config.StrategyCenterOut, config.StrategyDirectionFirst} {
		if extra != primary.Strategy {
			strategies = append(strategies, extra)
		}
	}
	for _, strat := range strategies {
		for retry := 0; retry < 20; retry++ {
			cfg := benchConfig(b, levelID, 0, dump)
			cfg.Strategy = strat
			cfg.Seed = int64(levelID)*31337 + int64(retry*12345) + int64(len(strat))
			generated, _, err := generator.GenerateRobust(cfg)
			if err != nil || len(generated.Vines) < 2 {
				continue
			}
			if common.NewSolver(&generated).IsSolvableGreedy() {
				return generated
			}
		}
	}
	b.Fatalf("level %d produced no greedily solvable board", levelID)
	return model.Level{}
}
