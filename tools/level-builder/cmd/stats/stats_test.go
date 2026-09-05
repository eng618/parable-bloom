package stats

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeJSON(t *testing.T, dir, name, content string) string {
	t.Helper()
	p := filepath.Join(dir, name)
	if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
		t.Fatalf("failed to write fixture: %v", err)
	}
	return p
}

func TestSummarizeValidationFile(t *testing.T) {
	dir := t.TempDir()
	p := writeJSON(t, dir, "validation_stats.json", `[
{"file":"level_1.json","level_id":1,"solvable":true,"solver":"greedy-fast","states_explored":0,"max_states":200000,"time_ms":1,"gave_up":false},
{"file":"level_2.json","level_id":2,"solvable":false,"solver":"heuristic","states_explored":200000,"max_states":200000,"time_ms":50,"gave_up":true}
]`)
	var buf bytes.Buffer
	if err := summarizeValidationFile(&buf, p); err != nil {
		t.Fatalf("summarize failed: %v", err)
	}
	out := buf.String()
	for _, want := range []string{"levels=2", "solvable=1", "unsolvable=[2]", "gave_up=1", "greedy-fast=1", "heuristic=1"} {
		if !strings.Contains(out, want) {
			t.Errorf("output missing %q:\n%s", want, out)
		}
	}
}

func TestSummarizeValidationFileEmpty(t *testing.T) {
	dir := t.TempDir()
	p := writeJSON(t, dir, "empty.json", `[]`)
	var buf bytes.Buffer
	if err := summarizeValidationFile(&buf, p); err != nil {
		t.Fatalf("summarize failed: %v", err)
	}
	if !strings.Contains(buf.String(), "levels=0") {
		t.Errorf("expected levels=0, got:\n%s", buf.String())
	}
}

func TestSummarizeBatchDir(t *testing.T) {
	dir := t.TempDir()
	writeJSON(t, dir, "level_1_stats.json", `{"level_id":1,"difficulty":"Seedling","strategy":"legacy-clearable","coverage":95.7,"playable_coverage":100.0,"vine_count":12,"generation_ms":100,"max_blocking_depth":3,"dumps_produced":0}`)
	writeJSON(t, dir, "level_2_stats.json", `{"level_id":2,"difficulty":"Seedling","strategy":"center-out","coverage":97.1,"playable_coverage":100.0,"vine_count":14,"generation_ms":200,"max_blocking_depth":5,"dumps_produced":1}`)
	var buf bytes.Buffer
	if err := summarizeBatchDir(&buf, dir); err != nil {
		t.Fatalf("summarize failed: %v", err)
	}
	out := buf.String()
	for _, want := range []string{"levels=2", "Seedling", "max_blocking=5", "dumps=1", "total_gen_ms=300"} {
		if !strings.Contains(out, want) {
			t.Errorf("output missing %q:\n%s", want, out)
		}
	}
}

func TestSummarizeBatchDirEmpty(t *testing.T) {
	var buf bytes.Buffer
	if err := summarizeBatchDir(&buf, t.TempDir()); err == nil {
		t.Fatalf("expected error for empty dir")
	}
}
