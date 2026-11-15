package variety

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/metrics"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

var (
	varietyDir string
	enforce    bool
)

var varietyCmd = &cobra.Command{
	Use:   "variety",
	Short: "Report grid, length, mask, and free-vine shape for a level directory",
	Long: `Print a per-tier variety report for level JSON files.

The report is informational. The shipped corpus still uses the old
midpoint grids, so this command exits 0 unless --enforce is set.
--enforce applies the new-ladder contract and is for newly generated levels.`,
	RunE: runVariety,
}

func init() {
	varietyCmd.Flags().StringVar(&varietyDir, "dir", "", "directory of level_*.json files (default: the app levels directory)")
	varietyCmd.Flags().BoolVar(&enforce, "enforce", false, "exit non-zero when a level misses the new-ladder contract")
}

// GetCommand returns the variety command.
func GetCommand() *cobra.Command {
	return varietyCmd
}

func runVariety(cmd *cobra.Command, args []string) error {
	dir := varietyDir
	if dir == "" {
		resolved, err := common.LevelsDir()
		if err != nil {
			return err
		}
		dir = resolved
	}

	matches, err := filepath.Glob(filepath.Join(dir, "level_*.json"))
	if err != nil {
		return err
	}
	sort.Strings(matches)
	if len(matches) == 0 {
		return fmt.Errorf("no level_*.json files in %s", dir)
	}

	out := cmd.OutOrStdout()
	fmt.Fprintf(out, "Variety report for %s (%d levels)\n", dir, len(matches))
	if !enforce {
		fmt.Fprintln(out, "Informational only. Pass --enforce to apply the new-ladder contract.")
	}

	type tierSum struct {
		n        int
		vines    int
		length   float64
		short    float64
		mask     float64
		free     float64
		grids    map[[2]int]int
		failures int
	}
	sums := map[string]*tierSum{}
	order := []string{"Seedling", "Sprout", "Nurturing", "Flourishing", "Transcendent"}
	var failures int

	for _, path := range matches {
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var lvl model.Level
		if err := json.Unmarshal(data, &lvl); err != nil {
			return fmt.Errorf("%s: %w", filepath.Base(path), err)
		}
		q := metrics.AnalyzeQuality(lvl)
		tier := lvl.Difficulty
		if tier == "" {
			tier = "unknown"
		}
		sum := sums[tier]
		if sum == nil {
			sum = &tierSum{grids: map[[2]int]int{}}
			sums[tier] = sum
		}
		sum.n++
		sum.vines += q.VineCount
		sum.length += q.AvgVineLength
		sum.short += q.ShortVineShare
		sum.mask += q.MaskShare
		sum.free += q.FreeVineShare
		if len(lvl.GridSize) == 2 {
			sum.grids[[2]int{lvl.GridSize[0], lvl.GridSize[1]}]++
		}
		if enforce {
			if err := metrics.CheckContract(lvl, q); err != nil {
				failures++
				sum.failures++
				fmt.Fprintf(out, "  level %d: %v\n", lvl.ID, err)
			}
		}
	}

	fmt.Fprintln(out, "tier            n  grids  vines  avgLen  short  mask  free")
	for _, tier := range order {
		sum := sums[tier]
		if sum == nil || sum.n == 0 {
			continue
		}
		fmt.Fprintf(out, "%-14s %3d  %5d  %5.1f  %6.1f  %5.0f%% %5.1f%% %5.0f%%\n",
			tier, sum.n, len(sum.grids),
			float64(sum.vines)/float64(sum.n),
			sum.length/float64(sum.n),
			100*sum.short/float64(sum.n),
			100*sum.mask/float64(sum.n),
			100*sum.free/float64(sum.n),
		)
	}

	if enforce && failures > 0 {
		return fmt.Errorf("%d levels failed the new-ladder contract", failures)
	}
	return nil
}
