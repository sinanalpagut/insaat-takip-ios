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

async function deleteAccount(idToken) {
  const res = await fetch(DELETE_FN, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
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
});
