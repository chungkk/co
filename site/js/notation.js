/* Đọc thế cờ (FEN) và biên bản nước đi người dùng dán vào.
   Hỗ trợ: tiếng Việt đầy đủ ("Pháo 2 bình 5"), ký hiệu Việt ngắn (P2-5, M8.7, X1/1),
   WXF (C2.5 / C2=5, H8+7, R1-1, +C.5) và chữ Hán (炮二平五, 馬８進７, 前炮平五). */
(function (G) {
  'use strict';
  const { Pos } = G.XQ;
  // khóa chuẩn của một nước: quân · cột (hoặc +/- cho trước/sau) · hướng (+ tiến, - thoái, = bình) · số
  const PC = { 'Tướng': 'K', 'Sĩ': 'A', 'Tượng': 'B', 'Mã': 'N', 'Xe': 'R', 'Pháo': 'C', 'Tốt': 'P' };
  function keyOf(pos, m) {
    const [pc, id, op, n] = pos.moveName(m).split(' ');
    return PC[pc] + (id === 'trước' ? '+' : id === 'sau' ? '-' : id) + (op === 'tiến' ? '+' : op === 'thoái' ? '-' : '=') + n;
  }

  const VN_FULL = /(tướng|tuong|sĩ|si|tượng|tuong|mã|ma|xe|pháo|phao|tốt|tot|binh)\s*(\d|trước|truoc|sau)\s*(tiến|tien|thoái|thoai|bình|binh)\s*(\d)/gi;
  const VN_PC = { 'tướng': 'K', 'sĩ': 'A', 'si': 'A', 'tượng': 'B', 'mã': 'N', 'ma': 'N', 'xe': 'R', 'pháo': 'C', 'phao': 'C', 'tốt': 'P', 'tot': 'P', 'binh': 'P' };
  const VN_OP = { 'tiến': '+', 'tien': '+', 'thoái': '-', 'thoai': '-', 'bình': '=', 'binh': '=' };
  function vnFull(text) {
    const out = [];
    for (const x of text.matchAll(VN_FULL)) {
      let p = x[1].toLowerCase();
      if (p === 'tuong') p = /ư|ợ/.test(x[1]) ? 'tượng' : 'tướng'; // không dấu: mặc định Tướng
      const id = x[2].toLowerCase();
      out.push([VN_PC[p] + (/^tr/.test(id) ? '+' : id === 'sau' ? '-' : id) + VN_OP[x[3].toLowerCase()] + x[4]]);
    }
    return out;
  }
  // ký hiệu ngắn: VN (X M T S P B Tg; . tiến, / thoái, - bình) và WXF (R H/N E/B A K C P; + tiến, - thoái, . = bình)
  const SHORT = /([+\-]?)(tg|[a-z])([1-9+\-]?)([.\-+=\/])([1-9])/gi;
  const VN_S = { x: 'R', m: 'N', t: 'B', s: 'A', p: 'C', b: 'P', tg: 'K', k: 'K' };
  const WXF_S = { r: 'R', h: 'N', n: 'N', e: 'B', b: 'B', a: 'A', k: 'K', c: 'C', p: 'P' };
  function short(text, scheme) {
    const out = [];
    for (const x of text.matchAll(SHORT)) {
      const pc = (scheme === 'vn' ? VN_S : WXF_S)[x[2].toLowerCase()];
      if (!pc) { out.push([]); continue; }
      const op = scheme === 'vn' ? { '.': '+', '/': '-', '-': '=', '+': '+', '=': '=' }[x[4]] : { '+': '+', '-': '-', '.': '=', '=': '=', '/': '-' }[x[4]];
      let id = x[3] || x[1];
      out.push(id ? [pc + id + op + x[5]] : []);
    }
    return out;
  }
  const ZH_PC = { '车': 'R', '車': 'R', '俥': 'R', '马': 'N', '馬': 'N', '傌': 'N', '炮': 'C', '砲': 'C', '包': 'C', '兵': 'P', '卒': 'P', '相': 'B', '象': 'B', '仕': 'A', '士': 'A', '帅': 'K', '帥': 'K', '将': 'K', '將': 'K' };
  const ZH_N = { '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '１': 1, '２': 2, '３': 3, '４': 4, '５': 5, '６': 6, '７': 7, '８': 8, '９': 9 };
  const zn = (c) => ZH_N[c] || +c;
  const ZH_OP = { '进': '+', '進': '+', '退': '-', '平': '=' };
  const ZH = /([前后後])?([车車俥马馬傌炮砲包兵卒相象仕士帅帥将將])([一二三四五六七八九1-9１-９前后後])?([进進退平])([一二三四五六七八九1-9１-９])/g;
  function zh(text) {
    const out = [];
    for (const x of text.matchAll(ZH)) {
      const id = x[1] || x[3];
      const i = id === '前' ? '+' : id === '后' || id === '後' ? '-' : id ? zn(id) : '';
      out.push(i === '' ? [] : [ZH_PC[x[2]] + i + ZH_OP[x[4]] + zn(x[5])]);
    }
    return out;
  }

  // phát lại các khóa nước trên thế cờ; trả về số nước hợp lệ đọc được
  function replay(start, toks) {
    const p = start.clone(), moves = [];
    for (const cands of toks) {
      const legal = p.legalMoves();
      const m = legal.find((x) => cands.includes(keyOf(p, x)));
      if (m === undefined) return { moves, bad: moves.length };
      moves.push(m); p.make(m);
    }
    return { moves };
  }

  const FEN_RE = /([rnbakcpheRNBAKCPHE1-9]{1,9}\/){9}[rnbakcpheRNBAKCPHE1-9]{1,9}(\s+[wbr])?/;
  function checkFen(fen) {
    const [bd, s = 'w'] = fen.trim().split(/\s+/);
    const rows = bd.split('/');
    if (rows.length !== 10) return 'FEN phải có 10 hàng.';
    let kr = 0, kb = 0;
    for (const r of rows) {
      let n = 0;
      for (const ch of r) { if (/\d/.test(ch)) n += +ch; else n++; if (ch === 'K') kr++; if (ch === 'k') kb++; }
      if (n !== 9) return 'Mỗi hàng của FEN phải có đúng 9 ô.';
    }
    if (kr !== 1 || kb !== 1) return 'Thế cờ phải có đúng một Tướng mỗi bên.';
    const p = Pos.fromFen(bd + ' ' + (s === 'b' ? 'b' : 'w'));
    if (p.inCheck(-p.side)) return 'Bên vừa đi đang bị chiếu: thế cờ không hợp lệ.';
    return null;
  }

  /* Đọc văn bản: trả về { fen, moves, err, notation }.
     fen: thế xuất phát (null = thế ban đầu), moves: các nước đọc được. */
  function parse(text) {
    text = String(text || '').replace(/\r/g, '');
    let fen = null, rest = text;
    const fm = text.match(FEN_RE);
    if (fm) {
      fen = fm[0].trim().replace(/\s+r$/, ' w');
      if (!/\s[wb]$/.test(fen)) fen += ' w';
      const err = checkFen(fen);
      if (err) return { err };
      rest = text.slice(0, fm.index) + ' ' + text.slice(fm.index + fm[0].length);
    }
    const start = fen ? Pos.fromFen(fen) : Pos.start();
    // bỏ số thứ tự nước ("1.", "12)") để không lẫn với ký hiệu
    const clean = rest.replace(/(^|\s)\d+\s*[.)]\s/g, ' ');
    const tries = [
      ['vn-full', vnFull(clean)],
      ['zh', zh(clean)],
      ['vn', short(clean.replace(VN_FULL, ' '), 'vn')],
      ['wxf', short(clean.replace(VN_FULL, ' '), 'wxf')],
    ];
    let best = null;
    for (const [name, toks] of tries) {
      if (!toks.length) continue;
      const r = replay(start, toks);
      const score = r.moves.length - (r.bad !== undefined ? 0.5 : 0);
      if (!best || score > best.score) best = { name, toks, r, score };
    }
    if (!best) {
      if (fen) return { fen, moves: [] };
      return { err: 'Không đọc được thế cờ hay nước đi nào. Hãy dán FEN hoặc biên bản như "Pháo 2 bình 5, Mã 8 tiến 7…", "C2.5 H8+7…" hoặc "炮二平五 馬8進7…".' };
    }
    const out = { fen, moves: best.r.moves, notation: best.name };
    if (best.r.bad !== undefined) {
      out.warn = 'Chỉ đọc được ' + best.r.moves.length + '/' + best.toks.length + ' nước: nước thứ ' + (best.r.bad + 1) + ' không hợp lệ ở thế cờ đó.';
    }
    return out;
  }

  G.Notation = { parse, checkFen, keyOf };
})(typeof self !== 'undefined' ? self : globalThis);
