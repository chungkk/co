importScripts('engine.js?v=3');
const searcher = new XQ.Search();
onmessage = (e) => {
  const { id, fen, hist, opts } = e.data;
  const pos = XQ.Pos.fromFen(fen);
  if (hist) pos.setHistory(hist);
  const r = searcher.run(pos, opts);
  postMessage(Object.assign({ id }, r));
};
