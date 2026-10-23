#!/usr/bin/env node
// Yetim davet temizliği — TEK SEFERLİK, dağıtımdan ÖNCE.
//
//   node scripts/yetim-davetler.mjs --proje <firebase-proje-kimliği>            # yalnızca LİSTELER
//   node scripts/yetim-davetler.mjs --proje <firebase-proje-kimliği> --uygula   # siler
//
// NEDEN: `deleteAccount` eskiden proje belgesini davetlerden ÖNCE siliyordu.
// İkisinin arasında kesinti olursa `invites/{KOD}` belgeleri, var olmayan bir
// projeyi gösteren YETİMLER olarak kalıyordu. İçlerinde `usedByName` — daveti
// kullanan kişinin gerçek adı — var (KVKK).
//
// Sıra 23 Ekim'de düzeltildi, ama yeni okuma kuralı (sahip kendi projesinin
// davetini okur) yayına girdiğinde ESKİ yetimler bir açık olur: proje
// kimliğini bilen biri (ör. eski bir ortak) aynı kimlikle proje kurup sahip
// olursa onları okuyabilir. Bu yüzden okuma kuralından ÖNCE temizlenmeli.
//
// KİMLİK BİLGİSİ: Yönetici SDK'sı "Application Default Credentials" kullanır:
//   gcloud auth application-default login
// Proje kimliği bilerek argüman — depoya ve çıktıya yazılmıyor.

import { createRequire } from 'node:module';

const require = createRequire(new URL('../functions/package.json', import.meta.url));
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const argv = process.argv.slice(2);
const i = argv.indexOf('--proje');
const projectId = i >= 0 ? argv[i + 1] : undefined;
const uygula = argv.includes('--uygula');

if (!projectId) {
  console.error('Kullanım: node scripts/yetim-davetler.mjs --proje <kimlik> [--uygula]');
  process.exit(2);
}

initializeApp({ projectId });
const db = getFirestore();

const davetler = await db.collection('invites').get();
const projeVar = new Map();
const yetimler = [];

for (const d of davetler.docs) {
  const pid = d.get('projectId');
  if (typeof pid !== 'string' || pid.length === 0) {
    yetimler.push({ ref: d.ref, neden: 'projectId yok' });
    continue;
  }
  if (!projeVar.has(pid)) {
    projeVar.set(pid, (await db.collection('projects').doc(pid).get()).exists);
  }
  if (!projeVar.get(pid)) yetimler.push({ ref: d.ref, neden: 'proje belgesi yok' });
}

// Kodun kendisi ve ad YAZDIRILMIYOR: bu çıktı bir terminal günlüğüne ya da
// sohbete yapıştırılabilir. Yalnızca sayı ve neden.
console.log(`Toplam davet: ${davetler.size} · yetim: ${yetimler.length}`);
const nedenler = {};
for (const y of yetimler) nedenler[y.neden] = (nedenler[y.neden] ?? 0) + 1;
for (const [neden, sayi] of Object.entries(nedenler)) console.log(`  ${neden}: ${sayi}`);

if (!uygula) {
  console.log(yetimler.length ? 'Silmek için --uygula ile yeniden çalıştır.' : 'Temizlenecek bir şey yok.');
  process.exit(0);
}

// Yönetici SDK'sı kuralları atlıyor; davet belgelerini yalnızca o silebilir.
for (let b = 0; b < yetimler.length; b += 400) {
  const batch = db.batch();
  for (const y of yetimler.slice(b, b + 400)) batch.delete(y.ref);
  await batch.commit();
}
console.log(`${yetimler.length} yetim davet silindi.`);
