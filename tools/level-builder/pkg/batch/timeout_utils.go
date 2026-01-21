package batch

// isTimeoutError checks if the error is related to circuit breaker timeout
func isTimeoutError(err error) bool {
    if err == nil {
        return false
    }
    // We look for the timeout messages generated in gen2.go
    msg := err.Error()
    return (len(msg) >= 7 && msg[:7] == "timeout") || 
           (len(msg) >= 12 && msg[:12] == "hard timeout") ||
           (len(msg) >= 25 && msg[:25] == "failed to generate solvable")
}
