// Firestore security rules, run against the emulator (HIT-011).
//
// Run with `npm test` from this directory. It starts the Firestore emulator,
// runs these tests, and stops it. See docs/architecture/FIRESTORE_MODEL.md.
//
// The project id starts with "demo-", which makes the emulator refuse to talk
// to any real project. Nothing here can reach production data.

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-hitup',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const anonymous = () => env.unauthenticatedContext().firestore();

/** Writes directly, bypassing the rules, to set up a starting state. */
const seed = (path, data) =>
  env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));

const aPastTime = () => Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));

const validUser = (overrides = {}) => ({
  displayName: 'Alice',
  email: 'alice@example.com',
  createdAt: serverTimestamp(),
  currentProgramDay: 1,
  totalTrainingMinutes: 0,
  currentStreak: 0,
  longestStreak: 0,
  ...overrides,
});

/** A user document as it sits in the database once created. */
const storedUser = (overrides = {}) => validUser({ createdAt: aPastTime(), ...overrides });

const validHistory = (overrides = {}) => ({
  trainingDate: '2026-09-14',
  programDay: 1,
  completedExerciseIds: ['breathing_diaphragm_01'],
  durationMinutes: 15,
  completedAt: serverTimestamp(),
  ...overrides,
});

const validProgress = (overrides = {}) => ({
  exerciseId: 'ex1',
  completionCount: 1,
  lastCompletedAt: serverTimestamp(),
  ...overrides,
});

describe('unauthenticated access is denied', () => {
  test('cannot read a user document', async () => {
    await seed('users/alice', { createdAt: aPastTime() });
    await assertFails(getDoc(doc(anonymous(), 'users/alice')));
  });

  test('cannot create a user document', async () => {
    await assertFails(setDoc(doc(anonymous(), 'users/alice'), validUser()));
  });

  test('cannot read or write anything outside users/', async () => {
    await assertFails(getDoc(doc(anonymous(), 'curriculum/day1')));
    await assertFails(setDoc(doc(anonymous(), 'curriculum/day1'), { a: 1 }));
  });
});

describe("an authenticated user cannot touch another user's data", () => {
  test("cannot read another user's document", async () => {
    await seed('users/alice', { createdAt: aPastTime() });
    await assertFails(getDoc(doc(bob(), 'users/alice')));
  });

  test("cannot create or overwrite another user's document", async () => {
    await assertFails(setDoc(doc(bob(), 'users/alice'), validUser()));
  });

  test("cannot overwrite another user's existing document", async () => {
    // The test above writes to an empty path, so it only reaches the create
    // rule. With a document already there, the same write reaches update.
    await seed('users/alice', storedUser());
    await assertFails(
      setDoc(doc(bob(), 'users/alice'), storedUser({ currentStreak: 1, longestStreak: 1 })),
    );
  });

  test("cannot delete another user's document", async () => {
    await seed('users/alice', { createdAt: aPastTime() });
    await assertFails(deleteDoc(doc(bob(), 'users/alice')));
  });

  test("cannot read or write another user's training history", async () => {
    await seed('users/alice/trainingHistory/2026-09-14', { programDay: 1 });
    await assertFails(getDoc(doc(bob(), 'users/alice/trainingHistory/2026-09-14')));
    await assertFails(setDoc(doc(bob(), 'users/alice/trainingHistory/2026-09-15'), validHistory()));
  });

  test("cannot delete another user's training history entry", async () => {
    await seed('users/alice/trainingHistory/2026-09-14', { programDay: 1 });
    await assertFails(deleteDoc(doc(bob(), 'users/alice/trainingHistory/2026-09-14')));
  });

  test("cannot read or delete another user's exercise progress", async () => {
    await seed('users/alice/exerciseProgress/ex1', validProgress({ lastCompletedAt: aPastTime() }));
    await assertFails(getDoc(doc(bob(), 'users/alice/exerciseProgress/ex1')));
    await assertFails(deleteDoc(doc(bob(), 'users/alice/exerciseProgress/ex1')));
  });

  test("cannot create or overwrite another user's exercise progress", async () => {
    await assertFails(setDoc(doc(bob(), 'users/alice/exerciseProgress/ex1'), validProgress()));
    await seed(
      'users/alice/exerciseProgress/ex2',
      validProgress({ exerciseId: 'ex2', completionCount: 5, lastCompletedAt: aPastTime() }),
    );
    await assertFails(
      setDoc(
        doc(bob(), 'users/alice/exerciseProgress/ex2'),
        validProgress({ exerciseId: 'ex2', completionCount: 6 }),
      ),
    );
  });

  test("cannot read or write another user's preferences", async () => {
    await seed('users/alice/preferences/settings', { soundEnabled: true });
    await assertFails(getDoc(doc(bob(), 'users/alice/preferences/settings')));
    await assertFails(
      setDoc(doc(bob(), 'users/alice/preferences/settings'), { soundEnabled: false }),
    );
  });

  test('a signed-in user still cannot write outside users/', async () => {
    await assertFails(setDoc(doc(alice(), 'curriculum/day1'), { a: 1 }));
  });
});

describe('user document', () => {
  test('the owner can create it with the server time as createdAt', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice'), validUser()));
  });

  test('the owner can read and delete it', async () => {
    await seed('users/alice', { createdAt: aPastTime() });
    await assertSucceeds(getDoc(doc(alice(), 'users/alice')));
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice')));
  });

  test('createdAt cannot be chosen by the client on create', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ createdAt: aPastTime() })));
  });

  test('createdAt cannot change on update', async () => {
    await seed('users/alice', { createdAt: aPastTime(), currentStreak: 0, longestStreak: 0 });
    await assertSucceeds(updateDoc(doc(alice(), 'users/alice'), { currentStreak: 1, longestStreak: 1 }));
    await assertFails(updateDoc(doc(alice(), 'users/alice'), { createdAt: serverTimestamp() }));
  });

  test('a field outside the model is refused', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ isAdmin: true })));
  });

  test('a field outside the model is refused on update too', async () => {
    await seed('users/alice', storedUser());
    await assertFails(updateDoc(doc(alice(), 'users/alice'), { isAdmin: true }));
  });

  test('displayName and email must be strings within their length limits', async () => {
    await assertSucceeds(
      setDoc(
        doc(alice(), 'users/alice'),
        validUser({ displayName: 'a'.repeat(100), email: 'a'.repeat(254) }),
      ),
    );
    await env.clearFirestore();
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ displayName: 'a'.repeat(101) })));
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ displayName: ['Alice'] })));
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ email: 'a'.repeat(255) })));
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ email: ['alice@example.com'] })));
  });

  test('a negative counter is refused', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ currentStreak: -1 })));
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ totalTrainingMinutes: -5 })));
  });

  test('a fractional counter is refused', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ currentProgramDay: 1.5 })));
  });

  test('a fractional longest streak is refused', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ longestStreak: 2.5 })));
  });

  test('a current streak longer than the longest is refused', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice'), validUser({ currentStreak: 5, longestStreak: 3 })),
    );
  });

  test('lastTrainingDate is a yyyy-MM-dd day, or absent', async () => {
    // HIT-010 settled the type: the user's own calendar day, so the streak can
    // compare days without carrying a timezone. Absent means never trained.
    await assertSucceeds(
      setDoc(doc(alice(), 'users/alice'), validUser({ lastTrainingDate: '2026-09-14' })),
    );
    await env.clearFirestore();
    await assertSucceeds(setDoc(doc(alice(), 'users/alice'), validUser()));
  });

  test('lastTrainingDate refuses a timestamp, a null and a malformed day', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice'), validUser({ lastTrainingDate: aPastTime() })),
    );
    await assertFails(
      setDoc(doc(alice(), 'users/alice'), validUser({ lastTrainingDate: null })),
    );
    await assertFails(
      setDoc(doc(alice(), 'users/alice'), validUser({ lastTrainingDate: '14.09.2026' })),
    );
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ lastTrainingDate: 20260914 })));
  });
});

describe('training history is append-only', () => {
  test('the owner can append an entry stamped with the server time', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/trainingHistory/2026-09-14'), validHistory()));
  });

  test('an entry cannot be backdated', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/trainingHistory/2026-09-14'), validHistory({ completedAt: aPastTime() })),
    );
  });

  test('an existing entry cannot be edited', async () => {
    await seed('users/alice/trainingHistory/2026-09-14', {
      trainingDate: '2026-09-14',
      programDay: 1,
      completedExerciseIds: ['breathing_diaphragm_01'],
      durationMinutes: 15,
      completedAt: aPastTime(),
    });
    await assertFails(updateDoc(doc(alice(), 'users/alice/trainingHistory/2026-09-14'), { durationMinutes: 90 }));
  });

  test('the owner can delete their own entry', async () => {
    await seed('users/alice/trainingHistory/2026-09-14', { programDay: 1 });
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice/trainingHistory/2026-09-14')));
  });

  test('the document id must be the training date', async () => {
    // One day, one entry. The repository (HIT-079) writes the day as the id,
    // and a second completion of that day is then refused rather than filed
    // under a new id with its minutes counted again.
    await assertSucceeds(
      setDoc(doc(alice(), 'users/alice/trainingHistory/2026-09-14'), validHistory()),
    );
    await assertFails(
      setDoc(doc(alice(), 'users/alice/trainingHistory/2026-09-15'), validHistory()),
    );
    await assertFails(
      setDoc(doc(alice(), 'users/alice/trainingHistory/h1'), validHistory()),
    );
  });

  test('a malformed training date is refused', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/trainingHistory/2026-09-14'), validHistory({ trainingDate: '14.09.2026' })),
    );
  });

  test('a session with no completed exercises is refused', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/trainingHistory/2026-09-14'), validHistory({ completedExerciseIds: [] })),
    );
  });

  test('a missing required field is refused', async () => {
    const { programDay, ...withoutDay } = validHistory();
    await assertFails(setDoc(doc(alice(), 'users/alice/trainingHistory/2026-09-14'), withoutDay));
  });

  test('an entry with a field outside the model is refused', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/trainingHistory/2026-09-14'), validHistory({ verified: true })),
    );
  });

  test('programDay must be a whole number of at least one', async () => {
    const path = 'users/alice/trainingHistory/2026-09-14';
    await assertFails(setDoc(doc(alice(), path), validHistory({ programDay: 0 })));
    await assertFails(setDoc(doc(alice(), path), validHistory({ programDay: 1.5 })));
  });

  test('completedExerciseIds must be a list of at most 50', async () => {
    const path = 'users/alice/trainingHistory/2026-09-14';
    const ids = (n) => Array.from({ length: n }, (_, i) => `exercise_${i}`);
    await assertFails(
      setDoc(doc(alice(), path), validHistory({ completedExerciseIds: 'breathing_diaphragm_01' })),
    );
    await assertFails(setDoc(doc(alice(), path), validHistory({ completedExerciseIds: ids(51) })));
    await assertSucceeds(setDoc(doc(alice(), path), validHistory({ completedExerciseIds: ids(50) })));
  });

  test('durationMinutes must be a whole number from 0 to 1440', async () => {
    const path = 'users/alice/trainingHistory/2026-09-14';
    await assertFails(setDoc(doc(alice(), path), validHistory({ durationMinutes: -1 })));
    await assertFails(setDoc(doc(alice(), path), validHistory({ durationMinutes: 1441 })));
    await assertSucceeds(setDoc(doc(alice(), path), validHistory({ durationMinutes: 1440 })));
  });
});

describe('exercise progress', () => {
  test('the document id must match the exerciseId field', async () => {
    const data = { completionCount: 1, lastCompletedAt: serverTimestamp() };
    await assertSucceeds(
      setDoc(doc(alice(), 'users/alice/exerciseProgress/ex1'), { exerciseId: 'ex1', ...data }),
    );
    await assertFails(
      setDoc(doc(alice(), 'users/alice/exerciseProgress/ex2'), { exerciseId: 'ex1', ...data }),
    );
  });

  test('a completion count cannot go down', async () => {
    await seed('users/alice/exerciseProgress/ex1', {
      exerciseId: 'ex1',
      completionCount: 5,
      lastCompletedAt: aPastTime(),
    });
    const path = 'users/alice/exerciseProgress/ex1';
    await assertSucceeds(
      setDoc(doc(alice(), path), { exerciseId: 'ex1', completionCount: 6, lastCompletedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(alice(), path), { exerciseId: 'ex1', completionCount: 2, lastCompletedAt: serverTimestamp() }),
    );
  });

  test('a completion count cannot start below zero', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/exerciseProgress/ex1'), validProgress({ completionCount: -1 })),
    );
  });

  test('lastCompletedAt cannot be backdated', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/exerciseProgress/ex1'), validProgress({ lastCompletedAt: aPastTime() })),
    );
  });

  test('a progress document with a field outside the model is refused', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/exerciseProgress/ex1'), validProgress({ verified: true })),
    );
  });
});

describe('preferences', () => {
  test('the owner can write the settings document', async () => {
    await assertSucceeds(
      setDoc(doc(alice(), 'users/alice/preferences/settings'), {
        reminderEnabled: true,
        reminderTime: '09:30',
        soundEnabled: true,
        hapticEnabled: false,
      }),
    );
  });

  test('no preferences document other than "settings" is allowed', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/preferences/other'), { soundEnabled: true }));
  });

  test('no preferences document other than "settings" can be read or deleted', async () => {
    await seed('users/alice/preferences/other', { soundEnabled: true });
    await assertFails(getDoc(doc(alice(), 'users/alice/preferences/other')));
    await assertFails(deleteDoc(doc(alice(), 'users/alice/preferences/other')));
  });

  test('an impossible reminder time is refused', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/preferences/settings'), { reminderTime: '25:00' }),
    );
  });

  test('each switch must be true or false', async () => {
    const path = 'users/alice/preferences/settings';
    await assertFails(setDoc(doc(alice(), path), { reminderEnabled: 'yes' }));
    await assertFails(setDoc(doc(alice(), path), { soundEnabled: 1 }));
    await assertFails(setDoc(doc(alice(), path), { hapticEnabled: 'false' }));
  });

  test('a preferences field outside the model is refused', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/preferences/settings'), { soundEnabled: true, theme: 'dark' }),
    );
  });
});

describe('everything not in the model is denied', () => {
  test("an unknown subcollection under the user's own document is refused", async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/secrets/x'), { a: 1 }));
    await assertFails(getDoc(doc(alice(), 'users/alice/secrets/x')));
  });
});
