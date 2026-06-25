# PROMPT.md — AI Health & Life Assistant App

## Project Overview

I want to build an iPhone-first app that acts as a personal AI assistant for daily health, fitness, recovery, habits, and lifestyle tracking.

The goal is not to build a medical app, nor to replace doctors, coaches, or clinical advice. The goal is to create a practical personal assistant that helps the user organize and interpret their own daily data in a clearer way.

The app should eventually combine:

* calorie and meal assistance
* workout tracking and workout advice
* sleep tracking and sleep interpretation
* screen-time / habit awareness
* daily check-ins
* AI-generated summaries and recommendations
* possible integration with Apple Health / Apple Watch data

The core idea is that many existing apps are expensive, fragmented, and paywalled. This project should explore whether a lightweight AI-powered app can provide useful daily guidance at low cost, especially for personal use.

## Initial Philosophy

Start simple. Do not over-engineer.

The first version should be useful even if it only works locally or in a basic development environment.

Avoid building too many features at once. The app should grow through small, testable modules.

The first objective is to create a working MVP, not a perfect product.

## Target Platform

Primary target: iPhone / Apple ecosystem.

Preferred direction:

* iOS app if feasible
* Swift / SwiftUI if building natively
* Consider Apple Health / HealthKit integration later
* Apple Watch direct support is not required for the first MVP

If a different architecture is clearly better for early prototyping, explain the tradeoff first before implementing.

## Development Environment

This project will likely be developed using:

* Xcode
* Claude Code
* Codex
* GitHub
* possibly GitHub Copilot for Xcode
* SwiftFormat
* SwiftLint

The intended workflow is:

1. Claude Code helps with architecture, planning, and larger refactors.
2. Codex helps implement specific features.
3. Xcode is used to compile, test, and run the app.
4. GitHub is used for version control.
5. Copilot, if used, helps with smaller completions and local edits.

The project should be organized clearly so that AI agents can understand and modify it without creating chaos.

Preferred initial structure:

```text
Project/
├── docs/
│   ├── vision.md
│   ├── roadmap.md
│   ├── architecture.md
│
├── app/
│   ├── Health/
│   ├── Nutrition/
│   ├── Workout/
│   ├── Sleep/
│   ├── Habits/
│   ├── AI/
│
├── prompts/
│   ├── system.md
│   ├── feature_requests.md
│
├── tests/
│
└── journal/
```

The exact structure can be adjusted if there is a better iOS-native convention, but the principle should remain: clear separation between modules, data models, views, AI logic, and documentation.

## Code Quality Tools

Please consider adding or recommending:

### SwiftFormat

Use SwiftFormat to automatically format Swift code.

### SwiftLint

Use SwiftLint to catch style issues, common mistakes, and enforce consistency.

### GitHub Copilot for Xcode

Consider GitHub Copilot for Xcode if useful, but do not make the project dependent on it.

## Documentation and AI-Agent Workflow

This project should include internal documentation from the beginning.

Important files:

* `docs/vision.md`: what the app is trying to become
* `docs/roadmap.md`: staged development plan
* `docs/architecture.md`: architecture decisions and module structure
* `journal/`: development notes, decisions, and open questions
* `prompts/`: reusable prompts for AI-related features inside the app or for development

When making meaningful changes, update the relevant documentation.

AI agents should not silently make major architectural decisions. If a decision is important, explain the options and recommend one.

## Possible App Modules

The app may eventually include:

### 1. Meal / Calorie Assistant

The user can enter meals in natural language, for example:

> “I ate two ham and cheese sandwiches with mayo and iceberg lettuce.”

The app should estimate:

* calories
* protein
* carbs
* fat
* rough confidence level
* possible uncertainty due to portion size

Do not require photo input for the first version. Text input is the priority because it is cheaper, simpler, and more realistic for daily use.

### 2. Workout Assistant

The user can log workouts manually.

The app can track:

* exercises
* sets
* reps
* weight
* duration
* perceived effort
* workout type

The AI can help with:

* basic workout suggestions
* progressive overload reminders
* recovery-aware recommendations
* simple explanations

Avoid dangerous or extreme advice. Keep recommendations general, moderate, and safety-conscious.

### 3. Sleep Assistant

The user can manually enter sleep data at first:

* bedtime
* wake time
* perceived sleep quality
* naps
* tiredness level

Later, the app may integrate with Apple Health to read sleep data automatically.

Do not attempt to replicate Sleep Cycle-style sleep-stage detection in the first version. Smart alarms, microphone analysis, accelerometer sleep detection, and sleep-stage estimation are advanced features and should be treated as future research.

### 4. Daily Check-In

The app should allow a short daily check-in:

* energy
* mood
* hunger
* soreness
* focus
* screen-time feeling
* stress

The AI can generate a short daily summary:

> “You slept less than usual and trained yesterday, so today may be better suited for a lighter workout.”

### 5. Screen-Time / Habit Awareness

Explore whether iOS allows access to screen-time data through public APIs.

If direct screen-time access is restricted, use manual input or habit check-ins instead.

Do not assume Apple allows full access to screen-time data without verifying.

### 6. Apple Health / Watch Data

Future integration should explore HealthKit.

Potential data:

* steps
* workouts
* active energy
* sleep duration
* resting heart rate
* body weight
* heart-rate trends

The app should use Apple Health data only with explicit user permission.

The app should not treat HealthKit data as medical diagnosis. It should only provide general wellness interpretation.

## MVP Goal

The first MVP should probably include:

1. A simple home dashboard
2. A meal text input and calorie estimate screen
3. A workout log screen
4. A sleep/manual check-in screen
5. A daily AI summary screen
6. Local data persistence
7. Clear separation between app logic, data models, and AI calls

The MVP should work even before Apple Health integration.

## Cost Philosophy

The app should be designed to be cheap to run.

For personal use, the ideal target is:

* no paid server if possible
* local storage when possible
* AI API calls kept minimal
* one daily summary instead of constant AI calls
* small model / cheaper model where possible
* avoid expensive image recognition at first

Text-based AI features are preferred over image-based features for cost reasons.

## AI Usage Principles

Use AI where it adds real value:

* interpreting messy natural-language food logs
* summarizing the day
* connecting sleep, food, workout, and habits
* explaining patterns
* generating practical suggestions

Do not use AI unnecessarily for simple calculations or storage.

Where possible:

* parse structured data normally
* store user data locally
* call the AI only for interpretation, summarization, or ambiguous natural language

## Safety and Scope

This is not a medical device.

The app should avoid:

* medical diagnosis
* extreme dieting advice
* unsafe workout recommendations
* eating-disorder-like calorie restriction
* overconfident health claims
* pretending to know exact calories when portions are uncertain

Use language like:

* “rough estimate”
* “based on the information entered”
* “consider”
* “general wellness suggestion”

Avoid language like:

* “you must”
* “this is medically true”
* “guaranteed”

## Development Instructions

Before coding, inspect the current project structure.

If there is no project yet, propose a clean initial structure.

When making changes:

* explain the plan briefly
* implement in small steps
* keep files organized
* avoid unnecessary dependencies
* document important decisions
* keep the MVP simple
* do not silently add paid services
* do not hardcode API keys
* use environment variables or secure local config for API keys

## Early Technical Questions to Resolve

Please investigate and propose answers to:

1. Should this start as native SwiftUI or a cross-platform app?
2. What is the simplest way to store data locally?
3. What should the initial data model look like?
4. How should AI calls be abstracted so models can be switched later?
5. Can the app work fully locally except for AI calls?
6. What HealthKit integrations are realistic later?
7. What features should be postponed to avoid overbuilding?
8. What iOS APIs are available for screen-time or habit-related features?
9. What project structure will work best with Claude Code and Codex?
10. Should SwiftFormat and SwiftLint be configured from the beginning?

## First Deliverable

Do not build the whole app immediately.

First, produce a short technical feasibility note covering:

* recommended initial architecture
* suggested MVP scope
* estimated complexity by module
* likely ongoing costs for personal use
* risks / limitations, especially around Apple Health and screen-time APIs
* recommended development environment
* recommended code quality tools
* recommended first implementation step

After that, wait for approval before generating the actual project skeleton.
