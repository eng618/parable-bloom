package generator

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

const (
	AssetsDir   = "../../assets"
	LevelsDir   = AssetsDir + "/levels"
	DataDir     = AssetsDir + "/data"
	ModulesFile = DataDir + "/modules.json"
)

// Clean removes generated level and module files used by the level builder.
// It deletes all files matching "level_*.json" in LevelsDir and the ModulesFile.
// Only errors returned by filepath.Glob are propagated; errors from os.Remove
// for individual files (including ModulesFile) are ignored, so Clean returns
// nil unless the initial pattern match fails.
func Clean() error {
	files, err := filepath.Glob(filepath.Join(LevelsDir, "level_*.json"))
	if err != nil {
		return err
	}
	for _, f := range files {
		os.Remove(f)
	}
	os.Remove(ModulesFile)
	return nil
}

// Generate creates and writes `count` levels to disk and assembles them into modules.
//
// It ensures the LevelsDir and DataDir directories exist, then repeatedly calls
// generateLevel and writeLevel to produce level data. Levels are numbered starting
// at 1 (levelID = 1 + i) and are grouped into modules of 10 levels (levelsPerModule = 10):
// each 10th level is treated as the module's challenge level and closes the current module,
// while preceding levels are appended to the module's Levels slice. Module IDs start at 1.
// Progress is printed to stdout (including current working directory at start and a status
// message every 10 levels).
//
// After generation, a ModuleRegistry (Version "2.0", Tutorials [1,2,3]) is marshaled with
// indentation and written to ModulesFile. The function returns any error encountered while
// creating directories, generating or writing levels, marshaling the registry, or writing
// the modules file. Note: if `count` is not a multiple of 10, a partially filled current
// module will not be added to the Modules list.
func Generate(count int) error {
	cwd, _ := os.Getwd()
	fmt.Printf("Generating %d levels (CWD: %s)...\n", count, cwd)
	if err := os.MkdirAll(LevelsDir, 0755); err != nil {
		return err
	}
	if err := os.MkdirAll(DataDir, 0755); err != nil {
		return err
	}

	// Ensure absolute paths or correct relative paths
	// We are running from tools/level-builder usually

	modules := []model.Module{}
	levelsPerModule := 10

	currentModuleID := 1
	var currentModule *model.Module

	for i := 0; i < count; i++ {
		levelID := 1 + i
		isChallenge := (i+1)%levelsPerModule == 0

		lvl, err := generateLevel(levelID, isChallenge)
		if err != nil {
			return fmt.Errorf("failed to generate level %d: %w", levelID, err)
		}

		if err := writeLevel(lvl); err != nil {
			return err
		}

		if (i+1)%10 == 0 {
			fmt.Printf("Generated %d/%d levels...\n", i+1, count)
		}

		if currentModule == nil {
			currentModule = newModule(currentModuleID)
		}

		if !isChallenge {
			currentModule.Levels = append(currentModule.Levels, levelID)
		} else {
			currentModule.ChallengeLevel = levelID
			modules = append(modules, *currentModule)
			currentModule = nil
			currentModuleID++
		}
	}

	reg := model.ModuleRegistry{
		Version:   "2.0",
		Tutorials: []int{1, 2, 3},
		Modules:   modules,
	}

	bytes, err := json.MarshalIndent(reg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(ModulesFile, bytes, 0644)
}

func generateLevel(id int, isChallenge bool) (model.Level, error) {
	width, height := 6, 8
	if isChallenge {
		width, height = 7, 8
	} else if id > 20 {
		width, height = 6, 9
	}

	for attempt := 0; attempt < 500000; attempt++ {
		lvl, success := tryGenerate(id, width, height)
		if success {
			lvl.MinMoves = len(lvl.Vines)
			lvl.MaxMoves = int(float64(lvl.MinMoves) * 1.5)
			if lvl.MaxMoves < 5 {
				lvl.MaxMoves = 5
			}

			lvl.Name = fmt.Sprintf("Level %d", id)
			lvl.Difficulty = "Seedling"
			if len(lvl.Vines) > 10 {
				lvl.Difficulty = "Sprout"
			}
			lvl.Complexity = "medium"

			lvl.ColorScheme = generateColorScheme()
			assignColors(&lvl)

			return lvl, nil
		}
	}
	return model.Level{}, fmt.Errorf("failed to generate level %d after 10000 attempts", id)
}

func tryGenerate(id, width, height int) (model.Level, bool) {
	vines := []model.Vine{}
	grid := make([]bool, width*height)
	occupiedCount := 0
	totalCells := width * height

	inBounds := func(p model.Point) bool {
		return p.X >= 0 && p.X < width && p.Y >= 0 && p.Y < height
	}

	failures := 0

	for occupiedCount < totalCells {
		if failures > 500 {
			return model.Level{}, false
		}

		var starts []int
		for i, occ := range grid {
			if !occ {
				starts = append(starts, i)
			}
		}
		if len(starts) == 0 {
			break
		}

		startIdx := starts[rand.Intn(len(starts))]
		start := model.Point{X: startIdx % width, Y: startIdx / width}

		length := 2 + rand.Intn(4)
		if totalCells-occupiedCount < length {
			length = totalCells - occupiedCount
		}
		if length < 2 {
			length = 2
		}

		path := []model.Point{start}
		curr := start

		for len(path) < length {
			dirs := []model.Point{{X: 0, Y: 1}, {X: 0, Y: -1}, {X: 1, Y: 0}, {X: -1, Y: 0}}
			rand.Shuffle(len(dirs), func(i, j int) { dirs[i], dirs[j] = dirs[j], dirs[i] })

			moved := false
			for _, d := range dirs {
				next := model.Point{X: curr.X + d.X, Y: curr.Y + d.Y}
				if inBounds(next) && !grid[next.Y*width+next.X] && !contains(path, next) {
					path = append(path, next)
					curr = next
					moved = true
					break
				}
			}
			if !moved {
				break
			}
		}

		if len(path) < 2 {
			failures++
			continue
		}

		dx := path[0].X - path[1].X
		dy := path[0].Y - path[1].Y
		dir := ""
		if dx == 1 {
			dir = "right"
		} else if dx == -1 {
			dir = "left"
		} else if dy == 1 {
			dir = "up"
		} else if dy == -1 {
			dir = "down"
		}

		v := model.Vine{
			ID:            fmt.Sprintf("vine_%d", len(vines)+1),
			HeadDirection: dir,
			OrderedPath:   path,
		}

		if canExit(v, vines, width, height) {
			vines = append(vines, v)
			for _, p := range path {
				grid[p.Y*width+p.X] = true
				occupiedCount++
			}
			failures = 0

			if hasIsolatedHoles(grid, width, height) {
				return model.Level{}, false
			}
		} else {
			failures++
		}
	}

	if occupiedCount == totalCells {
		return model.Level{ID: id, GridSize: []int{width, height}, Vines: vines, Grace: 3}, true
	}
	return model.Level{}, false
}

func hasIsolatedHoles(grid []bool, w, h int) bool {
	visited := make([]bool, len(grid))
	for i := 0; i < len(grid); i++ {
		if !grid[i] && !visited[i] {
			size := 0
			q := []int{i}
			visited[i] = true
			size++
			for len(q) > 0 {
				curr := q[0]
				q = q[1:]
				cy := curr / w
				cx := curr % w
				dirs := []model.Point{{X: 0, Y: 1}, {X: 0, Y: -1}, {X: 1, Y: 0}, {X: -1, Y: 0}}
				for _, d := range dirs {
					nx, ny := cx+d.X, cy+d.Y
					if nx >= 0 && nx < w && ny >= 0 && ny < h {
						nidx := ny*w + nx
						if !grid[nidx] && !visited[nidx] {
							visited[nidx] = true
							size++
							q = append(q, nidx)
						}
					}
				}
			}
			if size < 2 {
				return true
			}
		}
	}
	return false
}

func canExit(v model.Vine, blockers []model.Vine, w, h int) bool {
	blockMap := make(map[model.Point]bool)
	for _, b := range blockers {
		for _, p := range b.OrderedPath {
			blockMap[p] = true
		}
	}
	currentPath := make([]model.Point, len(v.OrderedPath))
	copy(currentPath, v.OrderedPath)
	maxSteps := w + h + 10
	dx, dy := 0, 0
	switch v.HeadDirection {
	case "up":
		dy = 1
	case "down":
		dy = -1
	case "left":
		dx = -1
	case "right":
		dx = 1
	}
	for i := 0; i < maxSteps; i++ {
		newPath := make([]model.Point, len(currentPath))
		for j, p := range currentPath {
			newPath[j] = model.Point{X: p.X + dx, Y: p.Y + dy}
		}
		head := newPath[0]
		if head.X < 0 || head.X >= w || head.Y < 0 || head.Y >= h {
			return true
		}

		validMove := true
		for _, p := range newPath {
			if p.X < 0 || p.X >= w || p.Y < 0 || p.Y >= h {
				continue
			}
			if blockMap[p] {
				validMove = false
				break
			}
		}
		if !validMove {
			return false
		}
		currentPath = newPath
	}
	return false
}

func contains(path []model.Point, p model.Point) bool {
	for _, pp := range path {
		if pp == p {
			return true
		}
	}
	return false
}

func generateColorScheme() []string {
	return []string{"#7CB342", "#FF9800", "#FFC107", "#7C4DFF", "#29B6F6"}
}

func assignColors(lvl *model.Level) {
	for i := range lvl.Vines {
		lvl.Vines[i].ColorIndex = rand.Intn(len(lvl.ColorScheme))
	}
}

func writeLevel(lvl model.Level) error {
	bytes, err := json.MarshalIndent(lvl, "", "  ")
	if err != nil {
		return err
	}
	filename := filepath.Join(LevelsDir, fmt.Sprintf("level_%d.json", lvl.ID))
	return os.WriteFile(filename, bytes, 0644)
}

func newModule(id int) *model.Module {
	seeds := []string{"forest", "sunset", "ocean", "volcano", "lavender"}
	seed := seeds[(id-1)%len(seeds)]
	return &model.Module{
		ID:            id,
		Name:          fmt.Sprintf("Module %d", id),
		ThemeSeed:     seed,
		Levels:        []int{},
		UnlockMessage: "A new path opens...",
		Parable: model.Parable{
			Title:     "Placeholder Parable",
			Scripture: "Book 1:1",
			Content:   "Lorem ipsum...",
		},
	}
}
