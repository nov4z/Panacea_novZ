# E2E Test Infra: panacea-antigravity-notch

## Test Philosophy
- Opaque-box, requirement-driven derived strictly from `ORIGINAL_REQUEST.md`.
- No dependency on internal implementation details; tests verify behavior through executable interfaces, filesystem artifacts, IPC signals, and visual rendering checks.
- Systematic 4-tier methodology: Category-Partition, Boundary Value Analysis, Pairwise Combinatorial, and Real-World Workload Testing.

## Feature Inventory
| # | Feature | Source | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|--------|:------:|:------:|:------:|:------:|
| F1 | Detection Engine Daemon | R3 | 5 | 5 | ✓ | ✓ |
| F2 | Subagent Counter Detection | R3 | 5 | 5 | ✓ | ✓ |
| F3 | Quickshell Process Bridge | R3 | 5 | 5 | ✓ | ✓ |
| F4 | Authentic Logo Asset & Rendering | R1 | 5 | 5 | ✓ | ✓ |
| F5 | Fluid Infinite Animation | R1 | 5 | 5 | ✓ | ✓ |
| F6 | Calm Progress Wave ("Ola Tranquila") | R2 | 5 | 5 | ✓ | ✓ |
| F7 | Notch Accent Color Matching | R2 | 5 | 5 | ✓ | ✓ |
| F8 | Subagent Counter Display | R2 | 5 | 5 | ✓ | ✓ |
| F9 | Smooth Idle / Active Transitions | R2 | 5 | 5 | ✓ | ✓ |
| F10 | Media Layout Placement | R1, R2 | 5 | 5 | ✓ | ✓ |
| F11 | Idle Layout Placement | R1, R2 | 5 | 5 | ✓ | ✓ |
| F12 | Super + O Shortcut Toggle | R1 | 5 | 5 | ✓ | ✓ |
| F13 | Settings Persistence & IPC | R1 | 5 | 5 | ✓ | ✓ |
| F14 | Comprehensive E2E Test Suite | Acceptance Criteria | 5 | 5 | ✓ | ✓ |
| F15 | Live Visual Quality & Screenshot Verification | R4 | 5 | 5 | ✓ | ✓ |

## Test Architecture
- Test Runner: Python-based comprehensive runner located at `/home/nova/.config/panacea/tests/run_tests.py`
- Test Suites:
  - `tests/test_tier1_feature.py`: Feature coverage (5 tests per feature, >=75 tests)
  - `tests/test_tier2_boundary.py`: Boundary and corner cases (5 tests per feature, >=75 tests)
  - `tests/test_tier3_combinations.py`: Pairwise and interaction tests (>=15 tests)
  - `tests/test_tier4_scenarios.py`: End-to-end real-world user workflows and live system verification (>=8 tests)
- Exit Code: 0 on all tests passing, non-zero on failure.
- Status Output: Emits `TEST_READY.md` upon suite creation and passing verification.

## Coverage Thresholds
- Tier 1: >= 75 test cases (5 per feature across all 15 features)
- Tier 2: >= 75 test cases (boundary values, invalid configs, missing assets, zero/max subagents, process kills)
- Tier 3: >= 15 test cases (feature interactions, e.g., media change while subagents change, Super+O while active)
- Tier 4: >= 8 application-level scenario tests
- **Total Minimum: >= 173 test cases**
