package ui

import (
	"fmt"
	"time"

	"github.com/briandowns/spinner"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

// Spinner wraps github.com/briandowns/spinner to provide UX consistent with the level-builder.
type Spinner struct {
	s *spinner.Spinner
}

// NewSpinner creates a new spinner with a default configuration.
func NewSpinner(msg string) *Spinner {
	s := spinner.New(spinner.CharSets[14], 100*time.Millisecond)
	s.Suffix = " " + msg
	_ = s.Color("cyan", "bold") // Unchecked return value: s.Color returns error, but we ignore it here.
	return &Spinner{s: s}
}

// Start starts the spinner if verbose mode is disabled.
func (s *Spinner) Start() {
	if !common.VerboseEnabled {
		s.s.Start()
	}
}

// Stop stops the spinner.
func (s *Spinner) Stop() {
	s.s.Stop()
}

// UpdateMessage updates the spinner's suffix message.
func (s *Spinner) UpdateMessage(format string, args ...interface{}) {
	s.s.Suffix = " " + fmt.Sprintf(format, args...)
}

// LogInfo stops the spinner, prints an info message, and restarts the spinner.
// This prevents the spinner from "tearing" or leaving artifacts when messages are printed.
func (s *Spinner) LogInfo(format string, args ...interface{}) {
	wasRunning := s.s.Active()
	if wasRunning {
		s.s.Stop()
	}
	common.Info(format, args...)
	if wasRunning && !common.VerboseEnabled {
		s.s.Start()
	}
}

// LogWarning stops the spinner, prints a warning message, and restarts the spinner.
func (s *Spinner) LogWarning(format string, args ...interface{}) {
	wasRunning := s.s.Active()
	if wasRunning {
		s.s.Stop()
	}
	common.Warning(format, args...)
	if wasRunning && !common.VerboseEnabled {
		s.s.Start()
	}
}
