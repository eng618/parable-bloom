package stats

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

var (
	statsFile    string
	statsDir     string
	lessonsStats bool
)

var statsCmd = &cobra.Command{
	Use:   "stats [file...]",
	Short: "Summarize validation or batch-generation stats JSON files",
	Long: `Summarize stats artifacts produced by validate and batch runs.

Defaults to logs/validation_stats.json (repo logs directory). Use --lessons
for tutorial stats, --dir for per-level batch stats directories
(level_*_stats.json), or pass explicit file paths.

Examples:
  level-builder stats
  level-builder stats --lessons
  level-builder stats --dir logs/20240101_120000/runs/stats
  level-builder stats validation_stats_bfs.json validation_stats_astar.json`,
	RunE: runStats,
}

func init() {
	statsCmd.Flags().StringVar(&statsFile, "file", "", "explicit stats file to summarize (default: logs/validation_stats.json)")
	statsCmd.Flags().StringVar(&statsDir, "dir", "", "directory of per-level batch stats (level_*_stats.json) to aggregate")
	statsCmd.Flags().BoolVar(&lessonsStats, "lessons", false, "summarize tutorial stats (validation_stats_lessons.json)")
}

// GetCommand returns the stats command.
func GetCommand() *cobra.Command {
	return statsCmd
}

func runStats(cmd *cobra.Command, args []string) error {
	out := cmd.OutOrStdout()

	// Directory mode: aggregate per-level batch stats.
	if statsDir != "" {
		return summarizeBatchDir(out, statsDir)
	}

	files := args
	if statsFile != "" {
		files = append([]string{statsFile}, files...)
	}
	if lessonsStats {
		files = append(files, "validation_stats_lessons.json")
	}
	if len(files) == 0 {
		logsDir, err := common.LogsDir()
		if err != nil {
			return fmt.Errorf("failed to resolve logs directory: %w", err)
		}
		files = []string{filepath.Join(logsDir, "validation_stats.json")}
	}

	failed := 0
	for _, p := range files {
		if err := summarizeValidationFile(out, p); err != nil {
			fmt.Fprintf(out, "error summarizing %s: %v\n", p, err)
			failed++
		}
	}
	if failed > 0 {
		return fmt.Errorf("failed to summarize %d file(s)", failed)
	}
	return nil
}

// levelStat mirrors validator.LevelStat for summary purposes.
type levelStat struct {
	File           string `json:"file"`
	LevelID        int    `json:"level_id"`
	Solvable       bool   `json:"solvable"`
	Solver         string `json:"solver"`
	StatesExplored int    `json:"states_explored"`
	MaxStates      int    `json:"max_states"`
	TimeMs         int64  `json:"time_ms"`
	GaveUp         bool   `json:"gave_up"`
	Error          string `json:"error,omitempty"`
}

func summarizeValidationFile(out io.Writer, path string) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var arr []levelStat
	if err := json.Unmarshal(b, &arr); err != nil {
		return fmt.Errorf("failed to parse %s: %w", path, err)
	}
	if len(arr) == 0 {
		fmt.Fprintf(out, "%s: levels=0\n", path)
		return nil
	}

	solvers := map[string]int{}
	totalStates, maxStates := 0, 0
	var totalTime int64
	solved, gaveUp := 0, 0
	var unsolved []int
	for _, s := range arr {
		solvers[s.Solver]++
		totalStates += s.StatesExplored
		if s.StatesExplored > maxStates {
			maxStates = s.StatesExplored
		}
		totalTime += s.TimeMs
		if s.Solvable {
			solved++
		} else {
			unsolved = append(unsolved, s.LevelID)
		}
		if s.GaveUp {
			gaveUp++
		}
	}
	n := len(arr)
	names := make([]string, 0, len(solvers))
	for k := range solvers {
		names = append(names, k)
	}
	sort.Strings(names)
	solverStr := ""
	for i, k := range names {
		if i > 0 {
			solverStr += ","
		}
		solverStr += fmt.Sprintf("%s=%d", k, solvers[k])
	}
	sort.Ints(unsolved)
	fmt.Fprintf(out, "%s: levels=%d solvable=%d unsolvable=%v gave_up=%d avg_states=%.1f max_states=%d avg_time_ms=%.1f solvers={%s}\n",
		path, n, solved, unsolved, gaveUp,
		float64(totalStates)/float64(n), maxStates, float64(totalTime)/float64(n), solverStr)
	return nil
}

// batchLevelStat mirrors the per-level stats JSON written by batch runs.
type batchLevelStat struct {
	LevelID          int     `json:"level_id"`
	Difficulty       string  `json:"difficulty"`
	Strategy         string  `json:"strategy"`
	Coverage         float64 `json:"coverage"`
	PlayableCoverage float64 `json:"playable_coverage"`
	ComplexityScore  float64 `json:"complexity_score"`
	AvgVineLength    float64 `json:"avg_vine_length"`
	DistinctColors   int     `json:"distinct_colors"`
	VineCount        int     `json:"vine_count"`
	GenerationMS     int64   `json:"generation_ms"`
	MaxBlockingDepth int     `json:"max_blocking_depth"`
	AvgBlockingDepth float64 `json:"avg_blocking_depth"`
	DumpsProduced    int     `json:"dumps_produced"`
}

func summarizeBatchDir(out io.Writer, dir string) error {
	files, err := filepath.Glob(filepath.Join(dir, "level_*_stats.json"))
	if err != nil {
		return err
	}
	if len(files) == 0 {
		return fmt.Errorf("no level_*_stats.json files in %s", dir)
	}
	var totalGenMS int64
	var totalCoverage, minCoverage float64
	maxBlocking, totalDumps, totalVines := 0, 0, 0
	byDifficulty := map[string]int{}
	minCoverage = 100.0
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil {
			return fmt.Errorf("failed to read %s: %w", f, err)
		}
		var s batchLevelStat
		if err := json.Unmarshal(b, &s); err != nil {
			return fmt.Errorf("failed to parse %s: %w", f, err)
		}
		totalGenMS += s.GenerationMS
		totalCoverage += s.Coverage
		if s.Coverage < minCoverage {
			minCoverage = s.Coverage
		}
		if s.MaxBlockingDepth > maxBlocking {
			maxBlocking = s.MaxBlockingDepth
		}
		totalDumps += s.DumpsProduced
		totalVines += s.VineCount
		byDifficulty[s.Difficulty]++
	}
	n := float64(len(files))
	keys := make([]string, 0, len(byDifficulty))
	for k := range byDifficulty {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	fmt.Fprintf(out, "%s: levels=%d difficulties=%v avg_coverage=%.1f%% min_coverage=%.1f%% avg_vines=%.1f max_blocking=%d dumps=%d total_gen_ms=%d\n",
		dir, len(files), keys, totalCoverage/n, minCoverage, float64(totalVines)/n, maxBlocking, totalDumps, totalGenMS)
	return nil
}
