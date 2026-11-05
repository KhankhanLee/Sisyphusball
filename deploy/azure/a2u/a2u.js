// Sends a small App-to-User (A2U) payment to every Pi player in a ranking
// file, once each. Built for the Testnet app: the Pi Developer Portal asks
// for A2U payments to 5 unique wallets before granting a Mainnet app wallet.
//
//   node a2u.js            # pay everyone not paid yet
//   node a2u.js --dry-run  # only list who would be paid
//
// Env: PI_API_KEY, APP_WALLET_SEED (the Testnet app wallet's secret, S...),
//      SCORES_FILE, LEDGER_FILE, AMOUNT (default 0.01), PI_API_BASE (tests).
// Every step is written to LEDGER_FILE before the next one, so a crash never
// pays anyone twice: a rerun finishes or cancels what was left open.
const fs = require('fs');
const PiNetwork = require('pi-backend').default;

const dryRun = process.argv.includes('--dry-run');
const scoresFile = process.env.SCORES_FILE || '/data/scores.json';
const ledgerFile = process.env.LEDGER_FILE || '/data/a2u-ledger.json';
const amount = Number(process.env.AMOUNT || '0.01');
const memo = 'Thanks for pushing the stone on Sisyphusball';

const readJson = (file, fallback) => (fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : fallback);
const ledger = readJson(ledgerFile, {});
const save = () => {
  fs.writeFileSync(`${ledgerFile}.tmp`, JSON.stringify(ledger, null, 2));
  fs.renameSync(`${ledgerFile}.tmp`, ledgerFile);
};
const errorText = (e) =>
  e?.response?.status ? `${e.response.status} ${JSON.stringify(e.response.data)}` : e?.message || e?.response?.title || String(e);

const players = (readJson(scoresFile, { players: [] }).players || [])
  .filter((p) => typeof p.uid === 'string' && p.uid.startsWith('pi:'))
  .map((p) => ({ uid: p.uid.slice(3), username: p.username }));

async function main() {
  const todo = players.filter((p) => ledger[p.uid]?.status !== 'completed');
  console.log(`${players.length} Pi players, ${players.length - todo.length} already paid, ${todo.length} to pay.`);
  for (const p of todo) console.log(`  - ${p.username}`);
  if (dryRun || todo.length === 0) return;

  const { PI_API_KEY, APP_WALLET_SEED } = process.env;
  if (!PI_API_KEY || !APP_WALLET_SEED) throw new Error('PI_API_KEY and APP_WALLET_SEED are required');
  const pi = new PiNetwork(PI_API_KEY, APP_WALLET_SEED, process.env.PI_API_BASE ? { baseUrl: process.env.PI_API_BASE } : null);

  // Pi allows one open A2U payment at a time: finish or cancel a leftover first.
  const incomplete = await pi.getIncompleteServerPayments();
  const leftovers = Array.isArray(incomplete) ? incomplete : incomplete?.incomplete_server_payments || [];
  for (const open of leftovers) {
    const entry = Object.values(ledger).find((e) => e.paymentId === open.identifier);
    if (open.transaction?.txid) {
      await pi.completePayment(open.identifier, open.transaction.txid);
      if (entry) Object.assign(entry, { txid: open.transaction.txid, status: 'completed' });
      console.log(`Completed a leftover payment ${open.identifier}`);
    } else {
      await pi.cancelPayment(open.identifier);
      if (entry) entry.status = 'cancelled';
      console.log(`Cancelled a leftover payment ${open.identifier}`);
    }
    save();
  }

  for (const p of todo) {
    try {
      const paymentId = await pi.createPayment({ amount, memo, metadata: { app: 'sisyphusball', kind: 'tester-thanks' }, uid: p.uid });
      ledger[p.uid] = { username: p.username, paymentId, status: 'created' };
      save();

      const payment = await pi.getPayment(paymentId);
      if (payment.network !== 'Pi Testnet' && process.env.ALLOW_MAINNET !== 'yes') {
        await pi.cancelPayment(paymentId);
        ledger[p.uid].status = 'cancelled';
        save();
        throw new Error(`refusing to pay real Pi on "${payment.network}" (set ALLOW_MAINNET=yes to allow)`);
      }

      const txid = await pi.submitPayment(paymentId);
      Object.assign(ledger[p.uid], { txid, status: 'submitted' });
      save();

      const done = await pi.completePayment(paymentId, txid);
      ledger[p.uid].status = done.status.developer_completed ? 'completed' : 'submitted';
      save();
      console.log(`Paid ${amount} to ${p.username} (tx ${txid})`);
    } catch (e) {
      if (String(e.message).startsWith('refusing')) throw e;
      console.error(`Failed for ${p.username}: ${errorText(e)}`);
      // Nothing reached the blockchain: cancel, so the next payment (or a
      // rerun) is not blocked by this open one.
      const entry = ledger[p.uid];
      if (entry?.status === 'created') {
        await pi.cancelPayment(entry.paymentId).then(() => { entry.status = 'cancelled'; save(); }, () => {});
      }
      process.exitCode = 1;
    }
  }
  const paid = Object.values(ledger).filter((e) => e.status === 'completed').length;
  console.log(`Done. ${paid} unique players paid so far.`);
}

main().catch((e) => {
  console.error(errorText(e));
  process.exit(1);
});
