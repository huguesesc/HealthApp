# Vision

## What this app is

A personal AI assistant for daily health, fitness, recovery, habits, and lifestyle.
It helps one person organise and interpret their own daily data more clearly. It is
explicitly **not** a medical app, a doctor, or a coach.

## What it eventually combines

- Calorie / meal assistance (natural-language text input)
- Workout tracking and light, safety-conscious advice
- Sleep tracking and interpretation (manual first; HealthKit later)
- Screen-time / habit awareness (threshold-based, see architecture.md)
- Short daily check-ins (energy, mood, soreness, focus, stress…)
- One AI-generated daily summary connecting the above
- Later: Apple Health / Apple Watch data (read-only, opt-in)

## Principles

- **Local-first.** All user data lives on-device. The network is touched only for
  AI interpretation.
- **Cheap to run.** One daily summary call by default; the smallest capable model;
  text over images.
- **Useful early.** Each version should be useful even if minimal.
- **Safe.** No diagnosis, no extreme diet/exercise advice. Hedged language only
  ("rough estimate", "consider", "general wellness suggestion").

## Non-goals (at least for now)

- Photo-based food recognition
- Sleep-stage detection, smart alarms, microphone/accelerometer analysis
- A standalone Apple Watch app
- Multi-user / accounts / cloud sync
