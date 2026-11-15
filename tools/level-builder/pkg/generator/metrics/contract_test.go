package metrics

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func contractVine(id, dir string, length, color, x, y int) model.Vine {
	dx, dy := 0, 0
	switch dir {
	case "right":
		dx = -1
	case "left":
		dx = 1
	case "up":
		dy = -1
	case "down":
		dy = 1
	}
	path := make([]model.Point, length)
	for i := range path {
		path[i] = model.Point{X: x + i*dx, Y: y + i*dy}
	}
	return model.Vine{ID: id, HeadDirection: dir, OrderedPath: path, ColorIndex: color}
}

func openingLevel() model.Level {
	vines := make([]model.Vine, 0, 15)
	dirs := []string{"right", "left", "up", "down"}
	for i := 0; i < 15; i++ {
		dir := dirs[i%4]
		length := 7
		if i == 0 {
			length = 9
		}
		if i == 1 {
			length = 8
		}
		x, y := 4, 6
		switch dir {
		case "right":
			x, y = 8, i%12
		case "left":
			x, y = 0, i%12
		case "up":
			x, y = i%9, 11
		case "down":
			x, y = i%9, 0
		}
		vines = append(vines, contractVine("vine", dir, length, i%5, x, y))
	}
	return model.Level{
		ID:         1,
		Difficulty: "Seedling",
		GridSize:   []int{9, 12},
		Vines:      vines,
		ColorScheme: []string{
			"#888888", "#7CB342", "#FF9800", "#FFC107", "#7C4DFF",
		},
	}
}

func TestCheckContractAcceptsOpeningSlot(t *testing.T) {
	lvl := openingLevel()
	q := AnalyzeQuality(lvl)
	if err := CheckContract(lvl, q); err != nil {
		t.Fatalf("opening slot rejected: %v (avg %.2f free %.0f%% short %.0f%% dirs r%d l%d u%d d%d)",
			err, q.AvgVineLength, q.FreeVineShare*100, q.ShortVineShare*100, q.DirRight, q.DirLeft, q.DirUp, q.DirDown)
	}
}

func TestCheckContractRejectsLateSlotThatIsAllFree(t *testing.T) {
	lvl := openingLevel()
	lvl.ID = 5
	lvl.GridSize = []int{12, 16}
	q := AnalyzeQuality(lvl)
	if err := CheckContract(lvl, q); err == nil {
		t.Fatal("expected slot 5 to reject a fully free board")
	}
}
