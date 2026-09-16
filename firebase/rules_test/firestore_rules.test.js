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

const validHistory = (overrides = {}) => ({
  trainingDate: '2026-09-14',
  programDay: 1,
  completedExerciseIds: ['breathing_diaphragm_01'],
  durationMinutes: 15,
  completedAt: serverTimestamp(),
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

  test("cannot delete another user's document", async () => {
    await seed('users/alice', { createdAt: aPastTime() });
    await assertFails(deleteDoc(doc(bob(), 'users/alice')));
  });

  test("cannot read or write another user's training history", async () => {
    await seed('users/alice/trainingHistory/h1', { programDay: 1 });
    await assertFails(getDoc(doc(bob(), 'users/alice/trainingHistory/h1')));
    await assertFails(setDoc(doc(bob(), 'users/alice/trainingHistory/h2'), validHistory()));
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

  test('a negative counter is refused', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ currentStreak: -1 })));
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ totalTrainingMinutes: -5 })));
  });

  test('a fractional counter is refused', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), validUser({ currentProgramDay: 1.5 })));
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
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/trainingHistory/h1'), validHistory()));
  });

  test('an entry cannot be backdated', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/trainingHistory/h1'), validHistory({ completedAt: aPastTime() })),
    );
  });

  test('an existing entry cannot be edited', async () => {
    await seed('users/alice/trainingHistory/h1', {
      trainingDate: '2026-09-14',
      programDay: 1,
      completedExerciseIds: ['breathing_diaphragm_01'],
      durationMinutes: 15,
      completedAt: aPastTime(),
    });
    await assertFails(updateDoc(doc(alice(), 'users/alice/trainingHistory/h1'), { durationMinutes: 90 }));
  });

  test('the owner can delete their own entry', async () => {
    await seed('users/alice/trainingHistory/h1', { programDay: 1 });
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice/trainingHistory/h1')));
  });

  test('a malformed training date is refused', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/trainingHistory/h1'), validHistory({ trainingDate: '14.09.2026' })),
    );
  });

  test('a session with no completed exercises is refused', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/trainingHistory/h1'), validHistory({ completedExerciseIds: [] })),
    );
  });

  test('a missing required field is refused', async () => {
    const { programDay, ...withoutDay } = validHistory();
    await assertFails(setDoc(doc(alice(), 'users/alice/trainingHistory/h1'), withoutDay));
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

  test('an impossible reminder time is refused', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users/alice/preferences/settings'), { reminderTime: '25:00' }),
    );
  });
});

describe('everything not in the model is denied', () => {
  test("an unknown subcollection under the user's own document is refused", async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/secrets/x'), { a: 1 }));
    await assertFails(getDoc(doc(alice(), 'users/alice/secrets/x')));
  });
});
