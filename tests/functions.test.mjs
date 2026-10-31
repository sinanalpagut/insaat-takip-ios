// İnşaat Takip — redeemInvite Cloud Function testleri
//
// Kural testleri (rules.test.mjs) kuralları doğruluyor; bu dosya İŞLEVİN
// KENDİSİNİ doğruluyor. İkisi ayrı şeyler: kurallar "kim neye dokunabilir"
// sorusuna cevap veriyor, işlev ise dört belgeyi atomik yazan, kodun süresini
// ve tek kullanımını denetleyen mantığı taşıyor. O mantık kural testlerinden
// görünmez.
//
//   npm test        (firestore + auth + functions emülatörleri)
//
// Emülatöre karşı çalışır; gerçek projeye dokunmaz.

import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';

const PROJECT_ID = 'demo-insaattakip';
const FIRESTORE = `http://127.0.0.1:8080/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const AUTH = `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1`;
// Bölge, functions/src/index.ts'teki `setGlobalOptions` ile AYNI olmak zorunda.
const CALLABLE = `http://127.0.0.1:5001/${PROJECT_ID}/europe-west1/redeemInvite`;
const DELETE_FN = `http://127.0.0.1:5001/${PROJECT_ID}/europe-west1/deleteAccount`;

const OWNER = 'uid-owner';
const P1 = 'project-1';

// ── Firestore yardımcıları (kurallar devre dışı: "Bearer owner") ──

const adminHeaders = { Authorization: 'Bearer owner', 'Content-Type': 'application/json' };

async function putDoc(path, fields) {
  const res = await fetch(`${FIRESTORE}/${path}`, {
    method: 'PATCH', headers: adminHeaders, body: JSON.stringify({ fields }),
  });
  if (!res.ok) throw new Error(`putDoc ${path}: ${res.status} ${await res.text()}`);
}

async function getFields(path) {
  const res = await fetch(`${FIRESTORE}/${path}`, { headers: adminHeaders });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`getFields ${path}: ${res.status}`);
  return (await res.json()).fields ?? {};
}

async function listDocs(path) {
  const res = await fetch(`${FIRESTORE}/${path}`, { headers: adminHeaders });
  if (!res.ok) return [];
  return (await res.json()).documents ?? [];
}

async function clearFirestore() {
  await fetch(`http://127.0.0.1:8080/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' });
}

const str = (v) => ({ stringValue: v });
const ts = (d) => ({ timestampValue: d.toISOString() });
const arr = (values) => ({ arrayValue: { values: values.map(str) } });

// ── Auth emülatöründe kullanıcı üretip jeton al ──

async function newUser() {
  const res = await fetch(`${AUTH}/accounts:signUp?key=fake-api-key`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  const j = await res.json();
  if (!j.idToken) throw new Error(`signUp: ${JSON.stringify(j)}`);
  return { uid: j.localId, idToken: j.idToken };
}

// ── App Check jetonu (madde 71) ──
//
// İKİ CALLABLE DA ARTIK ZORLAMAYA TABİ (`enforceAppCheck: true`). Jetonsuz
// çağrı 401 alıyor; bu dosyanın 39 testi zorlama açıldığı anda topluca
// düştü ve zorlamanın GERÇEKTEN uygulandığının ilk kanıtı o oldu.
//
// EMÜLATÖRDE JETON DOĞRULANMIYOR, ÇÖZÜLÜYOR. Firebase Functions emülatörü
// `skipTokenVerification` ile koşuyor, yani imzaya bakmadan JWT'yi açıp
// `sub` alanını `app_id` yapıyor. Bu yüzden imzasız bir JWT yeterli.
//
// BUNUN NE KANITLADIĞI, NE KANITLAMADIĞI AÇIK OLSUN: burada kanıtlanan şey
// işlevin jeton İSTEMESİ. Jetonun gerçekten App Attest'ten geldiği YALNIZCA
// gerçek cihazda, Release derlemesiyle kanıtlanabilir — emülatörde App
// Attest hiç çalışmıyor.
// `b64url` aşağıda zaten tanımlı (eskimiş jeton üretimi için) ve işlev
// bildirimi olduğu için modül başına yükseliyor — ikinci bir kopya
// çıkarmaya gerek yok.
const APP_CHECK_TOKEN =
  `${b64url({ alg: 'none', typ: 'JWT' })}.` +
  `${b64url({ sub: '1:0:ios:emulator', aud: [`projects/${PROJECT_ID}`] })}.imzasiz`;

// ── Callable çağrısı ──

async function redeem(idToken, code, { appCheck = true } = {}) {
  const res = await fetch(CALLABLE, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
      ...(appCheck ? { 'X-Firebase-AppCheck': APP_CHECK_TOKEN } : {}),
    },
    body: JSON.stringify({ data: { code } }),
  });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, result: body.result, error: body.error };
}

async function deleteAccount(idToken, { appCheck = true } = {}) {
  const res = await fetch(DELETE_FN, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
      ...(appCheck ? { 'X-Firebase-AppCheck': APP_CHECK_TOKEN } : {}),
    },
    body: JSON.stringify({ data: {} }),
  });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, result: body.result, error: body.error };
}

// ── Storage emülatörü yardımcıları ──
//
// KOVA ADI BİLEREK `.appspot.com`: işlevin `projectBucket()` çözücüsü önce
// `.firebasestorage.app` adayını yokluyor, o kova emülatörde YOK, ve
// `.appspot.com`'a düşüyor. Yani bu testler çözücünün "adı tahmin etme, VAR
// OLANI bul" davranışını da kanıtlıyor — ilk adayı körü körüne kullansaydı
// dosyalar silinmeden kalır ve test kırmızıya dönerdi.
const BUCKET = `${PROJECT_ID}.appspot.com`;
const STORAGE = `http://127.0.0.1:9199/v0/b/${BUCKET}/o`;

async function putObject(path) {
  const res = await fetch(`${STORAGE}?name=${encodeURIComponent(path)}`, {
    method: 'POST',
    // Storage emülatörü de kuralları uyguluyor; "Bearer owner" yönetici geçişi
    // (Firestore yardımcılarındaki `adminHeaders` ile aynı sözleşme).
    headers: { 'Content-Type': 'image/jpeg', Authorization: 'Bearer owner' },
    body: new Uint8Array([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]),
  });
  if (!res.ok) throw new Error(`putObject ${path}: ${res.status} ${await res.text()}`);
}

async function objectExists(path) {
  const res = await fetch(`${STORAGE}/${encodeURIComponent(path)}`,
                          { headers: { Authorization: 'Bearer owner' } });
  return res.status === 200;
}

// ── Auth emülatörü: kullanıcı gerçekten silindi mi? ──

async function authUserExists(uid) {
  const res = await fetch(`${AUTH}/projects/${PROJECT_ID}/accounts:lookup`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
    body: JSON.stringify({ localId: [uid] }),
  });
  if (!res.ok) throw new Error(`accounts:lookup ${res.status} ${await res.text()}`);
  const { users = [] } = await res.json();
  return users.length > 0;
}

// ── Eskimiş `auth_time` taşıyan jeton üretimi ──
//
// Auth emülatörünün ID jetonları İMZASIZ JWT ("alg":"none") ve firebase-admin
// emülatör kipinde imza doğrulamıyor — `exp`, `aud`, `iss`, `sub` alanlarına
// bakıyor. Bu yüzden `auth_time` alanını değiştirip yeniden paketlemek,
// "bir saat önce kimlik doğrulamış kullanıcının hâlâ geçerli jetonu"nu
// gerçekçi biçimde canlandırıyor. Kaçırılmış jeton senaryosu tam olarak bu.

function b64url(obj) {
  return Buffer.from(JSON.stringify(obj)).toString('base64url');
}

function withAuthTime(idToken, secondsAgo) {
  const [header, payload, signature] = idToken.split('.');
  const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  claims.auth_time = Math.floor(Date.now() / 1000) - secondsAgo;
  return `${header}.${b64url(claims)}.${signature}`;
}

// ── Zemin ──

async function seedProject() {
  await putDoc(`projects/${P1}`, {
    id: str(P1), ownerUid: str(OWNER), memberUids: arr([OWNER]),
    blockNumber: str('145'), parcelNumber: str('2'), createdAt: ts(new Date()),
  });
}

async function seedInvite(code, { expiresAt, usedAt = null, projectId = P1 } = {}) {
  const fields = {
    projectId: str(projectId),
    createdAt: ts(new Date()),
    expiresAt: ts(expiresAt ?? new Date(Date.now() + 48 * 3600 * 1000)),
  };
  if (usedAt) fields.usedAt = ts(usedAt);
  await putDoc(`invites/${code}`, fields);
}

let user;

before(async () => {
  await clearFirestore();
  await seedProject();
  user = await newUser();
});

after(async () => { await clearFirestore(); });

// ═══════════════════════════ Mutlu yol ═══════════════════════════

describe('redeemInvite — geçerli kod', () => {
  const CODE = 'X7B9Q2';

  before(async () => {
    await seedInvite(CODE);
    // İsim SUNUCUDAN geliyor: işlev `users/{uid}` profilini okuyor, istemciden
    // ad almıyor. Profil olmadan telefona ya da "Ortak"a düşer.
    await putDoc(`users/${user.uid}`, {
      uid: str(user.uid), name: str('Serkan Aydın'), phone: str('+905321112233'),
    });
  });

  it('projeye katılır ve proje başlığını döndürür', async () => {
    const { status, result, error } = await redeem(user.idToken, CODE);
    assert.equal(status, 200, `beklenmeyen hata: ${JSON.stringify(error)}`);
    assert.equal(result.projectId, P1);
    assert.equal(result.projectTitle, '145 Ada / 2 Parsel');
    assert.equal(result.alreadyMember, false);
  });

  it('memberUids’e eklenir — gizlilik sınırı buradan çözülüyor', async () => {
    const f = await getFields(`projects/${P1}`);
    const members = f.memberUids.arrayValue.values.map((v) => v.stringValue);
    assert.ok(members.includes(user.uid), 'uid üye listesinde yok');
    assert.ok(members.includes(OWNER), 'sahip üye listesinden düşmüş');
  });

  it('ortak kaydı SUNUCUDAKİ adla yazılır', async () => {
    const partners = await listDocs(`projects/${P1}/partners`);
    const mine = partners.find((d) => d.fields.userUid?.stringValue === user.uid);
    assert.ok(mine, 'ortak kaydı yok');
    assert.equal(mine.fields.name.stringValue, 'Serkan Aydın');
    assert.equal(mine.fields.isFounder.booleanValue, false);
    // Hisseyi yönetici tanımlar; işlev pay dağıtmaz.
    assert.equal(Number(mine.fields.sharePercent.integerValue), 0);
  });

  it('hareket akışına "katıldı" satırı düşer', async () => {
    const acts = await listDocs(`projects/${P1}/activities`);
    const joined = acts.find((d) => d.fields.kind?.stringValue === 'partnerJoined');
    assert.ok(joined, 'katılım hareketi yok');
    assert.equal(joined.fields.title.stringValue, 'Serkan Aydın projeye katıldı');
  });

  it('kod harcanır', async () => {
    const f = await getFields(`invites/${CODE}`);
    assert.ok(f.usedAt, 'usedAt boş');
    assert.equal(f.usedByUid.stringValue, user.uid);
    assert.equal(f.usedByName.stringValue, 'Serkan Aydın');
  });

  it('aynı kod ikinci kez kullanılamaz', async () => {
    const other = await newUser();
    const { status, error } = await redeem(other.idToken, CODE);
    assert.notEqual(status, 200);
    assert.equal(error.message, 'code-used');
  });
});

// ═══════════════════════════ Reddedilmesi gerekenler ═══════════════════════════

describe('redeemInvite — reddedilen durumlar', () => {
  it('oturum açmamış çağrı reddedilir', async () => {
    const { status, error } = await redeem(null, 'AAAAAA');
    assert.notEqual(status, 200);
    assert.equal(error.message, 'signed-in-required');
  });

  it('olmayan kod reddedilir', async () => {
    const { status, error } = await redeem(user.idToken, 'ZZZZZZ');
    assert.notEqual(status, 200);
    assert.equal(error.message, 'code-not-found');
  });

  it('6 haneden kısa kod reddedilir', async () => {
    const { status, error } = await redeem(user.idToken, 'AB');
    assert.notEqual(status, 200);
    assert.equal(error.message, 'code-format');
  });

  it('süresi dolmuş kod reddedilir', async () => {
    await seedInvite('EXPIRD', { expiresAt: new Date(Date.now() - 3600 * 1000) });
    const fresh = await newUser();
    const { status, error } = await redeem(fresh.idToken, 'EXPIRD');
    assert.notEqual(status, 200);
    assert.equal(error.message, 'code-expired');
  });

  it('projesi silinmiş davet reddedilir ve kod HARCANMAZ', async () => {
    await seedInvite('ORPHAN', { projectId: 'yok-boyle-proje' });
    const fresh = await newUser();
    const { status, error } = await redeem(fresh.idToken, 'ORPHAN');
    assert.notEqual(status, 200);
    assert.equal(error.message, 'project-missing');
    const f = await getFields('invites/ORPHAN');
    assert.equal(f.usedAt, undefined, 'kod boşa harcanmış');
  });
});

// ═══════════════════════════ Yeniden kullanım / sahip ═══════════════════════════

describe('redeemInvite — zaten üye olan', () => {
  it('ikinci dokunuş HATA DEĞİL, kod da harcanmaz', async () => {
    // Aynı bağlantıya iki kez dokunmak bir arıza değil; kod yakılırsa yönetici
    // boşuna yeni kod üretmek zorunda kalırdı.
    const CODE = 'TWICE1';
    await seedInvite(CODE);
    const u = await newUser();
    await putDoc(`users/${u.uid}`, { uid: str(u.uid), name: str('Ayşe Tuna') });

    const first = await redeem(u.idToken, CODE);
    assert.equal(first.status, 200);
    assert.equal(first.result.alreadyMember, false);

    const CODE2 = 'TWICE2';
    await seedInvite(CODE2);
    const second = await redeem(u.idToken, CODE2);
    assert.equal(second.status, 200);
    assert.equal(second.result.alreadyMember, true);

    const f = await getFields(`invites/${CODE2}`);
    assert.equal(f.usedAt, undefined, 'zaten üye olan kişi kodu harcadı');
  });

  it('AYNI KODA ikinci kez dokunmak hata döndürmez — idempotans', async () => {
    // Yukarıdaki test İKİ FARKLI kod kullanıyor, yani "zaten üye olan kişi YENİ
    // bir kod kullanıyor" senaryosunu sınıyor. Oysa kendi yorumu "aynı
    // bağlantıya iki kez dokunmak" diyor ve GERÇEK vaka bu: kullanıcı kodu
    // kullanıp üye oluyor, sonra aynı bağlantıya tekrar dokunuyor.
    //
    // O vaka bir dönem HATA döndürüyordu: üyelik denetimi `usedAt` kapısının
    // ARKASINDAYDI, dolayısıyla kişi kendi başarılı çağrısıyla kodu harcadığı
    // an ikinci dokunuşunda "bu kod kullanılmış" alıyordu. Ağ yeniden
    // denemesinde de aynısı oluyordu: çağrı sunucuda başarılı olup yanıt
    // kaybolursa kullanıcıya katılamadığı söyleniyordu.
    const CODE = 'SAMEC1';
    await seedInvite(CODE);
    const u = await newUser();

    const first = await redeem(u.idToken, CODE);
    assert.equal(first.status, 200);
    assert.equal(first.result.alreadyMember, false);

    // AYNI kod, AYNI kullanıcı, ikinci kez.
    const second = await redeem(u.idToken, CODE);
    assert.equal(second.status, 200, 'ikinci dokunuş hata döndürdü');
    assert.equal(second.result.alreadyMember, true);
    assert.equal(second.result.projectId, first.result.projectId);

    // Üyelik tekrar yazılmamalı: aynı uid iki kez listede olmamalı.
    const proje = await getFields(`projects/${first.result.projectId}`);
    const uyeler = proje.memberUids.arrayValue.values.map((v) => v.stringValue);
    assert.equal(uyeler.filter((x) => x === u.uid).length, 1, 'uid listeye iki kez girdi');
  });

  it('üye OLMAYAN biri harcanmış kodu hâlâ kullanamaz', async () => {
    // İdempotans dalı `usedAt` kapısının önüne alındı; kapının kendisi
    // yerinde durmalı, yoksa harcanmış kod herkese açılırdı.
    const CODE = 'SPENT1';
    await seedInvite(CODE);
    const ilk = await newUser();
    assert.equal((await redeem(ilk.idToken, CODE)).status, 200);

    const yabanci = await newUser();
    const r = await redeem(yabanci.idToken, CODE);
    assert.equal(r.status, 409);
    assert.equal(r.error.status, 'ALREADY_EXISTS');
  });

  it('projenin SAHİBİ kendi davetiyle ortak olmaz', async () => {
    // Sahibin jetonunu almak için ONA proje kurduruyoruz. Auth emülatörünün
    // `signUp`'ı belirli bir uid kabul etmiyor (localId yok sayılıyor ve jeton
    // üretilmiyor); emülatörün iç davranışına dayanmak yerine gerçek akışı
    // taklit etmek testi hem doğru hem dayanıklı yapıyor.
    const owner = await newUser();
    const pid = 'project-owned-by-caller';
    const CODE = 'OWNER1';
    await putDoc(`projects/${pid}`, {
      id: str(pid), ownerUid: str(owner.uid), memberUids: arr([owner.uid]),
      blockNumber: str('908'), parcelNumber: str('7'), createdAt: ts(new Date()),
    });
    await seedInvite(CODE, { projectId: pid });

    const { status, result } = await redeem(owner.idToken, CODE);
    assert.equal(status, 200);
    assert.equal(result.alreadyMember, true, 'sahip kendi projesine ortak olarak eklendi');

    // Kod harcanmadı ve ortak listesine kendini eklemedi.
    const invite = await getFields(`invites/${CODE}`);
    assert.equal(invite.usedAt, undefined, 'sahip kendi kodunu yaktı');
    const partners = await listDocs(`projects/${pid}/partners`);
    assert.equal(partners.length, 0, 'sahip kendi projesinde ortak kaydı oluştu');
  });
});

// ═══════════════════════════ İsim çözümü ═══════════════════════════

describe('redeemInvite — ad sunucudan çözülür', () => {
  it('profil yoksa "Ortak"a düşer, istemciden ad ALINMAZ', async () => {
    const CODE = 'NONAME';
    await seedInvite(CODE);
    const u = await newUser();   // users/{uid} yazılmadı
    const { status } = await redeem(u.idToken, CODE);
    assert.equal(status, 200);

    const partners = await listDocs(`projects/${P1}/partners`);
    const mine = partners.find((d) => d.fields.userUid?.stringValue === u.uid);
    assert.ok(mine);
    // Profilde ad yoksa → "Yeni ortak". Uydurma bir ad değil, dürüst bir yer
    // tutucu: yöneticinin gördüğü liste doğrulanmamış veri taşımıyor.
    //
    // TELEFON NUMARASI YEDEK DEĞİL: önce numaraya düşülüyordu ama
    // `partners/{id}` belgesi projenin TÜM üyelerine açık, yani numara diğer
    // ortakların cihazına iniyordu (KVKK). Kişi numarayı kimlik doğrulaması
    // için verdi, ortaklara gösterilsin diye değil.
    assert.equal(mine.fields.name.stringValue, 'Yeni ortak');
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// HESAP SİLME (madde 28) — App Store 5.1.1(v)
//
// En kritik test "ortağın hesabı silinince SAHİBİN VERİSİ DURUYOR MU": silme
// fazla geniş yazılsaydı, projeden ayrılan bir ortak müteahhidin bütün
// projesini götürürdü.
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════ Oran sınırı (madde 71) ═══════════════════════
//
// Callable uçları düz HTTPS uçları: bu dosyanın kendisi uygulamayı hiç
// açmadan curl benzeri bir POST ile çağırıyor. Her çağrı bir işlev
// çalıştırması, yani PARA — ve bütçe uyarısı harcamayı kesmiyor.

describe('redeemInvite — oran sınırı', () => {

  it('ONUNCU başarısız denemeden sonra REDDEDİLİYOR', async () => {
    const u = await newUser();
    // Var olmayan kod: her deneme 404 döner ama sayaç artar.
    for (let i = 0; i < 10; i++) {
      const { status } = await redeem(u.idToken, 'YOKKOD');
      assert.equal(status, 404, `${i + 1}. deneme beklenmedik biçimde ${status} döndü`);
    }
    const { status, error } = await redeem(u.idToken, 'YOKKOD');
    assert.equal(status, 429);
    assert.equal(error?.message, 'too-many-attempts');
  });

  it('SINIRA ÇARPAN kullanıcı GEÇERLİ kodu da kullanamıyor', async () => {
    // Sınır, kaba kuvvetin doğru kodu bulduğu anı da kapsamalı; aksi hâlde
    // sayaç yalnızca yanlış denemeleri yavaşlatır, doğruyu ödüllendirirdi.
    const owner = await newUser();
    const pid = `oran-${owner.uid}`;
    await putDoc(`projects/${pid}`, {
      id: str(pid), ownerUid: str(owner.uid), memberUids: arr([owner.uid]),
      blockNumber: str('910'), parcelNumber: str('1'), createdAt: ts(new Date()),
    });
    await seedInvite('ORAN11', { projectId: pid });

    const u = await newUser();
    for (let i = 0; i < 10; i++) await redeem(u.idToken, 'YOKKOD');
    const { status } = await redeem(u.idToken, 'ORAN11');
    assert.equal(status, 429, 'sınır geçerli kodu da kapsamalı');
  });

  it('BAŞARILI katılım sayacı SIFIRLIYOR', async () => {
    // Beş projeye davet edilen bir ortak, kimseyi zorlamadığı hâlde sınıra
    // çarpmamalı.
    const owner = await newUser();
    const pid = `oran2-${owner.uid}`;
    await putDoc(`projects/${pid}`, {
      id: str(pid), ownerUid: str(owner.uid), memberUids: arr([owner.uid]),
      blockNumber: str('911'), parcelNumber: str('2'), createdAt: ts(new Date()),
    });
    await seedInvite('ORAN22', { projectId: pid });

    const u = await newUser();
    for (let i = 0; i < 9; i++) await redeem(u.idToken, 'YOKKOD');

    const basarili = await redeem(u.idToken, 'ORAN22');
    assert.equal(basarili.status, 200);

    // Sayaç sıfırlandığı için yeniden 10 hak var.
    for (let i = 0; i < 10; i++) {
      const { status } = await redeem(u.idToken, 'YOKKOD');
      assert.notEqual(status, 429, `${i + 1}. denemede sayaç sıfırlanmamış`);
    }
  });

  it('PENCERE DOLUNCA yeniden hak veriliyor', async () => {
    const u = await newUser();
    for (let i = 0; i < 10; i++) await redeem(u.idToken, 'YOKKOD');
    assert.equal((await redeem(u.idToken, 'YOKKOD')).status, 429);

    // Pencere başlangıcını geriye alarak zamanı ileri sarıyoruz: 15 dakikalık
    // pencere dolmuş sayılıyor. Gerçek beklemeyi test etmek testi 15 dakika
    // uzatırdı.
    await putDoc(`rateLimits/${u.uid}`, {
      failedAttempts: { integerValue: '10' },
      windowStart: ts(new Date(Date.now() - 20 * 60 * 1000)),
    });
    const { status } = await redeem(u.idToken, 'YOKKOD');
    assert.equal(status, 404, 'pencere dolduktan sonra tekrar denenebilmeli');
  });

  it('sayaç KULLANICI BAŞINA — biri sınıra çarpınca diğeri etkilenmiyor', async () => {
    const a = await newUser();
    const b = await newUser();
    for (let i = 0; i < 11; i++) await redeem(a.idToken, 'YOKKOD');
    assert.equal((await redeem(a.idToken, 'YOKKOD')).status, 429);
    assert.equal((await redeem(b.idToken, 'YOKKOD')).status, 404);
  });
});

describe('deleteAccount — hesap silme', () => {

  it('oturum yoksa reddedilir', async () => {
    const { status, error } = await deleteAccount(null);
    assert.equal(status, 401);
    assert.equal(error?.message, 'signed-in-required');
  });

  it('SAHİP silince projesi ve alt koleksiyonları gider', async () => {
    const owner = await newUser();
    const pid = `sil-${owner.uid}`;
    await putDoc(`projects/${pid}`, {
      id: str(pid), ownerUid: str(owner.uid), memberUids: arr([owner.uid]),
      blockNumber: str('900'), parcelNumber: str('1'), createdAt: ts(new Date()),
    });
    await putDoc(`projects/${pid}/apartments/d1`, { id: str('d1'), projectId: str(pid) });
    await putDoc(`projects/${pid}/buyers/d1`, {
      apartmentId: str('d1'), projectId: str(pid), name: str('Ahmet Yılmaz'),
    });

    const { status, result } = await deleteAccount(owner.idToken);
    assert.equal(status, 200);
    assert.equal(result?.deletedProjects, 1);

    // Proje belgesi VE alt koleksiyon belgeleri gitmeli — Firestore alt
    // koleksiyonları üst belge silinince otomatik silmiyor, bu yüzden ayrıca
    // denetleniyor. Alıcı adı (KVKK) da bu ağacın içinde.
    const apartments = await listDocs(`projects/${pid}/apartments`);
    const buyers = await listDocs(`projects/${pid}/buyers`);
    assert.equal(apartments.length, 0);
    assert.equal(buyers.length, 0);
  });

  it('ORTAK silince SAHİBİN PROJESİ DURUR — yalnızca kendisi düşer', async () => {
    const owner = await newUser();
    const partner = await newUser();
    const pid = `kal-${owner.uid}`;
    await putDoc(`projects/${pid}`, {
      id: str(pid), ownerUid: str(owner.uid),
      memberUids: arr([owner.uid, partner.uid]),
      blockNumber: str('901'), parcelNumber: str('2'), createdAt: ts(new Date()),
    });
    await putDoc(`projects/${pid}/apartments/d1`, { id: str('d1'), projectId: str(pid) });
    await putDoc(`projects/${pid}/partners/p1`, {
      id: str('p1'), projectId: str(pid), userUid: str(partner.uid),
      name: str('Serkan Aydın'),
    });

    const { status, result } = await deleteAccount(partner.idToken);
    assert.equal(status, 200);
    assert.equal(result?.deletedProjects, 0);
    assert.equal(result?.leftProjects, 1);

    // Proje ve verisi YERİNDE.
    const apartments = await listDocs(`projects/${pid}/apartments`);
    assert.equal(apartments.length, 1);

    // Ortağın kaydı düştü (adı KVKK kapsamında) ve üyelikten çıkarıldı.
    const partners = await listDocs(`projects/${pid}/partners`);
    assert.equal(partners.length, 0);
  });

  // ─── Aşağıdaki dördü madde 68 ile eklendi ───────────────────────────────
  //
  // Var olan testler işlevin FIRESTORE tarafını doğruluyordu; Auth kaydının
  // gerçekten gidip gitmediği, Storage nesnelerinin silinip silinmediği ve
  // davet belgelerinin akıbeti HİÇ SORULMAMIŞTI. Üçü de sessizce
  // başarısız olabilecek adımlar: kullanıcıya "hesabın silindi" denip
  // hesabın durması, ya da fotoğraflarının kovada kalması, ekranda hiçbir
  // iz bırakmaz.

  it('ESKİMİŞ doğrulama reddediliyor — SMS turu artık gerçek bir kapı', async () => {
    const u = await newUser();
    // Jeton geçerli, oturum geçerli; eksik olan tek şey YAKIN doğrulama.
    const eski = withAuthTime(u.idToken, 60 * 60);   // bir saat önce
    const { status, error } = await deleteAccount(eski);
    assert.equal(status, 400);
    assert.equal(error?.message, 'reauth-required');

    // Ve hiçbir şey silinmemiş olmalı: reddedilen çağrı yan etki bırakmamalı.
    assert.equal(await authUserExists(u.uid), true);
  });

  it('YAKIN doğrulama kabul ediliyor — kapı meşru kullanıcıyı engellemiyor', async () => {
    const u = await newUser();
    const taze = withAuthTime(u.idToken, 30);        // yarım dakika önce
    const { status } = await deleteAccount(taze);
    assert.equal(status, 200);
    assert.equal(await authUserExists(u.uid), false);
  });

  it('AUTH KAYDI gerçekten siliniyor — yoksa "silindim" diyen kişi tekrar girebilir', async () => {
    const u = await newUser();
    assert.equal(await authUserExists(u.uid), true, 'zemin: kullanıcı var olmalı');

    const { status } = await deleteAccount(u.idToken);
    assert.equal(status, 200);
    assert.equal(await authUserExists(u.uid), false);
  });

  it('STORAGE nesneleri siliniyor — belgede yolu yazmayan yetim dahil', async () => {
    const owner = await newUser();
    const pid = `dosya-${owner.uid}`;
    await putDoc(`projects/${pid}`, {
      id: str(pid), ownerUid: str(owner.uid), memberUids: arr([owner.uid]),
      blockNumber: str('902'), parcelNumber: str('3'), createdAt: ts(new Date()),
    });
    // Biri belgeye bağlı, biri YETİM (yüklemesi yarım kalmış, hiçbir belgede
    // yolu yok). Önek silmesinin sebebi ikincisi.
    await putObject(`projects/${pid}/sitePhotos/kayitli.jpg`);
    await putObject(`projects/${pid}/paymentReceipts/yetim.jpg`);
    assert.equal(await objectExists(`projects/${pid}/sitePhotos/kayitli.jpg`), true);

    const { status } = await deleteAccount(owner.idToken);
    assert.equal(status, 200);

    assert.equal(await objectExists(`projects/${pid}/sitePhotos/kayitli.jpg`), false);
    assert.equal(await objectExists(`projects/${pid}/paymentReceipts/yetim.jpg`), false);
  });

  it('silinen projenin DAVET belgeleri de gidiyor — kural onları istemciye kapatıyor', async () => {
    const owner = await newUser();
    const pid = `davet-${owner.uid}`;
    await putDoc(`projects/${pid}`, {
      id: str(pid), ownerUid: str(owner.uid), memberUids: arr([owner.uid]),
      blockNumber: str('903'), parcelNumber: str('4'), createdAt: ts(new Date()),
    });
    await seedInvite('ZZZ111', { projectId: pid });

    const { status } = await deleteAccount(owner.idToken);
    assert.equal(status, 200);

    // `invites/{KOD}` için kural `allow update, delete: if false` — yani bu
    // belgeyi işlevden başka hiç kimse silemez. Kalsaydı sonsuza dek kalırdı.
    assert.equal(await getFields('invites/ZZZ111'), null);
  });

  it('AYRILAN ORTAĞIN ADI davet belgesinde ve akışta kalmıyor (KVKK)', async () => {
    const owner = await newUser();
    const partner = await newUser();
    const pid = `iz-${owner.uid}`;
    await putDoc(`projects/${pid}`, {
      id: str(pid), ownerUid: str(owner.uid),
      memberUids: arr([owner.uid, partner.uid]),
      blockNumber: str('904'), parcelNumber: str('5'), createdAt: ts(new Date()),
    });
    // Daveti kullanmış: adı davet belgesinde ve akışta duruyor.
    await putDoc('invites/ZZZ222', {
      projectId: str(pid), createdAt: ts(new Date()),
      expiresAt: ts(new Date(Date.now() + 3600e3)),
      usedAt: ts(new Date()), usedByUid: str(partner.uid),
      usedByName: str('Serkan Aydın'),
    });
    await putDoc(`projects/${pid}/activities/a1`, {
      id: str('a1'), projectId: str(pid), kind: str('partnerJoined'),
      title: str('Serkan Aydın projeye katıldı'), meta: str('904 Ada / 5 Parsel'),
      timestamp: ts(new Date()), actorUid: str(partner.uid),
    });

    const { status } = await deleteAccount(partner.idToken);
    assert.equal(status, 200);

    // Davet belgesi DURUYOR (sahibinin verisi, kod harcanmış olarak kalmalı)
    // ama KİMLİK alanları gitmiş olmalı.
    const invite = await getFields('invites/ZZZ222');
    assert.ok(invite, 'davet belgesi sahibinin projesine ait, silinmemeli');
    assert.ok(invite.usedAt, 'kodun harcandığı bilgisi kalmalı');
    assert.equal(invite.usedByName, undefined);
    assert.equal(invite.usedByUid, undefined);

    // Katılma hareketi başlığında gerçek ad vardı — satır tümden düşmeli.
    assert.equal(await getFields(`projects/${pid}/activities/a1`), null);
  });

  it('HİÇ PROJESİ OLMAYAN hesap da silinebiliyor', async () => {
    // Uygulamayı açıp vazgeçen kişi. Kova çözümü döngünün dışında yapılsaydı
    // bu kişi, hiç dosyası yokken kova arayan bir çağrıya takılırdı.
    const u = await newUser();
    const { status, result } = await deleteAccount(u.idToken);
    assert.equal(status, 200);
    assert.equal(result?.deletedProjects, 0);
    assert.equal(result?.leftProjects, 0);
    assert.equal(await authUserExists(u.uid), false);
  });

  it('profil belgesi siliniyor', async () => {
    const u = await newUser();
    await putDoc(`users/${u.uid}`, { name: str('Silinecek Kişi') });
    const { status } = await deleteAccount(u.idToken);
    assert.equal(status, 200);
    assert.equal(await getFields(`users/${u.uid}`), null);
  });

  it('S1 — davet deneme sayacı (rateLimits) da siliniyor', async () => {
    // Yalnızca BAŞARILI katılım siliyordu; yanlış kod deneyip hesabını silen
    // kişinin uid'ine bağlı belge süresiz kalıyordu.
    const u = await newUser();
    await putDoc(`rateLimits/${u.uid}`, {
      failedAttempts: { integerValue: '3' }, windowStart: ts(new Date()),
    });
    const { status } = await deleteAccount(u.idToken);
    assert.equal(status, 200);
    assert.equal(await getFields(`rateLimits/${u.uid}`), null);
  });
});

// ── S2 — Auth silmesi eşgüçlü (31 Eki) ──
//
// SENARYO ÜRETİMDE, EMÜLATÖRDE DEĞİL: silme bitti, yanıt yolda kayboldu,
// kullanıcı "Tekrar dene"ye bastı. Üretimde onCall jetonu `checkRevoked`
// olmadan doğruluyor, yani silinmiş kullanıcının jetonu işleve ulaşıyor ve
// tek patlayan satır `deleteUser` oluyordu. EMÜLATÖR ise jetonu doğrularken
// kullanıcının var olduğuna da bakıyor (firebase-admin `isEmulator` dalı) —
// ikinci çağrı orada 401 alır ve bu yolu HİÇ göremez. Bu yüzden düzeltmenin
// kendisi (`deleteAuthUser`) doğrudan, gerçek Auth emülatörüne karşı
// sınanıyor. İlk test sorunun var olduğunu, ikincisi kapandığını gösteriyor.
describe('S2 — Auth kaydı zaten yoksa silme başarı sayılıyor', () => {
  let fonksiyonlar;
  let adminAuth;

  before(async () => {
    fonksiyonlar = await import('../functions/lib/index.js');
    const { getAuth } = await import('../functions/node_modules/firebase-admin/lib/auth/index.js');
    adminAuth = getAuth();
  });

  it('kanıt: firebase-admin olmayan kullanıcıda auth/user-not-found fırlatıyor', async () => {
    await assert.rejects(adminAuth.deleteUser('hic-var-olmamis-uid'),
      (e) => e.code === 'auth/user-not-found');
  });

  it('deleteAuthUser olmayan kullanıcıda başarıyla dönüyor', async () => {
    await fonksiyonlar.deleteAuthUser('hic-var-olmamis-uid');
  });

  it('deleteAuthUser var olan kullanıcıyı gerçekten siliyor', async () => {
    const u = await newUser();
    await fonksiyonlar.deleteAuthUser(u.uid);
    assert.equal(await authUserExists(u.uid), false);
  });

  it('başka hatalar YUTULMUYOR (geçersiz uid)', async () => {
    // Boş uid firebase-admin'de `auth/invalid-uid`. Yutulsaydı kullanıcı
    // hesabının silindiğini sanırdı.
    await assert.rejects(fonksiyonlar.deleteAuthUser(''),
      (e) => e.code === 'auth/invalid-uid');
  });
});

// ── App Check zorlaması (madde 71) ──
//
// NEDEN AYRI BİR BÖLÜM: zorlama tek bir satırla kapatılabilir
// (`enforceAppCheck: true` silinir) ve kapandığı HİÇBİR YERDEN anlaşılmaz —
// diğer tüm testler yeşil kalır, uygulama çalışmaya devam eder, yalnızca
// koruma sessizce gider. Aynı sınıf madde 79'da (davet ömrü) ve 87'de
// (kota) yaşandı: "iddia yazılı, uygulayan yok".
//
// TEHDİT PARAYLA ÖLÇÜLÜ: bu iki uç düz HTTPS adresi ve madde 68'de
// testlerin kendisi kanıtladı — uygulama hiç açılmadan curl ile
// çağrılabiliyorlar. `deleteAccount` üstelik VERİ YOK EDİYOR.
//
// GÜNLÜKTEKİ YANILTICI SATIRI BİLEREK YAZIYORUM: reddedilen çağrıda bile
// emülatör `{"verifications":{"app":"MISSING"},"message":"Callable request
// verification passed"}` basıyor. "passed" burada gövdenin çalıştığı
// anlamına GELMİYOR — doğrulama özeti önce loglanıyor, zorlama sonra
// reddediyor. Kanıt iki yerde: durum kodu 401 ve işlev ~0,6 ms'de bitiyor
// (gerçek `deleteAccount` ~11 ms). Bu satırı görüp "zorlama çalışmıyor"
// sonucuna varmak kolay; o yüzden burada duruyor.
describe('App Check zorlaması', () => {
  it('redeemInvite jetonsuz çağrıyı reddediyor', async () => {
    const u = await newUser();
    const { status } = await redeem(u.idToken, 'ABC234', { appCheck: false });
    assert.equal(status, 401,
      'redeemInvite App Check jetonu olmadan çalışıyor — zorlama kapanmış');
  });

  it('deleteAccount jetonsuz çağrıyı reddediyor', async () => {
    const u = await newUser();
    const { status } = await deleteAccount(u.idToken, { appCheck: false });
    assert.equal(status, 401,
      'deleteAccount App Check jetonu olmadan çalışıyor — zorlama kapanmış');
    // Hesabın SİLİNMEDİĞİ de denetleniyor: 401 dönüp yine de silseydi
    // durum kodu yanıltıcı olurdu.
    assert.equal(await authUserExists(u.uid), true, 'reddedilen çağrı hesabı silmiş');
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MADDE 6 — davet yaşam döngüsü
//
// (a) KULLANILAN KOD "AKTİF" GÖRÜNÜYORDU: `redeemInvite` yalnızca
//     `invites/{KOD}` belgesine `usedAt` yazıyordu; proje belgesindeki ayna
//     hiç değişmiyordu ve sahibin ekranı kodun kullanıldığını görmüyordu.
// (b) "YENİ KOD" ESKİSİNİ İPTAL ETMİYORDU: eski kod kullanılana ya da 48 saat
//     dolana kadar geçerli kalıyordu.
//
// GERİYE UYUM: derleme 169 incelemede ve eski istemci kodunu taşıyor.
// Değişiklik YALNIZCA sunucuda; kural, indeks, istemci değişmiyor. Bu
// testlerin bir kısmı davranışı, bir kısmı 169 ile uyumu koruyan sınırları
// sabitliyor (yer tutucu ayna, aynasız proje, eşit damga).
// ═══════════════════════════════════════════════════════════════════════════


const mapv = (fields) => ({ mapValue: { fields } });

async function seedOwnProject(pid, { mirror } = {}) {
  const owner = await newUser();
  const fields = {
    id: str(pid), ownerUid: str(owner.uid), memberUids: arr([owner.uid]),
    blockNumber: str('950'), parcelNumber: str('6'), createdAt: ts(new Date()),
  };
  if (mirror) fields.invite = mapv({ code: str(mirror.code), createdAt: ts(mirror.createdAt ?? new Date()) });
  await putDoc(`projects/${pid}`, fields);
  return owner;
}

async function seedInviteAt(code, projectId, createdAt) {
  await putDoc(`invites/${code}`, {
    projectId: str(projectId), createdAt: ts(createdAt),
    expiresAt: ts(new Date(createdAt.getTime() + 48 * 3600 * 1000)),
    usedAt: { nullValue: null },
  });
}

describe('M6a — davet aynası', () => {
  it('kod aynadakiyle eşleşince ayna kullanıldı olur; code/createdAt korunur, ad yazılmaz', async () => {
    const pid = 'm6a-esles';
    const t0 = new Date(Date.now() - 60e3);
    await seedOwnProject(pid, { mirror: { code: 'AYNA11', createdAt: t0 } });
    await seedInviteAt('AYNA11', pid, t0);
    const u = await newUser();
    await putDoc(`users/${u.uid}`, { uid: str(u.uid), name: str('Ayşe Tuna') });
    const r = await redeem(u.idToken, 'AYNA11');
    assert.equal(r.status, 200, JSON.stringify(r.error));
    const inv = (await getFields(`projects/${pid}`)).invite?.mapValue?.fields;
    assert.ok(inv, 'ayna kayboldu');
    assert.equal(inv.code.stringValue, 'AYNA11');
    assert.equal(inv.createdAt.timestampValue, t0.toISOString());
    assert.ok(inv.usedAt?.timestampValue, 'ayna usedAt Timestamp değil');
    assert.equal(inv.usedByName, undefined, 'aynaya ad yazılmamalı');
  });

  it('ayna BAŞKA (var olmayan) kodu gösteriyorsa aynaya dokunulmaz — 169 yer tutucu', async () => {
    const pid = 'm6a-farkli';
    const t0 = new Date(Date.now() - 60e3);
    await seedOwnProject(pid, { mirror: { code: 'YERTUT', createdAt: t0 } });
    await seedInviteAt('GERCK1', pid, t0);
    const u = await newUser();
    const r = await redeem(u.idToken, 'GERCK1');
    assert.equal(r.status, 200, 'aynadaki koddan farklı GEÇERLİ kod reddedildi');
    const inv = (await getFields(`projects/${pid}`)).invite.mapValue.fields;
    assert.equal(inv.code.stringValue, 'YERTUT');
    assert.equal(inv.usedAt, undefined, 'başka kodun aynası işaretlendi');
  });

  it('ayna YOKSA yarım harita yaratılmaz', async () => {
    const pid = 'm6a-aynasiz';
    await seedOwnProject(pid);
    await seedInviteAt('AYNSZ1', pid, new Date(Date.now() - 60e3));
    const u = await newUser();
    assert.equal((await redeem(u.idToken, 'AYNSZ1')).status, 200);
    assert.equal((await getFields(`projects/${pid}`)).invite, undefined, 'code/createdAt olmayan yarım invite haritası oluştu');
  });

  it('zaten üye (sahip) dalı aynaya yazmaz', async () => {
    const owner = await newUser();
    const pid = `m6a-sahip-${owner.uid}`;
    const t0 = new Date(Date.now() - 60e3);
    await putDoc(`projects/${pid}`, {
      id: str(pid), ownerUid: str(owner.uid), memberUids: arr([owner.uid]),
      blockNumber: str('951'), parcelNumber: str('1'), createdAt: ts(new Date()),
      invite: mapv({ code: str('SAHIP1'), createdAt: ts(t0) }),
    });
    await seedInviteAt('SAHIP1', pid, t0);
    const r = await redeem(owner.idToken, 'SAHIP1');
    assert.equal(r.result?.alreadyMember, true);
    assert.equal((await getFields(`projects/${pid}`)).invite.mapValue.fields.usedAt, undefined);
  });
});

describe('M6b — yeni kod eskisini geçersiz kılar', () => {
  it('daha yeni kod varken ESKİ kullanılmamış kod reddedilir ve harcanmaz', async () => {
    const pid = 'm6b-eski';
    await seedOwnProject(pid);
    await seedInviteAt('ESKI33', pid, new Date(Date.now() - 120e3));
    await seedInviteAt('YENI33', pid, new Date(Date.now() - 60e3));
    const u = await newUser();
    const r = await redeem(u.idToken, 'ESKI33');
    assert.notEqual(r.status, 200, 'eski kod hâlâ geçerli');
    assert.equal(r.error?.message, 'code-expired');
    assert.equal(r.error?.details?.reason, 'replaced',
      'sonraki istemcilerin "yerine yeni kod üretildi" diyebilmesi için ayrıntı lazım');
    assert.equal((await getFields('invites/ESKI33')).usedAt?.nullValue, null);
    const uyeler = (await getFields(`projects/${pid}`)).memberUids.arrayValue.values.map((v) => v.stringValue);
    assert.ok(!uyeler.includes(u.uid), 'reddedilen kişi üye yapıldı');
    const ok = await redeem(u.idToken, 'YENI33');
    assert.equal(ok.status, 200, 'yeni kod çalışmadı');
  });

  it('yeni kod KULLANILMIŞ olsa bile eski kod dirilmez', async () => {
    const pid = 'm6b-dirilme';
    await seedOwnProject(pid);
    await seedInviteAt('DRLA11', pid, new Date(Date.now() - 120e3));
    await seedInviteAt('DRLB11', pid, new Date(Date.now() - 60e3));
    const u1 = await newUser();
    assert.equal((await redeem(u1.idToken, 'DRLB11')).status, 200);
    const u2 = await newUser();
    const r = await redeem(u2.idToken, 'DRLA11');
    assert.notEqual(r.status, 200, 'yeni kod harcanınca eski kod yeniden geçerli oldu');
  });

  it('BAŞKA projenin daha yeni kodu bu projenin kodunu düşürmez', async () => {
    await seedOwnProject('m6b-x');
    await seedOwnProject('m6b-y');
    await seedInviteAt('PRJX11', 'm6b-x', new Date(Date.now() - 120e3));
    await seedInviteAt('PRJY11', 'm6b-y', new Date(Date.now() - 60e3));
    const u = await newUser();
    assert.equal((await redeem(u.idToken, 'PRJX11')).status, 200);
  });

  it('eşit createdAt ile üretilmiş iki kod birbirini düşürmez', async () => {
    const pid = 'm6b-esit';
    await seedOwnProject(pid);
    const t = new Date(Date.now() - 60e3);
    await seedInviteAt('ESTA11', pid, t);
    await seedInviteAt('ESTB11', pid, t);
    assert.equal((await redeem((await newUser()).idToken, 'ESTA11')).status, 200);
  });

  it('zaten üye olan, eskimiş koda dokununca yine başarı alır (idempotans)', async () => {
    const pid = 'm6b-idem';
    await seedOwnProject(pid);
    await seedInviteAt('IDMA11', pid, new Date(Date.now() - 120e3));
    const u = await newUser();
    assert.equal((await redeem(u.idToken, 'IDMA11')).status, 200);
    await seedInviteAt('IDMB11', pid, new Date(Date.now() - 60e3));
    const r = await redeem(u.idToken, 'IDMA11');
    assert.equal(r.status, 200);
    assert.equal(r.result.alreadyMember, true);
  });
});
