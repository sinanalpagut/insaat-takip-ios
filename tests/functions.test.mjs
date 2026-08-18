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

// ── Callable çağrısı ──

async function redeem(idToken, code) {
  const res = await fetch(CALLABLE, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data: { code } }),
  });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, result: body.result, error: body.error };
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
