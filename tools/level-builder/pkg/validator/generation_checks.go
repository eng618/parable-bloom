package validator

import "github.com/eng618/parable-bloom/tools/level-builder/pkg/model"

// ValidateDesignConstraints runs the structural and coverage checks that the generator
// must satisfy before writing a level. It mirrors the validator's runtime checks
// so generation failures become early diagnostics.
func ValidateDesignConstraints(lvl model.Level) []error {
	var errors []error

	if err := checkOccupancyAndCoverage(lvl, false); err != nil {
		errors = append(errors, err)
	}

	if structuralErrors := ValidateStructural(lvl); len(structuralErrors) > 0 {
		errors = append(errors, structuralErrors...)
	}

	return errors
}
