/* Cờ Tướng engine: luật, sinh nước, đánh giá, tìm kiếm alpha-beta.
   Dùng chung cho main thread (luật, ký hiệu) và Web Worker (tìm kiếm). */
(function (G) {
  'use strict';
  const K = 1, A = 2, B = 3, N = 4, R = 5, C = 6, P = 7;
  const RED = 1, BLACK = -1;
  const VAL = [0, 0, 200, 200, 400, 900, 450, 100];
  const MATE = 30000, INF = 32000, MAXPLY = 96;
  const ORTH = [[-1, 0], [1, 0], [0, -1], [0, 1]];
  const DIAG = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
  // Mã: [chân mã, [đích...]]
  const NLEG = [
    [[-1, 0], [[-2, -1], [-2, 1]]],
    [[1, 0], [[2, -1], [2, 1]]],
    [[0, -1], [[-1, -2], [1, -2]]],
    [[0, 1], [[-1, 2], [1, 2]]],
  ];
  const FEN_MAP = { k: K, a: A, b: B, e: B, n: N, h: N, r: R, c: C, p: P };
  const FEN_CH = ['', 'k', 'a', 'b', 'n', 'r', 'c', 'p'];
  const START_FEN = 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w';

  const inB = (r, c) => r >= 0 && r < 10 && c >= 0 && c < 9;
  const inPalace = (r, c, s) => c >= 3 && c <= 5 && (s > 0 ? r >= 7 && r <= 9 : r >= 0 && r <= 2);

  // Bảng vị trí (góc nhìn bên Đỏ, hàng 0 = phía đối phương)
  function T(rows) { const a = new Int16Array(90); rows.forEach((row, r) => row.forEach((v, c) => (a[r * 9 + c] = v))); return a; }
  const Z9 = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  const PST = [null,
    T([Z9, Z9, Z9, Z9, Z9, Z9, Z9, [0, 0, 0, -20, -20, -20, 0, 0, 0], [0, 0, 0, -10, -10, -10, 0, 0, 0], [0, 0, 0, 0, 4, 0, 0, 0, 0]]),
    T([Z9, Z9, Z9, Z9, Z9, Z9, Z9, [0, 0, 0, -2, 0, -2, 0, 0, 0], [0, 0, 0, 0, 6, 0, 0, 0, 0], Z9]),
    T([Z9, Z9, Z9, Z9, Z9, [0, 0, -2, 0, 0, 0, -2, 0, 0], Z9, [-4, 0, 0, 0, 6, 0, 0, 0, -4], Z9, Z9]),
    T([
      [4, 8, 16, 12, 4, 12, 16, 8, 4],
      [4, 10, 28, 16, 8, 16, 28, 10, 4],
      [12, 14, 16, 20, 18, 20, 16, 14, 12],
      [8, 24, 18, 24, 20, 24, 18, 24, 8],
      [6, 16, 14, 18, 16, 18, 14, 16, 6],
      [4, 12, 16, 14, 12, 14, 16, 12, 4],
      [2, 6, 8, 6, 10, 6, 8, 6, 2],
      [4, 2, 8, 8, 4, 8, 8, 2, 4],
      [0, 2, 4, 4, -2, 4, 4, 2, 0],
      [0, -10, 0, 0, 0, 0, 0, -10, 0],
    ]),
    T([
      [14, 14, 12, 18, 16, 18, 12, 14, 14],
      [16, 20, 18, 24, 26, 24, 18, 20, 16],
      [12, 12, 12, 18, 18, 18, 12, 12, 12],
      [12, 18, 16, 22, 22, 22, 16, 18, 12],
      [12, 14, 12, 18, 18, 18, 12, 14, 12],
      [12, 16, 14, 20, 20, 20, 14, 16, 12],
      [6, 10, 8, 14, 14, 14, 8, 10, 6],
      [4, 8, 6, 14, 12, 14, 6, 8, 4],
      [8, 4, 8, 16, 8, 16, 8, 4, 8],
      [-6, 6, 4, 12, 0, 12, 4, 6, -6],
    ]),
    T([
      [6, 4, 0, -10, -12, -10, 0, 4, 6],
      [2, 2, 0, -4, -14, -4, 0, 2, 2],
      [2, 2, 0, -10, -8, -10, 0, 2, 2],
      [0, 0, -2, 4, 10, 4, -2, 0, 0],
      [0, 0, 0, 2, 8, 2, 0, 0, 0],
      [-2, 0, 4, 2, 6, 2, 4, 0, -2],
      [0, 0, 0, 2, 4, 2, 0, 0, 0],
      [4, 0, 4, 6, 16, 6, 4, 0, 4],
      [0, 2, 4, 6, 6, 6, 4, 2, 0],
      [0, 0, 2, 6, 6, 6, 2, 0, 0],
    ]),
    T([
      [0, 3, 6, 9, 12, 9, 6, 3, 0],
      [18, 36, 56, 80, 120, 80, 56, 36, 18],
      [14, 26, 42, 60, 80, 60, 42, 26, 14],
      [10, 20, 30, 34, 40, 34, 30, 20, 10],
      [6, 12, 18, 18, 20, 18, 18, 12, 6],
      [2, 0, 8, 0, 8, 0, 8, 0, 2],
      [0, 0, -2, 0, 4, 0, -2, 0, 0],
      Z9, Z9, Z9,
    ]),
  ];
  function pieceScore(p, sq) {
    const t = p > 0 ? p : -p;
    let idx = sq;
    if (p < 0) { const r = (sq / 9) | 0; idx = (9 - r) * 9 + (sq - r * 9); }
    return VAL[t] + PST[t][idx];
  }

  // Zobrist cố định (seed) để main thread và worker cho cùng giá trị hash
  function mulberry32(a) { return function () { a |= 0; a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) | 0; }; }
  const rnd = mulberry32(20261108);
  const Z1 = new Int32Array(14 * 90), Z2 = new Int32Array(14 * 90);
  for (let i = 0; i < Z1.length; i++) { Z1[i] = rnd(); Z2[i] = rnd(); }
  const ZS1 = rnd(), ZS2 = rnd();
  const zi = (p) => (p > 0 ? p - 1 : 6 - p);

  class Pos {
    constructor() {
      this.b = new Int8Array(90); this.side = RED;
      this.h1 = 0; this.h2 = 0; this.ev = 0; this.kR = -1; this.kB = -1;
      this.hs1 = []; this.hs2 = []; this.und = [];
    }
    static fromFen(fen) {
      const p = new Pos();
      const [bd, s] = fen.trim().split(/\s+/);
      let r = 0, c = 0;
      for (const ch of bd) {
        if (ch === '/') { r++; c = 0; }
        else if (ch >= '0' && ch <= '9') c += +ch;
        else { const t = FEN_MAP[ch.toLowerCase()]; p.b[r * 9 + c] = ch === ch.toLowerCase() ? -t : t; c++; }
      }
      p.side = s === 'b' ? BLACK : RED;
      p.recompute();
      return p;
    }
    static start() { return Pos.fromFen(START_FEN); }
    recompute() {
      this.h1 = 0; this.h2 = 0; this.ev = 0;
      for (let sq = 0; sq < 90; sq++) {
        const p = this.b[sq]; if (!p) continue;
        this.h1 ^= Z1[zi(p) * 90 + sq]; this.h2 ^= Z2[zi(p) * 90 + sq];
        this.ev += (p > 0 ? 1 : -1) * pieceScore(p, sq);
        if (p === K) this.kR = sq; else if (p === -K) this.kB = sq;
      }
      if (this.side === BLACK) { this.h1 ^= ZS1; this.h2 ^= ZS2; }
      this.hs1 = [this.h1]; this.hs2 = [this.h2]; this.und = [];
    }
    clone() {
      const p = new Pos();
      p.b.set(this.b); p.side = this.side; p.h1 = this.h1; p.h2 = this.h2; p.ev = this.ev;
      p.kR = this.kR; p.kB = this.kB; p.hs1 = this.hs1.slice(); p.hs2 = this.hs2.slice();
      return p;
    }
    // lịch sử các thế cờ trước (để nhận biết lặp)
    historyPairs() { const out = []; for (let i = 0; i < this.hs1.length - 1; i++) out.push([this.hs1[i], this.hs2[i]]); return out; }
    setHistory(pairs) { this.hs1 = pairs.map((x) => x[0]).concat([this.h1]); this.hs2 = pairs.map((x) => x[1]).concat([this.h2]); }
    toFen() {
      let s = '';
      for (let r = 0; r < 10; r++) {
        let e = 0;
        for (let c = 0; c < 9; c++) {
          const p = this.b[r * 9 + c];
          if (!p) { e++; continue; }
          if (e) { s += e; e = 0; }
          const ch = FEN_CH[p > 0 ? p : -p];
          s += p > 0 ? ch.toUpperCase() : ch;
        }
        if (e) s += e;
        if (r < 9) s += '/';
      }
      return s + (this.side === RED ? ' w' : ' b');
    }

    make(m) {
      const f = m & 127, t = m >> 7, b = this.b, p = b[f], q = b[t];
      this.und.push(m, q, this.h1, this.h2, this.ev);
      const zp = zi(p) * 90;
      this.h1 ^= Z1[zp + f] ^ Z1[zp + t]; this.h2 ^= Z2[zp + f] ^ Z2[zp + t];
      this.ev += (p > 0 ? 1 : -1) * (pieceScore(p, t) - pieceScore(p, f));
      if (q) {
        const zq = zi(q) * 90 + t;
        this.h1 ^= Z1[zq]; this.h2 ^= Z2[zq];
        this.ev -= (q > 0 ? 1 : -1) * pieceScore(q, t);
      }
      b[t] = p; b[f] = 0;
      if (p === K) this.kR = t; else if (p === -K) this.kB = t;
      this.side = -this.side; this.h1 ^= ZS1; this.h2 ^= ZS2;
      this.hs1.push(this.h1); this.hs2.push(this.h2);
    }
    unmake() {
      const u = this.und;
      const ev = u.pop(), h2 = u.pop(), h1 = u.pop(), q = u.pop(), m = u.pop();
      const f = m & 127, t = m >> 7, p = this.b[t];
      this.b[f] = p; this.b[t] = q;
      if (p === K) this.kR = f; else if (p === -K) this.kB = f;
      this.side = -this.side; this.h1 = h1; this.h2 = h2; this.ev = ev;
      this.hs1.pop(); this.hs2.pop();
    }
    makeNull() {
      this.und.push(0, 0, this.h1, this.h2, this.ev);
      this.side = -this.side; this.h1 ^= ZS1; this.h2 ^= ZS2;
      this.hs1.push(this.h1); this.hs2.push(this.h2);
    }
    unmakeNull() {
      const u = this.und;
      this.ev = u.pop(); this.h2 = u.pop(); this.h1 = u.pop(); u.pop(); u.pop();
      this.side = -this.side; this.hs1.pop(); this.hs2.pop();
    }

    // Sinh nước giả hợp lệ (chưa kiểm tra tự để Tướng bị chiếu)
    gen(capOnly, side) {
      const b = this.b, s = side || this.side, out = [];
      const add = (f, t) => {
        const q = b[t];
        if (q === 0) { if (!capOnly) out.push(f | (t << 7)); }
        else if ((q > 0) !== (s > 0)) out.push(f | (t << 7));
      };
      for (let sq = 0; sq < 90; sq++) {
        const p = b[sq];
        if (p === 0 || (p > 0) !== (s > 0)) continue;
        const t = p > 0 ? p : -p, r = (sq / 9) | 0, c = sq - r * 9;
        switch (t) {
          case K:
            for (const [dr, dc] of ORTH) { const nr = r + dr, nc = c + dc; if (inPalace(nr, nc, s)) add(sq, nr * 9 + nc); }
            break;
          case A:
            for (const [dr, dc] of DIAG) { const nr = r + dr, nc = c + dc; if (inPalace(nr, nc, s)) add(sq, nr * 9 + nc); }
            break;
          case B:
            for (const [dr, dc] of DIAG) {
              const nr = r + 2 * dr, nc = c + 2 * dc;
              if (!inB(nr, nc) || (s > 0 ? nr < 5 : nr > 4)) continue;
              if (b[(r + dr) * 9 + c + dc] === 0) add(sq, nr * 9 + nc);
            }
            break;
          case N:
            for (const [[lr, lc], tg] of NLEG) {
              const ar = r + lr, ac = c + lc;
              if (!inB(ar, ac) || b[ar * 9 + ac] !== 0) continue;
              for (const [tr, tc] of tg) { const nr = r + tr, nc = c + tc; if (inB(nr, nc)) add(sq, nr * 9 + nc); }
            }
            break;
          case R:
            for (const [dr, dc] of ORTH) {
              let nr = r + dr, nc = c + dc;
              while (inB(nr, nc)) {
                const q = b[nr * 9 + nc];
                if (q === 0) { if (!capOnly) out.push(sq | ((nr * 9 + nc) << 7)); }
                else { if ((q > 0) !== (s > 0)) out.push(sq | ((nr * 9 + nc) << 7)); break; }
                nr += dr; nc += dc;
              }
            }
            break;
          case C:
            for (const [dr, dc] of ORTH) {
              let nr = r + dr, nc = c + dc, screen = false;
              while (inB(nr, nc)) {
                const q = b[nr * 9 + nc];
                if (!screen) {
                  if (q === 0) { if (!capOnly) out.push(sq | ((nr * 9 + nc) << 7)); }
                  else screen = true;
                } else if (q !== 0) {
                  if ((q > 0) !== (s > 0)) out.push(sq | ((nr * 9 + nc) << 7));
                  break;
                }
                nr += dr; nc += dc;
              }
            }
            break;
          case P: {
            const fw = s > 0 ? -1 : 1;
            if (inB(r + fw, c)) add(sq, (r + fw) * 9 + c);
            if (s > 0 ? r <= 4 : r >= 5) {
              if (c > 0) add(sq, sq - 1);
              if (c < 8) add(sq, sq + 1);
            }
            break;
          }
        }
      }
      return out;
    }

    // Tướng của bên `side` có đang bị chiếu không
    inCheck(side) {
      const k = side > 0 ? this.kR : this.kB;
      if (k < 0) return true;
      const b = this.b, r = (k / 9) | 0, c = k - r * 9, e = -side;
      for (const [dr, dc] of ORTH) {
        let nr = r + dr, nc = c + dc, found = false;
        while (inB(nr, nc)) {
          const q = b[nr * 9 + nc];
          if (q !== 0) {
            if (!found) {
              if (q === e * R || (q === e * K && dc === 0)) return true;
              found = true;
            } else { if (q === e * C) return true; break; }
          }
          nr += dr; nc += dc;
        }
      }
      for (const [[lr, lc], tg] of NLEG) {
        for (const [tr, tc] of tg) {
          const nr = r - tr, nc = c - tc;
          if (!inB(nr, nc) || b[nr * 9 + nc] !== e * N) continue;
          if (b[(nr + lr) * 9 + nc + lc] === 0) return true;
        }
      }
      const pr = r + (side > 0 ? -1 : 1); // tốt đối phương đứng phía trước Tướng
      if (inB(pr, c) && b[pr * 9 + c] === e * P) return true;
      if (c > 0 && b[k - 1] === e * P) return true;
      if (c < 8 && b[k + 1] === e * P) return true;
      return false;
    }

    legalMoves() {
      const out = [], me = this.side;
      for (const m of this.gen(false)) { this.make(m); if (!this.inCheck(me)) out.push(m); this.unmake(); }
      return out;
    }
    isLegal(m) { return this.legalMoves().includes(m); }
    givesCheck(m) { this.make(m); const r = this.inCheck(this.side); this.unmake(); return r; }
    isRep() {
      const n = this.hs1.length - 1, h1 = this.h1, h2 = this.h2;
      for (let i = n - 2; i >= 0; i--) if (this.hs1[i] === h1 && this.hs2[i] === h2) return true;
      return false;
    }
    repCount() {
      let n = 0;
      for (let i = 0; i < this.hs1.length; i++) if (this.hs1[i] === this.h1 && this.hs2[i] === this.h2) n++;
      return n;
    }
    hasBig(side) {
      const b = this.b;
      for (let i = 0; i < 90; i++) { const p = b[i] * side; if (p === R || p === N || p === C) return true; }
      return false;
    }
    evalSide() { return this.side * this.ev + 10; }

    // Ký hiệu kiểu Việt Nam: "Pháo 2 bình 5", "Mã 8 tiến 7", "Xe trước tiến 1"
    moveName(m) {
      const f = m & 127, t = m >> 7, p = this.b[f];
      if (!p) return '?';
      const s = p > 0 ? 1 : -1, tp = p * s;
      const fr = (f / 9) | 0, fc = f % 9, tr = (t / 9) | 0, tc = t % 9;
      const col = (c) => (s > 0 ? 9 - c : c + 1);
      let id = String(col(fc));
      const same = [];
      for (let r = 0; r < 10; r++) if (this.b[r * 9 + fc] === p) same.push(r);
      if (same.length === 2 && tp !== K) {
        const front = s > 0 ? Math.min(...same) : Math.max(...same);
        id = fr === front ? 'trước' : 'sau';
      }
      let act;
      if (fr === tr) act = 'bình ' + col(tc);
      else {
        const fwd = s > 0 ? fr - tr : tr - fr;
        const num = tp === N || tp === B || tp === A ? col(tc) : Math.abs(tr - fr);
        act = (fwd > 0 ? 'tiến ' : 'thoái ') + num;
      }
      return PIECE_NAME[tp] + ' ' + id + ' ' + act;
    }
  }
  const PIECE_NAME = ['', 'Tướng', 'Sĩ', 'Tượng', 'Mã', 'Xe', 'Pháo', 'Tốt'];

  // ---------------- Tìm kiếm ----------------
  const EXACT = 0, LOWER = 1, UPPER = 2;
  class Search {
    constructor() {
      const SIZE = 1 << 20; this.mask = SIZE - 1;
      this.tk = new Int32Array(SIZE); this.tm = new Int32Array(SIZE); this.ts = new Int32Array(SIZE);
      this.td = new Int8Array(SIZE).fill(-1); this.tf = new Int8Array(SIZE);
      this.hist = new Int32Array(1 << 14); this.killers = new Int32Array(MAXPLY * 2);
      this.pv = []; for (let i = 0; i < MAXPLY + 1; i++) this.pv.push(new Int32Array(MAXPLY + 1));
      this.pvLen = new Int32Array(MAXPLY + 1);
    }
    ttStore(pos, d, s, f, m, ply) {
      const i = pos.h1 & this.mask;
      if (this.tk[i] === pos.h2 && this.td[i] > d && f !== EXACT) return;
      if (s > MATE - 500) s += ply; else if (s < -MATE + 500) s -= ply;
      this.tk[i] = pos.h2; this.td[i] = d; this.ts[i] = s; this.tf[i] = f; this.tm[i] = m;
    }
    order(pos, moves, ttm, ply) {
      const b = pos.b, sc = new Array(moves.length);
      const k1 = this.killers[ply * 2], k2 = this.killers[ply * 2 + 1];
      for (let i = 0; i < moves.length; i++) {
        const m = moves[i], q = b[m >> 7];
        if (m === ttm) sc[i] = 1e7;
        else if (q) { const a = b[m & 127]; sc[i] = 1e6 + VAL[q > 0 ? q : -q] * 10 - VAL[a > 0 ? a : -a] / 10 + ((q === K || q === -K) ? 1e5 : 0); }
        else if (m === k1) sc[i] = 9e5;
        else if (m === k2) sc[i] = 8e5;
        else sc[i] = this.hist[m];
      }
      return sc;
    }
    tick() {
      if ((++this.nodes & 2047) === 0 && Date.now() > this.deadline) this.stop = true;
      return this.stop;
    }
    copyPv(ply, m) {
      const dst = this.pv[ply], src = this.pv[ply + 1];
      dst[ply] = m;
      const n = this.pvLen[ply + 1];
      for (let k = ply + 1; k < n; k++) dst[k] = src[k];
      this.pvLen[ply] = Math.max(n, ply + 1);
    }
    nm(d, a, b, ply, nullOk) {
      const pos = this.pos;
      this.pvLen[ply] = ply;
      if (this.tick()) return 0;
      if (ply > 0 && pos.isRep()) return 0;
      if (ply >= MAXPLY - 1) return pos.evalSide();
      // cắt tỉa theo khoảng cách chiếu bí
      const ma = -MATE + ply, mb = MATE - ply - 1;
      if (a < ma) a = ma; if (b > mb) b = mb; if (a >= b) return a;
      const inC = pos.inCheck(pos.side);
      if (inC) d++;
      if (d <= 0) return this.qs(a, b, ply);
      const ti = pos.h1 & this.mask;
      let ttm = 0;
      if (this.tk[ti] === pos.h2 && this.td[ti] >= 0) {
        ttm = this.tm[ti];
        if (this.td[ti] >= d && ply > 0) {
          let s = this.ts[ti];
          if (s > MATE - 500) s -= ply; else if (s < -MATE + 500) s += ply;
          const f = this.tf[ti];
          if (f === EXACT || (f === LOWER && s >= b) || (f === UPPER && s <= a)) return s;
        }
      }
      if (nullOk && !inC && d >= 3 && b < MATE - 500 && b - a === 1 && pos.hasBig(pos.side) && pos.evalSide() >= b) {
        pos.makeNull();
        const s = -this.nm(d - 3, -b, -b + 1, ply + 1, false);
        pos.unmakeNull();
        if (this.stop) return 0;
        if (s >= b) return b;
      }
      const moves = pos.gen(false), sc = this.order(pos, moves, ttm, ply);
      const me = pos.side, a0 = a;
      let best = -INF, bestM = 0, legal = 0;
      for (let i = 0; i < moves.length; i++) {
        let bi = i;
        for (let j = i + 1; j < moves.length; j++) if (sc[j] > sc[bi]) bi = j;
        if (bi !== i) { let x = moves[i]; moves[i] = moves[bi]; moves[bi] = x; x = sc[i]; sc[i] = sc[bi]; sc[bi] = x; }
        const m = moves[i], isCap = pos.b[m >> 7] !== 0;
        pos.make(m);
        if (pos.inCheck(me)) { pos.unmake(); continue; }
        legal++;
        let s;
        if (legal === 1) s = -this.nm(d - 1, -b, -a, ply + 1, true);
        else {
          let red = 0;
          if (d >= 3 && legal > 4 && !isCap && !inC && sc[i] < 8e5 && !pos.inCheck(pos.side)) red = legal > 12 && d >= 5 ? 2 : 1;
          s = -this.nm(d - 1 - red, -a - 1, -a, ply + 1, true);
          if (s > a && red) s = -this.nm(d - 1, -a - 1, -a, ply + 1, true);
          if (s > a && s < b) s = -this.nm(d - 1, -b, -a, ply + 1, true);
        }
        pos.unmake();
        if (this.stop) return 0;
        if (s > best) {
          best = s; bestM = m;
          if (s > a) {
            a = s; this.copyPv(ply, m);
            if (a >= b) {
              if (!isCap) {
                if (this.killers[ply * 2] !== m) { this.killers[ply * 2 + 1] = this.killers[ply * 2]; this.killers[ply * 2] = m; }
                this.hist[m] += d * d;
              }
              break;
            }
          }
        }
      }
      if (legal === 0) return -MATE + ply; // cờ tướng: hết nước đi cũng là thua
      this.ttStore(pos, d, best, best <= a0 ? UPPER : best >= b ? LOWER : EXACT, bestM, ply);
      return best;
    }
    qs(a, b, ply) {
      const pos = this.pos;
      this.pvLen[ply] = ply;
      if (this.tick()) return 0;
      if (ply >= MAXPLY - 1) return pos.evalSide();
      const inC = pos.inCheck(pos.side);
      let best = -INF;
      if (!inC) {
        const st = pos.evalSide();
        if (st >= b) return st;
        if (st > a) a = st;
        best = st;
      }
      const moves = pos.gen(!inC), sc = this.order(pos, moves, 0, ply), me = pos.side;
      let legal = 0;
      for (let i = 0; i < moves.length; i++) {
        let bi = i;
        for (let j = i + 1; j < moves.length; j++) if (sc[j] > sc[bi]) bi = j;
        if (bi !== i) { let x = moves[i]; moves[i] = moves[bi]; moves[bi] = x; x = sc[i]; sc[i] = sc[bi]; sc[bi] = x; }
        const m = moves[i];
        pos.make(m);
        if (pos.inCheck(me)) { pos.unmake(); continue; }
        legal++;
        const s = -this.qs(-b, -a, ply + 1);
        pos.unmake();
        if (this.stop) return 0;
        if (s > best) {
          best = s;
          if (s > a) { a = s; this.copyPv(ply, m); if (a >= b) break; }
        }
      }
      if (inC && legal === 0) return -MATE + ply;
      return best;
    }
    // opts: timeMs, depth, multipv
    run(pos, opts) {
      opts = opts || {};
      this.pos = pos; this.nodes = 0; this.stop = false;
      const t0 = Date.now(), time = opts.timeMs || 1000, maxD = Math.min(opts.depth || 60, MAXPLY - 10), mpv = opts.multipv || 1;
      this.hist.fill(0); this.killers.fill(0);
      let root = pos.legalMoves().map((m) => ({ m, s: -INF, exact: false, pv: [m] }));
      if (!root.length) return { multi: [], all: [], depth: 0, nodes: 0, noMoves: true };
      // sắp xếp ban đầu: ăn quân giá trị cao trước
      const sc0 = this.order(pos, root.map((e) => e.m), 0, 0);
      root = root.map((e, i) => [e, sc0[i]]).sort((x, y) => y[1] - x[1]).map((x) => x[0]);
      let depth = 0;
      for (let d = 1; d <= maxD; d++) {
        this.deadline = d === 1 ? Infinity : t0 + time;
        const res = [], exacts = [];
        for (const e of root) {
          const thr = exacts.length >= mpv ? exacts[mpv - 1] : -INF;
          pos.make(e.m);
          let s;
          if (thr === -INF) s = -this.nm(d - 1, -INF, INF, 1, true);
          else {
            s = -this.nm(d - 1, -thr - 1, -thr, 1, true);
            if (s > thr && !this.stop) s = -this.nm(d - 1, -INF, -thr, 1, true);
          }
          pos.unmake();
          if (this.stop) break;
          const exact = s > thr;
          const pv = [e.m];
          for (let k = 1; k < this.pvLen[1]; k++) pv.push(this.pv[1][k]);
          res.push({ m: e.m, s, exact, pv: exact ? pv : e.pv });
          if (exact) { exacts.push(s); exacts.sort((x, y) => y - x); }
        }
        if (this.stop) break;
        res.sort((x, y) => (y.exact - x.exact) || (y.s - x.s));
        root = res; depth = d;
        const bs = root[0].s;
        if (bs > MATE - 500 && MATE - bs <= d) break;
        if (root.length === 1 && d >= 4) break;
        if (Date.now() - t0 > time * 0.5) break;
      }
      const multi = root.filter((e) => e.exact).slice(0, mpv).map((e) => ({ move: e.m, score: e.s, pv: e.pv }));
      return { multi, all: root.map((e) => ({ move: e.m, score: e.s, exact: e.exact })), depth, nodes: this.nodes, ms: Date.now() - t0 };
    }
  }

  G.XQ = { K, A, B, N, R, C, P, RED, BLACK, VAL, MATE, INF, START_FEN, PIECE_NAME, Pos, Search };
})(typeof self !== 'undefined' ? self : globalThis);
