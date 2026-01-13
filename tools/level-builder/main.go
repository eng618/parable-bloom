package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

func main() {
	fmt.Println("Starting Level Builder...")
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	cmd := os.Args[1]
	switch cmd {
	case "clean":
		if err := generator.Clean(); err != nil {
			fmt.Printf("Error cleaning: %v\n", err)
			os.Exit(1)
		}
	case "generate":
		generateCmd := flag.NewFlagSet("generate", flag.ExitOnError)
		count := generateCmd.Int("count", 50, "Number of levels to generate")
		generateCmd.Parse(os.Args[2:])

		if err := generator.Generate(*count); err != nil {
			fmt.Printf("Error generating: %v\n", err)
			os.Exit(1)
		}
	case "validate":
		validateCmd := flag.NewFlagSet("validate", flag.ExitOnError)
		checkSolvable := validateCmd.Bool("check-solvable", false, "Run solvability checks using the Dart solver (may be slow)")
		maxStates := validateCmd.Int("max-states", 100000, "Max states for solver heuristic")
		validateCmd.Parse(os.Args[2:])

		if err := validator.Validate(*checkSolvable, *maxStates); err != nil {
			fmt.Printf("Validation error: %v\n", err)
			_ = os.WriteFile("validation.log", []byte(fmt.Sprintf("Validation error: %v\n", err)), 0644)
			os.Exit(1)
		}
	case "validate-tutorials":
		tutorialsCmd := flag.NewFlagSet("validate-tutorials", flag.ExitOnError)
		checkSolvableT := tutorialsCmd.Bool("check-solvable", false, "Also run solvability checks for lessons (may be slow)")
		maxStatesT := tutorialsCmd.Int("max-states", 100000, "Max states for solver heuristic")
		tutorialsCmd.Parse(os.Args[2:])

		if err := validator.ValidateTutorials(*checkSolvableT, *maxStatesT); err != nil {
			fmt.Printf("Lesson validation error: %v\n", err)
			_ = os.WriteFile("validation.log", []byte(fmt.Sprintf("Lesson validation error: %v\n", err)), 0644)
			os.Exit(1)
		}
	default:
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: level-builder <command> [args]")
	fmt.Println("Commands:")
	fmt.Println("  clean     Remove generated levels")
	fmt.Println("  generate  Generate levels (flags: --count)")
	fmt.Println("  validate  Validate existing levels (flags: --check-solvable --max-states)")
}
