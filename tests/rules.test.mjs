// İnşaat Takip — Firestore güvenlik kuralları testleri
//
// Emülatöre karşı çalışır; gerçek projeye DOKUNMAZ (projectId "demo-" ile
// başladığı için Firebase araçları uzak bağlantı kurmaz).
//
//   npm test
//
// Neden test: güvenlik kuralları gözle okunarak doğrulanamaz. "Ortak yazamaz"
// cümlesi doğru görünen bir kuralla yanlış olabilir — özellikle `list` sorguları
// kural değerlendirmesinde tek tek belgelerden farklı davrandığı için. Buradaki
// her test bir SALDIRI ya da bir SÖZ; ikisi de kanıtlanmadan doğru sayılmaz.

import { readFileSync } from 'node:fs';
import { after, before, describe, it } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  arrayRemove, arrayUnion, collection, deleteDoc, deleteField, doc, getDoc,
  getDocs, query, serverTimestamp, setDoc, updateDoc, where, writeBatch,
} from 'firebase/firestore';

/// Uygulamanın HER yazmaya eklediği sunucu damgası (madde 77).
///
/// `updatedAt` SUNUCU zaman damgası olmak zorunda: kural
/// `updatedAt == request.time` diyor ve istemcinin kendi saatinden yazdığı bir
/// `Timestamp` bu şartı SAĞLAMAZ. Testlerin bu yardımcıyı kullanması bir
/// kolaylık değil, uygulamanın gerçek yazma biçimini aynalaması —
/// `FirestoreProjectRepository.stamped()` ile birebir aynı üç alan.
const stamped = (uid, fields) => ({
  ...fields,
  updatedAt: serverTimestamp(),
  updatedBy: uid,
  updatedFrom: 'test-session',
});

// AYRI proje kimliği — bilinçli. `functions.test.mjs` aynı emülatörde
// `demo-insaattakip` ad alanını kullanıyor ve kendi zeminini kurarken
// `clearFirestore()` çağırıyor. Node test dosyalarını PARALEL çalıştırdığı için
// aynı ad alanı paylaşılsa iki takım birbirinin verisini siler ve testler
// gerçek bir kusur yokken kırmızıya döner. Firestore emülatörü proje kimliğine
// göre ad alanı ayırdığından ayrı kimlik tam yalıtım veriyor.
const PROJECT_ID = 'demo-rules';

// Kimlikler: sahip, üye (davetli ortak), yabancı.
const OWNER = 'uid-owner';
const MEMBER = 'uid-member';
const STRANGER = 'uid-stranger';

const P1 = 'project-1';          // OWNER'ın projesi, MEMBER üye
const P2 = 'project-2';          // STRANGER'ın projesi

let testEnv;
let ownerDb, memberDb, strangerDb, anonDb;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });

  ownerDb = testEnv.authenticatedContext(OWNER).firestore();
  memberDb = testEnv.authenticatedContext(MEMBER).firestore();
  strangerDb = testEnv.authenticatedContext(STRANGER).firestore();
  anonDb = testEnv.unauthenticatedContext().firestore();
});

after(async () => {
  await testEnv?.cleanup();
});

/// Her testten önce temiz, kurallar devre dışı bırakılarak yazılmış zemin.
async function seed() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'projects', P1), {
      id: P1, ownerUid: OWNER, memberUids: [OWNER, MEMBER],
      blockNumber: '145', parcelNumber: '2', createdAt: new Date(),
    });
    await setDoc(doc(db, 'projects', P2), {
      id: P2, ownerUid: STRANGER, memberUids: [STRANGER],
      blockNumber: '908', parcelNumber: '7', createdAt: new Date(),
    });
    // Belgeler: biri ortağa açık, biri gizli.
    await setDoc(doc(db, 'projects', P1, 'documents', 'doc-visible'), {
      id: 'doc-visible', projectId: P1, partnerVisible: true,
      fileName: 'Mimari.pdf', date: new Date('2026-01-22'),
    });
    await setDoc(doc(db, 'projects', P1, 'documents', 'doc-hidden'), {
      id: 'doc-hidden', projectId: P1, partnerVisible: false,
      fileName: 'İskân Başvurusu · taslak.pdf', date: new Date('2026-02-10'),
    });
    await setDoc(doc(db, 'projects', P1, 'apartments', 'apt-1'), {
      id: 'apt-1', projectId: P1, apartmentNumber: 1, status: 'available',
    });
    await setDoc(doc(db, 'projects', P1, 'activities', 'act-1'), {
      id: 'act-1', projectId: P1, kind: 'sale', title: 'No 3 · satıldı',
    });
    await setDoc(doc(db, 'projects', P1, 'auditEntries', 'audit-1'), {
      id: 'audit-1', projectId: P1, action: 'update', subject: 'Demir',
    });
    await setDoc(doc(db, 'users', OWNER), {
      uid: OWNER, name: 'Mehmet Kılıç', phone: '+905550000001',
    });
  });
}

// ═══════════════════════════ Kullanıcı profili ═══════════════════════════

describe('users/{uid}', () => {
  before(seed);

  it('kişi kendi profilini okur', async () => {
    await assertSucceeds(getDoc(doc(ownerDb, 'users', OWNER)));
  });

  it('BAŞKASININ profilini okumaz — uid bilen biri telefon numarasına ulaşmasın', async () => {
    await assertFails(getDoc(doc(strangerDb, 'users', OWNER)));
  });

  it('oturum açmamış kullanıcı profil okumaz', async () => {
    await assertFails(getDoc(doc(anonDb, 'users', OWNER)));
  });

  it('kendi profilini yazar', async () => {
    await assertSucceeds(setDoc(doc(memberDb, 'users', MEMBER), {
      uid: MEMBER, name: 'Serkan Aydın', phone: '+905321112233',
    }));
  });

  it('belgedeki uid yolla uyuşmuyorsa yazamaz', async () => {
    await assertFails(setDoc(doc(memberDb, 'users', MEMBER), {
      uid: OWNER, name: 'Serkan Aydın', phone: '+905321112233',
    }));
  });

  it('başkasının profiline yazamaz', async () => {
    await assertFails(setDoc(doc(strangerDb, 'users', OWNER), {
      uid: OWNER, name: 'ele geçirildi', phone: '+900000000000',
    }));
  });

  it('profil silinemez — hesap silme Cloud Function işi', async () => {
    await assertFails(deleteDoc(doc(ownerDb, 'users', OWNER)));
  });
});

// ═══════════════════════════ Proje belgesi ═══════════════════════════

describe('projects/{pid}', () => {
  before(seed);

  it('üye projeyi okur', async () => {
    await assertSucceeds(getDoc(doc(memberDb, 'projects', P1)));
  });

  it('ÜYE OLMAYAN projeyi okumaz', async () => {
    await assertFails(getDoc(doc(strangerDb, 'projects', P1)));
  });

  it('üyelik süzgeci olan liste sorgusu çalışır', async () => {
    await assertSucceeds(getDocs(query(
      collection(memberDb, 'projects'),
      where('memberUids', 'array-contains', MEMBER),
    )));
  });

  it('süzgeçsiz liste sorgusu REDDEDİLİR — kural süzgeç değildir', async () => {
    await assertFails(getDocs(collection(memberDb, 'projects')));
  });

  it('başkasının uid’iyle süzülen sorgu reddedilir', async () => {
    await assertFails(getDocs(query(
      collection(strangerDb, 'projects'),
      where('memberUids', 'array-contains', MEMBER),
    )));
  });

  it('kendini sahip ve üye yazarak proje kurar', async () => {
    await assertSucceeds(setDoc(doc(memberDb, 'projects', 'yeni-proje'), {
      id: 'yeni-proje', ownerUid: MEMBER, memberUids: [MEMBER],
      blockNumber: '1', parcelNumber: '1', createdAt: new Date(),
    }));
  });

  it('sahipliği BAŞKASINA yazarak proje kuramaz', async () => {
    await assertFails(setDoc(doc(memberDb, 'projects', 'sahte-proje'), {
      id: 'sahte-proje', ownerUid: OWNER, memberUids: [OWNER],
      blockNumber: '1', parcelNumber: '1', createdAt: new Date(),
    }));
  });

  it('kendini üye listesine koymadan proje kuramaz', async () => {
    await assertFails(setDoc(doc(memberDb, 'projects', 'uyesiz-proje'), {
      id: 'uyesiz-proje', ownerUid: MEMBER, memberUids: [],
      blockNumber: '1', parcelNumber: '1', createdAt: new Date(),
    }));
  });

  it('sahip projeyi güncelleyebilir', async () => {
    await assertSucceeds(updateDoc(doc(ownerDb, 'projects', P1), { progress: 42 }));
  });

  it('ORTAK projeyi güncelleyemez — salt okunur sözü', async () => {
    await assertFails(updateDoc(doc(memberDb, 'projects', P1), { progress: 99 }));
  });

  it('sahiplik DEVREDİLEMEZ', async () => {
    await assertFails(updateDoc(doc(ownerDb, 'projects', P1), { ownerUid: MEMBER }));
  });

  it('sahip kendini üye listesinden çıkaramaz — kendi projesini kilitlemesin', async () => {
    await assertFails(updateDoc(doc(ownerDb, 'projects', P1), { memberUids: [MEMBER] }));
  });

  it('YABANCI kendini üye listesine EKLEYEMEZ (davet akışı bu yüzden Cloud Function ister)', async () => {
    await assertFails(updateDoc(doc(strangerDb, 'projects', P1), {
      memberUids: [OWNER, MEMBER, STRANGER],
    }));
  });

  it('SAHİP başka bir üyeyi çıkarabilir — ortak çıkarma (madde 66)', async () => {
    // Ayrılan ortağın erişimini kesmenin hiçbir yolu yoktu. Kural buna zaten
    // izin veriyor (sahip kendisi listede kaldığı sürece); eksik olan
    // istemcideki eylemdi. Bu test o iznin KAPANMADIĞINI koruyor.
    await assertSucceeds(updateDoc(doc(ownerDb, 'projects', P1), {
      memberUids: [OWNER],
    }));
  });

  it('ORTAK başka bir üyeyi ÇIKARAMAZ — çıkarma yönetici yetkisi', async () => {
    await assertFails(updateDoc(doc(memberDb, 'projects', P1), {
      memberUids: [OWNER],
    }));
  });

  it('proje silinemez — alt koleksiyonlar istemciden atomik temizlenemez', async () => {
    await assertFails(deleteDoc(doc(ownerDb, 'projects', P1)));
  });
});

// ═══════════════════════════ Alt koleksiyonlar ═══════════════════════════

describe('proje belgesi yazması üyeliği ve daveti EZMİYOR', () => {

  // ───────────────────────────────────────────────────────────────────────
  // NEDEN BU TESTLER EMÜLATÖRDE: Swift tarafındaki davranış testleri
  // `InMemoryProjectRepository` üzerinde koşuyor ve ÜRETİM yazma yolunu hiç
  // çalıştırmıyor. Kırmızı probla ölçüldü: `serverOwnedProjectFields` boşa
  // çekilince (yani düzeltmenin çekirdeği devre dışı) o testlerin ÜÇÜ DE
  // YEŞİL KALDI — ölçtükleri şey bellek içi deponun daraltması. Üretim
  // yükünün gerçek Firestore semantiğiyle doğrulanacağı tek yer burası.
  //
  // Kusur: proje belgesi her yazışta TAM gönderiliyordu ve yük sahibin
  // CİHAZINDAKİ kopyadan kuruluyordu. Sunucudaki `redeemInvite` ortağı
  // `arrayUnion` ile ekledikten sonra sahibin herhangi bir düzenlemesi
  // listeyi eski hâliyle eziyor, ortak projeyi okuyamaz hâle geliyordu.
  // ───────────────────────────────────────────────────────────────────────

  const NEWCOMER = 'uid-newcomer';

  /// `FirestoreProjectRepository.projectFields` ile AYNI biçim: iş alanları +
  /// silme sentinel'leri, üyelik yalnızca kendini onaran `arrayUnion`, davet
  /// aynası YOK.
  const duzenlemeYuku = (uid, isAlanlari) => stamped(uid, {
    ...isAlanlari,
    memberUids: arrayUnion(uid),
  });

  before(async () => {
    // `seed()` ÖNCE: dosyanın kalıbı bu ve zemini önceki bloğun artığından
    // bağımsız kılıyor. Atlandığında test, ölçmek istediği şeyi değil
    // çalıştırma sırasını ölçüyor.
    await seed();
    // Sunucu olayı: yeni ortak davetle katıldı (`redeemInvite` arrayUnion) ve
    // sahip bir davet kodu üretti (`createInvite` aynayı yazdı).
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'projects', P1), {
        memberUids: [OWNER, MEMBER, NEWCOMER],
        invite: { code: 'ABC123', createdAt: new Date() },
      });
    });
  });

  it('sahibin alan yazması sunucudaki ortağı DÜŞÜRMÜYOR', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();

    await assertSucceeds(setDoc(
      doc(db, 'projects', P1),
      duzenlemeYuku(OWNER, { progress: 42, phase: 'Kaba inşaat' }),
      { merge: true },
    ));

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), 'projects', P1));
      const uids = snap.data().memberUids;
      if (!uids.includes(NEWCOMER)) {
        throw new Error(`alan yazması üyeliği ezdi: ${JSON.stringify(uids)}`);
      }
      if (!uids.includes(MEMBER)) throw new Error('eski üye de düştü');
      if (snap.data().progress !== 42) throw new Error('iş alanı yazılmadı');
      if (snap.data().invite?.code !== 'ABC123') {
        throw new Error('davet aynası silindi');
      }
    });
  });

  it('ESKİ BİÇİM kusuru üretiyordu — tam liste yazması ortağı düşürür', async () => {
    // Bu test düzeltmeyi değil, DÜZELTİLEN ŞEYİ belgeliyor: aynı kural aynı
    // yazmayı kabul ediyor, yani kusur kuralda değil İSTEMCİNİN GÖNDERDİĞİ
    // VERİDE'ydi. Kuralın bunu reddetmesini beklemek yanlış yere bakmak olur.
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(setDoc(
      doc(db, 'projects', P1),
      stamped(OWNER, { memberUids: [OWNER], progress: 7 }),
      { merge: true },
    ));
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const uids = (await getDoc(doc(ctx.firestore(), 'projects', P1))).data().memberUids;
      if (uids.includes(NEWCOMER)) throw new Error('beklenen kusur üremedi');
      // Zemini bir sonraki test için geri al.
      await updateDoc(doc(ctx.firestore(), 'projects', P1), {
        memberUids: arrayUnion(MEMBER, NEWCOMER),
      });
    });
  });

  it('üyelik kapısı arrayRemove ile kapanıyor (ortak çıkarma)', async () => {
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(updateDoc(
      doc(db, 'projects', P1),
      stamped(OWNER, { memberUids: arrayRemove(NEWCOMER) }),
    ));
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const uids = (await getDoc(doc(ctx.firestore(), 'projects', P1))).data().memberUids;
      if (uids.includes(NEWCOMER)) throw new Error('üyelik kapısı kapanmadı');
      if (!uids.includes(OWNER)) throw new Error('sahip de düştü');
    });
  });

  it('silme sentinel’i merge yazmada kuraldan geçiyor', async () => {
    // `merge: true` yükte OLMAYAN alanı sunucuda bırakıyor; kullanıcının
    // temizlediği opsiyonel için açık `deleteField()` gerekiyor.
    const db = testEnv.authenticatedContext(OWNER).firestore();
    await assertSucceeds(setDoc(
      doc(db, 'projects', P1),
      duzenlemeYuku(OWNER, { archivedAt: deleteField() }),
      { merge: true },
    ));
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const d = (await getDoc(doc(ctx.firestore(), 'projects', P1))).data();
      if ('archivedAt' in d) throw new Error('silme sentinel’i işlemedi');
    });
  });

  it('ortak bu yoldan da yazamıyor', async () => {
    const db = testEnv.authenticatedContext(MEMBER).firestore();
    await assertFails(setDoc(
      doc(db, 'projects', P1),
      duzenlemeYuku(MEMBER, { progress: 99 }),
      { merge: true },
    ));
    // Kendini üyeliğe ekleme denemesi de reddedilmeli.
    await assertFails(updateDoc(
      doc(db, 'projects', P2),
      stamped(MEMBER, { memberUids: arrayUnion(MEMBER) }),
    ));
  });
});

describe('projects/{pid}/apartments — yönetici yazar, ortak okur', () => {
  before(seed);

  it('üye daireyi okur', async () => {
    await assertSucceeds(getDoc(doc(memberDb, 'projects', P1, 'apartments', 'apt-1')));
  });

  it('ÜYE OLMAYAN daireyi okumaz — alıcı adı ve bedel sızmasın', async () => {
    await assertFails(getDoc(doc(strangerDb, 'projects', P1, 'apartments', 'apt-1')));
  });

  it('sahip daire yazar', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, 'apartments', 'apt-2'),
      stamped(OWNER, {
        id: 'apt-2', projectId: P1, apartmentNumber: 2, status: 'sold',
        buyerName: 'Ayşe Tuna', price: 4200000_00,
      })));
  });

  it('ORTAK daire yazamaz', async () => {
    await assertFails(setDoc(doc(memberDb, 'projects', P1, 'apartments', 'apt-3'), {
      id: 'apt-3', projectId: P1, apartmentNumber: 3, status: 'sold',
    }));
  });

  it('projectId üst yolla uyuşmuyorsa yazılamaz', async () => {
    await assertFails(setDoc(doc(ownerDb, 'projects', P1, 'apartments', 'apt-4'), {
      id: 'apt-4', projectId: P2, apartmentNumber: 4, status: 'available',
    }));
  });

  it('YABANCI başkasının projesine belge enjekte edemez', async () => {
    await assertFails(setDoc(doc(strangerDb, 'projects', P1, 'apartments', 'apt-5'), {
      id: 'apt-5', projectId: P1, apartmentNumber: 5, status: 'available',
    }));
  });

  it('sahip daireyi silebilir', async () => {
    await assertSucceeds(deleteDoc(doc(ownerDb, 'projects', P1, 'apartments', 'apt-1')));
  });

  it('ortak daireyi silemez', async () => {
    await assertFails(deleteDoc(doc(memberDb, 'projects', P1, 'apartments', 'apt-1')));
  });
});

// ═══════════════════════════ Davet kodları ═══════════════════════════

describe('derleme 169 ile uyum — istemci yazma biçimleri', () => {

  // ───────────────────────────────────────────────────────────────────────
  // BEKÇİ TESTLERİ. Derleme 169 App Store'da ve ESKİ istemci kodunu taşıyor;
  // güncellenmeyen kullanıcılar bu sürümle uzun süre kalacak. Aşağıdaki
  // yazma biçimleri 169'un BUGÜN kullandıkları ve kural bunları kabul etmek
  // ZORUNDA. Kural sıkılaştırılırsa (ör. proje güncellemesinde damga şartı)
  // 169 sessizce kırılır ve bunu başka hiçbir test göstermez.
  //
  // Madde 6'nın tasarımı bu yüzden kurala dokunmuyor: tüm değişiklik
  // sunucuda (`redeemInvite`).
  // ───────────────────────────────────────────────────────────────────────

  const future = () => new Date(Date.now() + 48 * 3600 * 1000);

  before(seed);

  it('davet partisi kabul ediliyor — davet belgesi + DAMGASIZ ayna, tek partide', async () => {
    // `FirebaseInviteService.createInvite`in biçimi (169 ve güncel aynı):
    // aynada cihaz saati var ve damga YOK.
    const batch = writeBatch(ownerDb);
    batch.set(doc(ownerDb, 'invites', 'K7BAT2'), {
      projectId: P1, createdAt: serverTimestamp(), expiresAt: future(), usedAt: null,
    });
    batch.update(doc(ownerDb, 'projects', P1), {
      invite: { code: 'K7BAT2', createdAt: new Date() },
    });
    await assertSucceeds(batch.commit());
  });

  it('169’un KURULUMU kabul ediliyor — işaretsiz, cihaz saatli createdAt', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', 'k169-kurulum'), stamped(OWNER, {
      id: 'k169-kurulum', ownerUid: OWNER, memberUids: [OWNER],
      blockNumber: '1', parcelNumber: '1', createdAt: new Date(),
    })));
  });

  // İŞARETLİ PROJEDE 169. 169 `establishToken`i tanımıyor ve merge'siz TAM
  // yazma onu DÜŞÜRÜYOR. Kural "işaret istekte VARSA eşit olmalı" diyor; istekte
  // yoksa geçer. `get(k, null) == get(k, null)` biçimi BURADA 169'u KIRARDI
  // (düşen alan null ≠ eski değer) — bu üç test o yanlış biçimi yakalar.
  for (const [ad, ek] of [
    ['düzenleme (TAM set)', { progress: 55 }],
    ['ortak çıkarma (memberUids kısalıyor)', { memberUids: [OWNER] }],
    ['arşivden çıkarma (archivedAt yükte yok)', {}],
  ]) {
    it(`169 işaretli projede: ${ad}`, async () => {
      const pid = `k169-${ad.length}`;
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), 'projects', pid), {
          id: pid, ownerUid: OWNER, memberUids: [OWNER, MEMBER], establishToken: 'tok-169',
          blockNumber: '2', parcelNumber: '2', createdAt: new Date(), archivedAt: new Date(),
        });
      });
      await assertSucceeds(setDoc(doc(ownerDb, 'projects', pid), stamped(OWNER, {
        id: pid, ownerUid: OWNER, memberUids: [OWNER, MEMBER],
        blockNumber: '2', parcelNumber: '2', createdAt: new Date(), ...ek,
      })));
    });
  }

  it('işaretli projede ortak çıkarma arrayRemove ile geçiyor (güncel iOS ve Android)', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'projects', 'k169-ar'), {
        id: 'k169-ar', ownerUid: OWNER, memberUids: [OWNER, MEMBER], establishToken: 'tok-ar',
        blockNumber: '3', parcelNumber: '3', createdAt: new Date(),
      });
    });
    await assertSucceeds(updateDoc(doc(ownerDb, 'projects', 'k169-ar'),
      stamped(OWNER, { memberUids: arrayRemove(MEMBER) })));
  });

  it('BİLİNEN AÇIK: 169’un geri yüklemesi var olan belgeyi hâlâ ezebiliyor', async () => {
    // 169 işaret göndermediği için kural onun geri yüklemesini kendi sıradan
    // düzenlemesinden AYIRAMIYOR. Bu test bir söz değil, sınırın belgesi:
    // düzeltme yalnızca güncel ve sonraki istemcileri koruyor.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'projects', 'k169-acik'), {
        id: 'k169-acik', ownerUid: OWNER, memberUids: [OWNER, MEMBER],
        blockNumber: '4', parcelNumber: '4', createdAt: new Date(),
      });
    });
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', 'k169-acik'), stamped(OWNER, {
      id: 'k169-acik', ownerUid: OWNER, memberUids: [OWNER],
      blockNumber: '4', parcelNumber: '4', createdAt: new Date(),
    })));
  });

  it('169’un merge’siz TAM proje yazması kabul ediliyor', async () => {
    // 169 her proje düzenlemesini `setData(encode(project))` ile, merge
    // OLMADAN yazıyor (madde 1 düzeltmesi sonra geldi).
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1), stamped(OWNER, {
      id: P1, ownerUid: OWNER, memberUids: [OWNER, MEMBER],
      blockNumber: '145', parcelNumber: '2', createdAt: new Date(),
      progress: 50, invite: { code: 'K7BAT2', createdAt: new Date() },
    })));
  });
});

describe('davet aynası ya TAM ya HİÇ — 169 panosu boşalmasın', () => {

  // ───────────────────────────────────────────────────────────────────────
  // Derleme 169 ve Android aynayı ZORUNLU `code` + `createdAt` ile çözüyor ve
  // proje çözümü yalıtılmış değil: `code`'suz bir `invite` haritası o projenin
  // TÜM ÜYELERİNDE panoyu boşaltır (169 modeliyle derlenen prototipte ölçüldü).
  // Ayna kaldırılırken hiçbir yazma yolu yarım harita bırakamamalı.
  // ───────────────────────────────────────────────────────────────────────

  before(seed);

  it('yarım ayna (kodsuz) REDDEDİLİR', async () => {
    await assertFails(updateDoc(doc(ownerDb, 'projects', P1),
      stamped(OWNER, { invite: { createdAt: new Date() } })));
  });

  it('boş ayna haritası REDDEDİLİR', async () => {
    await assertFails(updateDoc(doc(ownerDb, 'projects', P1), stamped(OWNER, { invite: {} })));
  });

  it('yarım aynayla kurulum REDDEDİLİR', async () => {
    await assertFails(setDoc(doc(ownerDb, 'projects', 'ayna-yarim'), stamped(OWNER, {
      id: 'ayna-yarim', ownerUid: OWNER, memberUids: [OWNER],
      blockNumber: '5', parcelNumber: '5', createdAt: new Date(),
      invite: { code: 'ABC234' },
    })));
  });

  it('ESKİ yarım ayna projeyi KİLİTLEMEZ — ayna değişmeyen düzenleme geçer', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'projects', 'ayna-eski'), {
        id: 'ayna-eski', ownerUid: OWNER, memberUids: [OWNER],
        blockNumber: '6', parcelNumber: '6', createdAt: new Date(),
        invite: { createdAt: new Date() },   // bir şekilde kalmış yarım ayna
      });
    });
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', 'ayna-eski'),
      stamped(OWNER, { progress: 30, memberUids: arrayUnion(OWNER) }), { merge: true }));
    // Ama yarım aynayı DEĞİŞTİREREK yeniden yazmak yine reddedilir.
    await assertFails(updateDoc(doc(ownerDb, 'projects', 'ayna-eski'),
      stamped(OWNER, { invite: { createdAt: new Date(Date.now() + 1000) } })));
  });

  it('aynayı SİLMEK geçer — güncel istemcinin davet partisi bunu yapıyor', async () => {
    await assertSucceeds(updateDoc(doc(ownerDb, 'projects', P1), { invite: deleteField() }));
  });

  it('güncel istemcinin davet partisi geçer — davet belgesi + ayna SİLME', async () => {
    const batch = writeBatch(ownerDb);
    batch.set(doc(ownerDb, 'invites', 'NEW234'), {
      projectId: P1, createdAt: serverTimestamp(),
      expiresAt: new Date(Date.now() + 48 * 3600 * 1000), usedAt: null,
    });
    batch.update(doc(ownerDb, 'projects', P1), { invite: deleteField() });
    await assertSucceeds(batch.commit());
  });
});

describe('proje kurulumu YALNIZCA belge yoksa — establishToken', () => {

  // ───────────────────────────────────────────────────────────────────────
  // KUSUR: `restore()` yedekteki kimlikle `.createProject` yazıyor ve "bu
  // proje zaten var mı" sorusunu YALNIZCA yerel listeye soruyordu. Sahibin
  // kendi projesi yerelde yoksa (alt koleksiyonu çözülemeyip `failedProjects`e
  // düştüyse, ya da soğuk açılışta liste henüz boşken) yazma CANLI belgeye
  // tam setData oluyordu: ortaklar düşüyor, davet aynası, arşiv ve fotoğraf
  // sayacı siliniyordu — ve kural reddetmiyordu, çünkü sahiplik değişmiyor.
  //
  // DÜZELTME KURALDA: kurulum yazması rastgele bir dize işaret taşıyor; var
  // olan belgede işaretin EKLENMESİ ya da DEĞİŞMESİ reddediliyor. Var olmayan
  // belgeye yazma `create` sayıldığı için geçiyor. Yani kurulum sunucuda
  // "yalnızca yoksa yaz" oldu — istemcinin ne bildiğinden bağımsız.
  //
  // NEDEN DİZE, ZAMAN DAMGASI DEĞİL: onayı kaybolmuş bir yazma AYNI yükle
  // yeniden gönderilebiliyor; zaman damgalı işaret o yeniden gönderimi
  // reddederdi (emülatörde ölçüldü). Aynı dize ise eşit, geçiyor.
  // ───────────────────────────────────────────────────────────────────────

  before(seed);

  const kur = async (pid, alanlar) => testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'projects', pid), {
      id: pid, ownerUid: OWNER, memberUids: [OWNER, MEMBER],
      blockNumber: '300', parcelNumber: '1', createdAt: new Date(), ...alanlar,
    });
  });
  const geriYukleme = (pid, token) => stamped(OWNER, {
    id: pid, ownerUid: OWNER, memberUids: [OWNER],
    blockNumber: '300', parcelNumber: '1', createdAt: new Date(),
    establishToken: token,
  });

  it('İŞARETSİZ var olan projeye işaretli kurulum REDDEDİLİR — canlı belge ezilmez', async () => {
    await kur('et-canli', { invite: { code: 'ABC234', createdAt: new Date() } });
    await assertFails(setDoc(doc(ownerDb, 'projects', 'et-canli'), geriYukleme('et-canli', 'tok-1')));
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const d = (await getDoc(doc(ctx.firestore(), 'projects', 'et-canli'))).data();
      if (!d.memberUids.includes(MEMBER)) throw new Error('ortak düştü — belge ezildi');
      if (d.invite?.code !== 'ABC234') throw new Error('davet aynası silindi');
    });
  });

  it('BAŞKA işaretle kurulmuş projeye kurulum REDDEDİLİR', async () => {
    await kur('et-baska', { establishToken: 'tok-eski' });
    await assertFails(setDoc(doc(ownerDb, 'projects', 'et-baska'), geriYukleme('et-baska', 'tok-yeni')));
  });

  it('AYNI işaretle yeniden gönderim GEÇER — onayı kaybolan yazma ya da yarım kalan geri yükleme', async () => {
    await kur('et-ayni', { establishToken: 'tok-ayni', memberUids: [OWNER] });
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', 'et-ayni'), geriYukleme('et-ayni', 'tok-ayni')));
  });

  it('belge YOKKEN işaretli kurulum GEÇER', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', 'et-yeni'), geriYukleme('et-yeni', 'tok-yeni')));
  });

  it('işaret dize değilse kurulum REDDEDİLİR', async () => {
    await assertFails(setDoc(doc(ownerDb, 'projects', 'et-tip'),
      { ...geriYukleme('et-tip', 'x'), establishToken: 42 }));
  });

  it('64 karakteri aşan işaret REDDEDİLİR', async () => {
    await assertFails(setDoc(doc(ownerDb, 'projects', 'et-uzun'), geriYukleme('et-uzun', 'x'.repeat(65))));
  });

  it('güncel istemcinin merge düzenlemesi işareti KORUR ve geçer', async () => {
    await kur('et-merge', { establishToken: 'tok-m' });
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', 'et-merge'),
      stamped(OWNER, { progress: 40, memberUids: arrayUnion(OWNER) }), { merge: true }));
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const d = (await getDoc(doc(ctx.firestore(), 'projects', 'et-merge'))).data();
      if (d.establishToken !== 'tok-m') throw new Error('merge işareti düşürdü');
    });
  });
});

describe('invites/{KOD}', () => {
  before(seed);

  const future = () => new Date(Date.now() + 48 * 3600 * 1000);

  it('sahip kendi projesi için davet üretir', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'invites', 'X7B9Q2'), {
      projectId: P1, createdAt: serverTimestamp(), expiresAt: future(), usedAt: null,
    }));
  });

  // ÖMÜR SUNUCU SAATİYLE SINIRLI (31 Ağu 2026).
  //
  // `redeemInvite` süreyi belgedeki `expiresAt`e bakarak ölçüyor. O değer
  // istemciden geldiği ve denetlenmediği sürece "kod 48 saat geçerli"
  // cümlesini uygulayan kimse yoktu: saati ileri alınmış bir cihaz kodu
  // yıllarca geçerli yapabilirdi.
  it('CİHAZ SAATİYLE yazılmış createdAt reddedilir', async () => {
    // SAAT AÇIKÇA KAYDIRILIYOR (bir dakika geri) ve bu bir detay değil:
    // `new Date()` ile yazıldığında istemcinin damgası sunucununkiyle AYNI
    // MİLİSANİYEYE düşebiliyor (ikisi de aynı makinede, yerel ağ turu sıfıra
    // yakın) ve kural yazmayı haklı olarak kabul ediyordu — test rastgele
    // kırmızıya dönüyordu. Saldırının gerçek biçimi de bu zaten: kayık saat.
    await assertFails(setDoc(doc(ownerDb, 'invites', 'EEEEEE'), {
      projectId: P1, createdAt: new Date(Date.now() - 60_000),
      expiresAt: future(), usedAt: null,
    }));
  });

  it('48 saati AŞAN ömür reddedilir — kod sonsuza kadar yaşayamaz', async () => {
    const birYilSonra = new Date(Date.now() + 365 * 24 * 3600 * 1000);
    await assertFails(setDoc(doc(ownerDb, 'invites', 'FFFFFF'), {
      projectId: P1, createdAt: serverTimestamp(), expiresAt: birYilSonra, usedAt: null,
    }));
  });

  it('expiresAt zaman damgası değilse reddedilir', async () => {
    await assertFails(setDoc(doc(ownerDb, 'invites', 'GGGGGG'), {
      projectId: P1, createdAt: serverTimestamp(), expiresAt: 'yarın', usedAt: null,
    }));
  });

  // ALT SINIR YOK ve bilerek: saati GERİ alınmış cihaz kendi kodunu kısa
  // ömürlü yapar — sinir bozucu ama tehlikeli değil. Alt sınır konsaydı saati
  // bozuk kullanıcı davet üretemez hâle gelirdi.
  it('GEÇMİŞ tarihli expiresAt kabul ediliyor — alt sınır bilerek yok', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'invites', 'HHHHHH'), {
      projectId: P1, createdAt: serverTimestamp(),
      expiresAt: new Date(Date.now() - 3600 * 1000), usedAt: null,
    }));
  });

  it('YABANCI başkasının projesi için davet üretemez', async () => {
    await assertFails(setDoc(doc(strangerDb, 'invites', 'AAAAAA'), {
      projectId: P1, createdAt: serverTimestamp(), expiresAt: future(), usedAt: null,
    }));
  });

  it('ORTAK davet üretemez — davet etmek yönetici yetkisi', async () => {
    await assertFails(setDoc(doc(memberDb, 'invites', 'BBBBBB'), {
      projectId: P1, createdAt: serverTimestamp(), expiresAt: future(), usedAt: null,
    }));
  });

  it('oturum açmamış kullanıcı davet üretemez', async () => {
    await assertFails(setDoc(doc(anonDb, 'invites', 'CCCCCC'), {
      projectId: P1, createdAt: serverTimestamp(), expiresAt: future(), usedAt: null,
    }));
  });

  // ── SAHİP KENDİ DAVETİNİ OKUR (23 Eki) ──────────────────────────────
  //
  // Eskiden okuma HERKESE kapalıydı ve sahip kodu proje belgesindeki AYNADAN
  // görüyordu. Ama proje belgesi TÜM ÜYELERE açık: ham kod salt okur
  // ortakların cihazına iniyor, Yedek.json ile dosyalara sızıyordu. Ortak
  // kodu başkasına verirse o kişi katılabiliyordu — salt okur ortak fiilen
  // davet yetkisi kazanıyordu. Artık sahip OTORİTEYİ okuyor, ayna kalkıyor.
  //
  // NUMARALAMA KÂHİNİ AÇILMIYOR: sahip olmayan için karar kodun var olup
  // olmamasından bağımsız. Kod YOKSA `resource != null` düşer, BAŞKASININ
  // ise `isOwner` düşer — ikisi de aynı ret. (Eski gerekçe "6 hane kaba
  // kuvvetle denenebilirdi" bu biçimde geçerli değil; yazma yolundaki kâhin
  // ayrı bir madde.)
  it('sahip KENDİ projesinin davetini okur', async () => {
    await assertSucceeds(getDoc(doc(ownerDb, 'invites', 'X7B9Q2')));
  });

  it('başkasının kodu ile var olmayan kod AYNI yanıtı verir — numaralama kâhini yok', async () => {
    await assertFails(getDoc(doc(strangerDb, 'invites', 'X7B9Q2')));   // var, başkasının
    await assertFails(getDoc(doc(strangerDb, 'invites', 'ZZ9ZZ9')));   // yok
    await assertFails(getDoc(doc(ownerDb, 'invites', 'ZZ9ZZ9')));      // yok, sahip için de
  });

  it('ORTAK davet kodunu okuyamaz — davet yönetici yetkisi', async () => {
    await assertFails(getDoc(doc(memberDb, 'invites', 'X7B9Q2')));
  });

  it('sahip kendi projesinin davetlerini projectId ile listeler', async () => {
    await assertSucceeds(getDocs(query(collection(ownerDb, 'invites'), where('projectId', '==', P1))));
  });

  it('başkasının projesinin davetleri listelenemez', async () => {
    await assertFails(getDocs(query(collection(strangerDb, 'invites'), where('projectId', '==', P1))));
    await assertFails(getDocs(query(collection(memberDb, 'invites'), where('projectId', '==', P1))));
  });

  it('davet edilen kişi kodu okuyup projeyi bulamaz (callable şart)', async () => {
    await assertFails(getDoc(doc(strangerDb, 'invites', 'X7B9Q2')));
  });

  it('davetler listelenemez', async () => {
    await assertFails(getDocs(collection(ownerDb, 'invites')));
  });

  it('kodu SAHİBİ DAHİ harcanmış işaretleyemez — o yetki işlevin', async () => {
    await assertFails(updateDoc(doc(ownerDb, 'invites', 'X7B9Q2'), {
      usedAt: new Date(), usedByUid: STRANGER,
    }));
  });

  it('davet silinemez', async () => {
    await assertFails(deleteDoc(doc(ownerDb, 'invites', 'X7B9Q2')));
  });

  it('aynı kod ikinci kez üretilemez — başkasının daveti çalınamaz', async () => {
    // `create` yalnızca belge yokken geçerli; ikincisi `update` sayılır ve kapalı.
    await assertFails(setDoc(doc(strangerDb, 'invites', 'X7B9Q2'), {
      projectId: P2, createdAt: serverTimestamp(), expiresAt: future(), usedAt: null,
    }));
  });

  it('projectId olmadan davet üretilemez', async () => {
    await assertFails(setDoc(doc(ownerDb, 'invites', 'DDDDDD'), {
      createdAt: serverTimestamp(), expiresAt: future(), usedAt: null,
    }));
  });
});

// ═══════════════ Aynı kalıbı paylaşan TÜM alt koleksiyonlar ═══════════════
//
// Kural dosyasında sekiz koleksiyon aynı kalıbı tekrarlıyor (yönetici yazar,
// üye okur). Tekrarlanan kod, tekrarlanan yazım hatası demek: birinde
// `ownerWrite` yerine `isMember` yazılsa ya da `read` fazla açık bırakılsa
// gözle farkedilmezdi. Bu döngü her birini ayrı ayrı denetliyor — özellikle
// `payments` ve `expenses` finansal veri taşıdığı için.
describe('alt koleksiyonların tamamı aynı yetki kalıbına uyuyor', () => {
  before(seed);

  const COLLECTIONS = [
    'materials', 'materialLogs', 'apartments', 'partners',
    'sitePhotos', 'expenses', 'payments', 'apartmentPhotos',
    // Taksit planı (madde 21). Ortağa AÇIK: ortak zaten gerçekleşmiş
    // ödemelerin tarih ve tutarını görüyor, vadeleri gizlemek onu bilgisiz
    // bırakmaz — aynı sonucu elle çıkarmaya zorlar ve şeffaflıkla çelişir.
    'installments',
    // Ortak cari hesabı (madde 82). Ortağa AÇIK ve bu bilinçli: ortak
    // hesabın TARAFI — kimin ne koyduğu ve çektiği, hepsinin aynı havuz
    // üzerindeki iddiasını belirliyor. Alıcı kimliğiyle aynı sınıfta bir
    // karar ama sonucu ters, çünkü alıcı üçüncü kişi.
    'partnerLedger',
  ];

  for (const name of COLLECTIONS) {
    it(`${name}: sahip yazar`, async () => {
      await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, name, 'x1'),
        stamped(OWNER, { id: 'x1', projectId: P1 })));
    });

    it(`${name}: üye okur`, async () => {
      await assertSucceeds(getDoc(doc(memberDb, 'projects', P1, name, 'x1')));
    });

    it(`${name}: ORTAK yazamaz`, async () => {
      // Ortak damgayı da doğru koyuyor; reddin sebebi `isOwner`.
      await assertFails(setDoc(doc(memberDb, 'projects', P1, name, 'x2'),
        stamped(MEMBER, { id: 'x2', projectId: P1 })));
    });

    it(`${name}: ÜYE OLMAYAN okuyamaz`, async () => {
      await assertFails(getDoc(doc(strangerDb, 'projects', P1, name, 'x1')));
    });

    it(`${name}: yanlış projectId ile yazılamaz`, async () => {
      // Damga DOĞRU, yalnızca yol yanlış — reddin sebebi `pathBound`,
      // damga eksikliği değil. Damgasız yazsaydık test doğru sebeple
      // geçtiğini kanıtlamazdı.
      await assertFails(setDoc(doc(ownerDb, 'projects', P1, name, 'x3'),
        stamped(OWNER, { id: 'x3', projectId: P2 })));
    });

    it(`${name}: ortak silemez`, async () => {
      await assertFails(deleteDoc(doc(memberDb, 'projects', P1, name, 'x1')));
    });
  }
});

// ═══════════════════════════ Alıcı kimliği ═══════════════════════════

describe('projects/{pid}/buyers — alıcı adı yalnızca yöneticide', () => {
  before(async () => {
    await seed();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'projects', P1, 'buyers', 'apt-1'), {
        apartmentId: 'apt-1', projectId: P1, name: 'Ayşe Tuna',
      });
    });
  });

  it('sahip alıcı adını okur', async () => {
    await assertSucceeds(getDoc(doc(ownerDb, 'projects', P1, 'buyers', 'apt-1')));
  });

  it('ORTAK alıcı adını OKUYAMAZ — asıl mesele bu', async () => {
    // Daire belgesini okuyabiliyor (durum, bedel, tahsilat görmeli) ama
    // alıcının kimliği ayrı belgede ve kapalı. Kural ALAN gizleyemediği için
    // ayırmak tek yol: aynı belgede kalsa ortağın cihazına inerdi.
    await assertFails(getDoc(doc(memberDb, 'projects', P1, 'buyers', 'apt-1')));
  });

  it('ortak alıcı listesini çekemez', async () => {
    await assertFails(getDocs(collection(memberDb, 'projects', P1, 'buyers')));
  });

  it('üye olmayan hiç okuyamaz', async () => {
    await assertFails(getDoc(doc(strangerDb, 'projects', P1, 'buyers', 'apt-1')));
  });

  it('ortak DAİREYİ hâlâ okuyabiliyor — gizlenen yalnızca kimlik', async () => {
    // Gizlilik, ortağın yatırımcı olarak payını hesaplamasını engellememeli.
    await assertSucceeds(getDoc(doc(memberDb, 'projects', P1, 'apartments', 'apt-1')));
  });

  it('sahip alıcı adı yazar', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, 'buyers', 'apt-2'),
      stamped(OWNER, { apartmentId: 'apt-2', projectId: P1, name: 'Mehmet Demir' })));
  });

  it('ORTAK alıcı adı yazamaz', async () => {
    await assertFails(setDoc(doc(memberDb, 'projects', P1, 'buyers', 'apt-3'), {
      apartmentId: 'apt-3', projectId: P1, name: 'uydurma',
    }));
  });

  it('yanlış projectId ile yazılamaz', async () => {
    await assertFails(setDoc(doc(ownerDb, 'projects', P1, 'buyers', 'apt-4'), {
      apartmentId: 'apt-4', projectId: P2, name: 'Ayşe Tuna',
    }));
  });
});

// ═══════════════════════════ Belge görünürlüğü ═══════════════════════════

describe('projects/{pid}/documents — partnerVisible', () => {
  before(seed);

  it('ortak GÖRÜNÜR belgeyi okur', async () => {
    await assertSucceeds(getDoc(doc(memberDb, 'projects', P1, 'documents', 'doc-visible')));
  });

  it('ortak GİZLİ belgeyi okumaz — cihazının önbelleğine hiç inmez', async () => {
    await assertFails(getDoc(doc(memberDb, 'projects', P1, 'documents', 'doc-hidden')));
  });

  it('sahip gizli belgeyi okur', async () => {
    await assertSucceeds(getDoc(doc(ownerDb, 'projects', P1, 'documents', 'doc-hidden')));
  });

  it('ortağın SÜZGEÇLİ listesi çalışır', async () => {
    const snap = await assertSucceeds(getDocs(query(
      collection(memberDb, 'projects', P1, 'documents'),
      where('partnerVisible', '==', true),
    )));
    if (snap.size !== 1) throw new Error(`beklenen 1 belge, gelen ${snap.size}`);
  });

  it('ortağın SÜZGEÇSİZ listesi reddedilir — istemci sorgusu role göre kurulmak zorunda', async () => {
    await assertFails(getDocs(collection(memberDb, 'projects', P1, 'documents')));
  });

  it('ortak partnerVisible==false süzgeciyle de okuyamaz', async () => {
    await assertFails(getDocs(query(
      collection(memberDb, 'projects', P1, 'documents'),
      where('partnerVisible', '==', false),
    )));
  });

  it('sahibin süzgeçsiz listesi çalışır — iki belgeyi de görür', async () => {
    const snap = await assertSucceeds(getDocs(collection(ownerDb, 'projects', P1, 'documents')));
    if (snap.size !== 2) throw new Error(`beklenen 2 belge, gelen ${snap.size}`);
  });
});

// ═══════════════════════════ Ekle-only defterler ═══════════════════════════

describe('hareket akışı ve denetim defteri değiştirilemez', () => {
  before(seed);

  it('sahip hareket ekler', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, 'activities', 'act-2'),
      stamped(OWNER, { id: 'act-2', projectId: P1, kind: 'materialIn', title: 'Demir · giriş' })));
  });

  it('sahip DAHİ geçmiş hareketi düzeltemez', async () => {
    await assertFails(updateDoc(doc(ownerDb, 'projects', P1, 'activities', 'act-1'), {
      title: 'değiştirildi',
    }));
  });

  it('sahip DAHİ hareketi silemez', async () => {
    await assertFails(deleteDoc(doc(ownerDb, 'projects', P1, 'activities', 'act-1')));
  });

  it('sahip denetim kaydı ekler', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, 'auditEntries', 'audit-2'),
      stamped(OWNER, { id: 'audit-2', projectId: P1, action: 'delete', subject: 'Fiş #4471' })));
  });

  it('denetim kaydı DÜZELTİLEMEZ — şeffaflık iddiasının dayanağı', async () => {
    await assertFails(updateDoc(doc(ownerDb, 'projects', P1, 'auditEntries', 'audit-1'), {
      subject: 'temizlendi',
    }));
  });

  it('denetim kaydı SİLİNEMEZ', async () => {
    await assertFails(deleteDoc(doc(ownerDb, 'projects', P1, 'auditEntries', 'audit-1')));
  });

  it('ortak hareket ekleyemez', async () => {
    await assertFails(setDoc(doc(memberDb, 'projects', P1, 'activities', 'act-3'), {
      id: 'act-3', projectId: P1, kind: 'sale', title: 'uydurma satış',
    }));
  });

  // ── Madde 76'nın dayandığı iki kural ───────────────────────────────────
  //
  // "Kayıt İzi" ekranı ORTAĞA açık ve bunun tek dayanağı `auditEntries`
  // kuralındaki `allow read: if isMember(pid)`. O satır bugüne kadar HİÇ
  // test edilmemişti: var olan üç denetim testi yalnızca `ownerDb`
  // kullanıyordu (sahip ekler / düzeltemez / silemez). Yani ekranın
  // meşruiyetini veren izin de, onu sınırlayan kapı da denetimsizdi —
  // biri kuralı `signedIn()`e gevşetse hiçbir test düşmezdi.

  it('ORTAK denetim izini OKUR — Kayıt İzi ekranının dayanağı', async () => {
    await assertSucceeds(getDoc(doc(memberDb, 'projects', P1, 'auditEntries', 'audit-1')));
  });

  it('ÜYE OLMAYAN denetim izini OKUYAMAZ', async () => {
    await assertFails(getDoc(doc(strangerDb, 'projects', P1, 'auditEntries', 'audit-1')));
  });

  it('ortak denetim kaydı EKLEYEMEZ — defteri yazan yalnızca sahip', async () => {
    await assertFails(setDoc(doc(memberDb, 'projects', P1, 'auditEntries', 'audit-3'), {
      id: 'audit-3', projectId: P1, action: 'update', subject: 'uydurma düzeltme',
    }));
  });
});

// ═══════════════ İki aşamalı proje kurulumu (repository sözleşmesi) ═══════════════

describe('proje kurulumu tek partide YAPILAMAZ', () => {
  before(seed);

  // Bu test bir kuralı değil, FirestoreProjectRepository'nin uymak zorunda
  // olduğu bir KISITI sabitliyor: kural değerlendirmesi aynı partideki henüz
  // işlenmemiş üst belgeyi görmez. Yorum yerine test, çünkü yorum atlanabilir.
  it('proje + daire aynı WriteBatch içinde reddedilir', async () => {
    const batch = writeBatch(memberDb);
    const pid = 'tek-parti-proje';
    batch.set(doc(memberDb, 'projects', pid), {
      id: pid, ownerUid: MEMBER, memberUids: [MEMBER],
      blockNumber: '5', parcelNumber: '5', createdAt: new Date(),
    });
    batch.set(doc(memberDb, 'projects', pid, 'apartments', 'apt-1'), {
      id: 'apt-1', projectId: pid, apartmentNumber: 1, status: 'available',
    });
    await assertFails(batch.commit());
  });

  it('iki aşamada çalışır: önce proje, sonra alt belgeler tek parti', async () => {
    const pid = 'iki-asama-proje';
    // 1. aşama
    await assertSucceeds(setDoc(doc(memberDb, 'projects', pid), {
      id: pid, ownerUid: MEMBER, memberUids: [MEMBER],
      blockNumber: '6', parcelNumber: '6', createdAt: new Date(),
    }));
    // 2. aşama — çok belgeli parti, atomiklik sözü korunuyor
    const batch = writeBatch(memberDb);
    for (let n = 1; n <= 3; n++) {
      batch.set(doc(memberDb, 'projects', pid, 'apartments', `apt-${n}`),
        stamped(MEMBER, {
          id: `apt-${n}`, projectId: pid, apartmentNumber: n, status: 'available',
        }));
    }
    await assertSucceeds(batch.commit());
  });
});

// ═══════════════════════ Oran sınırı sayacı (madde 71) ═══════════════════

describe('oran sınırı sayacı istemciye kapalı', () => {
  before(seed);

  // Sayaç yalnızca Cloud Function tarafından yazılıyor. İki yön de önemli:
  // yazma açık olsa kullanıcı sayacı sıfırlar, okuma açık olsa saldırgan
  // kaç hakkı kaldığını görüp sınırın altında kalmayı öğrenirdi.

  it('kullanıcı KENDİ sayacını okuyamaz', async () => {
    await assertFails(getDoc(doc(ownerDb, 'rateLimits', OWNER)));
  });

  it('kullanıcı sayacı SIFIRLAYAMAZ', async () => {
    await assertFails(setDoc(doc(ownerDb, 'rateLimits', OWNER), { failedAttempts: 0 }));
  });

  it('başkasının sayacına da erişilemez', async () => {
    await assertFails(getDoc(doc(memberDb, 'rateLimits', OWNER)));
    await assertFails(setDoc(doc(memberDb, 'rateLimits', OWNER), { failedAttempts: 0 }));
  });
});

// ═══════════════════════ Sunucu damgası (madde 77) ═══════════════════════
//
// Denetim izinin tüm değeri tarihlerinde. "Kim ne zaman değiştirdi" sorusunun
// cevabı CİHAZIN saatinden geliyorsa iz bir kanıt değil bir İDDİADIR — ve
// madde 76 ile o iz artık ortağın gördüğü bir ekranda.
//
// Önceden `updatedAt`/`updatedBy` yazılıyordu ama kural HİÇ BAKMIYORDU:
// dosyada tek bir `request.time` ya da alan doğrulaması yoktu. Aşağıdaki
// testler kapının gerçekten kapandığını kanıtlıyor.

describe('sunucu damgası — tarih ve yazan hesap kuralda doğrulanıyor', () => {
  before(seed);

  it('DOĞRU damgayla yazma geçer', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, 'auditEntries', 'damga-1'),
      stamped(OWNER, { id: 'damga-1', projectId: P1, action: 'update', subject: 'Fiş' })));
  });

  it('CİHAZ SAATİNDEN yazılan tarih REDDEDİLİR — maddenin çekirdeği', async () => {
    // Kasten geri alınmış bir cihaz saati: kayıt bir yıl öncesine yazılmak
    // isteniyor. `updatedAt == request.time` şartı bunu geçirmiyor.
    await assertFails(setDoc(doc(ownerDb, 'projects', P1, 'auditEntries', 'damga-2'), {
      id: 'damga-2', projectId: P1, action: 'update', subject: 'Fiş',
      updatedAt: new Date('2025-01-01T00:00:00Z'),
      updatedBy: OWNER,
      updatedFrom: 'test-session',
    }));
  });

  it('İLERİ tarihli damga da REDDEDİLİR', async () => {
    await assertFails(setDoc(doc(ownerDb, 'projects', P1, 'auditEntries', 'damga-3'), {
      id: 'damga-3', projectId: P1, action: 'update', subject: 'Fiş',
      updatedAt: new Date(Date.now() + 86_400_000),
      updatedBy: OWNER,
      updatedFrom: 'test-session',
    }));
  });

  it('damgasız yazma REDDEDİLİR', async () => {
    await assertFails(setDoc(doc(ownerDb, 'projects', P1, 'auditEntries', 'damga-4'), {
      id: 'damga-4', projectId: P1, action: 'update', subject: 'Fiş',
    }));
  });

  it('BAŞKASININ uid’i ile damgalama REDDEDİLİR', async () => {
    // Sahip, değişikliği ortağın üstüne yıkamaz.
    await assertFails(setDoc(doc(ownerDb, 'projects', P1, 'auditEntries', 'damga-5'),
      stamped(MEMBER, { id: 'damga-5', projectId: P1, action: 'update', subject: 'Fiş' })));
  });

  it('`updatedBy` eksikse REDDEDİLİR', async () => {
    await assertFails(setDoc(doc(ownerDb, 'projects', P1, 'auditEntries', 'damga-6'), {
      id: 'damga-6', projectId: P1, action: 'update', subject: 'Fiş',
      updatedAt: serverTimestamp(),
      updatedFrom: 'test-session',
    }));
  });

  it('şart TÜM alt koleksiyonlarda geçerli, yalnızca denetim izinde değil', async () => {
    // `ownerWrite` tek yerde tanımlı; kapsam kaymasını burada sabitliyoruz.
    for (const name of ['materialLogs', 'payments', 'expenses', 'apartments']) {
      await assertFails(setDoc(doc(ownerDb, 'projects', P1, name, 'damgasiz'), {
        id: 'damgasiz', projectId: P1,
      }));
    }
  });

  it('SONRADAN DÜZELTMEDE de damga şart — eski kayıt taze damgayla güncellenir', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, 'expenses', 'gider-damga'),
      stamped(OWNER, { id: 'gider-damga', projectId: P1, amount: 100_00 })));
    // Güncelleme damgasız gelirse reddedilmeli.
    await assertFails(updateDoc(doc(ownerDb, 'projects', P1, 'expenses', 'gider-damga'), {
      amount: 999_00,
    }));
    await assertSucceeds(updateDoc(doc(ownerDb, 'projects', P1, 'expenses', 'gider-damga'),
      stamped(OWNER, { amount: 999_00 })));
  });
});

// ═══════════════════════════ Varsayılan red ═══════════════════════════

describe('tanımsız yollar kapalı', () => {
  before(seed);

  it('bilinmeyen koleksiyon okunamaz', async () => {
    await assertFails(getDoc(doc(ownerDb, 'ayarlar', 'global')));
  });

  it('bilinmeyen koleksiyona yazılamaz', async () => {
    await assertFails(setDoc(doc(ownerDb, 'ayarlar', 'global'), { x: 1 }));
  });

  it('proje altındaki tanımsız alt koleksiyon kapalı', async () => {
    await assertFails(setDoc(doc(ownerDb, 'projects', P1, 'gizliNotlar', 'n1'), {
      projectId: P1, text: 'x',
    }));
  });
});

// ═══════════ Kural kapsamı KODLA eşleşiyor mu (yapısal denetim) ═══════════
//
// NEDEN BU TEST VAR: 31 Ağu 2026'da `partnerLedger` koleksiyonu eklendi ve
// kurala yazılmasaydı uygulama üretimde sessizce reddedilecekti — kural
// dosyasındaki varsayılan "tanımsız yol kapalı" doğru davranış ama hatayı
// KULLANICI bulurdu, geliştirici değil. O gün gözle yakalandı; bir dahakini
// bu test yakalasın.
//
// Emülatör GEREKTİRMEZ: iki dosyayı okuyup karşılaştırıyor. Yine de bu
// dosyada duruyor, çünkü sorduğu soru bir kural sorusu ve ayrı bir koşu
// düzeni kurmak testin unutulmasının en kolay yolu olurdu.
describe('kural kapsamı: kodun yazdığı her koleksiyonun bir kuralı var', () => {
  const oku = (yol) => readFileSync(new URL(yol, import.meta.url), 'utf8');

  it('FirestoreProjectRepository.Coll ile firestore.rules birebir aynı', () => {
    const swift = oku('../InsaatTakip/Data/FirestoreProjectRepository.swift');
    const govde = swift.split('private enum Coll: String {')[1].split('}')[0];
    const kodda = [...govde.matchAll(/^\s*case\s+(\w+)/gm)].map((m) => m[1]).sort();

    const rules = oku('../firestore.rules');
    // Proje ALTINDAKİ bloklar altı boşlukla girintili; üst düzey yollar
    // (users, invites, rateLimits) bu karşılaştırmanın dışında.
    const kuralda = [...rules.matchAll(/^ {6}match \/(\w+)\/\{/gm)]
      .map((m) => m[1]).sort();

    const eksik = kodda.filter((c) => !kuralda.includes(c));
    const fazla = kuralda.filter((c) => !kodda.includes(c));

    if (eksik.length || fazla.length) {
      throw new Error(
        `Kural kapsamı kodla ayrıştı.\n` +
        `  Kodun yazdığı ama kuralda OLMAYAN (üretimde sessizce reddedilir): ${eksik.join(', ') || '—'}\n` +
        `  Kuralda olup kodun yazmadığı (ölü kural ya da eksik kod): ${fazla.join(', ') || '—'}`);
    }
    if (kodda.length === 0) throw new Error('Coll enum okunamadı — testin kendisi bozulmuş');
  });
});
