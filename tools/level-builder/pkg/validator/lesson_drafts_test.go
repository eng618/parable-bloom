package validator

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// Mirrors Dart LessonData.fromJson text constraints so drafts stay promotable.
const (
	maxTitleLength        = 80
	maxObjectiveLength    = 120
	maxInstructionsLength = 200
	maxLearningPointLen   = 80
	minLearningPoints     = 2
)

type draftLesson struct {
	model.Level
	Title          string   `json:"title"`
	Objective      string   `json:"objective"`
	Instructions   string   `json:"instructions"`
	LearningPoints []string `json:"learning_points"`
}

func headDelta(dir string) (int, int) { return directionDelta(dir) }

func TestLessonDrafts(t *testing.T) {
	files, err := filepath.Glob("../../test/fixtures/lesson_drafts/lesson_*.json")
	if err != nil {
		t.Fatalf("failed to glob drafts: %v", err)
	}
	if len(files) == 0 {
		t.Fatalf("no lesson drafts found")
	}

	for _, f := range files {
		name := filepath.Base(f)
		t.Run(name, func(t *testing.T) {
			b, err := os.ReadFile(f)
			if err != nil {
				t.Fatalf("failed to read draft: %v", err)
			}
			var d draftLesson
			if err := json.Unmarshal(b, &d); err != nil {
				t.Fatalf("failed to parse draft: %v", err)
			}

			// ID matches filename (lesson_N.json).
			var wantID int
			if _, err := fmt.Sscanf(name, "lesson_%d.json", &wantID); err != nil || wantID != d.ID {
				t.Fatalf("filename %s does not match ID %d", name, d.ID)
			}

			// Text constraints (Dart parity).
			if len(d.Title) == 0 || len(d.Title) > maxTitleLength {
				t.Errorf("title length %d out of 1..%d", len(d.Title), maxTitleLength)
			}
			if len(d.Objective) == 0 || len(d.Objective) > maxObjectiveLength {
				t.Errorf("objective length %d out of 1..%d", len(d.Objective), maxObjectiveLength)
			}
			if len(d.Instructions) == 0 || len(d.Instructions) > maxInstructionsLength {
				t.Errorf("instructions length %d out of 1..%d", len(d.Instructions), maxInstructionsLength)
			}
			if len(d.LearningPoints) < minLearningPoints {
				t.Errorf("need at least %d learning_points", minLearningPoints)
			}
			for _, p := range d.LearningPoints {
				if len(p) == 0 || len(p) > maxLearningPointLen {
					t.Errorf("learning_point length %d out of 1..%d", len(p), maxLearningPointLen)
				}
			}

			// Grid uses the unified [width, height] convention (Go model.Level
			// and Dart LessonData.fromJson agree since the transposition fix).
			if len(d.GridSize) != 2 || d.GridSize[0] < 2 || d.GridSize[1] < 2 {
				t.Fatalf("invalid grid size %v", d.GridSize)
			}
			w, h := d.GridSize[0], d.GridSize[1]
			seen := make(map[[2]int]string)
			for _, v := range d.Vines {
				if len(v.OrderedPath) < 2 {
					t.Errorf("vine %s shorter than 2 cells", v.ID)
				}
				for _, p := range v.OrderedPath {
					if p.X < 0 || p.X >= w || p.Y < 0 || p.Y >= h {
						t.Errorf("vine %s cell (%d,%d) out of bounds [%d,%d]", v.ID, p.X, p.Y, w, h)
					}
					key := [2]int{p.X, p.Y}
					if owner, dup := seen[key]; dup {
						t.Errorf("overlap at (%d,%d) between %s and %s", p.X, p.Y, owner, v.ID)
					}
					seen[key] = v.ID
				}
				// 4-connectivity + head/neck delta match.
				for i := 1; i < len(v.OrderedPath); i++ {
					dx := iabs(v.OrderedPath[i].X - v.OrderedPath[i-1].X)
					dy := iabs(v.OrderedPath[i].Y - v.OrderedPath[i-1].Y)
					if dx+dy != 1 {
						t.Errorf("vine %s not 4-connected at segment %d", v.ID, i)
					}
				}
				head, neck := v.OrderedPath[0], v.OrderedPath[1]
				ddx, ddy := headDelta(v.HeadDirection)
				if ddx == 0 && ddy == 0 {
					t.Errorf("vine %s has invalid head_direction %q", v.ID, v.HeadDirection)
				} else if neck.X-head.X == ddx && neck.Y-head.Y == ddy {
					// Head must move away from the body, not into it.
					t.Errorf("vine %s head points into its own neck", v.ID)
				}
			}

			if d.MaxMoves < 1 {
				t.Errorf("max_moves must be >= 1")
			}

			// Solvable (greedy is complete for current mechanics).
			lvl := d.Level
			solver := common.NewSolver(&lvl)
			if !solver.IsSolvableGreedy() {
				t.Errorf("draft lesson not greedy-solvable")
			}
		})
	}
}

func iabs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}
