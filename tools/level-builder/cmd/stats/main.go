package main

import (
	"encoding/json"
	"fmt"
	"os"
)

type Stat struct {
	File           string `json:"file"`
	LevelID        int    `json:"level_id"`
	StatesExplored int    `json:"states_explored"`
	TimeMs         int64  `json:"time_ms"`
}

func summarize(path string) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var arr []Stat
	if err := json.Unmarshal(b, &arr); err != nil {
		return err
	}
	totalStates := 0
	maxStates := 0
	totalTime := int64(0)
	for _, s := range arr {
		totalStates += s.StatesExplored
		if s.StatesExplored > maxStates {
			maxStates = s.StatesExplored
		}
		totalTime += s.TimeMs
	}
	n := len(arr)
	fmt.Printf("%s: levels=%d avg_states=%.1f max_states=%d avg_time_ms=%.1f\n", path, n, float64(totalStates)/float64(n), maxStates, float64(totalTime)/float64(n))
	return nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: stats <file1> [file2 ...]")
		os.Exit(1)
	}
	for _, p := range os.Args[1:] {
		if err := summarize(p); err != nil {
			fmt.Printf("error summarizing %s: %v\n", p, err)
		}
	}
}
