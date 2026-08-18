// İnşaat Takip — Storage güvenlik kuralları testleri (madde 17)
//
// Emülatöre karşı çalışır. AYRI proje ad alanı (`demo-storage`): diğer iki
// takım kendi ad alanlarını temizliyor ve Node test dosyalarını paralel
// çalıştırıyor — paylaşılan ad alanı, kusursuz kodda kırmızı test demekti.
//
// Storage kuralları yetkiyi ÇAPRAZ SERVİS `firestore.get()` ile Firestore'dan
// okuyor; bu testler o köprünün de emülatörde gerçekten çalıştığını kanıtlıyor.

import { readFileSync } from 'node:fs';
import { after, before, describe, it } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import { ref as storageRef, uploadBytes, getBytes, deleteObject } from 'firebase/storage';

// EMÜLATÖR SINIRI — pahalıya öğrenildi: Storage emülatörünün çapraz servis
// `firestore.get()`'i, isteğin proje ad alanını DEĞİL, emülatör hub'ının
// --project bayrağını (varsayılan projeyi) kullanıyor. Bu takım farklı bir ad
// alanında koşarsa kurallar BAŞKA ad alanının Firestore'una bakar: sahip
// testleri geçer (o ad alanında da ownerUid aynı), üye testleri düşer.
// Bu yüzden: (1) bu takım hub projesinde koşar, (2) kendi belge kimliğini
// kullanır, (3) test dosyaları SIRALI çalışır (package.json
// --test-concurrency=1) ki functions takımının clearFirestore'u bu takımın
// zeminini silmesin.
const PROJECT_ID = 'demo-insaattakip';

const OWNER = 'uid-owner';
const MEMBER = 'uid-member';
const STRANGER = 'uid-stranger';
const P1 = 'storage-p1';   // functions takımının 'project-1'i ile çakışmasın

const JPEG = { contentType: 'image/jpeg' };
const smallImage = () => new Uint8Array([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

let testEnv, ownerStorage, memberStorage, strangerStorage;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
      host: '127.0.0.1', port: 8080,
    },
    storage: {
      rules: readFileSync('storage.rules', 'utf8'),
      host: '127.0.0.1', port: 9199,
    },
  });

  // Yetkinin kaynağı Firestore'daki proje belgesi — kurallar oraya bakıyor.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'projects', P1), {
      id: P1, ownerUid: OWNER, memberUids: [OWNER, MEMBER],
      blockNumber: '145', parcelNumber: '2', createdAt: new Date(),
    });
    // Okuma testleri için önceden yüklenmiş bir görsel.
    await uploadBytes(storageRef(ctx.storage(), `projects/${P1}/sitePhotos/seed.jpg`),
                      smallImage(), JPEG);
  });

  ownerStorage = testEnv.authenticatedContext(OWNER).storage();
  memberStorage = testEnv.authenticatedContext(MEMBER).storage();
  strangerStorage = testEnv.authenticatedContext(STRANGER).storage();

});

after(async () => { await testEnv?.cleanup(); });

describe('storage — okuma', () => {
  it('üye görseli indirir (çapraz servis firestore.get çalışıyor)', async () => {
    await assertSucceeds(getBytes(storageRef(memberStorage, `projects/${P1}/sitePhotos/seed.jpg`)));
  });

  it('ÜYE OLMAYAN indiremez', async () => {
    await assertFails(getBytes(storageRef(strangerStorage, `projects/${P1}/sitePhotos/seed.jpg`)));
  });
});

describe('storage — yazma', () => {
  it('sahip JPEG yükler', async () => {
    await assertSucceeds(uploadBytes(
      storageRef(ownerStorage, `projects/${P1}/receipts/r1.jpg`), smallImage(), JPEG));
  });

  it('ORTAK yükleyemez — salt okunur sözü Storage için de geçerli', async () => {
    await assertFails(uploadBytes(
      storageRef(memberStorage, `projects/${P1}/sitePhotos/x.jpg`), smallImage(), JPEG));
  });

  it('YABANCI yükleyemez', async () => {
    await assertFails(uploadBytes(
      storageRef(strangerStorage, `projects/${P1}/sitePhotos/x.jpg`), smallImage(), JPEG));
  });

  it('JPEG dışı tür reddedilir — uygulama yalnızca JPEG üretir', async () => {
    await assertFails(uploadBytes(
      storageRef(ownerStorage, `projects/${P1}/sitePhotos/x.png`),
      smallImage(), { contentType: 'image/png' }));
  });

  it('4 MB üstü reddedilir — 1200px JPEG bunun çok altında', async () => {
    await assertFails(uploadBytes(
      storageRef(ownerStorage, `projects/${P1}/sitePhotos/big.jpg`),
      new Uint8Array(4 * 1024 * 1024 + 1), JPEG));
  });

  it('bilinmeyen kova reddedilir — sessizce açılan yol olmasın', async () => {
    await assertFails(uploadBytes(
      storageRef(ownerStorage, `projects/${P1}/gizliDosyalar/x.jpg`), smallImage(), JPEG));
  });

  it('proje dışı kök yol reddedilir', async () => {
    await assertFails(uploadBytes(
      storageRef(ownerStorage, `serseri/x.jpg`), smallImage(), JPEG));
  });
});

describe('storage — silme', () => {
  it('sahip siler', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(storageRef(ctx.storage(), `projects/${P1}/apartmentPhotos/del.jpg`),
                        smallImage(), JPEG);
    });
    await assertSucceeds(deleteObject(storageRef(ownerStorage, `projects/${P1}/apartmentPhotos/del.jpg`)));
  });

  it('ortak silemez', async () => {
    await assertFails(deleteObject(storageRef(memberStorage, `projects/${P1}/sitePhotos/seed.jpg`)));
  });
});
