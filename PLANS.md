# Execution — Development milestones

Process in priority order; use AGENTS.md for the loop. These are proposed milestones, not claims of existing verified features.

- [ ] M0 Baseline: generate Xcode project; compile and run existing tests; inspect source, persistence and notifications. Establish reproducible verification. Fix blockers without unrelated rewrites.
- [ ] M1 Core: edit/reschedule commitments; explicit started/completed timestamps; overdue and on-time handling; cancellation/rescheduling of reminders; deterministic tests for lifecycle and time boundaries; accessible empty and error states. Measure actual time to start (do not silently equate completing a task with starting it in metrics). Add privacy-conscious notification options. Verify data survives relaunch.
- [ ] M2 Apple surfaces: shared app-group storage design and WidgetKit extension with Home/Lock Screen views; ActivityKit Live Activity for a user-selected active commitment with Dynamic Island compact/minimal/expanded presentations. Handle start, completion, deletion, expiry and stale activities; acknowledge system lifetime limits. Native red accents within Apple constraints. Test supported simulator behavior; document physical-device checks.
- [ ] M3 App Intents and StandBy: user-authorized create/start/complete actions with appropriate disambiguation; shortcut phrases and deep links; StandBy-compatible widget layouts. Test supported OS versions.
- [ ] M4 Design: refine red/white/black command center, typography and hierarchy; availability-gated native Liquid Glass, accessibility, Dynamic Type and contrast. Preserve logo placeholder until approved logo assets are available. Capture simulator screenshots when possible.
- [ ] M5 Reliability: add regression and UI smoke tests where feasible; verify notifications, storage migration, widget privacy, deadline math, and history. Document signing, entitlements, setup and remaining device-only validation. Prepare release-readiness checklist; no publishing.
- [ ] Later / excluded from unattended session: cloud sync, real accountability invitations and family sharing, monetization, external services, production deployment. Draft architecture only if all core work is done and time remains.

## Done
M0–M5 have evidence-backed completion or clearly documented blockers; working changes are checkpointed on a dedicated branch; BUILD_LOG.md records commands, outcomes, risks, and the next step. A missing simulator/SDK is not a passing build.
