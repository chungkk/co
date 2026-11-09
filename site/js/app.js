/* Cờ Tướng — luyện cùng máy, có thầy gợi ý */
(function () {
  'use strict';
  const { Pos, K, A, B, N, R, C, P, RED, BLACK, VAL, MATE, PIECE_NAME } = XQ;

  // ---------- Cấu hình ----------
  const COACH_MS = 1100;
  const LEVELS = [
    null,
    { name: 'Mới tập', opts: { depth: 1, multipv: 8 }, margin: 160, randomChance: 0.25 },
    { name: 'Dễ', opts: { depth: 2, multipv: 6 }, margin: 70, randomChance: 0.08 },
    { name: 'Trung bình', opts: { depth: 4, timeMs: 500, multipv: 3 }, margin: 25 },
    { name: 'Khá', opts: { timeMs: 1300, multipv: 2 }, margin: 8 },
    { name: 'Giỏi', opts: { timeMs: 3000, multipv: 1 }, margin: 0 },
  ];
  const CLS = {
    best: { label: 'Nước hay nhất', short: 'Hay nhất', icon: '★' },
    good: { label: 'Nước tốt', short: 'Tốt', icon: '✓' },
    book: { label: 'Nước của đại sư', short: 'Đại sư', icon: '📖' },
    inacc: { label: 'Chưa chính xác', short: 'Chưa chuẩn', icon: '?!' },
    mistake: { label: 'Sai lầm', short: 'Sai lầm', icon: '?' },
    blunder: { label: 'Nước hỏng', short: 'Hỏng', icon: '??' },
  };

  // Sách khai cuộc nhỏ: chuỗi tên nước
  const BOOK = [
    ['Pháo 2 bình 5', 'Mã 8 tiến 7', 'Mã 2 tiến 3', 'Xe 9 bình 8', 'Xe 1 bình 2', 'Mã 2 tiến 3', 'Tốt 7 tiến 1', 'Tốt 7 tiến 1'],
    ['Pháo 2 bình 5', 'Mã 8 tiến 7', 'Mã 2 tiến 3', 'Mã 2 tiến 3', 'Xe 1 bình 2', 'Xe 9 bình 8'],
    ['Pháo 2 bình 5', 'Pháo 8 bình 5', 'Mã 2 tiến 3', 'Mã 8 tiến 7', 'Xe 1 bình 2', 'Xe 9 bình 8'],
    ['Pháo 2 bình 5', 'Pháo 2 bình 5', 'Mã 2 tiến 3', 'Mã 8 tiến 7', 'Xe 1 bình 2', 'Xe 9 bình 8'],
    ['Pháo 2 bình 5', 'Tượng 3 tiến 5', 'Mã 2 tiến 3', 'Mã 2 tiến 3'],
    ['Pháo 8 bình 5', 'Mã 2 tiến 3', 'Mã 8 tiến 7', 'Mã 8 tiến 7', 'Xe 9 bình 8', 'Xe 9 bình 8'],
    ['Tốt 7 tiến 1', 'Tốt 7 tiến 1', 'Mã 8 tiến 7', 'Mã 8 tiến 7'],
    ['Tốt 7 tiến 1', 'Pháo 2 bình 3', 'Pháo 8 bình 5', 'Tượng 3 tiến 5'],
    ['Tượng 3 tiến 5', 'Pháo 8 bình 4', 'Mã 2 tiến 3', 'Mã 8 tiến 7', 'Xe 1 bình 2', 'Xe 9 bình 8'],
    ['Mã 2 tiến 3', 'Tốt 7 tiến 1', 'Tốt 7 tiến 1', 'Mã 8 tiến 7'],
    ['Pháo 2 bình 4', 'Mã 8 tiến 7', 'Mã 2 tiến 3', 'Xe 9 bình 8'],
  ];
  const OPENINGS = [
    { seq: ['Pháo 2 bình 5', 'Pháo 8 bình 5'], name: 'Thuận pháo', tip: 'Hai bên cùng Pháo đầu. Tranh nhau ra Xe nhanh, chú ý trung lộ.' },
    { seq: ['Pháo 8 bình 5', 'Pháo 2 bình 5'], name: 'Thuận pháo', tip: 'Hai bên cùng Pháo đầu. Tranh nhau ra Xe nhanh, chú ý trung lộ.' },
    { seq: ['Pháo 2 bình 5', 'Pháo 2 bình 5'], name: 'Nghịch pháo (Liệt pháo)', tip: 'Đen chơi Pháo đầu ngược cánh, thế cờ sắc bén, đối công ngay từ đầu.' },
    { seq: ['Pháo 8 bình 5', 'Pháo 8 bình 5'], name: 'Nghịch pháo (Liệt pháo)', tip: 'Đen chơi Pháo đầu ngược cánh, thế cờ sắc bén, đối công ngay từ đầu.' },
    { seq: ['Pháo 2 bình 5', 'Mã 8 tiến 7', 'Mã 2 tiến 3', 'Mã 2 tiến 3'], name: 'Pháo đầu đối Bình phong mã', tip: 'Đen ra hai Mã bảo vệ Tốt đầu. Đỏ thường ra Xe, tiến Tốt 7 hoặc tấn công trung lộ.' },
    { seq: ['Pháo 8 bình 5', 'Mã 2 tiến 3', 'Mã 8 tiến 7', 'Mã 8 tiến 7'], name: 'Pháo đầu đối Bình phong mã', tip: 'Đen ra hai Mã bảo vệ Tốt đầu. Đỏ thường ra Xe, tiến Tốt và tấn công trung lộ.' },
    { seq: ['Pháo 2 bình 5'], name: 'Pháo đầu (Trung pháo)', tip: 'Khai cuộc tấn công phổ biến nhất: Pháo nhắm vào Tốt đầu và Tướng. Tiếp theo nên ra Mã, ra Xe.' },
    { seq: ['Pháo 8 bình 5'], name: 'Pháo đầu (Trung pháo)', tip: 'Khai cuộc tấn công phổ biến nhất: Pháo nhắm vào Tốt đầu và Tướng. Tiếp theo nên ra Mã, ra Xe.' },
    { seq: ['Tốt 7 tiến 1'], name: 'Tiên nhân chỉ lộ', tip: 'Tiến Tốt 3 hoặc 7 để mở đường cho Mã, thăm dò ý đồ đối phương.' },
    { seq: ['Tốt 3 tiến 1'], name: 'Tiên nhân chỉ lộ', tip: 'Tiến Tốt 3 hoặc 7 để mở đường cho Mã, thăm dò ý đồ đối phương.' },
    { seq: ['Tượng 3 tiến 5'], name: 'Phi tượng cuộc', tip: 'Khai cuộc phòng thủ vững chắc, phản công sau.' },
    { seq: ['Tượng 7 tiến 5'], name: 'Phi tượng cuộc', tip: 'Khai cuộc phòng thủ vững chắc, phản công sau.' },
    { seq: ['Mã 2 tiến 3'], name: 'Khởi mã cuộc', tip: 'Ra Mã trước, linh hoạt chuyển sang nhiều thế trận.' },
    { seq: ['Mã 8 tiến 7'], name: 'Khởi mã cuộc', tip: 'Ra Mã trước, linh hoạt chuyển sang nhiều thế trận.' },
    { seq: ['Pháo 2 bình 4'], name: 'Sĩ giác pháo', tip: 'Pháo đặt ở góc Sĩ, kín đáo, chuẩn bị ra Xe nhanh.' },
    { seq: ['Pháo 8 bình 6'], name: 'Sĩ giác pháo', tip: 'Pháo đặt ở góc Sĩ, kín đáo, chuẩn bị ra Xe nhanh.' },
    { seq: ['Pháo 2 bình 6'], name: 'Quá cung pháo', tip: 'Pháo đi qua cung Tướng sang cánh kia, thế trận vững.' },
    { seq: ['Pháo 8 bình 4'], name: 'Quá cung pháo', tip: 'Pháo đi qua cung Tướng sang cánh kia, thế trận vững.' },
  ];

  const HAN = { 1: ['帥', '將'], 2: ['仕', '士'], 3: ['相', '象'], 4: ['傌', '馬'], 5: ['俥', '車'], 6: ['炮', '砲'], 7: ['兵', '卒'] };
  const VIET = { 1: 'Tg', 2: 'S', 3: 'T', 4: 'M', 5: 'X', 6: 'P', 7: 'B' };

  // ---------- Lưu trữ ----------
  const store = {
    get(k, d) { try { const v = localStorage.getItem('cotuong.' + k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } },
    set(k, v) { try { localStorage.setItem('cotuong.' + k, JSON.stringify(v)); } catch (e) { /* bỏ qua */ } },
  };

  // ---------- Engine (Web Worker) ----------
  class Engine {
    constructor() { this.spawn(); }
    spawn() {
      this.w = new Worker('js/worker.js?v=3');
      this.q = new Map(); this.id = 0; this.ctl = this.ctl || new Set();
      this.w.onmessage = (e) => { const cb = this.q.get(e.data.id); if (cb) { this.q.delete(e.data.id); cb(e.data); } };
    }
    search(pos, opts) {
      const id = ++this.id;
      return new Promise((res) => { this.q.set(id, res); this.w.postMessage({ id, fen: pos.toFen(), hist: pos.historyPairs(), opts }); });
    }
    reset() {
      this.w.terminate(); for (const cb of this.q.values()) cb(null); this.spawn();
      for (const c of this.ctl) { c.byReset = true; c.abort(); }
    }
    // Phân tích để chấm nước: Pikafish trên máy chủ (server/engine-server.js), mạnh hơn nhiều;
    // máy chủ lỗi/bận/không có thì dùng engine trong trình duyệt. Máy đối thủ và bài tập vẫn dùng search().
    async analyse(pos, opts) {
      if (Date.now() >= REMOTE.off) {
        const ctl = new AbortController(), ms = opts.timeMs || 1000;
        this.ctl.add(ctl);
        const timer = setTimeout(() => ctl.abort(), ms + 4000);
        try {
          const r = await fetch('api/analyse', {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, signal: ctl.signal,
            body: JSON.stringify({ fen: pos.toFen(), multipv: opts.multipv || 1, ms }),
          });
          if (r.ok) {
            const res = fromRemote(pos, await r.json());
            if (res) { REMOTE.fails = 0; REMOTE.used = true; return res; }
          } else if (r.status === 404 || r.status === 405 || r.status === 501) REMOTE.off = Infinity; // trang tĩnh, không có máy chủ
          else if (r.status !== 503 && r.status !== 429) remoteFail(); // 503/429: máy chủ bận, lần này dùng engine trong trình duyệt
        } catch (e) {
          if (ctl.byReset) return null;
          remoteFail();
        } finally { clearTimeout(timer); this.ctl.delete(ctl); }
      }
      REMOTE.used = false;
      return this.search(pos, opts);
    }
  }
  const REMOTE = { off: 0, fails: 0, used: null }, REMOTE_SCALE = 1.2;
  // lỗi liên tiếp 3 lần thì tạm nghỉ gọi máy chủ 1 phút
  function remoteFail() { if (++REMOTE.fails >= 3) { REMOTE.off = Date.now() + 60000; REMOTE.fails = 0; } }
  // ô UCI ("e2") → chỉ số ô (hàng 0 là phía Đen)
  const uciSq = (u) => (9 - +u[1]) * 9 + (u.charCodeAt(0) - 97);
  function fromRemote(pos, d) {
    const multi = [];
    for (const x of d.multi || []) {
      const p = pos.clone(), pv = [];
      for (const u of x.pv || []) {
        if (!/^[a-i]\d[a-i]\d$/.test(u)) break;
        const m = uciSq(u) | (uciSq(u.slice(2)) << 7);
        if (!p.isLegal(m)) break;
        pv.push(m); p.make(m);
      }
      if (!pv.length) continue;
      // điểm chiếu bí theo số nửa nước như engine trong trình duyệt; điểm thường nhân REMOTE_SCALE
      // vì thang của Pikafish nhỏ hơn ~20% (thiếu Mã: -310 so với -374), để giữ nguyên ngưỡng xếp loại nước đi
      const score = x.mate != null ? (x.mate > 0 ? MATE - (2 * x.mate - 1) : -(MATE - 2 * -x.mate)) : Math.max(-MATE + 500, Math.min(MATE - 500, Math.round((x.cp | 0) * REMOTE_SCALE)));
      multi.push({ move: pv[0], score, pv });
    }
    return multi.length ? { multi, all: multi.map((x) => ({ move: x.move, score: x.score, exact: true })), depth: d.depth, remote: true } : null;
  }
  const engine = new Engine();

  // ---------- Trạng thái ----------
  const S = {
    pos: Pos.start(), userSide: store.get('side', RED), level: store.get('level', 3),
    hist: [], state: 'user', pre: null, tok: 0, selected: -1, arrows: [], view: -1,
    coach: null, hintsUsed: 0, result: null, lastScore: 0,
    startFen: null, // null = thế ban đầu; khác: ván bắt đầu từ thế cờ này (tàn cục, ván nhập vào)
    opt: Object.assign({ warn: true, threats: true, han: true, sound: true }, store.get('opt', {})),
  };

  // ---------- Âm thanh (cùng bộ tiếng quân gỗ với bản iOS) ----------
  // Trình duyệt chỉ cho phát âm thanh sau khi người dùng chạm/bấm: tải và giải mã ở lần chạm đầu.
  const SFX = {
    files: { move: ['move1', 'move2', 'move3'], capture: ['capture1', 'capture2'], check: ['check'], select: ['select'], win: ['win'], end: ['end'], fail: ['fail'] },
    ctx: null, buf: {}, last: '', n: 0, mode: null,
  };
  function sfxInit() {
    if (SFX.ctx) { if (SFX.ctx.state === 'suspended') SFX.ctx.resume().catch(() => {}); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    try { SFX.ctx = new AC(); } catch (e) { return; }
    for (const list of Object.values(SFX.files)) {
      for (const f of list) {
        fetch('sfx/' + f + '.m4a').then((r) => r.arrayBuffer()).then((b) => SFX.ctx.decodeAudioData(b)).then((d) => { SFX.buf[f] = d; }).catch(() => {});
      }
    }
  }
  addEventListener('pointerdown', sfxInit, { capture: true });
  addEventListener('keydown', sfxInit, { capture: true });
  // phát tiếng [kind]; delay: chờ quân trượt tới nơi rồi mới "cạch"
  function sfx(kind, delay) {
    if (!S.opt.sound || !SFX.ctx) return;
    const list = SFX.files[kind]; if (!list) return;
    let f = list[(Math.random() * list.length) | 0];
    if (list.length > 1 && f === SFX.last) f = list[(list.indexOf(f) + 1) % list.length]; // không lặp biến thể liền nhau
    SFX.last = f;
    const play = () => {
      const b = SFX.buf[f]; if (!b || !SFX.ctx) return;
      try { const src = SFX.ctx.createBufferSource(); src.buffer = b; src.connect(SFX.ctx.destination); src.start(); } catch (e) { /* bỏ qua */ }
    };
    if (delay > 0) setTimeout(play, delay); else play();
  }
  // tiếng cho nước vừa đi: chỉ khi ván tiến thêm đúng một nước (không kêu khi tua, đi lại, đổi ván)
  function sfxMove() {
    const n = S.hist.length;
    if (n === SFX.n + 1 && S.mode === SFX.mode) {
      const last = S.hist[n - 1];
      sfx(S.pos.inCheck(S.pos.side) ? 'check' : last.before && last.before.b[last.m >> 7] ? 'capture' : 'move', 200);
    }
    SFX.n = n; SFX.mode = S.mode;
  }

  // ---------- Tiện ích phân tích ----------
  const sgn = (p) => (p > 0 ? 1 : -1);
  const absT = (p) => (p > 0 ? p : -p);
  const pval = (p) => (absT(p) === K ? 10000 : VAL[absT(p)]);
  const nameOf = (p) => PIECE_NAME[absT(p)];
  const sideName = (s) => (s === RED ? 'Đỏ' : 'Đen');
  const rowOf = (sq) => (sq / 9) | 0, colOf = (sq) => sq % 9;
  const relRow = (sq, s) => (s > 0 ? rowOf(sq) : 9 - rowOf(sq)); // 9 = hàng cuối của mình, 0 = hàng cuối đối phương

  // Các quân của `side` có thể ăn ô sq (bỏ qua ghim)
  function attackers(pos, sq, side) {
    const b = pos.b, saved = b[sq], savedSide = pos.side;
    b[sq] = -side * P; // đặt tạm quân đối phương để sinh nước ăn
    const out = [];
    for (const m of pos.gen(true, side)) if ((m >> 7) === sq) out.push(m & 127);
    b[sq] = saved; pos.side = savedSide;
    return out;
  }
  function isHanging(pos, sq) {
    const p = pos.b[sq]; if (!p || absT(p) === K) return false;
    const s = sgn(p), att = attackers(pos, sq, -s);
    if (!att.length) return false;
    const def = attackers(pos, sq, s);
    if (!def.length) return true;
    const minAtt = Math.min(...att.map((f) => pval(pos.b[f])));
    return minAtt < pval(p);
  }
  function hangingSet(pos, side) {
    const out = [];
    for (let sq = 0; sq < 90; sq++) { const p = pos.b[sq]; if (p && sgn(p) === side && isHanging(pos, sq)) out.push(sq); }
    return out;
  }
  const listNames = (pos, sqs) => {
    const ns = sqs.map((s) => nameOf(pos.b[s]));
    return ns.length <= 1 ? ns.join('') : ns.slice(0, -1).join(', ') + ' và ' + ns[ns.length - 1];
  };
  const fmtScore = (s) => {
    if (s > MATE - 500) return 'Chiếu bí sau ' + Math.ceil((MATE - s) / 2) + ' nước';
    if (s < -MATE + 500) return 'Bị chiếu bí sau ' + Math.ceil((MATE + s) / 2) + ' nước';
    const v = s / 100; return (v > 0 ? '+' : '') + v.toFixed(1);
  };
  const lc = (s) => s.charAt(0).toLowerCase() + s.slice(1);
  const clampS = (s) => Math.max(-2500, Math.min(2500, s));

  // Giải thích một nước đi bằng lời
  function explain(pos, m, score, opts) {
    opts = opts || {};
    const out = [];
    const f = m & 127, t = m >> 7, p = pos.b[f], q = pos.b[t], me = sgn(p), tp = absT(p);
    const after = pos.clone(); after.make(m);
    const oppLegal = after.legalMoves().length;
    const check = after.inCheck(after.side);
    if (oppLegal === 0) { out.push('Chiếu bí, kết thúc ván cờ!'); return out; }
    if (score !== undefined && score > MATE - 500) out.push('Có đường chiếu bí: thắng sau ' + Math.ceil((MATE - score) / 2) + ' nước nếu đi chính xác.');
    if (q) {
      const recap = attackers(after, t, -me).length > 0;
      if (!recap) out.push('Ăn ' + nameOf(q) + ' không mất gì: đối phương không ăn lại được.');
      else if (pval(q) > pval(p)) out.push('Ăn ' + nameOf(q) + ' bằng ' + nameOf(p) + ', lời quân dù bị ăn lại.');
      else if (pval(q) === pval(p)) out.push('Đổi ' + nameOf(p) + ' lấy ' + nameOf(q) + '.');
      else out.push('Ăn ' + nameOf(q) + '.');
    }
    if (check) out.push('Chiếu Tướng, buộc đối phương phải đỡ.');
    if (opts.short) return out.length ? out : [positional(pos, m)];
    const oppBefore = hangingSet(pos, -me), oppAfter = hangingSet(after, -me);
    const newT = oppAfter.filter((s) => !oppBefore.includes(s));
    if (newT.length >= 2) out.push('Bắt đôi: cùng lúc dọa ăn ' + listNames(after, newT) + '.');
    else if (newT.length === 1) out.push('Dọa ăn ' + nameOf(after.b[newT[0]]) + '.');
    const myBefore = hangingSet(pos, me), myAfter = hangingSet(after, me);
    if (myBefore.includes(f) && !myAfter.includes(t)) out.push('Đưa ' + nameOf(p) + ' ra khỏi chỗ bị đe dọa.');
    const saved = myBefore.filter((s) => s !== f && after.b[s] === pos.b[s] && !myAfter.includes(s));
    if (saved.length) out.push('Bảo vệ ' + listNames(pos, saved) + ' đang bị đe dọa.');
    if (out.length < 2) out.push(positional(pos, m));
    return out;
  }
  function positional(pos, m) {
    const f = m & 127, t = m >> 7, p = pos.b[f], me = sgn(p), tp = absT(p);
    const fr = relRow(f, me), tr = relRow(t, me), tc = colOf(t);
    const ownPawnOnFile = () => { for (let r = 0; r < 10; r++) if (pos.b[r * 9 + tc] === me * P) return true; return false; };
    switch (tp) {
      case R:
        if (fr === 9 && (colOf(f) === 0 || colOf(f) === 8)) return 'Ra Xe sớm: Xe mạnh nhất bàn cờ, đừng để Xe nằm im ở góc.';
        if (tr <= 4 && fr > 4) return 'Xe qua sông, uy hiếp hậu phương đối phương.';
        if (!ownPawnOnFile()) return 'Đưa Xe vào đường mở để kiểm soát cả cột.';
        return 'Đưa Xe tới vị trí hoạt động hơn.';
      case N:
        if (fr === 9) return 'Phát triển Mã ra trận, đồng thời bảo vệ Tốt.';
        if (tr <= 4) return 'Mã tiến sang phía đối phương, chuẩn bị tấn công.';
        return 'Điều Mã tới vị trí tốt hơn (chú ý đừng để bị cản chân mã).';
      case C:
        if (tc === 4 && colOf(f) !== 4) return 'Pháo đầu: nhắm thẳng vào trung lộ và Tướng đối phương.';
        return 'Đưa Pháo tới vị trí hoạt động hơn, tìm "ngòi" để tấn công.';
      case P:
        if (tr === 4 && fr === 5) return 'Tốt qua sông: từ giờ được đi ngang, trở thành mối đe dọa.';
        if (fr >= 5 && (tc === 2 || tc === 6)) return 'Tiến Tốt mở đường cho Mã.';
        return 'Tiến Tốt, tăng sức ép.';
      case A: case B: return 'Củng cố phòng thủ quanh Tướng.';
      case K: return 'Đưa Tướng tránh khỏi đường bị tấn công.';
    }
    return 'Cải thiện thế cờ.';
  }
  // ---------- Sách khai cuộc đại sư (thống kê từ ván giải đấu) ----------
  const PRO = { pos: null, eco: null, names: null, games: 0 };
  fetch('data/book.json?v=1').then((r) => r.json()).then((d) => { Object.assign(PRO, d); render(); }).catch(() => {});
  const pkey = (p) => (p.h1 >>> 0).toString(36) + '.' + (p.h2 >>> 0).toString(36);
  function proMoves(pos) {
    if (!PRO.pos) return null;
    const e = PRO.pos[pkey(pos)];
    if (!e) return null;
    const legal = pos.legalMoves(), tot = e.reduce((s, x) => s + x[1], 0);
    return e.filter((x) => legal.includes(x[0])).map(([m, n, w, d, l]) => ({ m, n, w, d, l, share: n / tot, name: pos.moveName(m) }));
  }
  function ecoOf() {
    if (!PRO.eco) return null;
    const ps = S.hist.map((h) => h.before).concat([S.pos]);
    for (let i = ps.length - 1; i >= 0; i--) { const c = PRO.eco[pkey(ps[i])]; if (c) return { code: c, name: c + ' · ' + (PRO.names[c] || '') }; }
    return null;
  }
  const pct = (x) => Math.round(x * 100) + '%';
  function proLine(pm, k) {
    return pm.slice(0, k).map((x) => x.name + ' (' + pct(x.share) + ', thắng ' + pct(x.w / x.n) + ')').join(' · ');
  }
  function bookMoves(pos, names) {
    const pm = proMoves(pos);
    if (pm) return pm.filter((x) => x.share >= 0.05 && x.n >= 10).map((x) => x.m);
    if (PRO.pos || S.startFen) return [];
    if (names.length >= 10) return [];
    const legal = pos.legalMoves(), out = new Set();
    for (const line of BOOK) {
      if (line.length <= names.length) continue;
      let ok = true;
      for (let i = 0; i < names.length; i++) if (line[i] !== names[i]) { ok = false; break; }
      if (!ok) continue;
      const m = legal.find((x) => pos.moveName(x) === line[names.length]);
      if (m !== undefined) out.add(m);
    }
    return [...out];
  }
  function openingOf(names) {
    if (S.startFen) return null;
    const e = ecoOf();
    if (e) { const old = oldOpening(names); return { name: e.name, tip: old && old.tip }; }
    return oldOpening(names);
  }
  function oldOpening(names) {
    let best = null;
    for (const o of OPENINGS) {
      if (o.seq.length > names.length) continue;
      if (o.seq.every((x, i) => names[i] === x) && (!best || o.seq.length > best.seq.length)) best = o;
    }
    return best;
  }
  const histNames = () => S.hist.map((h) => h.name);
  const startPos = () => (S.startFen ? Pos.fromFen(S.startFen) : Pos.start());

  // ---------- Luyện khai cuộc theo cây nước đại sư ----------
  const DRILL_OPS = [{ name: 'Tự do (theo đại sư)', seq: [] }].concat(OPENINGS.filter((o, i) => OPENINGS.findIndex((x) => x.name === o.name) === i));
  const DRILL_MIN = 20; // thế cờ có ít hơn số ván này coi như đã ra khỏi sách
  const bookTot = (pm) => (pm ? pm.reduce((s, x) => s + x.n, 0) : 0);
  // nước chấp nhận được: ≥10% số ván, hoặc nằm trong top 3 và ≥3%
  function drillAccept(pm, m) {
    const sorted = pm.slice().sort((a, b) => b.n - a.n), x = sorted.find((y) => y.m === m);
    if (!x) return null;
    const rank = sorted.indexOf(x);
    return x.share >= 0.1 || (rank < 3 && x.share >= 0.03) ? { x, rank, top: sorted[0] } : null;
  }
  function startDrill(k) {
    if (!PRO.pos) return;
    const op = DRILL_OPS[k] || DRILL_OPS[0];
    S.tok++; engine.reset(); S.startFen = null; S.gameTitle = null;
    S.pos = Pos.start(); S.hist = []; S.selected = -1; S.arrows = []; S.view = -1; S.result = null;
    S.hintsUsed = 0; S.lastScore = 0;
    for (const nm of op.seq) {
      const m = S.pos.legalMoves().find((x) => S.pos.moveName(x) === nm);
      if (m === undefined) break;
      const before = S.pos.clone(); S.pos.make(m);
      S.hist.push({ m, name: nm, by: 'ai', before }); // nước dựng sẵn của khai cuộc, không tính là nước của người chơi
    }
    S.drill = { name: op.name, ok: 0, tot: 0, fails: 0 };
    const lines = [
      'Bạn cầm ' + sideName(S.userSide) + '. Máy đi theo các nước đại sư hay chơi; bạn hãy đáp bằng nước phổ biến (≥10% số ván, hoặc nằm trong top 3).',
      'Đi nước hiếm hoặc ngoài sách sẽ được đi lại. Bấm "Gợi ý" để xem đại sư thường đi gì.',
    ];
    if (op.tip) lines.push(op.name + ': ' + op.tip);
    S.coach = { title: '📖 Luyện khai cuộc: ' + op.name, cls: null, lines };
    save(); drillNext();
  }
  function stopDrill(msg) {
    S.drill = null; S.arrows = [];
    if (msg) S.coach = { title: 'Đã dừng luyện khai cuộc', cls: null, lines: ['Ván tiếp tục như đấu thường: máy đánh theo cấp độ đã chọn, thầy chấm từng nước.'] };
    if (checkOver()) return;
    if (S.pos.side === S.userSide) startUserTurn(); else aiTurn();
  }
  function drillNext() {
    const pm = proMoves(S.pos);
    if (bookTot(pm) < DRILL_MIN) return drillEnd();
    if (S.pos.side === S.userSide) { S.state = 'user'; S.selected = -1; S.drill.fails = 0; render(); }
    else drillReply(pm);
  }
  async function drillReply(pm) {
    const tok = S.tok;
    S.state = 'ai'; render();
    await sleep(450); if (tok !== S.tok || !S.drill) return;
    // chọn theo tần suất đại sư, bỏ các nước quá hiếm
    const pool = pm.filter((x) => x.n >= 3 && x.share >= 0.03), ws = pool.length ? pool : pm;
    let r0 = Math.random() * ws.reduce((s, x) => s + x.n, 0), pick = ws[ws.length - 1];
    for (const x of ws) { r0 -= x.n; if (r0 <= 0) { pick = x; break; } }
    const before = S.pos.clone(), name = S.pos.moveName(pick.m);
    S.pos.make(pick.m); S.hist.push({ m: pick.m, name, by: 'ai', before });
    if (S.coach && !S.coach.busy) S.coach.lines.push('Máy đáp: ' + name + ' (' + pct(pick.share) + ' số ván đại sư).');
    save(); drillNext();
  }
  function onDrillMove(m) {
    const pm = proMoves(S.pos) || [], name = S.pos.moveName(m), d = S.drill;
    const ok = drillAccept(pm, m);
    if (!ok) {
      d.fails++;
      const y = pm.find((z) => z.m === m);
      const lines = [y ? name + ' chỉ có ' + y.n.toLocaleString('vi') + ' ván (' + pct(y.share) + '): đại sư ít chọn nước này.' : name + ' không có trong ván đại sư nào ở thế cờ này.'];
      if (d.fails >= 2) {
        lines.push('Đại sư thường đi: ' + proLine(pm, 3) + '. Mũi tên xanh là nước chính.');
        S.arrows = pm.slice(0, 3).map((x, i) => ({ m: x.m, kind: i ? 'alt' : 'best' }));
      } else {
        lines.push('Hãy thử lại. Bấm "Gợi ý" nếu chưa nhớ.');
        S.arrows = [{ m, kind: 'bad' }];
      }
      S.coach = { title: '✗ ' + name + ': ' + (y ? 'nước hiếm' : 'ngoài sách'), cls: 'mistake', lines };
      sfx('fail');
      S.selected = -1; render(); return;
    }
    d.tot++; if (d.fails === 0) d.ok++;
    const { x, rank, top } = ok;
    const before = S.pos.clone();
    S.pos.make(m);
    const lines = [(rank === 0 ? 'Nước chính' : 'Nước phổ biến') + ': ' + x.n.toLocaleString('vi') + ' ván đại sư (' + pct(x.share) + '), bên đi thắng ' + pct(x.w / x.n) + ', hòa ' + pct(x.d / x.n) + '.'];
    if (rank > 0) lines.push('Nước chính ở thế này: ' + top.name + ' (' + pct(top.share) + ').');
    if (d.fails) lines.push('(Đúng sau ' + d.fails + ' lần thử.)');
    const coach = { title: (rank === 0 ? '★ ' : '📖 ') + name + ': nước của đại sư', cls: rank === 0 ? 'best' : 'book', lines };
    S.hist.push({ m, name, by: 'user', before, cls: d.fails ? 'inacc' : rank === 0 ? 'best' : 'book', coach: { title: coach.title, cls: coach.cls, lines } });
    S.coach = coach; S.arrows = [];
    save(); render(); drillNext();
  }
  function drillHint() {
    const pm = proMoves(S.pos) || [];
    S.hintsUsed++; S.drill.fails = Math.max(S.drill.fails, 1);
    S.arrows = pm.slice(0, 3).map((x, i) => ({ m: x.m, kind: i ? 'alt' : 'best' }));
    S.coach = { title: '💡 Đại sư thường đi', cls: null, lines: [proLine(pm, 3) + '.', 'Mũi tên xanh là nước chính, mũi tên vàng là các nước phổ biến khác.'] };
    render();
  }
  function drillEnd() {
    const d = S.drill; S.drill = null;
    const lines = ['Thế cờ đã ra khỏi sách (ít hơn ' + DRILL_MIN + ' ván đại sư).'];
    if (d.tot) lines.push('Bạn đi đúng ngay lần đầu ' + d.ok + '/' + d.tot + ' nước (' + pct(d.ok / d.tot) + ').');
    const eco = ecoOf(); if (eco) lines.push('Thế trận: ' + eco.name + '.');
    lines.push('Ván tiếp tục: từ đây máy đánh theo cấp độ đã chọn và thầy chấm từng nước như bình thường. Bấm "Luyện khai cuộc" để luyện lại.');
    S.coach = { title: '🏁 Hết sách khai cuộc: ' + d.name, cls: null, lines };
    stopDrill(false);
  }

  // ---------- Ván từ thế cờ bất kỳ: tàn cục đại sư, ván/thế cờ nhập vào ----------
  // ghi ván vào bộ nhớ rồi chuyển sang chế độ đấu: restore() sẽ dựng lại và cho máy/người đi tiếp
  // mine: các nước có sẵn là của người chơi (ván nhập vào) hay của người khác (ván đại sư)
  // hold: giữ nguyên thế cờ (máy không đi tiếp) cho tới khi người chơi phân tích hoặc đi nước
  function playFrom({ fen, moves, side, title, lines, mine, hold }) {
    store.set('game', { side, fen: fen || null, title: title || null, moves: moves.map((m, i) => ({ m, by: null, i })), hints: 0 });
    // gán người đi cho từng nước theo bên cầm quân
    const p = fen ? Pos.fromFen(fen) : Pos.start();
    const g = store.get('game');
    g.moves.forEach((e) => { e.by = mine && p.side === side ? 'user' : 'ai'; delete e.i; p.make(e.m); });
    store.set('game', g);
    S.pendingCoach = { title: title || 'Ván mới từ thế cờ', cls: null, lines };
    S.hold = !!hold;
    if (S.mode === 'play') { S.tok++; engine.reset(); if (!restore()) newGame(); }
    else setMode('play');
  }
  const CLS_ACC = { best: 100, book: 100, good: 90, inacc: 65, mistake: 35, blunder: 5 };
  function classify(loss, isBest, isBook, userScore, bestScore) {
    let cls;
    if (isBest) cls = 'best';
    else if (isBook && loss <= 120) cls = 'book';
    else if (loss <= 20) cls = 'best';
    else if (loss <= 60) cls = 'good';
    else if (loss <= 150) cls = 'inacc';
    else if (loss <= 320) cls = 'mistake';
    else cls = 'blunder';
    // đang thắng/thua quá rõ thì không bắt lỗi khắt khe
    if (clampS(userScore) > 1500 && cls !== 'blunder' && !(bestScore > MATE - 500 && userScore < MATE - 500)) cls = cls === 'best' ? 'best' : 'good';
    if (bestScore > MATE - 500 && userScore < MATE - 500 && cls !== 'blunder') cls = 'mistake';
    return cls;
  }
  // chấm lại từng nước của người chơi trong ván (ván nhập vào chưa có điểm)
  async function analyzeGame() {
    const todo = S.hist.map((h, i) => [h, i]).filter(([h]) => h.by === 'user' && !h.cls);
    if (!todo.length) return;
    const tok = ++S.tok; engine.reset();
    S.state = 'analyze'; S.view = -1; S.arrows = [];
    let saved = 0;
    for (let k = 0; k < todo.length; k++) {
      const [h] = todo[k];
      S.coach = { title: 'Đang phân tích ván… ' + (k + 1) + '/' + todo.length, cls: null, lines: ['Máy chấm từng nước của bạn (khoảng 1 giây mỗi nước). Có thể bấm vào các nước đã chấm để xem.'], busy: true };
      render();
      const before = h.before, after = before.clone(); after.make(h.m);
      const rb = await engine.analyse(before.clone(), { timeMs: 700, multipv: 1 });
      if (tok !== S.tok || !rb || !rb.multi[0]) return;
      const best = rb.multi[0];
      let userScore = best.score, reply = null;
      if (h.m !== best.move) {
        if (!after.legalMoves().length) userScore = MATE - 1;
        else {
          const ra = await engine.analyse(after.clone(), { timeMs: 500, multipv: 1 });
          if (tok !== S.tok || !ra) return;
          userScore = ra.multi[0] ? -ra.multi[0].score : 0; reply = ra.multi[0] && ra.multi[0].move;
        }
      }
      const loss = Math.max(0, clampS(best.score) - clampS(userScore));
      const pm = proMoves(before), bx = pm && pm.find((y) => y.m === h.m);
      const cls = classify(loss, h.m === best.move, !!(bx && bx.share >= 0.05 && bx.n >= 10), userScore, best.score);
      h.cls = cls; h.loss = loss; h.acc = Math.round(100 * Math.exp(-loss / 280));
      h.best = best.move; h.bestName = before.moveName(best.move);
      const lines = [];
      if (cls === 'best' || cls === 'book' || cls === 'good') {
        if (bx) lines.push('Nước của đại sư: ' + bx.n.toLocaleString('vi') + ' ván (' + pct(bx.share) + ').');
        lines.push(...explain(before, h.m, userScore).map((x) => '• ' + x));
        if (cls === 'good' && h.m !== best.move) lines.push('Máy thích ' + h.bestName + ' hơn một chút.');
      } else {
        lines.push('Bạn mất khoảng ' + (loss / 100).toFixed(1) + ' Tốt lợi thế.');
        if (reply && after.isLegal(reply)) lines.push('Vì đối phương có thể đáp ' + after.moveName(reply) + ': ' + lc(explain(after, reply, undefined, { short: true }).join(' ')));
        lines.push('Nước tốt hơn: ' + h.bestName + '.');
        if (pm && pm.length) lines.push('Đại sư thường đi: ' + proLine(pm, 3) + '.');
        lines.push(...explain(before, best.move, best.score).map((x) => '• ' + x));
        if ((cls === 'mistake' || cls === 'blunder') && addReview(before, h.m, best.move, loss)) saved++;
      }
      h.coach = { title: CLS[cls].icon + ' ' + h.name + ': ' + CLS[cls].label, cls, lines };
      save();
    }
    const mine = S.hist.filter((h) => h.by === 'user' && h.cls);
    const cnt = {}; let acc = 0;
    for (const h of mine) { cnt[h.cls] = (cnt[h.cls] || 0) + 1; acc += h.acc != null ? h.acc : CLS_ACC[h.cls]; }
    const lines = ['Độ chính xác của bạn: ' + Math.round(acc / mine.length) + '%', Object.keys(CLS).filter((k) => cnt[k]).map((k) => CLS[k].icon + ' ' + CLS[k].short + ': ' + cnt[k]).join(' · ')];
    lines.push('Bấm vào các nước đánh dấu ? hoặc ?? trong danh sách nước đi để xem nên đi thế nào.');
    if (saved) lines.push('📌 ' + saved + ' thế cờ đi sai đã được lưu vào "Ôn lỗi sai của bạn" (tab Bài tập).');
    S.coach = { title: 'Phân tích xong', cls: null, lines };
    if (checkOver()) { S.coach = { title: 'Phân tích xong', cls: null, lines: [S.result.text].concat(lines) }; render(); }
    else if (S.pos.side === S.userSide) startUserTurn(); else aiTurn();
  }
  function importGame(text, side) {
    const r = Notation.parse(text);
    if (r.err) return r.err;
    const start = r.fen ? Pos.fromFen(r.fen) : Pos.start();
    const end = start.clone(); for (const m of r.moves) end.make(m);
    const s = side === 'move' ? end.side : +side;
    const lines = [];
    lines.push(r.moves.length ? 'Đã nhập ' + r.moves.length + ' nửa nước' + (r.fen ? ' từ thế cờ FEN' : '') + '. Bạn cầm ' + sideName(s) + '.' : 'Đã nhập thế cờ. Bạn cầm ' + sideName(s) + '.');
    if (r.warn) lines.push('⚠️ ' + r.warn);
    if (r.moves.length) lines.push('Bấm "Phân tích ván" để thầy chấm từng nước của bạn; các nước sai sẽ vào sổ "Ôn lỗi sai". Hoặc cứ đánh tiếp với máy.');
    else lines.push('Đánh tiếp với máy từ thế này. Thầy chấm từng nước như bình thường.');
    playFrom({ fen: r.fen, moves: r.moves, side: s, title: 'Ván nhập vào', lines, mine: true });
    return null;
  }


  // ---------- Chơi online (không cần tài khoản) ----------
  // máy chủ: server/online.js. Máy này giữ một mã bí mật (token) để vào lại ván khi mất kết nối.
  const OL_TC = ['3+2', '5+3', '10+5', '15+10', '30+0'];
  const OL_REASON = { mate: 'chiếu bí', stalemate: 'hết nước đi', time: 'hết giờ', resign: 'đầu hàng', agreement: 'hai bên thỏa thuận hòa', repetition: 'lặp lại thế cờ 3 lần', length: 'ván cờ quá dài' };
  function randToken() {
    const a = new Uint8Array(18); crypto.getRandomValues(a);
    return btoa(String.fromCharCode(...a)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  const OL = { token: store.get('olToken', null), name: store.get('olName', ''), tc: store.get('olTc', '10+5'), room: store.get('olRoom', null), side: 0, st: null, es: null, recvAt: 0, err: '', busy: false, kind: null };
  if (!OL.token || !/^[A-Za-z0-9_-]{16,64}$/.test(OL.token)) { OL.token = randToken(); store.set('olToken', OL.token); }
  async function olPost(path, body) {
    try {
      const r = await fetch('api/online/' + path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(Object.assign({ token: OL.token }, body)) });
      const d = await r.json().catch(() => ({}));
      return Object.assign({ st: r.status }, d);
    } catch (e) { return { st: 0, error: 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.' }; }
  }
  function olSetRoom(room) { OL.room = room; if (room) store.set('olRoom', room); else { try { localStorage.removeItem('cotuong.olRoom'); } catch (e) { /* bỏ qua */ } } }
  async function olStart(kind, code) {
    if (OL.busy) return;
    OL.name = $('olName').value.trim().slice(0, 20); store.set('olName', OL.name);
    OL.tc = $('olTc').value; store.set('olTc', OL.tc);
    OL.busy = true; OL.err = ''; renderOnline();
    const body = { name: OL.name, tc: OL.tc };
    const r = kind === 'quick' ? await olPost('quick', body) : kind === 'new' ? await olPost('new', body) : await olPost('join', Object.assign(body, { room: code }));
    OL.busy = false;
    if (r.st !== 200) { OL.err = r.error || 'Có lỗi xảy ra.'; renderOnline(); return; }
    OL.kind = kind;
    olSetRoom(r.room); olConnect();
  }
  function olClose() { if (OL.es) { OL.es.close(); OL.es = null; } }
  function olConnect() {
    olClose();
    if (!OL.room) return;
    const es = new EventSource('api/online/events?room=' + encodeURIComponent(OL.room) + '&token=' + encodeURIComponent(OL.token));
    OL.es = es;
    es.onmessage = (e) => { if (OL.es === es) olState(JSON.parse(e.data)); };
    es.onerror = async () => {
      if (OL.es !== es || OL.unloading) return;
      OL.offline = true; renderOnline();
      if (es.readyState !== EventSource.CLOSED) return; // lỗi mạng: trình duyệt tự kết nối lại
      // kết nối bị đóng hẳn: hỏi máy chủ phòng còn không rồi mới bỏ
      const room = OL.room, r = await olPost('join', { room, name: OL.name });
      if (OL.es !== es || OL.room !== room) return;
      if (r.st === 404) olGone('Phòng ' + room + ' không còn (đã hết hạn hoặc máy chủ vừa khởi động lại).');
      else setTimeout(() => { if (OL.es === es && OL.room === room) olConnect(); }, 2000);
    };
    es.onopen = () => { OL.offline = false; };
  }
  function olGone(msg) {
    olClose(); olSetRoom(null); OL.st = null; OL.side = 0;
    OL.err = msg || '';
    S.pos = Pos.start(); S.hist = []; S.arrows = []; S.selected = -1; S.state = 'online-lobby'; S.userSide = RED;
    S.coach = { title: 'Chơi online', cls: null, lines: ['Chọn "Tìm đối thủ ngẫu nhiên" để chơi ngay với người đang chờ, hoặc tạo phòng rồi gửi mã/link cho bạn bè.', 'Không cần tài khoản. Trong ván không có gợi ý của máy; sau ván có thể nhờ Pikafish phân tích.'] };
    render();
  }
  function olState(st) {
    if (st.status === 'closed') return olGone('Phòng đã đóng.');
    const prev = OL.st;
    OL.st = st; OL.recvAt = Date.now(); OL.offline = false;
    OL.side = st.you || 0;
    S.userSide = OL.side || RED;
    // dựng lại bàn cờ từ danh sách nước
    if (!prev || prev.moves.length !== st.moves.length || prev.moves.some((m, i) => m !== st.moves[i]) || prev.room !== st.room) {
      const p = Pos.start(), hist = [];
      for (const m of st.moves) { const b = p.clone(); hist.push({ m, name: p.moveName(m), by: b.side === OL.side ? 'user' : 'ai', before: b }); p.make(m); }
      S.pos = p; S.hist = hist; S.selected = -1; S.view = -1;
    }
    S.arrows = [];
    const myTurn = st.status === 'playing' && OL.side && S.pos.side === OL.side;
    S.state = myTurn ? 'user' : 'online-wait';
    S.coach = olCoach(st);
    if (st.status === 'over' && prev && prev.status !== 'over' && prev.room === st.room) {
      const w = st.result.winner;
      sfx(OL.side && w === sk(OL.side) ? 'win' : 'end', 300);
    }
    if (myTurn && document.hidden) document.title = '● Đến lượt bạn · Cờ Tướng';
    render();
  }
  addEventListener('pagehide', () => { OL.unloading = true; });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) document.title = 'Cờ Tướng: luyện cùng máy'; });
  const sk = (s) => (s === RED ? 'r' : 'b');
  const olName = (st, side) => st.names[sk(side)] || (st.status === 'waiting' ? 'Đang chờ…' : '?');
  function olCoach(st) {
    const me = OL.side, opp = -me || BLACK;
    if (st.status === 'waiting') {
      return { title: OL.kind === 'quick' || st.quick ? 'Đang tìm đối thủ…' : 'Phòng ' + st.room + ': đang chờ bạn bè', cls: null, busy: true,
        lines: st.quick ? ['Ván ' + st.tc + '. Ván bắt đầu ngay khi có người cùng tìm đối thủ với thời gian này.'] : ['Gửi mã phòng ' + st.room + ' hoặc đường link bên dưới cho bạn bè. Ván bắt đầu khi bạn bè vào phòng.', 'Bạn cầm ' + sideName(me) + ' · thời gian ' + st.tc + '.'] };
    }
    if (st.status === 'over') {
      const w = st.result.winner === 'r' ? RED : st.result.winner === 'b' ? BLACK : 0;
      const why = OL_REASON[st.result.reason] || '';
      const title = !w ? 'Hòa (' + why + ')' : !me ? sideName(w) + ' thắng (' + why + ')' : w === me ? '🎉 Bạn thắng! (' + why + ')' : 'Bạn thua (' + why + ')';
      const lines = ['Bấm "Phân tích ván này" để Pikafish chấm từng nước của bạn; các nước sai sẽ vào sổ "Ôn lỗi sai".'];
      if (st.rematch[sk(opp)] && !st.rematch[sk(me)]) lines.unshift('Đối thủ muốn chơi ván mới.');
      else if (st.rematch[sk(me)]) lines.unshift('Đang chờ đối thủ đồng ý chơi ván mới…');
      return { title, cls: !w ? null : w === me ? 'best' : 'mistake', lines };
    }
    if (!me) return { title: 'Đang xem: ' + olName(st, RED) + ' – ' + olName(st, BLACK), cls: null, lines: ['Bạn đang xem ván (phòng đã đủ hai người).'] };
    const lines = [];
    if (st.drawOffer === sk(opp)) lines.push('Đối thủ đề nghị hòa.');
    if (st.drawOffer === sk(me)) lines.push('Đã đề nghị hòa, đang chờ đối thủ trả lời.');
    if (!st.online[sk(opp)]) lines.push('Đối thủ đang mất kết nối. Đồng hồ của họ vẫn chạy.');
    const last = S.hist[S.hist.length - 1];
    const title = S.pos.side === me ? (S.pos.inCheck(me) ? 'Bạn đang bị chiếu!' : 'Đến lượt bạn') : 'Đối thủ đang nghĩ…';
    if (last) lines.unshift('Nước vừa đi: ' + (last.by === 'user' ? 'Bạn' : olName(st, -me)) + ' · ' + last.name);
    return { title, cls: null, lines };
  }
  async function olMove(m) {
    const st = OL.st; if (!st) return;
    const ply = S.hist.length;
    // hiện ngay trên bàn cờ, máy chủ xác nhận sau
    const before = S.pos.clone(), name = S.pos.moveName(m);
    S.pos.make(m); S.hist.push({ m, name, by: 'user', before });
    S.selected = -1; S.state = 'online-wait';
    S.coach = { title: 'Đối thủ đang nghĩ…', cls: null, lines: ['Bạn đi: ' + name] };
    render();
    const r = await olPost('act', { room: st.room, act: 'move', move: m, ply });
    if (r.st !== 200) { OL.err = r.error || ''; if (r.state) { OL.st = null; olState(r.state); } else if (OL.st) { const s2 = OL.st; OL.st = null; olState(s2); } renderOnline(); }
  }
  async function olAct(act) {
    if (!OL.room) return;
    if (act === 'resign' && !confirm('Đầu hàng ván này?')) return;
    if (act === 'leave') {
      if (OL.st && OL.st.status === 'playing' && OL.side && !confirm('Rời phòng khi đang chơi sẽ bị xử thua. Rời phòng?')) return;
      await olPost('act', { room: OL.room, act: 'leave' });
      return olGone('');
    }
    const r = await olPost('act', { room: OL.room, act });
    if (r.st !== 200) { OL.err = r.error || ''; renderOnline(); }
  }
  function olAnalyze() {
    const st = OL.st; if (!st) return;
    olClose();
    playFrom({ moves: st.moves, side: OL.side || RED, title: 'Ván online ' + olName(st, RED) + ' – ' + olName(st, BLACK), mine: true, hold: true,
      lines: ['Đã chép ván online (' + st.moves.length + ' nửa nước) sang "Đấu với máy".', 'Bấm "Phân tích ván" để Pikafish chấm từng nước của bạn.'] });
  }
  const fmtClock = (ms) => { const t = Math.max(0, Math.ceil(ms / 1000)); return Math.floor(t / 60) + ':' + String(t % 60).padStart(2, '0'); };
  function olClock(side) {
    const st = OL.st; if (!st) return 0;
    const k = sk(side), v = st.clock[k];
    return st.running === k ? v - (Date.now() - OL.recvAt) : v;
  }
  function olPlayerRow(side, isMe) {
    const st = OL.st, k = sk(side), ms = olClock(side), on = st.online[k];
    const running = st.running === k;
    return `<div class="ol-player${running ? ' run' : ''}${ms < 20000 && st.status === 'playing' ? ' low' : ''}">` +
      `<span class="ol-dot ${side === RED ? 'r' : 'b'}"></span><span class="ol-name">${esc(olName(st, side))}${isMe ? ' (bạn)' : ''}${st.names[k] && !on ? ' <i class="muted small">mất kết nối</i>' : ''}</span>` +
      `<span class="ol-clock" data-clock="${side}">${fmtClock(ms)}</span></div>`;
  }
  function renderOnline() {
    if (S.mode !== 'online') return;
    const st = OL.st, inRoom = !!OL.room;
    $('olLobby').hidden = inRoom; $('olGame').hidden = !inRoom;
    $('olErr').textContent = OL.err || '';
    $('olErr2').textContent = (OL.offline ? 'Mất kết nối, đang kết nối lại… ' : '') + (inRoom ? OL.err || '' : '');
    for (const b of document.querySelectorAll('#olLobby button')) b.disabled = OL.busy;
    if (!inRoom) { if ($('olName').value === '' && OL.name) $('olName').value = OL.name; $('olTc').value = OL.tc; $('olInfo').textContent = ''; return; }
    if (!st) { $('olPlayers').innerHTML = '<div class="muted small">Đang vào phòng ' + esc(OL.room) + '…</div>'; $('olActions').innerHTML = ''; $('olShare').innerHTML = ''; return; }
    $('olInfo').textContent = 'Phòng ' + st.room + ' · ' + st.tc + (st.watchers ? ' · ' + st.watchers + ' người xem' : '');
    const bottom = OL.side || RED;
    $('olPlayers').innerHTML = olPlayerRow(-bottom, false) + olPlayerRow(bottom, !!OL.side);
    const link = location.origin + location.pathname + '?p=' + st.room;
    $('olShare').innerHTML = st.status === 'waiting' && !st.quick
      ? `<div class="ol-code">Mã phòng <b>${esc(st.room)}</b></div><div class="ol-link"><input class="full" readonly value="${esc(link)}"><button class="btn" data-act="ol-copy">Chép link</button></div>` : '';
    const b = [], me = OL.side, opp = -me;
    if (st.status === 'playing' && me) {
      if (st.drawOffer === sk(opp)) b.push('<button class="btn primary" data-act="ol-accept">Đồng ý hòa</button><button class="btn" data-act="ol-decline">Từ chối</button>');
      else b.push('<button class="btn" data-act="ol-draw"' + (st.drawOffer === sk(me) ? ' disabled' : '') + '>½ Xin hòa</button>');
      b.push('<button class="btn" data-act="ol-resign">⚑ Đầu hàng</button>');
    }
    if (st.status === 'over') {
      if (me) b.push('<button class="btn primary" data-act="ol-rematch"' + (st.rematch[sk(me)] ? ' disabled' : '') + '>' + (st.rematch[sk(opp)] ? 'Đồng ý ván mới' : 'Ván mới (đổi bên)') + '</button>');
      b.push('<button class="btn" data-act="ol-analyze">Phân tích ván này</button>');
    }
    b.push('<button class="btn" data-act="ol-leave">' + (st.status === 'waiting' ? 'Hủy' : 'Rời phòng') + '</button>');
    const html = b.join('');
    if ($('olActions').dataset.sig !== html) { $('olActions').innerHTML = html; $('olActions').dataset.sig = html; }
  }
  // đồng hồ chạy
  setInterval(() => {
    if (S.mode !== 'online' || !OL.st || OL.st.status !== 'playing') return;
    for (const el of document.querySelectorAll('[data-clock]')) {
      const ms = olClock(+el.dataset.clock); el.textContent = fmtClock(ms);
      el.parentElement.classList.toggle('low', ms < 20000);
    }
  }, 250);
  function olEnter() {
    S.pos = Pos.start(); S.hist = []; S.arrows = []; S.selected = -1; S.view = -1;
    S.state = 'online-lobby';
    if (OL.pendingJoin) { const c = OL.pendingJoin; OL.pendingJoin = null; olGone(''); olStart('join', c); return; }
    if (OL.room) { S.coach = { title: 'Đang vào lại phòng ' + OL.room + '…', cls: null, lines: [], busy: true }; OL.st = null; render(); olConnect(); }
    else olGone('');
  }

  // ---------- Luồng ván cờ ----------
  function save() {
    if (S.mode !== 'play') return;
    store.set('game', { side: S.userSide, fen: S.startFen, title: S.gameTitle, moves: S.hist.map((h) => ({ m: h.m, by: h.by, cls: h.cls, coach: h.coach })), hints: S.hintsUsed });
  }
  function newGame(keepSide) {
    S.tok++; engine.reset(); S.drill = null; S.startFen = null; S.gameTitle = null;
    if (!keepSide) S.userSide = store.get('side', RED);
    S.pos = Pos.start(); S.hist = []; S.selected = -1; S.arrows = []; S.view = -1; S.result = null;
    S.hintsUsed = 0; S.lastScore = 0;
    S.coach = { title: 'Bắt đầu ván mới', cls: null, lines: ['Bạn cầm quân ' + sideName(S.userSide) + '. ' + (S.userSide === RED ? 'Bạn đi trước.' : 'Máy đi trước.'), 'Bấm "Gợi ý" bất cứ lúc nào để xem nước nên đi và lý do. Sau mỗi nước, thầy sẽ chấm điểm nước của bạn.'] };
    save(); render();
    if (S.pos.side === S.userSide) startUserTurn(); else aiTurn();
  }
  function restore() {
    const g = store.get('game', null);
    const hold = S.hold; S.hold = false; // chỉ áp dụng cho lần khôi phục ngay sau playFrom
    S.drill = null;
    if (!g || !g.moves || (!g.moves.length && !g.fen)) return false;
    try {
      S.userSide = g.side; S.startFen = g.fen || null; S.gameTitle = g.title || null; S.pos = startPos(); S.hist = [];
      for (const e of g.moves) {
        if (!S.pos.isLegal(e.m)) throw new Error('bad');
        const before = S.pos.clone();
        S.hist.push({ m: e.m, by: e.by, cls: e.cls, coach: e.coach, name: S.pos.moveName(e.m), before });
        S.pos.make(e.m);
      }
      S.hintsUsed = g.hints || 0;
      // nếu đang chờ xác nhận nước hỏng thì coi như đã đi
      S.coach = S.pendingCoach || { title: 'Tiếp tục ván cũ', cls: null, lines: ['Ván cờ trước đã được khôi phục.' + (S.gameTitle ? ' (' + S.gameTitle + ')' : '')] };
      S.pendingCoach = null;
      render();
      if (hold && S.pos.side !== S.userSide && S.pos.legalMoves().length) { S.state = 'user'; S.result = null; render(); }
      else if (!checkOver()) { if (S.pos.side === S.userSide) startUserTurn(); else aiTurn(); }
      return true;
    } catch (e) { S.startFen = null; S.gameTitle = null; return false; }
  }

  function checkOver() {
    const pos = S.pos;
    if (pos.legalMoves().length === 0) {
      const winner = -pos.side;
      const inC = pos.inCheck(pos.side);
      S.result = { winner, text: (winner === S.userSide ? 'Bạn thắng! ' : 'Máy thắng. ') + (inC ? 'Chiếu bí.' : 'Hết nước đi.') };
    } else if (pos.repCount() >= 3) {
      S.result = { winner: 0, text: 'Hòa do lặp lại thế cờ 3 lần.' };
    } else if (S.hist.length >= 300) {
      S.result = { winner: 0, text: 'Hòa do ván cờ quá dài.' };
    }
    if (S.result) { S.state = 'over'; S.arrows = []; S.coach = summaryCoach(); save(); render(); sfx(S.result.winner === S.userSide ? 'win' : 'end', 480); return true; }
    return false;
  }
  function summaryCoach() {
    const mine = S.hist.filter((h) => h.by === 'user' && h.cls);
    const cnt = {}; let acc = 0;
    for (const h of mine) { cnt[h.cls] = (cnt[h.cls] || 0) + 1; acc += h.acc != null ? h.acc : ({ best: 100, book: 100, good: 90, inacc: 65, mistake: 35, blunder: 5 })[h.cls]; }
    const lines = [S.result.text];
    if (mine.length) {
      lines.push('Độ chính xác của bạn: ' + Math.round(acc / mine.length) + '%');
      lines.push(Object.keys(CLS).filter((k) => cnt[k]).map((k) => CLS[k].icon + ' ' + CLS[k].short + ': ' + cnt[k]).join(' · '));
      const bad = S.hist.map((h, i) => [h, i]).filter(([h]) => h.by === 'user' && (h.cls === 'mistake' || h.cls === 'blunder'));
      if (bad.length) lines.push('Bấm vào các nước đánh dấu ? hoặc ?? trong danh sách nước đi để xem lại nên đi thế nào. ' + bad.length + ' thế cờ đi sai đã được lưu vào "Ôn lỗi sai của bạn" ở tab Bài tập.');
    }
    if (S.hintsUsed) lines.push('Số lần dùng gợi ý: ' + S.hintsUsed);
    return { title: 'Kết thúc ván', cls: null, lines };
  }

  function startUserTurn() {
    S.state = 'user'; S.selected = -1;
    const pos = S.pos.clone(), tok = S.tok;
    S.pre = { tok, p: engine.analyse(pos, { timeMs: COACH_MS, multipv: 3 }) };
    S.pre.p.then((r) => { if (r && tok === S.tok && S.state === 'user') { S.lastScore = r.multi[0] ? r.multi[0].score : 0; renderEval(); } });
    render();
  }

  async function onUserMove(m) {
    const tok = S.tok, pos = S.pos, before = pos.clone();
    const name = pos.moveName(m), names = histNames();
    const book = bookMoves(before, names);
    const preP = S.pre.p;
    pos.make(m);
    const entry = { m, name, by: 'user', before };
    S.hist.push(entry); S.state = 'ai'; S.selected = -1; S.arrows = [];
    S.coach = { title: 'Thầy đang xem nước của bạn…', cls: null, lines: [], busy: true };
    render();
    const over = pos.legalMoves().length === 0;
    const pre = await preP;
    if (tok !== S.tok || !pre) return;
    const best = pre.multi[0];
    let userScore, reply = null;
    const found = pre.multi.find((x) => x.move === m);
    if (over) userScore = MATE - 1;
    else if (found) { userScore = found.score; if (found.pv[1]) reply = found.pv[1]; }
    else {
      const r = await engine.analyse(pos.clone(), { timeMs: Math.round(COACH_MS * 0.8), multipv: 1 });
      if (tok !== S.tok || !r) return;
      userScore = -r.multi[0].score; reply = r.multi[0].move;
    }
    let loss = Math.max(0, clampS(best.score) - clampS(userScore));
    let cls;
    if (m === best.move) cls = 'best';
    else if (book.includes(m) && loss <= 120) cls = 'book';
    else if (loss <= 20) cls = 'best';
    else if (loss <= 60) cls = 'good';
    else if (loss <= 150) cls = 'inacc';
    else if (loss <= 320) cls = 'mistake';
    else cls = 'blunder';
    // đang thắng/thua quá rõ thì không bắt lỗi khắt khe
    if (clampS(userScore) > 1500 && cls !== 'blunder' && !(best.score > MATE - 500 && userScore < MATE - 500)) cls = cls === 'best' ? 'best' : 'good';
    if (best.score > MATE - 500 && userScore < MATE - 500 && cls !== 'blunder') cls = 'mistake';
    entry.cls = cls; entry.loss = loss; entry.acc = Math.round(100 * Math.exp(-loss / 280));
    entry.bestName = before.moveName(best.move); entry.best = best.move;
    S.lastScore = userScore;
    const saved = (cls === 'mistake' || cls === 'blunder') && addReview(before, m, best.move, loss);

    const lines = [];
    if (cls === 'best' || cls === 'book' || cls === 'good') {
      if (cls === 'best' && m === best.move) lines.push('Đúng nước máy chọn.');
      if (cls === 'book') {
        const pm = proMoves(before), x = pm && pm.find((y) => y.m === m);
        lines.push(x ? 'Nước của đại sư: ' + x.n.toLocaleString('vi') + ' ván giải đấu đã đi nước này (' + pct(x.share) + '), bên đi thắng ' + pct(x.w / x.n) + ', hòa ' + pct(x.d / x.n) + '.' : 'Nước đi theo bài bản khai cuộc.');
      }
      lines.push(...explain(before, m, userScore).map((x) => '• ' + x));
      if (cls === 'good' && m !== best.move) lines.push('Máy thích ' + entry.bestName + ' hơn một chút.');
    } else {
      lines.push('Bạn mất khoảng ' + (loss / 100).toFixed(1) + ' Tốt lợi thế.');
      if (reply) {
        const aft = pos.clone();
        if (aft.isLegal(reply)) lines.push('Vì đối phương có thể đáp ' + aft.moveName(reply) + ': ' + lc(explain(aft, reply, undefined, { short: true }).join(' ')));
      }
      lines.push('Nước tốt hơn: ' + entry.bestName + '.');
      const pmB = proMoves(before);
      if (pmB && pmB.length) lines.push('Đại sư thường đi: ' + proLine(pmB, 3) + '.');
      lines.push(...explain(before, best.move, best.score).map((x) => '• ' + x));
      if (saved) lines.push('📌 Đã lưu thế cờ này vào "Ôn lỗi sai của bạn" (tab Bài tập) để luyện lại.');
    }
    const op = openingOf(histNames());
    const coach = { title: CLS[cls].icon + ' ' + name + ': ' + CLS[cls].label, cls, lines, arrowsBest: cls === 'best' ? null : best.move, userMove: m };
    if (op && S.hist.length <= 30) coach.opening = op;
    entry.coach = { title: coach.title, cls, lines, opening: coach.opening && coach.opening.name };
    S.coach = coach;
    if (cls !== 'best' && cls !== 'book' && cls !== 'good') S.arrows = [{ m: best.move, kind: 'best', on: before }];
    save(); render();
    if (checkOver()) return;
    if (cls === 'blunder' && S.opt.warn) {
      S.state = 'confirm';
      S.coach.confirm = true;
      S.confirmPre = pre;
      render();
      return;
    }
    aiTurn();
  }

  function confirmBlunder(undo) {
    if (S.state !== 'confirm') return;
    if (undo) {
      S.pos.unmake(); S.hist.pop();
      const pre = S.confirmPre; S.arrows = [];
      S.state = 'user';
      S.pre = { tok: S.tok, p: Promise.resolve(pre) };
      S.coach = { title: 'Đã đi lại', cls: null, lines: ['Hãy tìm nước tốt hơn. Bấm "Gợi ý" nếu cần.'] };
      save(); render();
    } else {
      S.coach.confirm = false; S.arrows = [];
      aiTurn();
    }
  }

  async function aiTurn() {
    const tok = S.tok;
    if (checkOver()) return;
    S.state = 'ai'; render();
    const L = LEVELS[S.level], t0 = Date.now();
    const names = histNames();
    const pos = S.pos;
    const book = S.level >= 2 ? bookMoves(pos, names) : [];
    const pmA = S.level >= 2 ? proMoves(pos) : null;
    let move, score;
    if (pmA && pmA.length && pmA.reduce((s, x) => s + x.n, 0) >= 20 && Math.random() < 0.95) {
      // chọn nước theo tần suất đại sư; cấp cao ưu tiên nước có thành tích tốt
      const pool = pmA.filter((x) => x.n >= 3 && (S.level < 4 || (x.w + x.d / 2) / x.n >= 0.4));
      const ws = (pool.length ? pool : pmA).map((x) => [x, Math.pow(x.n, S.level >= 4 ? 1.4 : 1)]);
      let r0 = Math.random() * ws.reduce((s, x) => s + x[1], 0);
      move = ws[ws.length - 1][0].m;
      for (const [x, w] of ws) { r0 -= w; if (r0 <= 0) { move = x.m; break; } }
      const r = await engine.search(pos.clone(), { timeMs: 250, multipv: 1 });
      if (tok !== S.tok || !r) return;
      score = r.multi[0].score;
    } else if (book.length && Math.random() < 0.85) {
      move = book[(Math.random() * book.length) | 0];
      const r = await engine.search(pos.clone(), { timeMs: 250, multipv: 1 });
      if (tok !== S.tok || !r) return;
      score = r.multi[0].score;
    } else {
      const r = await engine.search(pos.clone(), L.opts);
      if (tok !== S.tok || !r) return;
      let cands = r.multi.filter((x) => x.score >= r.multi[0].score - L.margin && x.score > -MATE + 500);
      if (!cands.length) cands = [r.multi[0]];
      let pick = cands[(Math.random() * cands.length) | 0];
      if (r.multi[0].score > MATE - 500) pick = r.multi[0];
      else if (L.randomChance && Math.random() < L.randomChance && r.all.length > 1) {
        const safe = r.all.filter((x) => x.score > -MATE + 500);
        if (safe.length) pick = safe[(Math.random() * Math.min(safe.length, 10)) | 0];
      }
      move = pick.move; score = pick.score;
    }
    const wait = 450 - (Date.now() - t0);
    if (wait > 0) await new Promise((r) => setTimeout(r, wait));
    if (tok !== S.tok) return;
    const before = pos.clone(), name = pos.moveName(move);
    pos.make(move);
    S.hist.push({ m: move, name, by: 'ai', before });
    S.lastScore = -score;
    const op = openingOf(histNames());
    if (S.coach && !S.coach.busy && op && S.hist.length <= 30) S.coach.opening = op;
    save();
    if (!checkOver()) startUserTurn(); else render();
  }

  async function showHint() {
    if (S.state !== 'user' || S.view >= 0) return;
    const tok = S.tok, pos = S.pos.clone();
    S.hintsUsed++;
    S.coach = { title: 'Đang phân tích…', cls: null, lines: [], busy: true }; render();
    const pre = await S.pre.p;
    if (tok !== S.tok || !pre || S.state !== 'user') return;
    const lines = [];
    // mối đe dọa của đối phương (nước "miễn phí" nếu mình đứng yên)
    let threatLine = null;
    if (pos.inCheck(pos.side)) threatLine = 'Bạn đang bị chiếu! Phải đỡ chiếu trước.';
    else {
      const np = pos.clone(); np.makeNull();
      const t = await engine.search(np, { timeMs: 350, multipv: 1 });
      if (tok !== S.tok || !t) return;
      const tm = t.multi[0];
      if (tm && (tm.score + pre.multi[0].score > 150 || tm.score > MATE - 500)) {
        const what = lc(explain(np, tm.move, tm.score, { short: true }).join(' '));
        threatLine = 'Chú ý: đối phương đang dọa ' + np.moveName(tm.move) + ' (' + what.replace(/\.$/, '') + ').';
      }
    }
    if (threatLine) lines.push(threatLine);
    const book = bookMoves(pos, histNames());
    const best = pre.multi[0];
    lines.push('Nên đi: ' + pos.moveName(best.move) + '  (' + fmtScore(best.score) + ')');
    lines.push(...explain(pos, best.move, best.score).map((x) => '• ' + x));
    if (best.pv.length > 1) {
      const p2 = pos.clone(), seq = [];
      for (const mv of best.pv.slice(0, 5)) { if (!p2.isLegal(mv)) break; seq.push(p2.moveName(mv)); p2.make(mv); }
      if (seq.length > 1) lines.push('Diễn biến dự kiến: ' + seq.join(' → '));
    }
    const alts = pre.multi.slice(1).filter((x) => x.score > best.score - 120);
    if (alts.length) lines.push('Cũng được: ' + alts.map((x) => pos.moveName(x.move) + ' (' + fmtScore(x.score) + ')').join(', '));
    const pmH = proMoves(pos);
    if (pmH && pmH.length) lines.push('Đại sư thường đi: ' + proLine(pmH, 3) + '. Xem bảng "Khai cuộc đại sư" bên dưới.');
    else {
      const bookOnly = book.filter((m) => m !== best.move && !alts.some((a) => a.move === m));
      if (bookOnly.length) lines.push('Theo bài bản khai cuộc: ' + bookOnly.map((m) => pos.moveName(m)).join(', '));
    }
    S.arrows = [{ m: best.move, kind: 'best', on: pos }].concat(alts.map((x) => ({ m: x.move, kind: 'alt', on: pos })));
    S.coach = { title: '💡 Gợi ý', cls: null, lines };
    render();
  }

  function undo() {
    if (S.view >= 0) { S.view = -1; render(); return; }
    if (S.state === 'confirm') { confirmBlunder(true); return; }
    if (S.state !== 'user' && S.state !== 'over') return;
    // lùi về nước gần nhất của người chơi
    let i = S.hist.length - 1;
    while (i >= 0 && S.hist[i].by !== 'user') i--;
    if (i < 0) return;
    S.tok++; engine.reset();
    while (S.hist.length > i) { S.pos.unmake(); S.hist.pop(); }
    // pos.und không còn sau restore() → dựng lại từ đầu cho chắc
    rebuildPos();
    S.result = null; S.arrows = [];
    S.coach = { title: 'Đã đi lại', cls: null, lines: ['Hãy thử một nước khác.'] };
    if (S.drill) { S.drill.fails = 0; save(); render(); return drillNext(); }
    save(); startUserTurn();
  }
  function rebuildPos() {
    const p = startPos();
    for (const h of S.hist) { h.before = p.clone(); p.make(h.m); }
    S.pos = p;
  }

  // ---------- Giao diện ----------
  const $ = (id) => document.getElementById(id);
  const boardEl = $('board'), piecesEl = $('pieces'), overlay = $('overlay');
  const X0 = 50, Y0 = 100, CELL = 100, W = 900, H = 1100;
  const flipped = () => S.userSide === BLACK;
  function disp(sq) { let r = rowOf(sq), c = colOf(sq); if (flipped()) { r = 9 - r; c = 8 - c; } return [X0 + c * CELL, Y0 + r * CELL]; }

  function drawGrid() {
    const g = [];
    const L = (x1, y1, x2, y2) => g.push(`<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"/>`);
    for (let r = 0; r < 10; r++) L(X0, Y0 + r * CELL, X0 + 8 * CELL, Y0 + r * CELL);
    for (let c = 0; c < 9; c++) {
      if (c === 0 || c === 8) L(X0 + c * CELL, Y0, X0 + c * CELL, Y0 + 9 * CELL);
      else { L(X0 + c * CELL, Y0, X0 + c * CELL, Y0 + 4 * CELL); L(X0 + c * CELL, Y0 + 5 * CELL, X0 + c * CELL, Y0 + 9 * CELL); }
    }
    L(X0 + 3 * CELL, Y0, X0 + 5 * CELL, Y0 + 2 * CELL); L(X0 + 5 * CELL, Y0, X0 + 3 * CELL, Y0 + 2 * CELL);
    L(X0 + 3 * CELL, Y0 + 7 * CELL, X0 + 5 * CELL, Y0 + 9 * CELL); L(X0 + 5 * CELL, Y0 + 7 * CELL, X0 + 3 * CELL, Y0 + 9 * CELL);
    const mark = (r, c) => {
      const x = X0 + c * CELL, y = Y0 + r * CELL, d = 8, l = 18;
      for (const sx of [-1, 1]) {
        if ((c === 0 && sx < 0) || (c === 8 && sx > 0)) continue;
        for (const sy of [-1, 1]) g.push(`<polyline points="${x + sx * (d + l)},${y + sy * d} ${x + sx * d},${y + sy * d} ${x + sx * d},${y + sy * (d + l)}"/>`);
      }
    };
    for (const [r, c] of [[2, 1], [2, 7], [7, 1], [7, 7]]) mark(r, c);
    for (const r of [3, 6]) for (const c of [0, 2, 4, 6, 8]) mark(r, c);
    g.push(`<rect class="frame" x="${X0 - 12}" y="${Y0 - 12}" width="${8 * CELL + 24}" height="${9 * CELL + 24}"/>`);
    // số cột: mỗi bên đếm từ phải sang trái theo góc nhìn của mình
    const nums = [];
    for (let c = 0; c < 9; c++) {
      const x = X0 + c * CELL;
      nums.push(`<text class="num" x="${x}" y="40">${c + 1}</text>`);
      nums.push(`<text class="num" x="${x}" y="${H - 40}">${9 - c}</text>`);
    }
    $('grid').innerHTML = `<g class="lines">${g.join('')}</g>` +
      `<text class="river" x="${X0 + 2 * CELL}" y="${Y0 + 4.5 * CELL}">楚 河</text>` +
      `<text class="river" x="${X0 + 6 * CELL}" y="${Y0 + 4.5 * CELL}">漢 界</text>` + nums.join('');
  }

  let lastAnimated = null;
  function renderPieces() {
    const viewing = S.view >= 0;
    const pos = viewing ? S.hist[S.view].before : S.pos;
    const last = viewing ? null : S.hist[S.hist.length - 1];
    const html = [];
    const userTurn = S.state === 'user' && !viewing;
    const hang = S.opt.threats && userTurn ? hangingSet(pos, S.userSide) : [];
    const checkSq = pos.inCheck(pos.side) ? (pos.side > 0 ? pos.kR : pos.kB) : -1;
    for (let sq = 0; sq < 90; sq++) {
      const p = pos.b[sq]; if (!p) continue;
      const [x, y] = disp(sq), t = absT(p);
      const label = S.opt.han ? HAN[t][p > 0 ? 0 : 1] : VIET[t];
      const cls = ['piece', p > 0 ? 'red' : 'black', S.opt.han ? 'han' : 'viet'];
      if (sq === S.selected) cls.push('sel');
      if (hang.includes(sq)) cls.push('danger');
      if (sq === checkSq) cls.push('check');
      let style = `left:${(x / W) * 100}%;top:${(y / H) * 100}%`;
      if (last && sq === (last.m >> 7) && lastAnimated !== last) {
        const [fx, fy] = disp(last.m & 127);
        style += `;--dx:${((fx - x) / CELL) * 100}%;--dy:${((fy - y) / CELL) * 100}%`;
        cls.push('anim');
      }
      html.push(`<div class="${cls.join(' ')}" style="${style}" title="${nameOf(p)} ${sideName(sgn(p))}"><span>${label}</span></div>`);
    }
    if (last) lastAnimated = last;
    piecesEl.innerHTML = html.join('');
    sfxMove();
  }

  function arrowSvg(m, kind) {
    const [x1, y1] = disp(m & 127), [x2, y2] = disp(m >> 7);
    const dx = x2 - x1, dy = y2 - y1, len = Math.hypot(dx, dy), ux = dx / len, uy = dy / len;
    const sx = x1 + ux * 30, sy = y1 + uy * 30, ex = x2 - ux * 34, ey = y2 - uy * 34;
    return `<line class="arrow ${kind}" x1="${sx}" y1="${sy}" x2="${ex}" y2="${ey}" marker-end="url(#ah-${kind})"/>`;
  }
  function renderOverlay() {
    const out = [];
    const viewing = S.view >= 0;
    const last = viewing ? null : S.hist[S.hist.length - 1];
    if (last) for (const sq of [last.m & 127, last.m >> 7]) { const [x, y] = disp(sq); out.push(`<rect class="lastmove" x="${x - 46}" y="${y - 46}" width="92" height="92" rx="10"/>`); }
    if (S.selected >= 0 && !viewing) {
      for (const m of S.pos.legalMoves()) {
        if ((m & 127) !== S.selected) continue;
        const [x, y] = disp(m >> 7);
        out.push(S.pos.b[m >> 7] ? `<circle class="dest cap" cx="${x}" cy="${y}" r="44"/>` : `<circle class="dest" cx="${x}" cy="${y}" r="13"/>`);
      }
    }
    if (viewing) {
      const h = S.hist[S.view];
      out.push(arrowSvg(h.m, h.by === 'user' && h.cls && !['best', 'good', 'book'].includes(h.cls) ? 'bad' : 'played'));
      if (h.best && h.best !== h.m) out.push(arrowSvg(h.best, 'best'));
    } else {
      for (const a of S.arrows) out.push(arrowSvg(a.m, a.kind));
    }
    $('marks').innerHTML = out.join('');
  }

  function renderEval() {
    // điểm theo góc nhìn người chơi; S.lastScore luôn tính cho bên đang tới lượt? → chuẩn hoá
    let s = S.lastScore; // đã là góc nhìn người chơi
    if (S.result) s = S.result.winner === 0 ? 0 : S.result.winner === S.userSide ? MATE : -MATE;
    const cs = clampS(s);
    const pct = 50 + 50 * Math.tanh(cs / 600);
    $('evalFill').style.width = pct + '%';
    $('evalText').textContent = Math.abs(s) > MATE - 500 ? (s > 0 ? 'Bạn sắp thắng' : 'Bạn sắp thua') : Math.abs(cs) < 40 ? 'Cân bằng' : (cs > 0 ? 'Bạn ưu thế ' : 'Máy ưu thế ') + (Math.abs(cs) / 100).toFixed(1);
  }

  function esc(s) { return String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]); }
  function renderCoach() {
    const c = S.view >= 0 ? viewCoach() : S.coach;
    const el = $('coach');
    if (!c) { el.innerHTML = ''; return; }
    el.className = 'coach' + (c.cls ? ' c-' + c.cls : '') + (c.busy ? ' busy' : '');
    let html = `<div class="coach-title">${esc(c.title)}</div>`;
    if (c.busy) html += `<div class="dots"><span></span><span></span><span></span></div>`;
    html += c.lines.map((l) => `<p>${esc(l)}</p>`).join('');
    const op = c.opening && (typeof c.opening === 'string' ? { name: c.opening } : c.opening);
    if (op) html += `<div class="opening"><b>Khai cuộc: ${esc(op.name)}</b>${op.tip ? '<br>' + esc(op.tip) : ''}</div>`;
    if (S.mode === 'play' && S.view < 0 && S.state === 'user' && S.hist.some((h) => h.by === 'user' && !h.cls)) html += `<div class="confirm"><button class="btn primary" data-act="analyze">Phân tích ván</button></div>`;
    if (c.confirm) html += `<div class="confirm"><button class="btn primary" data-act="undo-blunder">Đi lại nước này</button><button class="btn" data-act="keep-blunder">Vẫn đi</button></div>`;
    if (S.mode === 'puzzle') html += puzzleButtons();
    html += gmButtons();
    if (S.view >= 0) html += `<div class="confirm"><button class="btn" data-act="exit-view">← Về ván đang chơi</button></div>`;
    el.innerHTML = html;
  }
  function viewCoach() {
    const h = S.hist[S.view];
    if (h.by === 'user' && h.coach) {
      const lines = h.coach.lines.slice();
      return { title: 'Xem lại · ' + h.coach.title, cls: h.coach.cls, lines: ['Mũi tên cam: nước bạn đã đi. Mũi tên xanh: nước máy đề xuất.'].concat(lines), opening: h.coach.opening };
    }
    return { title: 'Xem lại · ' + (h.by === 'ai' ? 'Máy' : 'Bạn') + ': ' + h.name, cls: null, lines: ['Thế cờ trước nước này.'] };
  }

  function renderMoves() {
    const rows = [];
    for (let i = 0; i < S.hist.length; i += 2) {
      const cell = (j) => {
        const h = S.hist[j]; if (!h) return '<span class="mv empty"></span>';
        const badge = h.by === 'user' && h.cls ? `<i class="b b-${h.cls}" title="${CLS[h.cls].label}">${CLS[h.cls].icon}</i>` : '';
        return `<button class="mv${S.view === j ? ' on' : ''}${h.by === 'ai' ? ' ai' : ''}" data-view="${j}">${badge}${esc(h.name)}</button>`;
      };
      rows.push(`<div class="mrow"><span class="mn">${i / 2 + 1}.</span>${cell(i)}${cell(i + 1)}</div>`);
    }
    const el = $('moves');
    el.innerHTML = rows.length ? rows.join('') : '<div class="muted">Chưa có nước nào.</div>';
    el.scrollTop = el.scrollHeight;
  }

  function renderPro() {
    const el = $('pro'); if (!el) return;
    if (S.mode !== 'play') return;
    const pos = S.view >= 0 ? S.hist[S.view].before : S.pos;
    const pm = proMoves(pos);
    const op = ecoOf();
    let h = '';
    if (!PRO.pos) h = '<div class="muted small">Đang tải dữ liệu…</div>';
    else if (S.drill && S.view < 0 && S.state === 'user') h = '<div class="muted small">Đang luyện: hãy tự nhớ nước đại sư hay đi. Bấm "Gợi ý" nếu cần.</div>';
    else if (!pm || !pm.length) h = '<div class="muted small">' + (S.hist.length ? 'Thế cờ này đã ra khỏi sách khai cuộc. Từ đây hãy tự tính toán!' : '') + '</div>';
    else {
      const tot = pm.reduce((s, x) => s + x.n, 0), red = pos.side === RED;
      h = '<div class="muted small">' + tot.toLocaleString('vi') + ' ván đại sư đến thế này. Bấm một nước để xem trên bàn cờ.</div>';
      h += pm.slice(0, 6).map((x) => {
        const rw = (red ? x.w : x.l) / x.n, dr = x.d / x.n, bw = (red ? x.l : x.w) / x.n;
        return `<button class="prow" data-pro="${x.m}"><span class="pn">${esc(x.name)}</span><span class="pc">${pct(x.share)}</span>` +
          `<span class="pbar"><i class="r" style="width:${rw * 100}%"></i><i class="d" style="width:${dr * 100}%"></i><i class="k" style="width:${bw * 100}%"></i></span>` +
          `<span class="pg">${x.n.toLocaleString('vi')}</span></button>`;
      }).join('');
      h += '<div class="plegend"><span><i class="r"></i>Đỏ thắng</span><span><i class="d"></i>Hòa</span><span><i class="k"></i>Đen thắng</span></div>';
    }
    if (op) h = '<div class="peco">' + esc(op.name) + '</div>' + h;
    el.innerHTML = h;
    const sel = $('drillOp');
    if (!sel.options.length) sel.innerHTML = DRILL_OPS.map((o, i) => `<option value="${i}">${esc(o.name)}</option>`).join('');
    sel.disabled = !!S.drill;
    $('drillBtn').textContent = S.drill ? 'Dừng luyện' : 'Luyện khai cuộc';
    $('drillBtn').disabled = !PRO.pos;
  }

  function renderStatus() {
    let t;
    document.querySelectorAll('[data-mode]').forEach((b) => b.classList.toggle('on', b.dataset.mode === S.mode));
    if (S.mode === 'online') {
      const st = OL.st;
      t = S.view >= 0 ? 'Đang xem lại nước ' + (S.view + 1) : !OL.room ? 'Chơi online' : !st ? 'Đang kết nối…' : S.coach ? S.coach.title : '';
      $('status').textContent = t;
      $('status').className = 'status' + (st && st.status === 'playing' && S.state === 'user' && S.pos.inCheck(S.pos.side) ? ' alert' : '');
      return;
    }
    $('undoBtn').innerHTML = S.mode === 'puzzle' ? '↺ Làm lại bài' : S.mode === 'games' ? '◀ Lùi <kbd>←</kbd>' : '↶ Đi lại <kbd>U</kbd>';
    $('hintBtn').innerHTML = S.mode === 'games' ? 'Tiến ▶ <kbd>→</kbd>' : '<span>💡</span> Gợi ý <kbd>H</kbd>';
    if (S.mode === 'games') {
      const g = GM.game;
      t = !g ? 'Đang tải…' : S.state === 'user' ? 'Đến lượt ' + sideName(GM.gside) + ': đại sư sẽ đi nước nào?' : S.state === 'ai' ? (S.coach && S.coach.busy ? 'Đang so sánh…' : 'Đại sư đang đi…') : S.state === 'reveal' ? 'Xem nước đại sư rồi bấm Tiếp tục' : GM.ply >= GM.moves.length ? 'Hết ván' : 'Nước ' + GM.ply + '/' + GM.moves.length;
      $('status').textContent = t;
      $('status').className = 'status' + (S.state === 'ai' ? ' thinking' : '');
      $('hintBtn').disabled = !g || GM.ply >= GM.moves.length || S.state === 'ai' || S.state === 'user';
      $('undoBtn').disabled = !g || GM.ply === 0 || S.state === 'ai';
      return;
    }
    document.querySelectorAll('[data-mode]').forEach((b) => b.classList.toggle('on', b.dataset.mode === S.mode));
    if (S.mode === 'puzzle') {
      const left = PZ.cur ? PZ.cur.n - usedMoves() : 0;
      t = S.view >= 0 ? 'Đang xem lại nước ' + (S.view + 1) : PZ.col.review && S.state === 'user' ? 'Thẻ ' + (PZ.idx + 1) + ': tìm nước tốt nhất' : PZ.col.review && S.state === 'done' ? 'Đã tìm ra nước đúng' : ({ empty: 'Chưa có thẻ nào', user: 'Bài ' + (PZ.idx + 1) + ': chiếu bí trong ' + left + ' nước', ai: 'Máy đang tìm cách đỡ…', fail: 'Chưa đúng, thử lại nhé', done: 'Đã chiếu bí!', demo: 'Đang xem lời giải…' })[S.state] || '';
      $('status').textContent = t;
      $('status').className = 'status' + (S.state === 'ai' || S.state === 'demo' ? ' thinking' : '');
      $('hintBtn').disabled = !(S.state === 'user' && S.view < 0);
      $('undoBtn').disabled = S.state === 'ai' || !PZ.cur;
      return;
    }
    if (S.view >= 0) t = 'Đang xem lại nước ' + (S.view + 1);
    else if (S.state === 'analyze') t = 'Đang phân tích ván…';
    else if (S.state === 'over') t = S.result.text;
    else if (S.state === 'ai' && !S.drill) t = S.coach && S.coach.busy ? 'Thầy đang chấm nước của bạn…' : 'Máy đang nghĩ…';
    else if (S.state === 'confirm') t = 'Bạn có chắc muốn đi nước này?';
    else if (S.drill && S.state === 'ai') t = 'Máy đi theo đại sư…';
    else if (S.state === 'user' && S.pos.side !== S.userSide) t = 'Bấm "Phân tích ván" để thầy chấm các nước của bạn';
    else if (S.drill) t = 'Luyện khai cuộc: nước ' + (Math.floor(S.hist.length / 2) + 1) + ', đến lượt bạn';
    else t = S.pos.inCheck(S.pos.side) ? 'Bạn đang bị chiếu!' : 'Đến lượt bạn (' + sideName(S.userSide) + ')';
    $('status').textContent = t;
    $('status').className = 'status' + (S.state === 'ai' ? ' thinking' : '') + (S.state === 'user' && S.pos.inCheck(S.pos.side) ? ' alert' : '');
    $('hintBtn').disabled = !(S.state === 'user' && S.view < 0);
    $('undoBtn').disabled = !S.hist.some((h) => h.by === 'user') || S.state === 'ai';
  }

  function render() {
    renderOnline();
    renderPieces(); renderOverlay(); renderCoach(); renderMoves(); renderStatus(); if (S.mode === 'play') renderEval(); renderPuzzle(); renderPro(); renderGames();
    $('level').value = S.level; $('side').value = S.userSide;
    $('engInfo').textContent = REMOTE.used === true ? 'Máy chấm: Pikafish trên máy chủ (mạnh, cần mạng).' : REMOTE.used === false ? 'Máy chấm: engine trong trình duyệt (không kết nối được máy chủ Pikafish).' : '';
    $('optWarn').checked = S.opt.warn; $('optThreats').checked = S.opt.threats; $('optHan').checked = S.opt.han; $('optSound').checked = S.opt.sound;
  }


  // ---------- Bài tập sát cục (nhiều bộ: thực chiến + cổ phổ) ----------
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const THEME_INFO = {
    'Mã hậu pháo': 'Mã đứng trước làm ngòi cho Pháo phía sau, đồng thời khống chế các ô cạnh Tướng. Một trong những đòn sát kinh điển nhất.',
    'Trùng pháo': 'Hai Pháo xếp chồng trên một đường: Pháo trước làm ngòi cho Pháo sau. Tướng chạy dọc đường vẫn bị chiếu.',
    'Bạch diện tướng': 'Lợi dụng luật lộ mặt tướng: Tướng mình khống chế cả cột, Tướng đối phương không thể bước sang.',
    'Pháo đáy': 'Pháo xuống hàng đáy, dùng chính Sĩ/Tượng đối phương làm ngòi, Tướng bị kẹt trong cung.',
    'Song chiếu': 'Một nước tạo ra hai đường chiếu cùng lúc: không thể vừa chặn vừa ăn.',
    'Thí quân': 'Hy sinh quân để mở đường chiếu bí. Phải tính đến cùng mới dám đi!',
    'Xe Mã': 'Xe và Mã phối hợp: Mã khống chế ô thoát, Xe chiếu hết (hoặc ngược lại).',
    'Mã Pháo': 'Mã và Pháo phối hợp vây Tướng.',
    'Tốt sát': 'Tốt qua sông áp sát cung, một Tốt cũng có thể kết liễu ván cờ.',
    'Song xe': 'Hai Xe thay nhau chiếu, dồn Tướng vào đường cùng.',
    'Mã sát': 'Mã chiếu bí: chú ý chân mã và các ô Mã khống chế.',
    'Pháo mượn ngòi': 'Pháo dùng quân của đối phương làm ngòi để chiếu.',
    'Pháo sát': 'Pháo chiếu bí nhờ một quân làm ngòi.',
    'Xe sát': 'Xe chiếu hết: tìm hàng hoặc cột then chốt để Xe chiếm.',
  };
  const BUILTIN = { id: 'thuc-chien', title: 'Thực chiến (máy tự đánh)', source: 'Đào từ ván máy tự đánh, engine kiểm chứng', items: (self.PUZZLES || []) };
  const PZ = { cols: [{ id: BUILTIN.id, title: BUILTIN.title, count: BUILTIN.items.length }], col: BUILTIN, idx: 0, cur: null, fails: 0, hintStep: 0, cache: { 'thuc-chien': BUILTIN } };
  // tiến độ: "bộ:số thứ tự"; chuyển đổi dữ liệu cũ (chỉ lưu id số của bộ thực chiến)
  PZ.solved = new Set(store.get('solved', []).map((x) => (typeof x === 'number' ? 'thuc-chien:' + (x - 1) : x)));
  PZ.cols.unshift({ id: 'on-loi', title: 'Ôn lỗi sai của bạn', count: 0 });
  fetch('data/puzzles/index.json?v=2').then((r) => r.json()).then((list) => { PZ.cols = PZ.cols.concat(list); renderPuzzle(); }).catch(() => {});
  setTimeout(updateReviewCount);
  const usedMoves = () => S.hist.filter((h) => h.by === 'user').length;

  // ---------- Sổ lỗi sai: ôn lại thế cờ mình từng đi sai (lặp lại ngắt quãng) ----------
  const DAY = 864e5, REV_MAX = 300, REV_ID = 'on-loi';
  const REV = { cards: store.get('review', []) };
  const saveReview = () => store.set('review', REV.cards);
  function addReview(before, played, best, loss) {
    if (played === best) return false;
    const fen = before.toFen();
    let c = REV.cards.find((x) => x.fen === fen);
    if (!c) { c = { fen, added: Date.now(), reps: 0, lapses: 0 }; REV.cards.push(c); }
    Object.assign(c, { best, played, bestName: before.moveName(best), playedName: before.moveName(played), loss, iv: 0, due: Date.now() });
    if (REV.cards.length > REV_MAX) REV.cards.splice(0, REV.cards.length - REV_MAX);
    saveReview(); updateReviewCount();
    return true;
  }
  const dueCount = () => REV.cards.filter((c) => c.due <= Date.now()).length;
  function updateReviewCount() {
    const c = PZ.cols.find((x) => x.id === REV_ID);
    if (c) { c.count = REV.cards.length; c.title = reviewTitle(); }
  }
  const reviewTitle = () => 'Ôn lỗi sai của bạn' + (dueCount() ? ' · ' + dueCount() + ' đến hạn' : '');
  function reviewCollection() {
    // thẻ đến hạn lên trước, rồi tới thẻ sắp đến hạn
    const cards = REV.cards.slice().sort((a, b) => a.due - b.due);
    return { id: REV_ID, title: 'Ôn lỗi sai của bạn', review: true, items: cards.map((c) => ({ fen: c.fen, n: 1, sol: [c.best], rv: c })) };
  }
  function gradeReview(c, ok) {
    c.reps++;
    if (ok) c.iv = c.iv ? Math.min(120, Math.round(c.iv * 2.5)) : 1;
    else { c.iv = 0; c.lapses++; }
    c.due = Date.now() + (ok ? c.iv * DAY : 0);
    saveReview(); updateReviewCount();
  }
  const fmtDue = (c) => {
    const d = Math.ceil((c.due - Date.now()) / DAY);
    return d <= 0 ? 'đến hạn ôn' : 'ôn lại sau ' + d + ' ngày';
  };
  async function onReviewMove(m) {
    const tok = S.tok, before = S.pos.clone(), name = S.pos.moveName(m), c = PZ.cur.rv;
    S.pos.make(m); S.hist.push({ m, name, by: 'user', before });
    S.selected = -1; S.arrows = []; S.state = 'ai';
    S.coach = { title: 'Thầy đang chấm…', cls: null, lines: [], busy: true };
    render();
    let ok = m === c.best, loss = 0;
    if (!ok && m !== c.played) {
      // chấp nhận nước khác nếu máy đánh giá ngang nước tốt nhất
      const rb = await engine.analyse(before.clone(), { timeMs: 900, multipv: 1 });
      if (tok !== S.tok || !rb) return;
      const ra = S.pos.legalMoves().length ? await engine.analyse(S.pos.clone(), { timeMs: 900, multipv: 1 }) : null;
      if (tok !== S.tok) return;
      const sb = rb.multi[0] ? rb.multi[0].score : 0, sa = ra && ra.multi[0] ? -ra.multi[0].score : MATE;
      loss = Math.max(0, clampS(sb) - clampS(sa));
      ok = loss <= 40;
    }
    if (PZ.fails === 0 && !PZ.hinted) gradeReview(c, ok);
    if (ok) {
      S.state = 'done';
      const lines = [m === c.best ? 'Đúng nước tốt nhất.' : 'Nước này cũng tốt ngang nước máy chọn (' + c.bestName + ').'];
      lines.push(...explain(before, m).map((x) => '• ' + x));
      lines.push('Lúc trước bạn đã đi ' + c.playedName + ' và mất ' + (c.loss / 100).toFixed(1) + ' Tốt lợi thế.');
      lines.push(PZ.fails || PZ.hinted ? 'Thẻ này sẽ được ôn lại sớm vì bạn chưa làm đúng ngay lần đầu.' : 'Thẻ này: ' + fmtDue(c) + '.');
      S.coach = { title: '✓ ' + name + ': chính xác!', cls: 'best', lines };
      sfx('win', 300);
    } else {
      PZ.fails++;
      S.state = 'fail';
      S.arrows = [{ m, kind: 'bad' }];
      const lines = [m === c.played ? 'Đây chính là nước bạn đã đi sai lần trước.' : 'Nước này kém nước tốt nhất khoảng ' + (loss / 100).toFixed(1) + ' Tốt.'];
      lines.push('Bấm "Thử lại" để tìm nước khác, hoặc "Gợi ý" sau khi thử lại.');
      S.coach = { title: '✗ Chưa đúng: ' + name, cls: 'mistake', lines };
      sfx('fail', 350);
    }
    render();
  }
  function deleteReview() {
    const c = PZ.cur && PZ.cur.rv; if (!c) return;
    REV.cards = REV.cards.filter((x) => x !== c); saveReview(); updateReviewCount();
    PZ.col = reviewCollection();
    if (PZ.col.items.length) loadPuzzle(Math.min(PZ.idx, PZ.col.items.length - 1)); else loadPuzzle(0);
  }

  // ---------- Thống kê theo chủ đề: tỷ lệ giải đúng ngay lần đầu ----------
  const TSTAT = store.get('themeStat', {});
  function recordTheme(ok) {
    if (PZ.recorded || !PZ.cur || PZ.col.review) return;
    PZ.recorded = true;
    const ts = PZ.cur.themes && PZ.cur.themes.length ? PZ.cur.themes : PZ.cur.theme ? [PZ.cur.theme] : [];
    for (const t of ts) { const x = TSTAT[t] || (TSTAT[t] = [0, 0]); x[1]++; if (ok) x[0]++; }
    store.set('themeStat', TSTAT);
  }
  function weakThemes() {
    return Object.entries(TSTAT).filter(([, x]) => x[1] >= 3 && x[0] / x[1] < 0.7)
      .map(([t, x]) => ({ t, ok: x[0], tot: x[1], r: (x[0] + 1) / (x[1] + 2) }))
      .sort((a, b) => a.r - b.r).slice(0, 3);
  }
  function practiceTheme(t) {
    const items = PZ.col.items;
    const has = (p) => (p.themes || [p.theme]).includes(t);
    for (let k = 1; k <= items.length; k++) {
      const i = (PZ.idx + k) % items.length;
      if (has(items[i]) && !isSolved(i)) return loadPuzzle(i);
    }
    for (let k = 1; k <= items.length; k++) { const i = (PZ.idx + k) % items.length; if (has(items[i])) return loadPuzzle(i); }
    S.coach = { title: 'Không có bài "' + t + '" trong bộ này', cls: null, lines: ['Hãy chọn bộ khác, ví dụ Vu sư ma đề hoặc Sát trước đại toàn.'] };
    render();
  }
  // "k": chỉ số gốc của bài (giữ nguyên khi bộ đã lọc bài trùng)
  const pzKey = (i) => PZ.col.id + ':' + (PZ.col.items[i].k ?? i);
  // cùng thế cờ có mặt ở nhiều bộ: giải ở bộ nào cũng tính là đã giải
  PZ.solvedFen = new Set(store.get('solvedFen', []));
  const isSolved = (i) => (PZ.col.review ? PZ.col.items[i].rv.due > Date.now() : PZ.solved.has(pzKey(i)) || PZ.solvedFen.has(PZ.col.items[i].fen));

  async function openCollection(id, idx) {
    if (id === REV_ID) { PZ.col = reviewCollection(); store.set('pzCol', REV_ID); return loadPuzzle(PZ.col.items.length ? 0 : idx || 0); }
    let col = PZ.cache[id];
    if (!col) {
      try { col = await (await fetch('data/puzzles/' + id + '.json?v=2')).json(); PZ.cache[id] = col; }
      catch (e) { col = BUILTIN; }
    }
    PZ.col = col; store.set('pzCol', col.id);
    const n0 = PZ.solvedFen.size;
    col.items.forEach((p, i) => { if (PZ.solved.has(pzKey(i))) PZ.solvedFen.add(p.fen); });
    if (PZ.solvedFen.size !== n0) store.set('solvedFen', [...PZ.solvedFen]);
    loadPuzzle(idx || 0);
  }
  function setMode(mode) {
    if (S.mode === mode) return;
    if (S.mode === 'online') olClose(); // ván online vẫn tiếp tục trên máy chủ; quay lại tab sẽ vào lại
    S.tok++; engine.reset();
    S.mode = mode; document.body.dataset.mode = mode; store.set('mode', mode);
    S.view = -1; S.arrows = []; S.selected = -1; S.result = null;
    if (mode === 'puzzle') { S.userSide = RED; openCollection(store.get('pzCol', 'thuc-chien'), store.get('pzIdx', 0)); }
    else if (mode === 'games') gmEnter();
    else if (mode === 'online') olEnter();
    else { S.userSide = store.get('side', RED); if (!restore()) newGame(); }
  }
  function loadPuzzle(i) {
    const items = PZ.col.items;
    if (!items.length) {
      S.tok++; PZ.cur = null; S.pos = Pos.start(); S.hist = []; S.arrows = []; S.selected = -1; S.view = -1; S.state = 'empty'; S.userSide = RED;
      S.coach = PZ.col.review
        ? { title: 'Chưa có lỗi nào để ôn', cls: null, lines: ['Khi đấu với máy, mỗi nước Sai lầm (?) hoặc Nước hỏng (??) của bạn sẽ được lưu vào đây.', 'Ôn lại đúng những thế cờ mình từng đi sai là cách tiến bộ nhanh nhất. Thẻ làm đúng sẽ được giãn lịch ôn (1, 3, 7, 18… ngày), làm sai sẽ quay lại ngay.'] }
        : { title: 'Bộ bài trống', cls: null, lines: [] };
      render(); return;
    }
    S.tok++;
    i = Math.max(0, Math.min(items.length - 1, i)); PZ.idx = i; PZ.cur = items[i]; store.set('pzIdx', i);
    PZ.hintStep = 0; PZ.fails = 0; PZ.hinted = false; PZ.recorded = false;
    S.pos = Pos.fromFen(PZ.cur.fen); S.hist = []; S.arrows = []; S.selected = -1; S.view = -1; S.state = 'user'; S.result = null;
    S.userSide = PZ.col.review ? S.pos.side : RED;
    if (PZ.col.review) {
      const c = PZ.cur.rv;
      S.coach = { title: 'Ôn lỗi · thẻ ' + (i + 1) + '/' + items.length, cls: null, lines: [
        'Thế cờ từ ván của bạn (' + new Date(c.added).toLocaleDateString('vi') + '). Bạn cầm ' + sideName(S.pos.side) + '.',
        'Lần đó bạn đi ' + c.playedName + ' và mất ' + (c.loss / 100).toFixed(1) + ' Tốt lợi thế. Hãy tìm nước tốt hơn.',
        'Đã ôn ' + c.reps + ' lần · ' + fmtDue(c) + '.',
      ] };
      render(); return;
    }
    const lines = ['Đỏ đi trước, chiếu bí trong ' + PZ.cur.n + ' nước. Máy sẽ chống đỡ bằng nước tốt nhất.'];
    if (PZ.cur.theme) lines.push('Đòn: ' + PZ.cur.theme + '. ' + (THEME_INFO[PZ.cur.theme] || ''));
    if (PZ.col.source) lines.push('Nguồn: ' + PZ.col.title + ' · ' + PZ.col.source);
    const n0 = noteAt(0); if (n0) lines.push('Lời bình gốc: ' + n0);
    S.coach = { title: 'Bài ' + (i + 1) + (PZ.cur.name ? ' · ' + PZ.cur.name : ''), cls: null, lines };
    render();
    const el = document.querySelector('.pz.cur'); if (el) el.scrollIntoView({ block: 'nearest' });
  }
  function noteAt(ply) {
    const ns = PZ.cur && PZ.cur.notes; if (!ns) return '';
    const x = ns.find((n) => n[0] === ply); return x ? x[1] : '';
  }
  const onSolPath = () => S.hist.every((h, i) => h.m === PZ.cur.sol[i]);
  async function onPuzzleMove(m) {
    if (PZ.col.review) return onReviewMove(m);
    const tok = S.tok, before = S.pos.clone(), name = S.pos.moveName(m);
    const followed = onSolPath() && PZ.cur.sol[S.hist.length] === m;
    S.pos.make(m); S.hist.push({ m, name, by: 'user', before });
    S.selected = -1; S.arrows = []; S.state = 'ai';
    S.coach = { title: 'Máy đang tìm cách đỡ…', cls: null, lines: [], busy: true };
    render();
    const left = PZ.cur.n - usedMoves();
    if (S.pos.legalMoves().length === 0) return puzzleSolved();
    if (left <= 0) return puzzleFail(null, 'Đã hết ' + PZ.cur.n + ' nước mà chưa chiếu bí được.');
    let reply;
    if (followed && PZ.cur.sol[S.hist.length] !== undefined) reply = PZ.cur.sol[S.hist.length]; // đúng lời giải gốc: đối phương đỡ theo sách
    else {
      const r = await engine.search(S.pos.clone(), { depth: 2 * left + 2, timeMs: 4000, multipv: 1 });
      if (tok !== S.tok || !r) return;
      const best = r.multi[0];
      if (best.score > -MATE + 2 * left) return puzzleFail(best.move, null);
      reply = best.move;
    }
    await sleep(350); if (tok !== S.tok) return;
    const b2 = S.pos.clone(), rn = S.pos.moveName(reply);
    S.pos.make(reply); S.hist.push({ m: reply, name: rn, by: 'ai', before: b2 });
    S.state = 'user'; PZ.hintStep = 0;
    const lines = explain(before, m, undefined, { short: true }).concat(['Đối phương đỡ: ' + rn + '. Còn ' + left + ' nước nữa để chiếu bí.']);
    const note = noteAt(S.hist.length - 1) || noteAt(S.hist.length);
    if (note) lines.push('Lời bình gốc: ' + note);
    S.coach = { title: '✓ Đúng rồi: ' + name, cls: 'good', lines };
    render();
  }
  function puzzleFail(reply, msg) {
    sfx('fail', 350);
    recordTheme(false);
    PZ.fails++;
    const h = S.hist[S.hist.length - 1], lines = [];
    if (msg) lines.push(msg);
    if (reply) { lines.push('Đối phương thoát được bằng ' + S.pos.moveName(reply) + ' (mũi tên cam).'); S.arrows = [{ m: reply, kind: 'bad' }]; }
    lines.push('Bấm "Thử lại" để đi lại nước này, hoặc "Gợi ý" sau khi thử lại.');
    S.state = 'fail';
    S.coach = { title: '✗ Chưa đúng: ' + h.name, cls: 'mistake', lines };
    render();
  }
  function retryPuzzle() {
    let i = S.hist.length - 1;
    while (i >= 0 && S.hist[i].by !== 'user') i--;
    if (i < 0) return loadPuzzle(PZ.idx);
    S.tok++;
    S.pos = S.hist[i].before.clone(); S.hist = S.hist.slice(0, i);
    S.arrows = []; S.selected = -1; S.state = 'user';
    S.coach = { title: 'Thử lại', cls: null, lines: [PZ.col.review ? 'Tìm nước tốt nhất cho ' + sideName(S.pos.side) + '. Bấm "Gợi ý" nếu cần.' : 'Còn ' + (PZ.cur.n - usedMoves()) + ' nước để chiếu bí. Hãy tìm nước chiếu mà đối phương không thoát được.'] };
    render();
  }
  function puzzleSolved() {
    sfx('win', 480);
    recordTheme(PZ.fails === 0 && !PZ.hinted);
    S.state = 'done'; S.arrows = [];
    PZ.solved.add(pzKey(PZ.idx)); store.set('solved', [...PZ.solved]);
    PZ.solvedFen.add(PZ.cur.fen); store.set('solvedFen', [...PZ.solvedFen]);
    const lines = [
      PZ.fails ? 'Bạn giải được sau ' + PZ.fails + ' lần thử sai.' : 'Giải đúng ngay lần đầu!',
      'Các nước: ' + S.hist.map((h) => h.name).join(' → '),
    ];
    if (PZ.cur.theme) lines.push('Đòn: ' + PZ.cur.theme + '. ' + (THEME_INFO[PZ.cur.theme] || ''));
    const note = noteAt(S.hist.length); if (note) lines.push('Lời bình gốc: ' + note);
    S.coach = { title: '🎉 Chiếu bí! Xong bài ' + (PZ.idx + 1), cls: 'best', lines };
    render();
  }
  async function puzzleHint() {
    if (S.state !== 'user') return;
    const tok = S.tok, left = PZ.cur.n - usedMoves();
    let m, score;
    if (onSolPath() && PZ.cur.sol[S.hist.length] !== undefined) m = PZ.cur.sol[S.hist.length];
    else {
      S.coach = { title: 'Đang tìm…', cls: null, lines: [], busy: true }; render();
      const r = await engine.search(S.pos.clone(), { depth: 2 * left + 1, timeMs: 4000, multipv: 1 });
      if (tok !== S.tok || !r) return;
      m = r.multi[0].move; score = r.multi[0].score;
    }
    PZ.hintStep++; PZ.hinted = true;
    if (PZ.hintStep === 1) {
      S.selected = m & 127;
      S.coach = { title: '💡 Gợi ý 1', cls: null, lines: ['Quân cần đi: ' + nameOf(S.pos.b[m & 127]) + ' (đang được chọn sẵn).', 'Bấm Gợi ý lần nữa để xem nước cụ thể.'] };
    } else {
      S.arrows = [{ m, kind: 'best' }];
      S.coach = { title: '💡 Gợi ý 2', cls: null, lines: ['Nước đúng: ' + S.pos.moveName(m) + '.'].concat(explain(S.pos, m, score, { short: true })) };
    }
    render();
  }
  async function showSolution() {
    if (!PZ.cur) return;
    const tok = ++S.tok;
    S.pos = Pos.fromFen(PZ.cur.fen); S.hist = []; S.arrows = []; S.selected = -1; S.view = -1; S.state = 'demo';
    S.coach = { title: 'Lời giải bài ' + (PZ.idx + 1) + (PZ.cur.name ? ' · ' + PZ.cur.name : ''), cls: null, lines: [] };
    render();
    for (const m of PZ.cur.sol) {
      await sleep(1000); if (tok !== S.tok) return;
      const b = S.pos.clone(), nm = S.pos.moveName(m);
      S.coach.lines.push((b.side === RED ? 'Đỏ: ' : 'Đen: ') + nm);
      S.pos.make(m); S.hist.push({ m, name: nm, by: b.side === RED ? 'user' : 'ai', before: b });
      const note = noteAt(S.hist.length); if (note) S.coach.lines.push('   ↳ ' + note);
      render();
    }
    if (PZ.col.review) {
      PZ.hinted = true; if (PZ.cur.rv.iv || PZ.cur.rv.due > Date.now()) gradeReview(PZ.cur.rv, false);
      S.state = 'done'; S.coach.lines.push('Nước tốt nhất. Lúc trước bạn đi ' + PZ.cur.rv.playedName + '.');
      S.coach.lines.push(...explain(Pos.fromFen(PZ.cur.fen), PZ.cur.sol[0]).map((x) => '• ' + x));
      render(); return;
    }
    recordTheme(false);
    S.state = 'done'; S.coach.lines.push('Chiếu bí!' + (PZ.cur.theme ? ' ' + (THEME_INFO[PZ.cur.theme] || '') : ''));
    render();
  }
  function renderPuzzle() {
    if (S.mode !== 'puzzle') return;
    const sel = $('pzCol');
    const opts = PZ.cols.map((c) => `<option value="${c.id}"${c.id === PZ.col.id ? ' selected' : ''}>${esc(c.title)} (${c.count})</option>`).join('');
    if (sel.dataset.sig !== opts) { sel.innerHTML = opts; sel.dataset.sig = opts; }
    const items = PZ.col.items;
    const done = items.filter((_, i) => isSolved(i)).length;
    $('pzProgress').textContent = PZ.col.review ? items.length - done + ' thẻ đến hạn / ' + items.length : 'Đã giải ' + done + '/' + items.length;
    const weak = weakThemes();
    const wh = PZ.col.review || !weak.length ? '' : '<div class="pzweak"><span class="muted small">Chủ đề cần luyện (giải đúng ngay lần đầu):</span>' +
      weak.map((w) => `<button class="tag" data-theme="${esc(w.t)}" title="Mở bài chưa giải có đòn này">${esc(w.t)} <b>${w.ok}/${w.tot}</b></button>`).join('') + '</div>';
    if ($('pzWeak').dataset.sig !== wh) { $('pzWeak').innerHTML = wh; $('pzWeak').dataset.sig = wh; }
    const groups = [];
    if (PZ.col.review) {
      const now = Date.now();
      const part = (lab, f) => { const its = items.map((p, i) => [p, i]).filter(([p]) => f(p.rv)); return its.length ? `<div class="pzg"><div class="pzg-h">${lab} · ${its.length} thẻ</div><div class="pzgrid">` + its.map(([p, i]) => `<button class="pz${isSolved(i) ? ' ok' : ''}${i === PZ.idx ? ' cur' : ''}" data-pz="${i}" title="${esc(p.rv.playedName + ' → ' + p.rv.bestName)}">${i + 1}</button>`).join('') + '</div></div>' : ''; };
      groups.push(part('Đến hạn ôn', (c) => c.due <= now), part('Đã thuộc, chờ ôn lại', (c) => c.due > now));
    } else
    for (const n of [...new Set(items.map((p) => p.n))].sort((a, b) => a - b)) {
      const its = items.map((p, i) => [p, i]).filter(([p]) => p.n === n);
      groups.push(`<div class="pzg"><div class="pzg-h">Chiếu bí ${n} nước · ${its.length} bài</div><div class="pzgrid">` +
        its.map(([p, i]) => `<button class="pz${isSolved(i) ? ' ok' : ''}${i === PZ.idx ? ' cur' : ''}" data-pz="${i}" title="${esc((p.name ? p.name + ' · ' : '') + (p.theme || ''))}">${i + 1}</button>`).join('') + '</div></div>');
    }
    const html = groups.join('');
    if ($('pzList').dataset.sig !== html) { $('pzList').innerHTML = html; $('pzList').dataset.sig = html; }
  }
  function puzzleButtons() {
    if (S.view >= 0) return '';
    let b = '';
    if (S.state === 'fail') b += '<button class="btn primary" data-act="pz-retry">Thử lại</button>';
    if (S.state === 'done') b += '<button class="btn primary" data-act="pz-next">' + (PZ.col.review ? 'Thẻ tiếp theo →' : 'Bài tiếp theo →') + '</button><button class="btn" data-act="pz-restart">Làm lại</button>';
    if (PZ.col.review && PZ.cur && (S.state === 'done' || S.state === 'fail')) b += '<button class="btn" data-act="rv-del" title="Xoá thẻ này khỏi sổ lỗi sai">Bỏ thẻ</button>';
    return b ? '<div class="confirm">' + b + '</div>' : '';
  }

  // ---------- Ván đại sư: xem lại & luyện đoán nước ----------
  const GM = { index: null, col: null, game: null, moves: [], start: null, ply: 0, guess: false, gside: RED, stat: { ok: 0, near: 0, tot: 0, skip: 0 }, cache: {}, filter: '', key: {} };
  // chỉ hỏi ở thời điểm then chốt: nước tốt nhất hơn nước nhì ít nhất KEY_GAP (≈1 Tốt)
  GM.keyOnly = store.get('gmKey', true);
  const KEY_GAP = 100;
  const decodeM = (s) => ((+s[1]) * 9 + (+s[0])) | (((+s[3]) * 9 + (+s[2])) << 7);
  async function gmEnter() {
    S.state = 'gview'; S.hist = []; S.arrows = [];
    if (!GM.index) {
      try { GM.index = await (await fetch('data/games/index.json?v=1')).json(); } catch (e) { GM.index = []; }
    }
    if (S.mode !== 'games') return;
    if (!GM.col) await gmOpenCol(store.get('gmCol', GM.index[0] && GM.index[0].id), store.get('gmGame', 0));
    else gmShow();
  }
  async function gmOpenCol(id, gi) {
    if (!id) return;
    let col = GM.cache[id];
    if (!col) { try { col = await (await fetch('data/games/' + id + '.json?v=1')).json(); GM.cache[id] = col; } catch (e) { return; } }
    GM.col = col; store.set('gmCol', id); GM.filter = ''; $('gmFilter').value = '';
    gmLoad(Math.min(gi || 0, col.games.length - 1));
  }
  function gmLoad(i) {
    S.tok++;
    const g = GM.col.games[i]; GM.gi = i; GM.game = g; store.set('gmGame', i);
    GM.start = g.fen ? Pos.fromFen(g.fen) : Pos.start();
    GM.moves = []; for (let k = 0; k < g.m.length; k += 4) GM.moves.push(decodeM(g.m.substr(k, 4)));
    GM.stat = { ok: 0, near: 0, tot: 0, skip: 0 }; GM.key = {};
    GM.gside = g.res === -1 ? BLACK : RED; // mặc định đoán nước bên thắng
    S.userSide = GM.guess ? GM.gside : RED;
    gmGoto(0);
  }
  function gmGoto(ply) {
    S.tok++;
    ply = Math.max(0, Math.min(GM.moves.length, ply));
    const p = GM.start.clone(); S.hist = [];
    for (let k = 0; k < ply; k++) { const m = GM.moves[k]; const b = p.clone(); S.hist.push({ m, name: p.moveName(m), by: 'ai', before: b }); p.make(m); }
    S.pos = p; GM.ply = ply; S.view = -1; S.selected = -1; S.arrows = [];
    S.state = GM.guess && ply < GM.moves.length && p.side === GM.gside ? 'user' : 'gview';
    if (S.state === 'user' && GM.keyOnly) return gmCheckKey();
    gmShow();
    if (GM.guess && S.state === 'gview' && ply < GM.moves.length) gmAutoReply();
  }
  // thế cờ có phải thời điểm then chốt (chỉ một nước tốt rõ rệt)? Không thì tự đi nước đại sư
  async function gmCheckKey() {
    const tok = S.tok, ply = GM.ply;
    let key = GM.key[ply];
    if (key === undefined) {
      S.state = 'ai';
      if (S.pos.legalMoves().length < 2) key = false;
      else {
        gmShow(['Đang tìm thời điểm then chốt…']);
        const r = await engine.analyse(S.pos.clone(), { timeMs: 600, multipv: 2 });
        if (tok !== S.tok || !r) return;
        key = r.multi.length >= 2 && clampS(r.multi[0].score) - clampS(r.multi[1].score) >= KEY_GAP;
      }
      GM.key[ply] = key;
    }
    if (key) { S.state = 'user'; GM.flash = GM.flash && GM.flash.n > 0 ? GM.flash : { title: '⚑ Thời điểm then chốt', cls: 'inacc', n: 1 }; gmShow(['Ở thế này chỉ có một nước tốt rõ rệt. Đại sư sẽ đi gì?']); return; }
    // nước thường: đại sư đi luôn
    GM.stat.skip++;
    S.state = 'ai';
    GM.flash = { title: 'Nước thường: ' + S.pos.moveName(GM.moves[ply]), cls: null, n: 1 };
    gmShow();
    await sleep(450); if (tok !== S.tok || S.mode !== 'games') return;
    gmGoto(ply + 1);
  }
  async function gmAutoReply() {
    const tok = S.tok; await sleep(700); if (tok !== S.tok || S.mode !== 'games') return;
    gmGoto(GM.ply + 1);
  }
  function gmInfoLines() {
    const g = GM.game, lines = [];
    const who = (g.r || 'Đỏ') + ' (Đỏ) – ' + (g.b || 'Đen') + ' (Đen)';
    lines.push(who + (g.res === 1 ? ' · Đỏ thắng' : g.res === -1 ? ' · Đen thắng' : g.res === 0 ? ' · Hòa' : ''));
    const meta = [g.ev, g.d].filter(Boolean).join(' · '); if (meta) lines.push(meta);
    if (g.eco) lines.push('Khai cuộc: ' + g.eco);
    else if (g.t) lines.push(g.t);
    return lines;
  }
  function gmNote(ply) { const ns = GM.game.notes; if (!ns) return ''; const x = ns.find((n) => n[0] === ply); return x ? x[1] : ''; }
  function gmShow(extra) {
    const g = GM.game; if (!g) { render(); return; }
    const lines = gmInfoLines();
    const note = gmNote(GM.ply); if (note) lines.push('Bình luận: ' + note);
    if (extra) lines.push(...extra);
    if (GM.guess) {
      const st = GM.stat;
      lines.push('Luyện đoán nước bên ' + sideName(GM.gside) + ': trùng ' + st.ok + '/' + st.tot + (st.near ? ', tương đương ' + st.near : '') + (st.tot ? ' (' + Math.round(100 * (st.ok + st.near) / st.tot) + '%)' : '') + (st.skip ? ' · tự đi ' + st.skip + ' nước thường' : ''));
    }
    const fl = GM.flash && GM.flash.n-- > 0 ? GM.flash : null;
    S.coach = { title: fl ? fl.title : (GM.col ? GM.col.title : '') + ' · Ván ' + (GM.gi + 1), cls: fl ? fl.cls : null, lines };
    render();
  }
  async function onGuessMove(m) {
    const tok = S.tok, pos = S.pos, before = pos.clone(), master = GM.moves[GM.ply];
    const mine = before.moveName(m), mname = before.moveName(master);
    GM.stat.tot++;
    if (m === master) {
      GM.stat.ok++;
      GM.flash = { title: '✓ Trùng nước đại sư: ' + mine, cls: 'best', n: 2 };
      gmGoto(GM.ply + 1);
      return;
    }
    S.state = 'ai'; S.selected = -1;
    S.coach = { title: 'Đang so sánh với nước đại sư…', cls: null, lines: [], busy: true }; render();
    const pa = before.clone(); pa.make(m);
    const pb = before.clone(); pb.make(master);
    const ra = await engine.analyse(pa, { timeMs: 900, multipv: 1 }); if (tok !== S.tok || !ra) return;
    const rb = await engine.analyse(pb, { timeMs: 900, multipv: 1 }); if (tok !== S.tok || !rb) return;
    const sa = -ra.multi[0].score, sb = -rb.multi[0].score, diff = clampS(sb) - clampS(sa);
    let verdict, cls;
    if (diff <= 30) { verdict = 'Nước của bạn được máy đánh giá tương đương (chênh ' + (diff / 100).toFixed(1) + ').'; cls = 'good'; GM.stat.near++; }
    else if (diff <= 120) { verdict = 'Nước của đại sư tốt hơn khoảng ' + (diff / 100).toFixed(1) + ' Tốt.'; cls = 'inacc'; }
    else { verdict = 'Nước của bạn kém hơn rõ rệt (' + (diff / 100).toFixed(1) + ' Tốt).'; cls = 'mistake'; }
    S.state = 'reveal';
    S.arrows = [{ m: master, kind: 'best' }, { m, kind: 'bad' }];
    const lines = gmInfoLines();
    lines.push('Bạn đi: ' + mine + ' (mũi tên cam). Đại sư đi: ' + mname + ' (mũi tên xanh).', verdict);
    lines.push(...explain(before, master, sb).map((x) => '• ' + x));
    S.coach = { title: 'Đại sư đi ' + mname, cls, lines, gmNext: true };
    render();
  }
  function renderGames() {
    if (S.mode !== 'games' || !GM.index) return;
    const sel = $('gmCol');
    const opts = GM.index.map((c) => `<option value="${c.id}"${GM.col && c.id === GM.col.id ? ' selected' : ''}>${esc(c.title)} (${c.count})</option>`).join('');
    if (sel.dataset.sig !== opts) { sel.innerHTML = opts; sel.dataset.sig = opts; }
    if (!GM.col) return;
    const f = GM.filter.trim().toLowerCase();
    const rows = [];
    GM.col.games.forEach((g, i) => {
      const label = (g.r || '?') + ' – ' + (g.b || '?');
      const sub = [g.res === 1 ? '1-0' : g.res === -1 ? '0-1' : g.res === 0 ? '½-½' : '', g.d, g.eco ? g.eco.split(' · ')[1] : g.t].filter(Boolean).join(' · ');
      if (f && !(label + ' ' + sub).toLowerCase().includes(f)) return;
      if (rows.length < 400) rows.push(`<button class="gmrow${i === GM.gi ? ' on' : ''}" data-gm="${i}"><b>${i + 1}. ${esc(label)}</b><span>${esc(sub)}</span></button>`);
    });
    const html = rows.join('') || '<div class="muted small">Không có ván phù hợp.</div>';
    if ($('gmList').dataset.sig !== html) { $('gmList').innerHTML = html; $('gmList').dataset.sig = html; const on = $('gmList').querySelector('.on'); if (on) on.scrollIntoView({ block: 'nearest' }); }
    $('gmPly').textContent = GM.ply + '/' + GM.moves.length;
    $('gmGuess').classList.toggle('on', GM.guess);
    $('gmGuess').textContent = GM.guess ? 'Đang luyện đoán nước (' + sideName(GM.gside) + ')' : 'Luyện đoán nước';
  }
  function gmPlay() {
    const g = GM.game; if (!g) return;
    const p = GM.start.clone(); for (let k = 0; k < GM.ply; k++) p.make(GM.moves[k]);
    if (!p.legalMoves().length) { S.coach = { title: 'Ván đã kết thúc ở thế này', cls: null, lines: ['Hãy lùi về một thế cờ trước đó rồi bấm "Đánh tiếp với máy".'] }; render(); return; }
    // cầm bên thắng trong ván gốc (hòa: bên đang tới lượt)
    const side = g.res === 1 ? RED : g.res === -1 ? BLACK : p.side;
    const res = g.res === 1 ? 'Đỏ thắng' : g.res === -1 ? 'Đen thắng' : g.res === 0 ? 'hòa' : '';
    const lines = ['Bạn cầm ' + sideName(side) + (GM.ply ? ' từ nước ' + GM.ply : ' từ thế xuất phát') + ' của ván ' + (g.r ? g.r + ' – ' + g.b : '') + (res ? ' (kết quả gốc: ' + res + ')' : '') + '.'];
    lines.push(g.res === (side === RED ? 1 : -1) ? 'Đại sư đã thắng từ thế này. Hãy thắng máy (cấp ' + S.level + ') để chứng tỏ bạn nắm được cách thắng.' : 'Hãy đánh tiếp và giữ thế cờ trước máy.');
    lines.push('Mẹo: chọn cấp 4–5 trong "Đấu với máy" để máy chống trả mạnh nhất.');
    playFrom({ fen: GM.start.toFen(), moves: GM.moves.slice(0, GM.ply), side, title: (GM.col.title || 'Ván đại sư') + ' · ván ' + (GM.gi + 1), lines });
  }
  function renderKeyToggle() { const b = $('gmKey'); if (b) { b.classList.toggle('on', GM.keyOnly); b.setAttribute('aria-pressed', GM.keyOnly); } }
  function gmButtons() {
    renderKeyToggle();
    if (S.mode !== 'games' || !S.coach || !S.coach.gmNext) return '';
    return '<div class="confirm"><button class="btn primary" data-act="gm-next">Tiếp tục →</button></div>';
  }

  // ---------- Sự kiện ----------
  function sqFromEvent(e) {
    const rect = boardEl.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * W, y = ((e.clientY - rect.top) / rect.height) * H;
    let c = Math.round((x - X0) / CELL), r = Math.round((y - Y0) / CELL);
    if (c < 0 || c > 8 || r < 0 || r > 9) return -1;
    if (flipped()) { r = 9 - r; c = 8 - c; }
    return r * 9 + c;
  }
  boardEl.addEventListener('click', (e) => {
    if (S.view >= 0) { S.view = -1; render(); return; }
    if (S.state !== 'user') return;
    const sq = sqFromEvent(e); if (sq < 0) return;
    const p = S.pos.b[sq];
    if (S.selected >= 0) {
      const m = S.selected | (sq << 7);
      if (S.pos.isLegal(m)) { if (S.mode === 'puzzle') onPuzzleMove(m); else if (S.mode === 'games') onGuessMove(m); else if (S.mode === 'online') olMove(m); else if (S.drill) onDrillMove(m); else onUserMove(m); return; }
    }
    if (p && sgn(p) === S.userSide) { S.selected = sq === S.selected ? -1 : sq; if (S.selected >= 0) sfx('select'); }
    else S.selected = -1;
    renderPieces(); renderOverlay();
  });
  document.addEventListener('click', (e) => {
    const t = e.target.closest('[data-act],[data-view],[data-pz],[data-mode],[data-pro],[data-gm],[data-theme]');
    if (!t) return;
    if (t.dataset.theme != null) { practiceTheme(t.dataset.theme); return; }
    if (t.dataset.view != null && S.mode === 'online') { const i = +t.dataset.view; S.view = S.view === i ? -1 : i; render(); return; }
    if (t.dataset.view != null && S.mode === 'games') { if (S.state !== 'ai') { GM.guess = false; S.userSide = RED; gmGoto(+t.dataset.view + 1); } return; }
    if (t.dataset.gm != null) { gmLoad(+t.dataset.gm); return; }
    if (t.dataset.view != null) {
      const i = +t.dataset.view;
      if (S.state === 'ai') return;
      S.view = S.view === i ? -1 : i; render(); return;
    }
    if (t.dataset.pz != null) { loadPuzzle(+t.dataset.pz); return; }
    if (t.dataset.pro != null) { const m = +t.dataset.pro; S.arrows = S.arrows.length === 1 && S.arrows[0].m === m ? [] : [{ m, kind: 'alt' }]; renderOverlay(); return; }
    if (t.dataset.mode) { setMode(t.dataset.mode); return; }
    const a = t.dataset.act;
    if (a === 'pz-retry') retryPuzzle();
    else if (a === 'pz-next') {
      if (PZ.col.review) { const id = PZ.cur && PZ.cur.rv; PZ.col = reviewCollection(); const due = PZ.col.items.findIndex((p) => p.rv.due <= Date.now()); loadPuzzle(due >= 0 ? due : Math.max(0, PZ.col.items.findIndex((p) => p.rv === id))); }
      else loadPuzzle(PZ.idx + 1 < PZ.col.items.length ? PZ.idx + 1 : 0);
    }
    else if (a === 'rv-del') deleteReview();
    else if (a === 'gm-next') { S.coach.gmNext = false; gmGoto(GM.ply + 1); }
    else if (a === 'gm-first') gmGoto(0);
    else if (a === 'gm-play') gmPlay();
    else if (a === 'ol-quick') olStart('quick');
    else if (a === 'ol-new') olStart('new');
    else if (a === 'ol-join') { const c = $('olCode').value.trim().toUpperCase(); if (c) olStart('join', c); }
    else if (a === 'ol-analyze') olAnalyze();
    else if (a === 'ol-copy') { const inp = document.querySelector('.ol-link input'); navigator.clipboard.writeText(inp.value).then(() => { t.textContent = 'Đã chép'; }, () => { inp.select(); }); }
    else if (a && a.startsWith('ol-')) olAct(a.slice(3));
    else if (a === 'gm-key') { GM.keyOnly = !GM.keyOnly; store.set('gmKey', GM.keyOnly); if (GM.guess && S.state !== 'ai') gmGoto(GM.ply); else render(); }
    else if (a === 'analyze') analyzeGame();
    else if (a === 'gm-last') { GM.guess = false; S.userSide = RED; gmGoto(GM.moves.length); }
    else if (a === 'gm-guess') { GM.guess = !GM.guess; S.userSide = GM.guess ? GM.gside : RED; GM.stat = { ok: 0, near: 0, tot: 0, skip: 0 }; gmGoto(GM.guess ? 0 : GM.ply); }
    else if (a === 'gm-side') { GM.gside = -GM.gside; if (GM.guess) { S.userSide = GM.gside; GM.stat = { ok: 0, near: 0, tot: 0 }; gmGoto(0); } else gmShow(); }
    else if (a === 'pz-prev') loadPuzzle(PZ.idx - 1);
    else if (a === 'pz-restart') loadPuzzle(PZ.idx);
    else if (a === 'pz-solution') showSolution();
    else if (a === 'undo-blunder') confirmBlunder(true);
    else if (a === 'keep-blunder') confirmBlunder(false);
    else if (a === 'exit-view') { S.view = -1; render(); }
  });
  $('olCode').onkeydown = (e) => { if (e.key === 'Enter') { const c = e.target.value.trim().toUpperCase(); if (c) olStart('join', c); } };
  $('hintBtn').onclick = () => S.mode === 'online' ? null : (S.mode === 'puzzle' ? puzzleHint() : S.mode === 'play' && S.drill ? S.state === 'user' && drillHint() : S.mode === 'games' ? (S.state === 'reveal' ? (S.coach.gmNext = false, gmGoto(GM.ply + 1)) : gmGoto(GM.ply + 1)) : showHint());
  $('undoBtn').onclick = () => S.mode === 'online' ? null : (S.mode === 'puzzle' ? loadPuzzle(PZ.idx) : S.mode === 'games' ? gmGoto(GM.guess ? Math.max(0, GM.ply - 2) : GM.ply - 1) : undo());
  $('pzCol').onchange = (e) => openCollection(e.target.value, 0);
  $('impBtn').onclick = () => {
    if (S.hist.length > 2 && !S.result && !confirm('Bỏ ván đang chơi để nhập ván mới?')) return;
    const err = importGame($('impText').value, $('impSide').value);
    $('impErr').textContent = err || '';
    if (!err) $('impText').value = '';
  };
  $('fenBtn').onclick = async () => {
    const f = S.pos.toFen();
    try { await navigator.clipboard.writeText(f); $('impErr').textContent = 'Đã chép FEN thế cờ hiện tại.'; } catch (e) { $('impText').value = f; }
  };
  $('drillBtn').onclick = () => {
    if (S.drill) { S.tok++; stopDrill(true); return; }
    if (S.hist.length > 2 && !S.result && !confirm('Bỏ ván đang chơi để luyện khai cuộc?')) return;
    startDrill(+$('drillOp').value);
  };
  $('gmCol').onchange = (e) => gmOpenCol(e.target.value, 0);
  $('gmFilter').oninput = (e) => { GM.filter = e.target.value; renderGames(); };
  $('newBtn').onclick = () => {
    // ván mới luôn theo bên đã chọn ở "Cầm quân" (không giữ bên của ván đánh tiếp/ván nhập/ván online vừa phân tích)
    if (S.drill) { newGame(false); return; } if (S.hist.length > 2 && !S.result && !confirm('Bỏ ván đang chơi và bắt đầu ván mới?')) return; newGame(false); };
  $('level').onchange = (e) => { S.level = +e.target.value; store.set('level', S.level); };
  $('side').onchange = (e) => {
    S.userSide = +e.target.value; store.set('side', S.userSide);
    newGame(true);
  };
  const optChange = () => {
    S.opt = { warn: $('optWarn').checked, threats: $('optThreats').checked, han: $('optHan').checked, sound: $('optSound').checked };
    store.set('opt', S.opt); render();
  };
  ['optWarn', 'optThreats', 'optHan', 'optSound'].forEach((id) => ($(id).onchange = optChange));
  document.addEventListener('keydown', (e) => {
    if (e.target.tagName === 'SELECT' || e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    if (S.mode === 'online' && e.key !== 'Escape') return; // không gợi ý/đi lại khi chơi online
    if (S.mode === 'games' && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')) { e.preventDefault(); $(e.key === 'ArrowRight' ? 'hintBtn' : 'undoBtn').click(); return; }
    if (e.key === 'h' || e.key === 'H') $('hintBtn').click();
    else if (e.key === 'u' || e.key === 'U' || (e.key === 'z' && (e.metaKey || e.ctrlKey))) $('undoBtn').click();
    else if (e.key === 'Escape') { S.selected = -1; S.view = -1; render(); }
  });

  // ---------- Khởi động ----------
  drawGrid();
  // link mời: ?p=MÃPHÒNG
  const invite = new URLSearchParams(location.search).get('p');
  if (invite && /^[A-Za-z0-9]{4,8}$/.test(invite)) { OL.pendingJoin = invite.toUpperCase(); history.replaceState(null, '', location.pathname); }
  const m0 = OL.pendingJoin ? 'online' : store.get('mode', 'play');
  S.mode = 'none';
  setMode(['play', 'puzzle', 'games', 'online'].includes(m0) ? m0 : 'play');
})();
