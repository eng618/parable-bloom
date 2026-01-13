package common

import (
	"fmt"
	"os"
)

var (
	// VerboseEnabled controls whether verbose output is shown
	VerboseEnabled = false
)

// Info prints a message to stdout (always shown, regardless of verbose mode)
func Info(format string, args ...interface{}) {
	fmt.Printf(format+"\n", args...)
}

// InfoNoNewline prints a message to stdout without a newline
func InfoNoNewline(format string, args ...interface{}) {
	fmt.Printf(format, args...)
}

// Verbose prints a message only when verbose mode is enabled
func Verbose(format string, args ...interface{}) {
	if VerboseEnabled {
		fmt.Printf("[VERBOSE] "+format+"\n", args...)
	}
}

// Debug is an alias for Verbose for semantic clarity in code
func Debug(format string, args ...interface{}) {
	Verbose(format, args...)
}

// Error prints an error message to stderr (always shown)
func Error(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
}

// Warning prints a warning message (always shown)
func Warning(format string, args ...interface{}) {
	fmt.Printf("WARNING: "+format+"\n", args...)
}
