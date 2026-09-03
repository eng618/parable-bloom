# Circuit Breaker Orchestration

Purpose

- Coordinate fallback strategies and avoid unbounded generation time by tracking attempts and applying progressive relaxations.

Behavior

- Maintain state: number of attempts, structural success rate, elapsed time.
- On threshold breaches (timeouts or low success rates) escalate policies:
  - Increase backtrack depth
  - Lower target coverage slightly
  - Switch to solver-driven fallback (CP/SAT) for stubborn seeds

Testing

- Simulation tests that drive the circuit breaker through states and assert correct policy transitions.
