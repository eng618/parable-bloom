package validator

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func TestValidateLessonFile_RejectsSelfBlocking(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "lesson_99.json")

	lvl := model.Level{
		ID:       99,
		GridSize: []int{4, 3},
		Vines: []model.Vine{
			{
				ID:            "vine_loop",
				HeadDirection: "right",
				OrderedPath: []model.Point{
					{X: 1, Y: 1},
					{X: 0, Y: 1},
					{X: 0, Y: 2},
					{X: 1, Y: 2},
					{X: 2, Y: 2},
					{X: 2, Y: 1},
				},
			},
		},
		MaxMoves: 3,
	}
	raw, err := json.Marshal(lvl)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, raw, 0o644); err != nil {
		t.Fatal(err)
	}

	err = validateLessonFile(path)
	if err == nil {
		t.Fatal("expected validateLessonFile to reject self-blocking vine")
	}
	if !strings.Contains(err.Error(), "self-blocking") {
		t.Fatalf("expected self-blocking in error, got %v", err)
	}
}
