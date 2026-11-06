(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else Object.assign(root, api);
})(typeof window === 'undefined' ? this : window, function () {
  'use strict';

  // Original IBM PC PIT input clock divided by the BIOS timer divisor.
  const HZ = 1193182 / 65536;
  const SCHEDULE_AHEAD = 0.03;
  const ATLAS_PROGRAMS = [10, 11, 12, 13, 9, 15, 24, 25, 26, 27, 28, 29, 30, 31, 45, 46, 104, 105, 106, 107, 108, 114, 115, 116, 117, 118, 119];
  const MEGA_PROGRAMS = [46, 108, 9, 45, 11, 12, 24, 114, 10, 9, 8, 10, 98, 81, 4];

  function penta(value) {
    const v = value & 254;
    return Math.floor(v / 5) * 6 + v % 5;
  }

  function visualNote(sample) {
    return penta((sample & 30) + 50);
  }

  function programme(show, partIndex) {
    const list = show === 'ATLAS' ? ATLAS_PROGRAMS : MEGA_PROGRAMS;
    return list[((partIndex % list.length) + list.length) % list.length];
  }

  class MidiSequence {
    constructor(show, partIndex) { this.reset(show || 'MEGA', partIndex || 0); }
    reset(show, partIndex) { this.show = show; this.partIndex = partIndex || 0; this.tick = 0; this.lastProgram = -1; }
    next(sample) {
      const out = [], t = this.tick++, voice = programme(this.show, this.partIndex);
      if (voice !== this.lastProgram) { out.push([0xC0, voice]); this.lastProgram = voice; }
      const lead = visualNote(sample);
      out.push([0x90, lead, lead], [0x90, lead - 24, Math.max(24, lead - 24)]);
      if (this.show === 'ATLAS') {
        out.push([0x99, 42, 32 + (t & 15)]);
        if (!(t & 3)) {
          out.push([0x99, 36 + ((t & 4) >> 1), 100]);
          const bass = penta(((t >> 2) & 14) + 30);
          out.push([0xC1, 32], [0x91, bass, 72], [0xC2, 45],
            [0x92, bass + 12, 52], [0x92, bass + 19, 44]);
        }
      }
      return out;
    }
  }

  class WebAudioMidiSynth {
    constructor(context) {
      this.context = context;
      this.programs = new Uint8Array(16);
      this.master = context.createGain();
      this.master.gain.value = 0.34;
      this.master.connect(context.destination);
      this.noise = this.makeNoise();
    }
    setVolume(value) {
      const volume = Math.max(0, Math.min(1, Number(value) || 0));
      this.master.gain.setTargetAtTime(volume * 0.5, this.context.currentTime, 0.02);
    }
    makeNoise() {
      const b = this.context.createBuffer(1, Math.ceil(this.context.sampleRate * 0.16), this.context.sampleRate);
      const d = b.getChannelData(0);
      for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
      return b;
    }
    send(message, when) {
      const status = message[0], command = status & 0xF0, channel = status & 15;
      if (command === 0xC0) { this.programs[channel] = message[1]; return; }
      if (command === 0x90 && message[2]) {
        if (channel === 9) this.drum(message[1], message[2], when);
        else this.note(message[1], message[2], this.programs[channel], when, channel);
      }
    }
    note(number, velocity, program, when, channel) {
      const ac = this.context, t = Math.max(ac.currentTime, when || 0), f = 440 * Math.pow(2, (number - 69) / 12);
      const gain = ac.createGain(), filter = ac.createBiquadFilter();
      const world = program >= 104, guitar = program >= 24 && program <= 31;
      const bass = channel === 1 || program === 32;
      const duration = bass ? 0.34 : world ? 0.22 : guitar ? 0.42 : 0.55;
      const osc = ac.createOscillator();
      osc.type = bass ? 'triangle' : guitar ? 'sawtooth' : world ? 'square' : 'sine';
      osc.frequency.setValueAtTime(f, t);
      filter.type = 'lowpass'; filter.frequency.setValueAtTime(bass ? 700 : guitar ? 1800 : 4200, t);
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.exponentialRampToValueAtTime(Math.max(0.002, velocity / 127 * (bass ? 0.24 : 0.16)), t + 0.008);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + duration);
      osc.connect(filter); filter.connect(gain); gain.connect(this.master);
      osc.start(t); osc.stop(t + duration + 0.03);
      if (!bass && !guitar) {
        const overtone = ac.createOscillator(), og = ac.createGain();
        overtone.type = 'sine'; overtone.frequency.setValueAtTime(f * (world ? 3 : 2), t);
        og.gain.setValueAtTime(velocity / 127 * 0.04, t);
        og.gain.exponentialRampToValueAtTime(0.0001, t + duration * 0.55);
        overtone.connect(og); og.connect(this.master); overtone.start(t); overtone.stop(t + duration);
      }
    }
    drum(number, velocity, when) {
      const ac = this.context, t = Math.max(ac.currentTime, when || 0);
      if (number === 36) {
        const o = ac.createOscillator(), g = ac.createGain();
        o.frequency.setValueAtTime(120, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.12);
        g.gain.setValueAtTime(velocity / 127 * 0.5, t); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.18);
        o.connect(g); g.connect(this.master); o.start(t); o.stop(t + 0.2);
        return;
      }
      const n = ac.createBufferSource(), f = ac.createBiquadFilter(), g = ac.createGain();
      n.buffer = this.noise; f.type = number === 42 ? 'highpass' : 'bandpass';
      f.frequency.value = number === 42 ? 6500 : 1800;
      const duration = number === 42 ? 0.045 : 0.12;
      g.gain.setValueAtTime(velocity / 127 * (number === 42 ? 0.14 : 0.32), t);
      g.gain.exponentialRampToValueAtTime(0.0001, t + duration);
      n.connect(f); f.connect(g); g.connect(this.master); n.start(t); n.stop(t + duration + 0.01);
    }
  }

  class BrowserMidi {
    constructor(context, sampler, showProvider) {
      this.context = context; this.sampler = sampler; this.showProvider = showProvider;
      this.synth = new WebAudioMidiSynth(context); this.sequence = new MidiSequence(showProvider());
      this.nextTime = 0; this.timer = 0;
    }
    start() {
      if (this.timer) return;
      this.context.resume(); this.nextTime = this.context.currentTime + 0.05;
      this.timer = setInterval(() => this.pump(), 20); this.pump();
    }
    pump() {
      const horizon = this.context.currentTime + SCHEDULE_AHEAD;
      while (this.nextTime < horizon) {
        const tick = this.sequence.tick, messages = this.sequence.next(this.sampler(tick));
        for (const message of messages) this.synth.send(message, this.nextTime);
        this.nextTime += 1 / HZ;
      }
    }
    enterPart(show, partIndex) {
      this.pause();
      this.sequence.reset(show || this.showProvider(), partIndex || 0);
      this.nextTime = this.context.currentTime + 0.01;
    }
    enterCard(playChime) {
      this.pause();
      if (playChime !== false) {
        const t = this.context.currentTime + 0.01;
        this.synth.send([0xC0, 14], t);
        this.synth.send([0x90, 84, 70], t);
        this.synth.send([0x90, 91, 60], t);
      }
    }
    restart(show) {
      this.enterPart(show || this.showProvider(), 0);
    }
    setVolume(value) { this.synth.setVolume(value); }
    pause() { clearInterval(this.timer); this.timer = 0; }
    resume() { this.start(); }
    stop() { this.pause(); }
  }

  return { HZ, SCHEDULE_AHEAD, ATLAS_PROGRAMS, MEGA_PROGRAMS, penta, visualNote, programme, MidiSequence, WebAudioMidiSynth, BrowserMidi };
});
