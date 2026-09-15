# MVP Curriculum: sourced material for HIT-080

**STATUS: DRAFT, NOT APPROVED. Nothing here may ship until the content lead signs it off.**

This is the input to the approval HIT-080 asks for, not the approval. Every exercise below is quoted or summarised from a published source, with the page it came from, so a reviewer can check each line against the original rather than trusting this file.

Where two sources cover the same ground they are shown side by side rather than merged, so the choice between them stays a decision someone makes rather than one this file made quietly.

The decisions taken on #82 on 14 September 2026 are recorded below, next to the material each one settles.

## Sources

**[S1] T.C. Millî Eğitim Bakanlığı, Büro Yönetimi, "Diksiyon 1", module code 90KG00004, Ankara 2011.** 72 pages. Vocational training material published by the Ministry. Its front matter states: *"Millî Eğitim Bakanlığınca ücretsiz olarak verilmiştir."*
<https://megep.meb.gov.tr/mte_program_modul/moduller_pdf/diksiyon-%201.pdf>

**[S2] Cahit Maaç, "Etkin Konuşma ve Diksiyon".** 45 pages, hosted on a Ministry school domain. Its cover page states the author's credentials: a former TRT main news anchor, and since 1994 an instructor authorised by the Ministry for what the page calls, in capitals, TÜRK DİLİNİ GELİŞTİRME VE TOPLUM ÖNÜNDE SÖZ SÖYLEME SANATI EĞİTİMİ.
<https://yukaritoprakliortaokulu.meb.k12.tr/meb_iys_dosyalar/76/02/735949/dosyalar/2018_02/19143425_etkin-konusma.pdf>

Those are the document's own claims about its author. Nothing here verifies them independently, and the reviewer may want to.

**[S3] T.C. Millî Eğitim Bakanlığı, Büro Yönetimi, "Diksiyon 2", module code 90KG00005.** 57 pages. Covers delivery (`anlatım`) and gesture, not exercise mechanics. Relevant to the speaking challenge (HIT-048), not to the drills below.

Page numbers are each document's own printed numbers, not PDF positions.

**Licence, settled on #82: the app does not reproduce source text.** Instructional text in `assets/content/` is written by the team. The sources supply facts, such as durations, ratios, repetition limits and which techniques exist, and those stay page-cited in this file so each one can be checked. That takes the question of whether "free of charge" permits reproduction in a commercial app out of the MVP's path.

## The breathing ratio: two sources, one answer

This is the part with a real recommendation behind it, and the two sources agree.

| | Inhale | Hold | Exhale | Source |
|---|---|---|---|---|
| **S1**, p.14 | 1 | 4 | 2 | Exercise V |
| **S2**, p.3 | 1 | 4 | 2 | "Derin Soluma" |
| **shipped before #151** | 4 | 2 | 6 | placeholder, none |
| **shipped since #151** | 1 | 4 | 2 | S1 and S2 |

Verbatim, S1:

> bir saniyede alıyorsanız dört saniye tutmalı ve iki saniyede bırakmalısınız.

Verbatim, S2. The separators are reproduced as the document prints them:

> Nefesimizi alış, tutuş ve veriş zamanımız 1 – 4 - 2 formülüne uygun olacak. Yani eğer nefesimizi 2 saniyede almışsak 8 saniye içimizde tutacağız ve 4 saniyede vereceğiz.

S2 states the same ratio as a formula and gives a worked example: two seconds in, eight held, four out. S1 gives it as one second in, four held, two out. Same shape, different scale.

**The value the repository shipped before #151 matched neither, and came from nowhere.** It was written as a placeholder and held the breath for less time than the inhale, which both sources invert. #151 replaced it with 1-4-2.

S1 also gives a second, different pattern at p.14, a progression rather than a fixed cycle: inhale through the nose for a count of 6, exhale through the mouth for 8, then raise the exhale by two at a time up to 22 while the inhale stays at 6. `BreathingConfig` cannot express that today; it carries one inhale, one hold, one exhale and a repeat count.

Both sources agree on nose in, mouth out, from the diaphragm.

## Safety, and where it comes from

S1 carries no warnings. **S2 does**, in the same paragraph as the ratio, p.3-4:

> Bir seansta 10 defadan fazla yapmayınız. Derin soluma çalışmasını sabah erkenden ve akşam saatlerinde 10'ar defa yapınız. **Bir anda alınan fazla oksijen, oksijen krizine yol açabilir.**

That is three separate facts an app needs: a per-session cap of ten repetitions, a suggested twice-daily rhythm, and a stated reason not to exceed it.

**#82 adopts the cap:** deep breathing is limited to ten repetitions per session. The shipped exercise uses five cycles, inside it.

**This matters most for S1's Exercise IV**, the rapid panting it calls “Köpek soluması”. S1 gives it no limit at all. S2's warning is about exactly this class of exercise. **#82 excludes it from the MVP.**

**#82 also sets a notice:** every breathing exercise is preceded by a short notice to stop if the user feels dizzy or lightheaded. That is a conservative posture to build against, not a safety sign-off; see the last section.

## Breathing exercises [S1, pages 13-15]

Ten in total. The two with explicit counts are above; the rest:

| | Page | What it is |
|---|---|---|
| I | 13 | Lie on the back, breathe into the belly. Two weeks, daily |
| II | 13 | Upright, deep breath held, pull the belly in and release |
| III | 13 | Deep breath, exhale as a hiss. Broken or wave-like variants |
| IV | 14 | Rapid shallow panting, “Köpek soluması”. Excluded from the MVP by #82 |
| VI | 14 | Rise onto the toes while inhaling, hold, drop onto the heels and release |
| VIII | 14 | Read a marked poem, one breath per marked span |
| IX | 15 | One long sentence in a single breath |
| X | 15 | Speak near a candle flame without blowing it out |

Exercise III is the sound cue HIT-029 left room for: the exhale is a hiss.

Exercise VIII quotes Yahya Kemal Beyatlı's *Akıncılar* with breath marks. **#82 excludes that excerpt:** the author died in 1958 and the poem is still under copyright protection in Turkey, so it is not S1's to grant. The exercise itself, one breath per marked span, can be built on text the team writes.

## Relaxation [S1, pages 15-17]

Ten exercises, tension and release through the body: hands, shoulders, neck, face, abdomen, legs. Exercise I asks for at least fifteen minutes of breathing work daily. Exercise VIII asks to slow breathing to about six breaths per minute.

Not an exercise type in the app today. Would be a new type, or a preamble to breathing.

## Voice strength [S1, page 17]

Six drills on the vowel "a": open the mouth and voice it, swell it while exhaling, hold a steady intensity, raise and lower it, repeat that several times, produce loud sounds on short exhales.

## Articulation organs [S1, page 43]

- **Moving:** jaw, lips, tongue, soft palate
- **Fixed:** teeth, gums, hard palate

That split is what the three exercise sets below are organised around.

## Tongue [S1, pages 45-46]

Six exercises. The instruction above them: repeat long enough and exaggerated enough to tire the muscles inside the mouth.

1. Chew the tongue quickly, as if chewing gum
2. Circle the tongue rapidly inside the mouth, outside the jaws, under the lips
3. Tip against the lower front teeth, move back and forth from the root
4. Push the tongue right out and hold
5. Roll the tongue and move it in and out between narrowed lips and jaws
6. Tip against the lower front teeth, move in and out rapidly from the root

## Jaw [S1, page 46]

Six exercises, aimed at jaw opening and free movement.

1. Hand against the lower jaw, shout *"çak çak"*, push the jaw back up against the hand
2. Massage the cheekbones with both palms
3. Fists under the chin, open the jaw, push the head back, close, repeat with the head further back
4. Open and close the jaw rapidly, then faster
5. Move the jaw rapidly forwards and back
6. Rotate the jaw rapidly in circles

## Lips [S1, page 46]

Five exercises, against what S1 calls lip laziness.

1. Exhale hard through the mouth saying *"pofff"*, letting the pressure push the lips
2. Lips held tight and close to the teeth, force air through them
3. Lips closed and pushed forward, rotated in circles, then up and down, then side to side
4. Jaw closed, say *"mı, mi, mu, mü"* rapidly, then *"fe, ve"*, *"pe, be"*, *"u, ü"*, *"o, ö"*
5. Hold a pen horizontally in the lips and say “Benim memleketim… Bir ben vardır bende benden içeri”, then release and let the air flutter the lips

Exercise 4 is the closest thing in either source to the U-X lip drill HIT-034 names.

## Resonance [S1, pages 46-47]

Four exercises. Hum *"mmmm"* with the mouth closed; touch the forehead and feel the vibration; read one text three ways, strained then nasal then relaxed; sing across very low and very high tones.

## Letters [S1, pages 47-50]

Articulation sentences grouped by the sound they drill, eighteen letters: A, I, O, U, E, F, P, M, V, B, S, L, Z, C, D, Y, G, H.

Two examples, page 47, verbatim:

> **(A)** Abana'dan Adana'ya abarta abarta apar topar ahlatla ağdalı avuntucu ahmak Ahmet'in avandanlıklarını aparanlardan acar Abdullah ile akıllı Abdi akşam akşam bize geldi.

> Al, bu takatukaları takatukacıya takatukalatmaya götür. Takatukacı takatukaları takatukalamam derse takatukacıdan takatukaları takatukalatmadan al getir.

S1's own instruction for these: say them slowly first, then gradually faster. It also says outright that some will read as nonsense, and that the meaning does not matter, only the articulation.

This maps onto `LetterLadder` directly, and the second example is a tongue twister in the sense `TongueTwister` means. Under the licence decision above, both are shown here as evidence of the technique; the sentences the app uses are written by the team.

## Articulation faults S1 names [page 44]

Useful because they are what the exercises are for, and because a progress screen could name them: "ğ" for "r", trilling the "r", stammering, swallowing letters, indistinct final letters, inserting letters, a shaky voice, affected speech, speaking too fast, speaking inside the mouth, dialect faults, filler sounds (*"eee"*, *"ıh"*, *"şey"*), speaking too slowly, dragging or chopping words, and wrong or misplaced pauses.

S1 suggests reading aloud and working through tongue twisters for stammering, and adds that its cause may need psychological help. **That is a clinical claim and this app should not repeat it.**

## Pauses [S1, pages 57-58]

Three lengths: short, normal, long. This is the material HIT-045 needs.

## What was missing, and what #82 decided

**A day by day program.** Neither source has a notion of "day 1". **#82:** fourteen days of around fifteen minutes each, both figures taken from the sources. Each day runs breathing, then articulation (tongue, jaw, lips, letter), then a text exercise, a tongue twister or a reading. The progression across the fourteen days is authored by the team; the sources do not define one, so it is a design choice rather than a gap.

**Durations for everything except breathing.** Between them the sources give: two weeks of daily practice, fifteen minutes a day, six breaths a minute, the 1-4-2 ratio, the 6-to-22 progression, ten repetitions a session, twice daily. Every other duration in the app is set by the team.

**Tongue twisters.** A handful across both sources. **#82:** written originally by the team. Original text needs no licence, and this is also how HIT-041 reaches its ten entries.

**Speaking prompts.** None in S1 or S2. S3 covers delivery and may help HIT-048, but it carries no prompts either. **#82:** written originally by the team, like the tongue twisters.

**A safety text the app shows.** S2 gives one warning and one cap. **#82** adopts the cap and the dizziness notice above as the posture to build against. **Still open:** the final breathing text must be reviewed by someone qualified before any public release.

Until content is rewritten under these decisions, everything shipping in `assets/content/` stays `status: placeholder`.

## What this file deliberately does not do

It does not assign exercises to days, set durations, or write the text the app shows. Those follow the decisions above and belong in the curriculum content itself.

The one change it argued for was the breathing ratio: two independent sources give 1-4-2, the repository shipped 4-2-6 from no source, and #151 corrected it with the citation above.
