package utils

import (
	"math/rand"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func TestChooseExitDirectionIsStableForASeed(t *testing.T) {
	balance := map[string]float64{"left": 1, "right": 1, "up": 1, "down": 1}
	seed := model.Point{X: 3, Y: 4}
	grid := []int{8, 10}
	var first []string
	for run := 0; run < 2; run++ {
		rng := rand.New(rand.NewSource(99))
		var got []string
		for i := 0; i < 12; i++ {
			got = append(got, ChooseExitDirection(seed, grid, balance, rng))
		}
		if run == 0 {
			first = got
			continue
		}
		for i := range first {
			if got[i] != first[i] {
				t.Fatalf("run %d pick %d = %s, first run %s", run, i, got[i], first[i])
			}
		}
	}
}
