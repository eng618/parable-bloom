package common

import (
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// TestCanVineClear_SimpleMovement tests basic vine clearance scenarios
func TestCanVineClear_SimpleMovement(t *testing.T) {
	tests := []struct {
		name     string
		level    model.Level
		vineID   string
		occupied map[string]bool
		want     bool
	}{
		{
			name: "Single cell vine moving right can clear",
			level: model.Level{
				GridSize: []int{5, 5},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 2, Y: 2},
						},
					},
				},
			},
			vineID: "v1",
			occupied: map[string]bool{
				"2,2": true,
			},
			want: true,
		},
		{
			name: "Two-segment vine moving right can clear",
			level: model.Level{
				GridSize: []int{5, 5},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 2, Y: 2}, // head
							{X: 1, Y: 2}, // tail
						},
					},
				},
			},
			vineID: "v1",
			occupied: map[string]bool{
				"2,2": true,
				"1,2": true,
			},
			want: true,
		},
		{
			name: "model.Vine blocked by another vine",
			level: model.Level{
				GridSize: []int{5, 5},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 2, Y: 2},
							{X: 1, Y: 2},
						},
					},
					{
						ID:            "v2",
						HeadDirection: "up",
						OrderedPath: []model.Point{
							{X: 3, Y: 2}, // blocks v1
							{X: 3, Y: 1},
						},
					},
				},
			},
			vineID: "v1",
			occupied: map[string]bool{
				"2,2": true,
				"1,2": true,
				"3,2": true,
				"3,1": true,
			},
			want: false,
		},
		{
			name: "Long vine can clear without self-collision",
			level: model.Level{
				GridSize: []int{6, 3},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 2, Y: 1},
							{X: 1, Y: 1},
							{X: 0, Y: 1},
							{X: 0, Y: 0},
							{X: 1, Y: 0},
						},
					},
				},
			},
			vineID: "v1",
			occupied: map[string]bool{
				"2,1": true,
				"1,1": true,
				"0,1": true,
				"0,0": true,
				"1,0": true,
			},
			want: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			solver := NewSolver(&tt.level)
			vine := &tt.level.Vines[0]
			got := solver.canVineClear(vine, tt.occupied)
			if got != tt.want {
				t.Errorf("canVineClear() = %v, want %v", got, tt.want)
			}
		})
	}
}

// TestIsSolvableGreedy_KnownConfigurations tests greedy solver with known results
func TestIsSolvableGreedy_KnownConfigurations(t *testing.T) {
	tests := []struct {
		name  string
		level model.Level
		want  bool
	}{
		{
			name: "Empty grid is solvable",
			level: model.Level{
				GridSize: []int{5, 5},
				Vines:    []model.Vine{},
			},
			want: true,
		},
		{
			name: "Single vine moving away is solvable",
			level: model.Level{
				GridSize: []int{5, 5},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 2, Y: 2},
							{X: 1, Y: 2},
						},
					},
				},
			},
			want: true,
		},
		{
			name: "Two independent vines are solvable",
			level: model.Level{
				GridSize: []int{5, 5},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 1, Y: 1},
							{X: 0, Y: 1},
						},
					},
					{
						ID:            "v2",
						HeadDirection: "up",
						OrderedPath: []model.Point{
							{X: 3, Y: 1},
							{X: 3, Y: 0},
						},
					},
				},
			},
			want: true,
		},
		{
			name: "Simple blocking scenario - v1 must clear first",
			level: model.Level{
				GridSize: []int{5, 5},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 2, Y: 2},
							{X: 1, Y: 2},
						},
					},
					{
						ID:            "v2",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 0, Y: 2}, // head at v1's tail position
							{X: 0, Y: 1},
						},
					},
				},
			},
			want: true,
		},
		{
			name: "Circular deadlock - two vines block each other",
			level: model.Level{
				GridSize: []int{4, 4},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 1, Y: 2},
							{X: 0, Y: 2},
						},
					},
					{
						ID:            "v2",
						HeadDirection: "left",
						OrderedPath: []model.Point{
							{X: 2, Y: 2},
							{X: 3, Y: 2},
						},
					},
				},
			},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			solver := NewSolver(&tt.level)
			got := solver.IsSolvableGreedy()
			if got != tt.want {
				t.Errorf("IsSolvableGreedy() = %v, want %v", got, tt.want)
			}
		})
	}
}

// TestIsSolvableBFS_ComplexScenarios tests BFS solver with complex configurations
func TestIsSolvableBFS_ComplexScenarios(t *testing.T) {
	tests := []struct {
		name  string
		level model.Level
		want  bool
	}{
		{
			name: "Empty grid is solvable",
			level: model.Level{
				GridSize: []int{5, 5},
				Vines:    []model.Vine{},
			},
			want: true,
		},
		{
			name: "Three independent vines are solvable",
			level: model.Level{
				GridSize: []int{7, 7},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 1, Y: 1},
							{X: 0, Y: 1},
						},
					},
					{
						ID:            "v2",
						HeadDirection: "up",
						OrderedPath: []model.Point{
							{X: 3, Y: 1},
							{X: 3, Y: 0},
						},
					},
					{
						ID:            "v3",
						HeadDirection: "left",
						OrderedPath: []model.Point{
							{X: 6, Y: 3},
							{X: 6, Y: 2},
						},
					},
				},
			},
			want: true,
		},
		{
			name: "Impossible configuration - three-way deadlock",
			level: model.Level{
				GridSize: []int{4, 4},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []model.Point{
							{X: 1, Y: 1},
							{X: 0, Y: 1},
						},
					},
					{
						ID:            "v2",
						HeadDirection: "down",
						OrderedPath: []model.Point{
							{X: 2, Y: 2},
							{X: 2, Y: 3},
						},
					},
					{
						ID:            "v3",
						HeadDirection: "left",
						OrderedPath: []model.Point{
							{X: 2, Y: 1}, // blocks v1
							{X: 3, Y: 1},
						},
					},
				},
			},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			solver := NewSolver(&tt.level)
			got := solver.IsSolvableBFS()
			if got != tt.want {
				t.Errorf("IsSolvableBFS() = %v, want %v", got, tt.want)
			}
		})
	}
}

// TestSolverAgreement tests that greedy and BFS solvers agree on simple cases
func TestSolverAgreement(t *testing.T) {
	tests := []struct {
		name  string
		level model.Level
	}{
		{
			name: "Single vine",
			level: model.Level{
				GridSize: []int{5, 5},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath:   []model.Point{{X: 2, Y: 2}, {X: 1, Y: 2}},
					},
				},
			},
		},
		{
			name: "Two independent vines",
			level: model.Level{
				GridSize: []int{5, 5},
				Vines: []model.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath:   []model.Point{{X: 1, Y: 1}, {X: 0, Y: 1}},
					},
					{
						ID:            "v2",
						HeadDirection: "up",
						OrderedPath:   []model.Point{{X: 3, Y: 1}, {X: 3, Y: 0}},
					},
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			solver := NewSolver(&tt.level)
			greedy := solver.IsSolvableGreedy()
			bfs := solver.IsSolvableBFS()
			if greedy != bfs {
				t.Errorf("Solvers disagree: Greedy=%v, BFS=%v", greedy, bfs)
			}
		})
	}
}

// Benchmark tests
func BenchmarkIsSolvableGreedy_Simple(b *testing.B) {
	level := model.Level{
		GridSize: []int{7, 7},
		Vines: []model.Vine{
			{ID: "v1", HeadDirection: "right", OrderedPath: []model.Point{{X: 3, Y: 3}, {X: 2, Y: 3}}},
			{ID: "v2", HeadDirection: "up", OrderedPath: []model.Point{{X: 4, Y: 2}, {X: 4, Y: 1}}},
		},
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		solver := NewSolver(&level)
		_ = solver.IsSolvableGreedy()
	}
}

func BenchmarkIsSolvableBFS_Complex(b *testing.B) {
	level := model.Level{
		GridSize: []int{8, 8},
		Vines: []model.Vine{
			{ID: "v1", HeadDirection: "right", OrderedPath: []model.Point{{X: 2, Y: 3}, {X: 1, Y: 3}}},
			{ID: "v2", HeadDirection: "up", OrderedPath: []model.Point{{X: 5, Y: 2}, {X: 5, Y: 1}}},
			{ID: "v3", HeadDirection: "left", OrderedPath: []model.Point{{X: 3, Y: 3}, {X: 4, Y: 3}}},
			{ID: "v4", HeadDirection: "down", OrderedPath: []model.Point{{X: 3, Y: 5}, {X: 3, Y: 6}}},
		},
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		solver := NewSolver(&level)
		_ = solver.IsSolvableBFS()
	}
}
