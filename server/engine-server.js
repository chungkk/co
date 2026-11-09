// Máy chủ phân tích: chạy sẵn vài tiến trình Pikafish (UCI) và trả lời POST /api/analyse.
// Không dùng thư viện ngoài. Biến môi trường:
//   PIKAFISH   đường dẫn file chạy (mặc định /opt/pikafish/pikafish); pikafish.nnue nằm cùng thư mục
//   ENGINES    số tiến trình engine (mặc định 2), mỗi tiến trình 1 luồng
//   HASH_MB    bộ nhớ băm mỗi tiến trình (mặc định 64)
//   PORT       cổng nghe (mặc định 8080, chỉ 127.0.0.1)
'use strict';
const http = require('http');
const { spawn } = require('child_process');
const path = require('path');

const BIN = process.env.PIKAFISH || '/opt/pikafish/pikafish';
const ENGINES = Math.max(1, +process.env.ENGINES || 2);
const HASH_MB = Math.max(16, +process.env.HASH_MB || 64);
const PORT = +process.env.PORT || 8080;
const HOST = process.env.HOST || '127.0.0.1';
const MAX_QUEUE = 16; // quá số này trả 503 để máy khách dùng engine trong trình duyệt
const MAX_PER_IP = 3; // số yêu cầu đang chờ tối đa của một địa chỉ
const MAX_MS = 2000, MIN_MS = 100, MAX_PV = 5;

const FEN_RE = /^[rnbakcpRNBAKCP1-9]{1,9}(\/[rnbakcpRNBAKCP1-9]{1,9}){9} [wb]$/;

class Engine {
  constructor(id) { this.id = id; this.busy = false; this.start(); }
  start() {
    this.buf = ''; this.job = null; this.ready = false;
    const p = (this.p = spawn(BIN, [], { cwd: path.dirname(BIN), stdio: ['pipe', 'pipe', 'ignore'] }));
    this.alive = true;
    p.on('error', (e) => log('engine', this.id, 'lỗi', e.message));
    p.stdin.on('error', () => { /* tiến trình đã thoát */ });
    p.on('exit', (code, sig) => {
      if (this.p !== p) return;
      log('engine', this.id, 'thoát', code ?? sig);
      this.alive = false; this.ready = false;
      if (this.job) this.finish(new Error('engine exited'));
      setTimeout(() => this.start(), 1000);
    });
    p.stdout.on('data', (d) => {
      this.buf += d;
      let i;
      while ((i = this.buf.indexOf('\n')) >= 0) { const line = this.buf.slice(0, i).trim(); this.buf = this.buf.slice(i + 1); this.line(line); }
    });
    this.send('uci');
    this.send('setoption name Threads value 1');
    this.send('setoption name Hash value ' + HASH_MB);
    this.send('isready');
  }
  send(s) { try { this.p.stdin.write(s + '\n'); } catch (e) { /* tiến trình đang khởi động lại */ } }
  line(l) {
    if (l === 'readyok') { this.ready = true; pump(); return; }
    const j = this.job; if (!j) return;
    if (l.startsWith('info ') && l.includes(' multipv ') && l.includes(' pv ')) {
      // bỏ các dòng chưa chính xác (lowerbound/upperbound) giữa chừng
      if (/ (lower|upper)bound /.test(l)) return;
      const t = l.split(' '), at = (k) => t.indexOf(k);
      const k = +t[at('multipv') + 1], depth = +t[at('depth') + 1];
      const si = at('score'), kind = t[si + 1], val = +t[si + 2];
      const pv = t.slice(at('pv') + 1);
      if (!pv.length) return;
      // các dòng multipv của cùng một độ sâu đi cùng nhau; sang độ sâu mới thì giữ lại bộ cũ để bù chỗ thiếu
      if (k === 1 && depth !== j.depth) { if (j.cur.length) j.prev = j.cur; j.cur = []; j.depth = depth; }
      j.cur[k - 1] = { depth, pv, ...(kind === 'mate' ? { mate: val } : { cp: val }) };
    } else if (l.startsWith('bestmove')) {
      const best = l.split(' ')[1];
      const lines = [], seen = new Set();
      for (const x of j.cur.filter(Boolean).concat(j.prev.filter(Boolean))) {
        if (lines.length >= j.mpv || seen.has(x.pv[0])) continue;
        seen.add(x.pv[0]); lines.push(x);
      }
      if (!lines.length && best && best !== '(none)') lines.push({ depth: 0, pv: [best], cp: 0 });
      this.finish(null, { multi: lines.map((x) => ({ move: x.pv[0], pv: x.pv.slice(0, 12), cp: x.cp, mate: x.mate })), depth: lines.length ? Math.max(...lines.map((x) => x.depth)) : 0 });
    }
  }
  run(job) {
    this.busy = true; this.job = job; job.cur = []; job.prev = []; job.depth = 0;
    const p = this.p;
    job.timer = setTimeout(() => {
      log('engine', this.id, 'quá giờ, khởi động lại');
      this.alive = false; this.ready = false;
      if (this.job === job) this.finish(new Error('timeout'));
      p.kill('SIGKILL');
    }, job.ms + 5000);
    this.send('setoption name MultiPV value ' + job.mpv);
    this.send('position fen ' + job.fen + ' - - 0 1');
    this.send('go movetime ' + job.ms);
  }
  finish(err, res) {
    const j = this.job; this.job = null; this.busy = false;
    clearTimeout(j.timer);
    j.done(err, res);
    pump();
  }
}

const pool = [];
const queue = [];
const perIp = new Map();
function pump() {
  while (queue.length) {
    const e = pool.find((x) => x.alive && x.ready && !x.busy);
    if (!e) return;
    e.run(queue.shift());
  }
}

// bộ nhớ đệm: khai cuộc và các thế cờ hay gặp được hỏi lại rất nhiều
const cache = new Map(), CACHE_MAX = 5000;
function cacheGet(k) { const v = cache.get(k); if (v) { cache.delete(k); cache.set(k, v); } return v; }
function cacheSet(k, v) { cache.set(k, v); if (cache.size > CACHE_MAX) cache.delete(cache.keys().next().value); }

function analyse(fen, mpv, ms, ip) {
  return new Promise((resolve, reject) => {
    const key = fen + '|' + mpv + '|' + ms, hit = cacheGet(key);
    if (hit) return resolve({ ...hit, cached: true });
    if (queue.length >= MAX_QUEUE) return reject(Object.assign(new Error('busy'), { status: 503 }));
    const n = perIp.get(ip) || 0;
    if (n >= MAX_PER_IP) return reject(Object.assign(new Error('too many'), { status: 429 }));
    perIp.set(ip, n + 1);
    queue.push({
      fen, mpv, ms,
      done(err, res) {
        const m = perIp.get(ip) - 1; if (m > 0) perIp.set(ip, m); else perIp.delete(ip);
        if (err) return reject(err);
        cacheSet(key, res); resolve(res);
      },
    });
    pump();
  });
}

function send(res, status, body) {
  const s = JSON.stringify(body);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': '*' });
  res.end(s);
}

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, GET', 'Access-Control-Allow-Headers': 'Content-Type', 'Access-Control-Max-Age': '86400' });
    return res.end();
  }
  if (req.url === '/api/health') return send(res, 200, { ok: pool.some((e) => e.ready), engines: pool.length, queue: queue.length, cache: cache.size });
  if (req.url !== '/api/analyse' || req.method !== 'POST') return send(res, 404, { error: 'not found' });
  let body = '';
  req.on('data', (d) => { body += d; if (body.length > 2000) req.destroy(); });
  req.on('end', async () => {
    let q;
    try { q = JSON.parse(body); } catch (e) { return send(res, 400, { error: 'bad json' }); }
    const fen = String(q.fen || '').trim();
    if (!FEN_RE.test(fen)) return send(res, 400, { error: 'bad fen' });
    const mpv = Math.min(MAX_PV, Math.max(1, q.multipv | 0 || 1));
    const ms = Math.min(MAX_MS, Math.max(MIN_MS, q.ms | 0 || 1000));
    // sau proxy (Coolify/Traefik → nginx): địa chỉ thật là phần đầu của X-Forwarded-For
    const ip = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress).split(',')[0].trim();
    const t0 = Date.now();
    try {
      const r = await analyse(fen, mpv, ms, ip);
      send(res, 200, { ...r, ms: Date.now() - t0 });
    } catch (e) {
      send(res, e.status || 500, { error: e.message });
    }
  });
});

function log(...a) { console.log(new Date().toISOString(), ...a); }

for (let i = 0; i < ENGINES; i++) pool.push(new Engine(i));
server.listen(PORT, HOST, () => log('engine-server nghe', HOST + ':' + PORT, 'engines', ENGINES, 'bin', BIN));
