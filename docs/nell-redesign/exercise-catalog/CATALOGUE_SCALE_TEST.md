# Catalogue scale test

Date: 2026-08-23 · Host: Windows (Python 3.12.10) · Method: synthetic
authoring fixtures through `exercise_catalog.validate_catalogue(strict=True)`
plus a permanent regression test
(`test_scale_synthetic_catalogue_of_one_thousand_stays_deterministic`).

No synthetic exercises exist in production data; everything was generated in
temporary directories.

## Validator timings

| Exercises | Name claims (display + aliases) | Strict validate wall time | Errors |
|---|---|---|---|
| 100 | 300 | 0.012 s | 0 |
| 1,000 | 5,000 | 0.053 s | 0 |
| 2,000 | 12,000 | 0.075 s | 0 |

Growth from 300 → 12,000 claims (40×) costs 0.012 s → 0.075 s (~6×): the
collision namespace and reference checks are effectively linear with no
accidental O(n²) behavior at realistic future scale.

The committed scale test also proves correctness at 1,000 entries: zero false
positives on clean data, and an injected duplicate ID is still isolated by
`E_EXERCISE_DUPLICATE` among thousands of valid records.

## Swift-side expectation

Runtime resolution uses O(1) dictionary indexes built once per load
(`ExerciseCatalogIndex`, `LegacyExerciseResolver`), so lookup cost is
constant regardless of catalogue size; only load-time indexing is O(n).
That structure is covered by existing loading tests; a large-fixture decode
timing belongs to the Mac/CI session if it is ever needed.

## Conclusion

Adding the 51st through the 1,000th exercise is a data problem, not a code
problem: one JSON entry plus optional media rows, validated in well under a
second at any near-term scale.
