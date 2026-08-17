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
  collection, deleteDoc, doc, getDoc, getDocs, query,
  setDoc, updateDoc, where, writeBatch,
} from 'firebase/firestore';

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

  it('proje silinemez — alt koleksiyonlar istemciden atomik temizlenemez', async () => {
    await assertFails(deleteDoc(doc(ownerDb, 'projects', P1)));
  });
});

// ═══════════════════════════ Alt koleksiyonlar ═══════════════════════════

describe('projects/{pid}/apartments — yönetici yazar, ortak okur', () => {
  before(seed);

  it('üye daireyi okur', async () => {
    await assertSucceeds(getDoc(doc(memberDb, 'projects', P1, 'apartments', 'apt-1')));
  });

  it('ÜYE OLMAYAN daireyi okumaz — alıcı adı ve bedel sızmasın', async () => {
    await assertFails(getDoc(doc(strangerDb, 'projects', P1, 'apartments', 'apt-1')));
  });

  it('sahip daire yazar', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, 'apartments', 'apt-2'), {
      id: 'apt-2', projectId: P1, apartmentNumber: 2, status: 'sold',
      buyerName: 'Ayşe Tuna', price: 4200000_00,
    }));
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

describe('invites/{KOD}', () => {
  before(seed);

  const future = () => new Date(Date.now() + 48 * 3600 * 1000);

  it('sahip kendi projesi için davet üretir', async () => {
    await assertSucceeds(setDoc(doc(ownerDb, 'invites', 'X7B9Q2'), {
      projectId: P1, createdAt: new Date(), expiresAt: future(), usedAt: null,
    }));
  });

  it('YABANCI başkasının projesi için davet üretemez', async () => {
    await assertFails(setDoc(doc(strangerDb, 'invites', 'AAAAAA'), {
      projectId: P1, createdAt: new Date(), expiresAt: future(), usedAt: null,
    }));
  });

  it('ORTAK davet üretemez — davet etmek yönetici yetkisi', async () => {
    await assertFails(setDoc(doc(memberDb, 'invites', 'BBBBBB'), {
      projectId: P1, createdAt: new Date(), expiresAt: future(), usedAt: null,
    }));
  });

  it('oturum açmamış kullanıcı davet üretemez', async () => {
    await assertFails(setDoc(doc(anonDb, 'invites', 'CCCCCC'), {
      projectId: P1, createdAt: new Date(), expiresAt: future(), usedAt: null,
    }));
  });

  it('kodu SAHİBİ DAHİ okuyamaz — 6 hane kaba kuvvetle denenebilirdi', async () => {
    await assertFails(getDoc(doc(ownerDb, 'invites', 'X7B9Q2')));
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
      projectId: P2, createdAt: new Date(), expiresAt: future(), usedAt: null,
    }));
  });

  it('projectId olmadan davet üretilemez', async () => {
    await assertFails(setDoc(doc(ownerDb, 'invites', 'DDDDDD'), {
      createdAt: new Date(), expiresAt: future(), usedAt: null,
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
  ];

  for (const name of COLLECTIONS) {
    it(`${name}: sahip yazar`, async () => {
      await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, name, 'x1'), {
        id: 'x1', projectId: P1,
      }));
    });

    it(`${name}: üye okur`, async () => {
      await assertSucceeds(getDoc(doc(memberDb, 'projects', P1, name, 'x1')));
    });

    it(`${name}: ORTAK yazamaz`, async () => {
      await assertFails(setDoc(doc(memberDb, 'projects', P1, name, 'x2'), {
        id: 'x2', projectId: P1,
      }));
    });

    it(`${name}: ÜYE OLMAYAN okuyamaz`, async () => {
      await assertFails(getDoc(doc(strangerDb, 'projects', P1, name, 'x1')));
    });

    it(`${name}: yanlış projectId ile yazılamaz`, async () => {
      await assertFails(setDoc(doc(ownerDb, 'projects', P1, name, 'x3'), {
        id: 'x3', projectId: P2,
      }));
    });

    it(`${name}: ortak silemez`, async () => {
      await assertFails(deleteDoc(doc(memberDb, 'projects', P1, name, 'x1')));
    });
  }
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
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, 'activities', 'act-2'), {
      id: 'act-2', projectId: P1, kind: 'materialIn', title: 'Demir · giriş',
    }));
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
    await assertSucceeds(setDoc(doc(ownerDb, 'projects', P1, 'auditEntries', 'audit-2'), {
      id: 'audit-2', projectId: P1, action: 'delete', subject: 'Fiş #4471',
    }));
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
      batch.set(doc(memberDb, 'projects', pid, 'apartments', `apt-${n}`), {
        id: `apt-${n}`, projectId: pid, apartmentNumber: n, status: 'available',
      });
    }
    await assertSucceeds(batch.commit());
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
