# Firestore Data Model

**STATUS: DRAFT** — finalize under HIT-010; implement access via HIT-079.

## Principles

- Minimal collections
- Curriculum stays in local JSON (not Firestore)
- No user audio in Firestore
- Users may only access their own paths (HIT-011 security rules)

## Proposed shape

```text
users/{uid}
  displayName: string
  email: string
  createdAt: timestamp
  currentProgramDay: number
  totalTrainingMinutes: number
  currentStreak: number
  longestStreak: number
  lastTrainingDate: string (yyyy-MM-dd local calendar day) | timestamp (decide in HIT-010)

users/{uid}/trainingHistory/{historyId}
  trainingDate: string
  programDay: number
  completedExerciseIds: string[]
  durationMinutes: number
  completedAt: timestamp

users/{uid}/exerciseProgress/{exerciseId}
  exerciseId: string
  completionCount: number
  lastCompletedAt: timestamp

users/{uid}/preferences/settings
  reminderEnabled: bool
  reminderTime: string (HH:mm)
  soundEnabled: bool
  hapticEnabled: bool
```

Exact field types and timezone strategy are owned by HIT-010 + HIT-054.
