'use strict';
const assert = require('assert');
const fs = require('fs');
const { HZ, SCHEDULE_AHEAD, ATLAS_PROGRAMS, MEGA_PROGRAMS, penta, visualNote, programme, MidiSequence } = require('../web/midi.js');

assert.strictEqual(ATLAS_PROGRAMS.length, 27);
assert.strictEqual(MEGA_PROGRAMS.length, 15);
assert.deepStrictEqual([...new Set(ATLAS_PROGRAMS)], ATLAS_PROGRAMS);
assert(Math.abs(HZ - 18.206512451171875) < 1e-12);
assert(SCHEDULE_AHEAD <= 0.03);
for (let sample = 0; sample < 256; sample++) {
  const note = visualNote(sample);
  assert(note >= 60 && note <= 96);
  assert([0, 2, 4, 7, 9].includes(note % 12));
}
assert.strictEqual(penta(50), 60);
assert.strictEqual(programme('ATLAS', 0), ATLAS_PROGRAMS[0]);
for (const [show, programs] of [['ATLAS', ATLAS_PROGRAMS], ['MEGA', MEGA_PROGRAMS]]) {
  for (let i = 0; i < programs.length; i++) assert.strictEqual(programme(show, i), programs[i]);
  assert.strictEqual(programme(show, programs.length), programs[0]);
}

const sourceProgram = playlist => {
  const names = [...fs.readFileSync(`src/mega/${playlist}_program.inc`, 'utf8').matchAll(/^\s*ENTRY\s+([a-z]+),/gm)].map(m => m[1]);
  return names.map(effect => +(fs.readFileSync(`src/${effect}.asm`, 'utf8').match(/^%define INSTRUMENT (\d+)/m) || [])[1]);
};
assert.deepStrictEqual(ATLAS_PROGRAMS, sourceProgram('atlas'));
assert.strictEqual(MEGA_PROGRAMS.length,
  [...fs.readFileSync('src/mega/mega_program.inc', 'utf8').matchAll(/^\s*ENTRY\s+/gm)].length);
for (const show of ['MEGA', 'ATLAS']) {
  assert(!fs.readFileSync(`${show}.COM`).includes(Buffer.from('UBSYNC')),
    `${show}.COM release binary must not contain the web sync channel`);
  assert(fs.readFileSync(`web/${show}.COM`).includes(Buffer.from('UBSYNC')),
    `web/${show}.COM must contain the signed sync record`);
}
for (const show of ['UBER70', 'UBERSHOW']) {
  assert(fs.readFileSync(`${show}.COM`).equals(fs.readFileSync(`web/${show}.COM`)),
    `web/${show}.COM must be the exact preserved DOS binary`);
}
const player = fs.readFileSync('web/index.html', 'utf8');
for (const token of ['id="prev"', 'id="next"', 'id="shortcutGrid"', 'id="codePanel"', 'highlightAsm', 'ArrowLeft', 'ArrowRight', 'EMBEDDED_THUMBNAILS'])
  assert(player.includes(token), `browser control missing: ${token}`);

const atlas = new MidiSequence('ATLAS', 5);
let events = [];
for (let i = 0; i < 64; i++) events.push(...atlas.next(i * 3));
assert.deepStrictEqual(events.find(e => (e[0] & 0xF0) === 0xC0), [0xC0, ATLAS_PROGRAMS[5]]);
const notes = events.filter(e => (e[0] & 0xF0) === 0x90 && e[2]);
for (let i = 0; i < 64; i++) {
  const lead = visualNote(i * 3), pair = notes.filter(e => (e[0] & 15) === 0).slice(i * 2, i * 2 + 2);
  assert.deepStrictEqual(pair.map(e => e[1]), [lead, lead - 24]);
}
assert.deepStrictEqual([...new Set(notes.map(e => e[0] & 15))].sort((a, b) => a - b), [0, 1, 2, 9]);
assert(new Set(notes.filter(e => (e[0] & 15) === 9).map(e => e[1])).has(36));
assert(new Set(notes.filter(e => (e[0] & 15) === 9).map(e => e[1])).has(38));
assert(new Set(notes.filter(e => (e[0] & 15) === 9).map(e => e[1])).has(42));

const mega = new MidiSequence('MEGA');
events = [];
for (let i = 0; i < 32; i++) events.push(...mega.next(i));
assert(events.every(e => (e[0] & 15) === 0));
console.log('Browser MIDI: scale, voices, octave response, bass, harmony and drums PASS');
