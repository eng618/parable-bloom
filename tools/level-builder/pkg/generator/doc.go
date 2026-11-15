// Package generator builds puzzle levels for Parable Bloom.
//
// GenerateLevel is the entry point. It runs GenerateRobust:
//
//  1. Place vines with the strategy named on the config (a motif per tier slot).
//  2. Extend existing tails into empty cells while the greedy solver still passes.
//  3. Fill leftover gaps, keeping a prefix that stays inside the length band and the short-vine cap.
//  4. Extend again, absorb adjacent holes, and walk sealed pockets into bordering vines.
//     Mask whatever is still empty so playable coverage is 100%.
//  5. Assemble the level JSON.
//
// Batch generation accepts a level only when it also passes metrics.CheckContract:
// the scheduled grid, vine count, average length, short-vine share, mask share,
// head-direction balance, and free-vine share for that slot.
//
// The same seed produces the same level. math/rand is intentional. crypto/rand
// would drop that reproducibility.
package generator
