# Task 06 — Profile, Settings, Onboarding, and Visual QA

## Goal

Finish the product shell, clarify first use, and verify the redesign without weakening privacy or health-safety communication.

## Profile and settings

Settings remains configuration-focused:

- profile and goals
- movement considerations
- equipment and locations
- Apple Health
- Coach connection
- appearance
- privacy and data
- About Nell

No mascot in deletion, permission, or privacy-control flows.

## First-run onboarding

Proposed sequence:

1. Welcome to Nell
2. What would you like help with?
3. Training context and preferences
4. User-reported movement considerations
5. Apple Health, optional
6. Coach connection, optional

The user can skip optional integrations and use manual local features.

## Product naming

Visible copy changes to:

- `Nell`
- `Your personal health companion`

Keep project and module names unchanged during this feature.

## Visual QA matrix

Test:

- light mode
- dark mode
- smallest supported iPhone
- large iPhone
- iPad only if it remains an intentional target
- Dynamic Type at accessibility sizes
- VoiceOver labels
- Reduce Motion
- keyboard-open states
- empty data
- realistic populated data
- no API key
- offline/network failure
- Apple Health denied and empty

## Documentation outputs

- implementation notes per task
- asset manifest
- screen-to-concept mapping
- known deviations
- physical-device test checklist

## Acceptance criteria

- First launch is understandable without prior explanation.
- Optional services are clearly optional.
- The product name is consistent across visible UI.
- Privacy and serious health states remain restrained.
- No unfinished Screen Time or placeholder functionality is exposed in the primary flow.
- The branch is not merged until a physical-device build and regression pass succeeds.
