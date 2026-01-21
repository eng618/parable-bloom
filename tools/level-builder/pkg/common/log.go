package common

import (
	"fmt"
	"os"
)

var (
	// VerboseEnabled controls whether verbose output is shown
	VerboseEnabled = false
	// LogFile is the path to write logs to (empty means stdout only)
	LogFile = ""
)

// writeToLogFile writes a message to the log file if LogFile is set
func writeToLogFile(message string) {
	if LogFile != "" {
		file, err := os.OpenFile(LogFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err == nil {
			defer file.Close()
			fmt.Fprintln(file, message)
		}
	}
}

// Info prints a message to stdout (always shown, regardless of verbose mode)
func Info(format string, args ...interface{}) {
	message := fmt.Sprintf(format, args...)
	fmt.Println(message)
	writeToLogFile(message)
}

// InfoNoNewline prints a message to stdout without a newline
func InfoNoNewline(format string, args ...interface{}) {
	message := fmt.Sprintf(format, args...)
	fmt.Print(message)
	writeToLogFile(message)
}

// Verbose prints a message only when verbose mode is enabled
func Verbose(format string, args ...interface{}) {
	if VerboseEnabled {
		message := fmt.Sprintf("[VERBOSE] "+format, args...)
		fmt.Println(message)
		writeToLogFile(message)
	}
}

// Debug is an alias for Verbose for semantic clarity in code
func Debug(format string, args ...interface{}) {
	Verbose(format, args...)
}

// Error prints an error message to stderr (always shown)
func Error(format string, args ...interface{}) {
	message := fmt.Sprintf("ERROR: "+format, args...)
	fmt.Fprintln(os.Stderr, message)
	writeToLogFile(message)
}

// Warning prints a warning message (always shown)
func Warning(format string, args ...interface{}) {
	message := fmt.Sprintf("WARNING: "+format, args...)
	fmt.Println(message)
	writeToLogFile(message)
}
