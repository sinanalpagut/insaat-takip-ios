# İnşaat Takip — Ürün ve Teknik Boşluk Analizi

> 9 boyutta paralel inceleme + tamlık eleştirmeni · **86 bulgu**
> Analiz tarihi: 11 Ağustos 2026 · Kod durumu: commit `92f1554`

| Ciddiyet | Adet |
|---|---|
| 🔴 Kritik | 16 |
| 🟠 Yüksek | 39 |
| 🟡 Orta | 28 |
| 🔵 Düşük | 3 |
| **Toplam** | **86** |

Efor: **S** = birkaç saat · **M** = 1-3 gün · **L** = 1 hafta+

---

## 📋 İlerleme

Bu listedeki her madde tamamlandıkça işaretlenir ve aynı commit'te push edilir.
**Hedef: listenin tamamı.** Sıradaki iş her zaman en üstteki işaretsiz maddedir.

### Faz 0 — Hızlı kazanımlar ✅ **tamamlandı**

- [x] 1. "Net" etiketini dürüstleştir (satış − malzeme olduğu görünsün)
- [x] 2. Rol değiştirmeyi DEBUG'a al (ortak kendini yönetici yapamasın)
- [x] 3. Satış iptali (yanlış girilen satış geri alınabilsin)
- [x] 4. Uygulama ikonundaki alfa kanalını kaldır (ITMS-90717)
- [x] 5. Türkçe büyük harf (YÖNETİCİ, AKTİF, FİŞ — i/İ sorunu)
- [x] 6. Klavye "Bitti" butonu + sheet'lere `.large` detent
- [x] 7. Çift sürükleme tutamacı + kritik stok görünürlüğü
- [x] 8. İnşaat ilerlemesi/aşaması düzenlenebilsin

### Faz 1 — Firebase'den ÖNCE (sonraya kalırsa veri göçü gerektirir)

- [x] 9. Kimlik ve üyelik modeli (userId/ownerId, davet kodu ↔ proje bağı, dashboard filtresi)
- [x] 10a. Tarihler → `Date`, `ActivityItem.section` hesaplanıyor
- [x] 10b. Kimlikler → `UUID` (Project / Material / Apartment)
- [x] 10c. Para → kuruş `Int64` (`Kurus` tipi) — Faz 2 şeması Double yazılmasın diye
      Firestore'dan ÖNCE yapıldı; sonradan yapmak kayıtlı dokümanların göçü olurdu.
      `Kurus` bilerek tam sayı literaline uymuyor: 173 demo sabitinin her biri
      derleme hatası verdi, yani iş listesini derleyici çıkardı. Bölme operatörü
      de yok — para/para bölmesinin oran ürettiği üç nokta sessiz tam sayı
      bölmesi olmak yerine derleme hatasına dönüştü.
- [x] 11. Gider defteri (işçilik, taşeron, arsa, harç, makine, yakıt)
- [x] 12. Tahsilat ve taksit defteri (ödeme geçmişi, vade, dekont)
- [x] 13. Silme / düzenleme / geçmiş tarihli kayıt + denetim izi
- [x] 14. Daire durum modeli (kat karşılığı, rezerve, iptal) + daire bilgisi düzenleme
      · İptal ayrı bir durum DEĞİL: daire `.available`'a döner (yeniden satılabilir),
        izi denetim defterinde alıcı/bedel/silinen tahsilat anlık görüntüsüyle kalır
- [x] 15. Repository katmanı (ProjectViewModel'i protokol arkasına al)
      · View'lar DEĞİŞMEDİ: ViewModel'in genel arayüzü senkron kaldı, kalıcılık
        iyimser güncelleme + arka plan yazma modeline geçti
      · DEBUG'da `verifySeam` her yazmadan sonra kaynak/ekran tutarlılığını denetler

### Faz 2 — Kilometre taşı: kalıcılık

- [x] 16. Firestore + Auth + güvenlik kuralları — **TAMAM (18 Ağu 2026)**: tüm alt maddeler (16a–16j) bitti ve uçtan uca kanıtlı
      · KARAR (13 Ağu 2026): Auth = **telefon + SMS kodu**. Şantiyedeki ortak
        e-posta hatırlamak zorunda kalmasın; davet akışıyla da doğal eşleşiyor.
        Gerektirdikleri: APNs kurulumu, SMS kotası sonrası ücret, test numaraları.
      - [x] 16a. Kimlik tipi göçü: kullanıcı kimliği `UUID` → `String` uid.
            `UUID` kalsaydı `request.auth.uid == ownerUid` karşılaştırması hiçbir
            zaman doğru olmaz ve tüm yetki modeli sessizce çökerdi.
      - [x] 16b. Modeller Firestore yoluna bağlandı (her belgede `projectId`) +
            madde 19'un yeni kılığı kapatıldı.
      - [x] 16c. Telefon + SMS girişi (commit `59f657d`). Repository ile aynı
            dikiş: protokol + sahte + gerçek uygulama. Simülatörde sahte servis,
            çünkü gerçek doğrulama APNs istiyor ve Firebase'in yedeği olan
            reCAPTCHA ekranının metni Google'ın kontrolünde, Türkçe değil.
      - [x] 16d. `users/{uid}` profili — isim kalıcılığı. Telefon doğrulaması
            numarayı kanıtlar ama isim VERMEZ; bir yere yazılmazsa dönen
            kullanıcı her açılışta "Adın ne?" ekranıyla karşılaşır. Bugün yerel
            önbellek tek kaynak; uzak kopya Firestore ile bağlanacak.
      - [x] 16e. `FirestoreProjectRepository` (commit `7e9ad0c`) — emülatörde
            uçtan uca kanıtlı: iki proje, her birinde 12 daire + 9 malzeme + 1
            ortak; `ownerUid` gerçek 28 karakterlik Firebase uid'i; her alt
            belgenin `projectId`'si yolla tutarlı; `Kurus` **integerValue**
            olarak yazılmış (Double değil — kuruş kararı diskte de tutuyor).
            Yeniden başlatmada veri Firestore'dan geri geldi, okuma yolu da
            çalışıyor. Uygulama `-backend firestore -emulator 127.0.0.1:8080`
            ile gerçek kurallara karşı çalıştırılabiliyor.
            · YOL AÇILIRKEN ÇIKAN KUSURLAR — hepsi simülatörde sahte servis
              kullanıldığı için gizliydi, yani "giriş akışı doğrulandı" demek
              yalnızca sahte yolu doğrulamıştı:
              1. Telefon girişi GERÇEK CİHAZDA ÇÖKÜYORDU. Üç eksik: Info.plist'te
                 geri çağrı URL şeması yok (`verifyPhoneNumber` nil unwrap ile
                 çöküyor, hata döndürmüyor); app delegate yok (Firebase sessiz
                 push denetimini test bayrağından ÖNCE yapıyor, atlanamıyor);
                 `FirebaseApp.configure()` `App.init()`teydi ve SwiftUI delegate'i
                 henüz kurmamışken swizzler bağlanamıyordu. Üçü de düzeltildi;
                 ayrıca `sendCode` şemayı önceden denetliyor — yanlış yapılandırma
                 çökme yerine Türkçe hata veriyor.
              2. GERÇEK KİMLİKLE HİÇ KİMSE PROJE KURAMIYORDU: `addProject`
                 sahipliği `User.admin.id`'ye sabitliyordu. Kural yazmayı
                 reddediyor (`ownerUid != request.auth.uid`) ve proje kuranın
                 listesinde görünmüyordu. Artık `user` alıyor.
              3. `apply()` iç kopyayı güncellemiyordu → DEBUG'daki `verifySeam`
                 her yazmada yanlış alarm veriyordu.
              4. `persist` hatayı yutuyordu; DEBUG'da ham hata basılıyor artık.
            · BİLİNEN SINIR: `refresh()` yerel durumu yüklenen kopyayla
              değiştiriyor; yazma uçuştayken çalışırsa iyimser güncelleme
              silinebilir. Pencere dar (`.task` yalnızca kimlik değişiminde)
              ama kapalı değil.
            · KISIT (16f testiyle sabitlendi): proje kurulumu İKİ AŞAMALI olmak
              zorunda — önce `projects/{pid}`, sonra alt belgeler tek parti.
              Alt koleksiyon yazması üst belgeyi `get()` ile doğruluyor ve kural
              değerlendirmesi aynı partideki işlenmemiş yazmaları GÖRMEZ.
              `addProject` bugün proje + ~20 daire + 9 malzemeyi tek partide
              veriyor. Kurulum dışındaki eylemlerde atomiklik sözü bozulmuyor.
            · KISIT: ortağın belge sorgusu `whereField("partnerVisible",
              isEqualTo: true)` biçiminde kurulmak zorunda. Kurallar süzgeç
              değildir; süzgeçsiz sorgu tek tek belgeleri saklamaz, sorgunun
              TAMAMINI reddeder ve ekran boş kalır.
      - [x] 16f. `firestore.rules` + bileşik indeksler (commit `47484ad`)
            · Yetki artık SUNUCUDA ve PROJE BAŞINA: kişi kendi projesinde
              yönetici, davet edildiği projede yalnızca okuyucu. İstemcinin
              global rolü artık sadece arayüz ipucu — yani madde 16'nın "bilinen
              sınır"ı güvenlik açısından kapandı, geriye arayüz tutarsızlığı
              kaldı (ortak görünümünde yazma düğmeleri hâlâ görünüyor, yazma
              sunucuda reddedilecek).
            · Hareket akışı ve denetim defteri EKLE-ONLY: sahip DAHİ geçmişi
              düzeltemez. Şeffaflık iddiasının dayanağı bu ve istemci bunu kendi
              başına sağlayamaz.
            · `partnerVisible: false` belge ortağın cihazına İNMEZ — madde 18'in
              "gizle ama indir" sızıntısı kapandı.
            · 96 test, Firestore emülatörü (`npm test`). Aynı kalıbı paylaşan
              sekiz alt koleksiyonun her biri ayrı denetleniyor; tekrarlanan
              kuralda tekrarlanan yazım hatası gözle farkedilmezdi.
            · Testlerin dişi İKİ MUTASYONLA doğrulandı: belge gizliliğini
              kaldırmak 3, proje okuma üyelik denetimini kaldırmak 3 testi
              düşürüyor. Geçen bir takım, yakalayabildiğini kanıtlamadan
              güvence sayılmaz.
            · BİLİNÇLİ SONUÇ: davet akışı istemciden ÇALIŞMAZ. Davet edilen kişi
              kendini `memberUids`'e ekleyemez (aksi halde herkes her projeye
              kendini ekleyebilirdi), projeyi okuyup kodu da doğrulayamaz.
              → `redeemInvite` Cloud Function şart (yeni madde 16g).
            · YAYINA ALINDI (17 Ağu 2026) — `npm run rules:deploy`. Doğrulama
              tahminle değil denemeyle yapıldı: production Firestore'a kimliksiz
              okuma isteği gönderildi, `projects` ve `users` ikisi de
              `403 PERMISSION_DENIED` döndü. Kapı kapalı.
              Geri dönüş yolu: Firebase konsolu kural geçmişini tutuyor
              (Firestore → Rules → eski sürüm).
      - [x] 16h. APNs kurulumu (17 Ağu 2026). Telefon doğrulaması uygulamanın
            gerçekliğini sessiz push ile kanıtlıyor; anahtar olmadan Firebase
            Google'ın Türkçe OLMAYAN reCAPTCHA ekranına düşüyor.
            · Xcode'da **Push Notifications** yeteneği eklendi →
              `InsaatTakip.entitlements` (`aps-environment = development`).
              Yetenek Xcode üzerinden eklendi, elle pbxproj düzenlemesiyle değil:
              Xcode aynı anda Apple portalındaki App ID'yi de güncelliyor,
              entitlements dosyası tek başına yeterli olmazdı.
            · APNs anahtarı: Key ID `WL72654D5U`, Team ID `36HVD2S94X`,
              kapsam **Sandbox & Production** + **Team Scoped (All Topics)**.
              Firebase'e development VE production satırlarına aynı dosya yüklendi.
              Apple bu kapsam ayarını kaydettikten sonra DEĞİŞTİRMİYOR; yalnızca
              Sandbox seçilse anahtar TestFlight'ta sessizce ölürdü.
            · Özel anahtar (`*.p8`) gitignore'da — kimlik bilgisi, repoya girmez.
            · HENÜZ GERÇEK CİHAZDA DENENMEDİ: simülatörde push hiç çalışmıyor,
              bu ayarın işe yaradığı yalnızca fiziksel telefonda görülür.
      - [x] 16g. `redeemInvite` Cloud Function — davet akışı UÇTAN UCA ÇALIŞIYOR.
            · DOĞRULAMA (18 Ağu 2026, simülatör + emülatör): yönetici proje kurdu
              → davet kodu üretti (`invites/M2TJEW` Firestore'a düştü) → çıkış →
              ikinci numarayla giriş → kod girildi → callable çalıştı. Sunucuda:
              kod harcandı ("Serkan Ortak" tarafından), proje 2 üyeli oldu, ortak
              kaydı ve "projeye katıldı" hareketi yazıldı. Ekranda: ortak davet
              edildiği projeyi görüyor (145 Ada, 12 daire, 9 kalem).
            · Ad SUNUCUDAN çözüldü (`users/{uid}`), istemci ad göndermedi.
            · BULUNAN VE DÜZELTİLEN KUSUR — `visibleProjects` role göre süzüyordu
              (`.admin` → yalnızca `ownerUid == uid`). Her yeni hesap `.admin`
              açıldığı için davet edilen ortak sunucuda üye oluyor ama ekranda
              HİÇBİR proje göremiyordu: katılma başarılı, sonuç boş ekran.
              Artık üyeliğe bakıyor — sunucunun uyguladığı model de bu
              (`memberUids arrayContains uid` + kural). Rol ne YAPABİLDİĞİNİ
              belirler, ne GÖRDÜĞÜNÜ değil.
            · Tanılama izleri bırakıldı (DEBUG): `[load]` uid + sonuç sayısı +
              önbellekten mi geldiği. Sorgu hata vermeden boş dönebiliyor ve bu
              sessizlik iki kez saatler kaybettirdi.
            · Blaze engeli KALKTI (17 Ağu 2026): plan yükseltildi, bütçe uyarısı
              25 TRY. Uyarı harcamayı KESMİYOR, yalnızca haber veriyor.
            · Sunucu (commit `a1a7a36`), 121/121 test: geçerli kod dört belgeyi
              tek transaction'da yazıyor; süresi dolmuş/kullanılmış kod
              reddediliyor; projesi silinmiş davet kodu HARCAMIYOR; zaten üye
              olan hata almıyor ve kodu yakmıyor; sahip kendi davetiyle ortak
              olmuyor. Ad SUNUCUDAN (`users/{uid}`) çözülüyor — istemciden ad
              alınsa kişi ortak tablosunda istediği adla görünürdü.
            · Bölge **europe-west1** (eur3 = europe-west1 + europe-west4;
              Frankfurt/west3 eur3'ün İÇİNDE DEĞİL — önceki notum yanlıştı).
            · `invites/{KOD}` okuma HERKESE kapalı, sahibe de: 6 hane / 31
              karakter alfabe, okunabilir olsa kodlar kaba kuvvetle denenirdi.
              Mutasyonla sınandı, açıldığında 3 test düşüyor.
            · İstemci (commit `efffbe9`): InviteService dikişi, davet üretme
              (iki belge tek parti), JoinWithCodeView callable'a bağlı, hata
              kodları Türkçeye çevriliyor. Derleme uyarısız.
            · SIRADAKİ İŞ: uçtan uca test. Yönetici kod üretir → ikinci numarayla
              girilir → kod kullanılır. Engel kalktı (bkz. commit `7f5a073`),
              yalnızca yapılmadı.
      - [x] 16i. **Bekleyen yazma kullanıcıya görünmeli** — YAPILDI, doğrulandı — bugün bulunan gerçek
            kusur, 16g ararken ortaya çıktı.
            · Firestore çevrimdışıyken yazmayı KUYRUĞA alıyor ve `commit()`
              yalnızca sunucu onayı gelince dönüyor. Dolayısıyla `persist`in
              catch bloğu çalışmıyor: kullanıcı "kaydedildi" görüyor, veri
              sunucuda yok. Şantiyede internetin gidip geldiği bir uygulamada
              bu, sessiz veri kaybı demek.
            · Bugün bunun bir yapılandırma hatasıyla (emülatöre TLS) tetiklendiği
              görüldü ve o düzeltildi — ama kusur DURUYOR: gerçek şebekede aynı
              durum yaşanır.
            · ÇÖZÜM: `ProjectViewModel.pendingWrites` sayacı + `PendingWritesBar`
              şeridi ("Bağlantı bekleniyor · N kayıt gönderilecek"). Toast DEĞİL:
              toast bir olay bildirir ve söner, bekleyen yazma bir DURUM ve
              kuyruk boşalana kadar durmalı. Kehribar ton — hata değil, veri
              kaybolmadı, yalnızca gönderilmedi.
            · 2 saniyelik gecikme: normal yazma milisaniyeler sürüyor, her
              kayıtta şerit çıksa gerçekten takıldığında farkedilmezdi.
            · `RootView`de TEK yerde bağlı; ekran ekran eklenseydi biri unutulur
              ve tam orada veri sessizce beklerdi.
            · `MemoryCacheSettings` kaldırıldı — kalıcı önbellek kuyruğu uygulama
              kapanınca koruyor. Doğrulandı: ölü porta bağlıyken kurulan proje
              yeniden açılışta yerel önbellekten geldi.
            · DOĞRULAMA: ölü porta (127.0.0.1:9999) yazma → şerit çıktı; çalışan
              emülatörde başarılı yazma → veri düştü (12 daire, 9 malzeme, 1
              ortak). Şerit, ÖNCEKİ takılı yazmayı doğru saydı ve çıkış/giriş
              arasında bile bıraktı — yani sayaç gerçek durumu izliyor.
            · YAN BULGU: Firebase oturumu KEYCHAIN'de ve uygulama silinse bile
              hayatta kalıyor; emülatörün kullanıcı veritabanı ise her yeniden
              başlatmada siliniyor. Sonuç: uygulama kendini giriş yapmış sanıyor,
              jeton yenilenemiyor, yazmalar sonsuza dek kuyrukta. Emülatörle
              çalışırken emülatör yeniden başlatıldıysa UYGULAMADAN ÇIKIŞ YAP.
            Kod doğrulama, süre/tek kullanım denetimi ve `memberUids` yazması
            yönetici adına işlevde yapılacak. 16f olmadan gerekliliği
            görünmüyordu; kurallar yazıldığı an zorunlu hale geldi.
      · Yol açılırken çıkan ve düzeltilen dört kusur — hepsi kimlik doğrulaması
        gelmeden ERİŞİLEMEZ olduğu için gizliydi:
        1. `AppState.init` parametre `auth`'u kullanıyordu, `self.auth`'u değil:
           varsayılan çağrıda oturum hiç geri yüklenmiyordu.
        2. Davet kodu kartı `!isAdmin` koşuluyla gösteriliyordu, ama her yeni
           hesap `.admin` açılıyor → davet edilen ortağın kodu girecek yeri yoktu.
           Faz 1/14'teki "ölü doğmuş özellik" hatasının aynısı. Kart artık rolden
           bağımsız; kendi projesinin yöneticisi başkasının projesine ortak olarak
           davet edilebilir zaten.
        3. Dashboard'un boş durumu yoktu. Kimlik doğrulaması bu hâli erişilebilir
           yaptı: artık her YENİ HESABIN gördüğü ilk ekran o.
        4. Hesap kartı ismi düzenlemeye izin vermiyordu, ama isim ekranı
           "sonradan değiştirebilirsin" diyordu. Telefon da hiçbir yerde
           görünmüyordu — oysa kimliğin kendisi o numara.
      - [x] 16j. **Proje bazlı rol** — eski "bilinen sınır" KAPANDI (18 Ağu 2026,
            commit `ddb6913`). Kişi kendi projesinde yönetici, davet edildiği
            projede ortak. `Project.role(for:)` tek kaynak; 18 dosyadaki view
            koşulları ve 16 ViewModel çağrısı buna bağlandı —
            `role: appState.currentUser?.role` kalıbı kodda SIFIR.
            · Neden bu sıra: 16g davet akışını çalışır hale getirdi, yani artık
              GERÇEK ortaklar var. Ortak yönetici düğmelerini görüyor, basıyor,
              yazma sunucuda reddediliyordu — güvenlik açığı değil (kural
              tutuyor) ama yalan bir arayüz.
            · Sunucu zaten bu modeli uyguluyordu (yazma `ownerUid`e, okuma
              `memberUids`e bağlı); istemcinin global rol kullanması iki modelin
              ayrışmasıydı.
            · Proje bulunamazsa en kısıtlı rol: bilinmeyen bir projede yazma
              yetkisi varsaymak yanlış tarafta hata yapmak olurdu.
            · Doğrulama (aynı proje, iki rol): `-role partner` → "İZLEYİCİ"
              rozeti, "Fiş Ekle" YOK; `-role admin` → "YÖNETİCİ", düğme var.
            · Yeni hesap hâlâ `.admin` açılıyor — bu artık bir sorun DEĞİL:
              global rol yalnızca "kendi projesini kurabilir" anlamına geliyor,
              başkasının projesindeki yetkiyi belirlemiyor.
            · 18. maddenin ÖN KOŞULUYDU: "ortak alıcı adını görmesin" ancak
              "bu projede kim ortak" cevaplanınca yazılabilir.
- [x] 17. Storage (fiş/daire/belge görselleri, `storagePath`) — **TAMAM (18 Ağu 2026), uçtan uca kanıtlı**
      · (1/3) `storage.rules` + 15 emülatör testi. Yetki FIRESTORE'UN AYNASI:
        kurallar çapraz servis `firestore.get()` ile `projects/{pid}` belgesine
        bakıyor. Yetki iki yerde tekrarlansaydı biri güncellenip diğeri
        unutulurdu. Yalnızca image/jpeg, 4 MB tavan, kova beyaz listesi,
        varsayılan RED.
      · (2/3) Şantiye + daire görselleri: `ImageStore` (DİSK önce, BULUT
        arkada), modellerde `storagePath`, yüklemeler bekleyen-yazma sayacına
        dahil. `uploadState` diye bir ALAN YOK — "yükleniyor" cihaza özgü bir
        durum, belgeye yazılsaydı iki cihaz birbirinin durumunu ezerdi.
        Yolun varlığı = buluttaki tek gerçek.
      · Uçtan uca kanıt (emülatör): yükle → nesne + `storagePath`; yeniden
        başlat → diskten; SİL+YENİDEN KUR → buluttan indi, diske aynı
        baytlarla yazıldı; görseli sil → Storage + Firestore temizlendi.
      · YAZILDIKTAN SONRA DENETİM (4 mercek, 21 iddia, 9'u doğrulandı) — hepsi
        kapatıldı. Üçü kritikti ve üçü de "yazdım, çalıştı" ile yakalanamazdı:
        - Alıcı kimliği Storage'dan sızıyordu: tahsilat dekontu gönderenin
          adını taşıyor, `receipts` kovası ortağa açıktı. 18. maddede
          kapatılan sızıntı buradan geri açılıyordu. Dekont ayrı
          `paymentReceipts` kovasına alındı, okuma yalnızca yöneticide.
        - Disk yazımı başarısız olursa fotoğraf kalıcı kayboluyordu; üstelik
          "sonra yeniden denenecek" deniyordu, oysa yeniden deneme diskteki
          dosyayı arıyordu ve o dosya hiç oluşmamıştı. Bellek yedeği eklendi.
        - Ortak daire görseli ekleyebiliyordu: sheet global rolü okuyordu
          (16j'den sonra her oturum `.admin`). Rol proje bazlısıyla değişti.
        - Uçuş kaydı yoktu (çift yükleme + şerit iki kat), silme sırasında
          uçuştaki yükleme yetim nesne bırakıyordu, açılışta bütün projelerin
          bütün görselleri sınırsız iniyordu (indirme artık ekrandaki hücreye
          bağlı).
      · (3/3) Fiş ve dekont görselleri. Üç kayıt türü (`materialLogs`,
        `payments`, `expenses`) tek `receiptImages` sözlüğünü paylaşıyordu ve
        piksel yalnızca RAM'deydi — "Fiş kaydedildi" deniyor, uygulama
        kapanınca fotoğraf uçuyordu.
        - KOVA AYRIMI gizliliğin ayağı: malzeme + gider fişi `receipts`
          (ortak OKUR — aynı harcamayı listede zaten görüyor), tahsilat
          dekontu `paymentReceipts` (YALNIZCA YÖNETİCİ — dekontun üstünde
          gönderenin adı ve çoğu kez IBAN'ı var, yani madde 18'in alıcı
          kimliği). Kova çözümü TEK YERDE: yanlış kova = yetki sızıntısı.
        - "Fişi kaldır" sessizce yutuluyordu: `UIImage?` ile nil hem
          "dokunmadım" hem "kaldırdım" demekti. Üç durumlu `ReceiptEdit`.
        - Göstergeler RAM'e bakıyordu; fiş bulutta dururken ikinci cihazda ve
          ortakta "fiş yok" görünüyordu. Kapı artık `receiptPath`.
        - Dört silme yolu (fiş, tahsilat, gider, SATIŞ İPTALİ) Storage'a hiç
          dokunmuyordu. Satış iptali en keskini: N dekont, belgeler
          silindikten sonra kimlikler geri gelmez.
        - Dekont hiçbir ekranda gösterilmiyordu; kalıcı olmayınca yalnızca
          eksiklikti, kalıcı olunca kişisel veriyi süresiz saklayıp
          karşılığını vermemek olurdu. Yöneticiye özel dekont küçük resmi ve
          dokunulabilir gider fişi eklendi.
      · ERTELENDİ → madde 23: BELGE baytları (PDF/DWG). Bugün `documents`
        yalnızca üst veri tutuyor; asıl engel dosya seçicide güvenlik
        kapsamlı URL'in seçim anında bırakılması — ayrı bir iş.
      · YAYINDA (18 Ağu 2026): kova `insaat-takip-e5683.firebasestorage.app`,
        konum **europe-west1** — Functions ile aynı bölge, veri AB'de kalıyor.
        Ücretsiz katman yalnızca ABD bölgelerini veriyordu; alıcı adı ve
        dekont KVKK kapsamında kişisel veri olduğu için ABD'de barındırmak
        "yurt dışına aktarım" olurdu, o yüzden ücretli Avrupa seçildi
        (1200px JPEG'lerle aylık maliyet kuruşlar mertebesinde).
        `storage.rules` yayınlandı ve bağımsız doğrulandı: kimliksiz istek
        dört yolda da 403 (paymentReceipts, receipts, sitePhotos, yazma).
- [x] 18. Gizliliğin sorgu düzeyinde uygulanması — **TAMAM (18 Ağu 2026), uçtan uca kanıtlı**
      · KARAR: ortak bir YATIRIMCI. Payını hesaplamak için daire durumunu,
        bedeli, tahsil edilen tutarı ve satış tarihini görmesi gerekiyor —
        bunlar açık kalıyor. ALICININ KİMLİĞİ gizleniyor: hiçbir yatırım
        amacına hizmet etmiyor ve o kişi müteahhidin ortaklarına görünmeye
        rıza vermedi. Şeffaflık iddiası zayıflamıyor; iddia PARA AKIŞI
        üzerine, alıcı listesi üzerine değil.
      · ŞEMA: `projects/{pid}/buyers/{apartmentId}` → { apartmentId, projectId,
        name }, yalnızca yöneticiye açık. Belge kimliği = daire kimliği, yani
        yönetici tek sorguyla tüm alıcıları çekip dairelerle eşleştiriyor.
      · NEDEN AYRI BELGE: kural ALAN GİZLEYEMEZ, belgeye izin verir ya da
        vermez. `buyerName` daire belgesinde kaldıkça ortağın CİHAZINA İNER;
        ekranda gizlemek sızıntıyı kapatmaz. (Belgelerdeki `partnerVisible`
        ile aynı ders.)
      · 8 test, mutasyonla sınandı: alıcı okumasını üyelere açınca tam 2 test
        düşüyor. Ortak daireyi HÂLÂ okuyabiliyor — gizlenen yalnızca kimlik.
      · KAPSAM DIŞI bırakıldı: serbest metin notları (`Payment.note`,
        `MaterialLog.note`) yapısal olarak korunamaz, kullanıcı ne yazarsa
        yazar. Bu bir politika/arayüz konusu, şema konusu değil.
      · İSTEMCİ TARAFI (commit ile): `Apartment.CodingKeys` buyerName'i dışarıda
        bırakıyor (malzeme toplamlarıyla aynı desen — bellekte bütün, kodlama
        sınırında ayrık); satış `.buyer` yazıyor, iptal ve kat karşılığına
        çevirme `.deleteBuyer` ile kimliği SİLİYOR (veri minimizasyonu);
        `load()` buyers'ı YALNIZCA sahibin projesinde çekiyor — ortak için
        sorguyu atmamak şart, kural reddedince tüm yükleme düşerdi.
      · SIZINTI TARAMASI: ad, hareket akışı metasından ve denetim defterinden
        de çıkarıldı (ikisi ortağa açık). Defter artık kimliği değil DEĞİŞİMİ
        söylüyor: "Alıcı kaydı: kayıtlı → kaldırıldı". Para izi eksiksiz.
      · UÇTAN UCA KANIT (emülatör): satış → daire belgesinde buyerName alanı
        YOK, ad yalnızca buyers'ta; yeniden başlatma → yönetici adı görüyor
        (birleştirme çalışıyor); iptal → buyers belgesi silindi; ortağın
        okuyabildiği hiçbir belgede ad geçmiyor. Gecikmiş iptal yazmasını
        16i'nin şeridi anında görünür kıldı — şerit ilk gerçek işini yaptı.
- [x] 19. Stok toplamlarında atomik güncelleme — **çözüm değişti, sorun kapandı**
      Maddenin önerdiği `FieldValue.increment`'in hedeflediği `accruedCost += ...`
      deseni Faz 1/13'te kalktı; toplamlar hareketlerden türetiliyor. Ama sorun
      kılık değiştirmişti: alanlar KALICI olduğu sürece her fiş işlemi tam
      dokümanı yazıyor, Firestore'da bu `setData` → son yazan kazanır. İki cihaz
      eşzamanlı fiş girince iki hareket de yaşıyor (doğruluk kaynağı sağlam) ama
      `materials/{id}.totalIn` birinde kalıyor ve sapma "Malzeme" ile "Net"e
      gidiyordu. Çözüm increment değil: türetilen alanları KODLAMAMAK
      (`Material.CodingKeys`). Yazılmayan alanın çakışacak bir şeyi yok.

#
---

## Sunucu tarafı — TAMAMI YAYINDA (18 Ağu 2026)

`firestore.rules`, `firestore.indexes`, `storage.rules` ve `redeemInvite`
Cloud Function'ı yayında ve bağımsız doğrulandı:

- Kimliksiz Storage isteği dört yolda da 403 (paymentReceipts, receipts,
  sitePhotos, ham yükleme).
- Kimliksiz `redeemInvite` çağrısı HTTP 401 + `signed-in-required` — bu
  bizim yazdığımız makine-okur hata anahtarı, yani istek işlevin İÇİNE girip
  kimlik kapısından döndü; genel bir ağ geçidi hatası değil.

`redeemInvite` ilk denemede Google Cloud'un derleme servis hesabı izni
yüzünden düşmüş ve geriye `FAILED` durumda (`CloudRunServiceNotFound`) bir
kayıt bırakmıştı; Firebase o kaydı güncelleyemiyordu. Çözüm: varsayılan
compute servis hesabına `Cloud Build Service Account` rolü + bozuk kaydı
silip yeniden oluşturmak. **Ders:** yeni Firebase projelerinde ilk işlev
deploy'u bu izin yüzünden düşebiliyor ve hata mesajı asıl sebebi
("update edilemiyor") ikinci bir kusur gibi gösteriyor.

Yayına çıkan sürüm bir KVKK düzeltmesi taşıyor: `displayName()` profilinde ad
olmayan kişinin TELEFON NUMARASINI `partners/{id}.name` alanına yazıyordu ve
o koleksiyon projenin tüm üyelerine açık — numara diğer ortakların cihazına
iniyordu. Artık "Yeni ortak".

---

## Gerçek cihaz turu — TUR A'nın kritik yolu GEÇTİ (18 Ağu 2026)

**Telefonla giriş gerçek altyapıda uçtan uca çalışıyor.** iPhone 13 Pro,
üretim Firebase (emülatör YOK): numara girildi → **gerçek SMS geldi** → kod →
isim → dashboard. Sunucu teyidi: `firebase auth:export` üretimde 1 gerçek
kullanıcı gösteriyor.

**APNs sessiz doğrulaması ÇALIŞTI.** "Kod Gönder"den sonra Safari/web sayfası
AÇILMADI — yani Firebase reCAPTCHA'ya düşmedi, sessiz push cihaza ulaştı ve
FirebaseAuth onu aldı. Yüklenen APNs anahtarı (`WL72654D5U`, Team `36HVD2S94X`,
Sandbox & Production) doğru yapılandırılmış. Bu madde simülatörde YAPISAL
olarak denenemiyordu.

Yol boyunca üç gerçek kusur çıktı ve üçü de düzeltildi:

1. **`UIBackgroundModes`'ta `remote-notification` yoktu** (`800d6b3`). iOS
   uyarıyor ve `content-available` bildirimlerini güvenilir teslim etmiyor —
   telefon doğrulaması tam olarak o sessiz push'a dayanıyor.
2. **Kimlik hataları okunamıyordu** (`800d6b3`). 17006 ekranda "Giriş
   yapılamadı" görünüyordu; kullanıcı "SMS gelmedi" sandı. `.providerDisabled`
   ve `.appVerificationFailed` ayrıldı; ikincisi APNs sınıfını topluyor.
3. **İsim ekranında çıkış yolu yoktu** (`d25eb94`). Doğrulama bitmiş ama profil
   yazılmamışsa uygulama her açılışta oraya dönüyor ve kullanıcı KİLİTLİ
   kalıyordu. Uygulamayı silmek kurtarmıyor: Firebase oturumu KEYCHAIN'de ve
   keychain silinmiyor. Turda birebir yaşandı — emülatörde açılan oturum,
   üretim yapılandırmasına geçilince geri geldi ve giriş akışına ulaşılamadı.

**Yöntem notu:** `identitytoolkit/v1/projects?key=…` uç noktası bu projede
`signIn` bloğunu BOŞ döndürüyor; sağlayıcı açıkken bile. Sağlayıcının durumunu
bu uç noktayla ölçmek YANILTICI — tek güvenilir sinyal uygulamanın aldığı hata
kodu.

**ÇÖZÜLDÜ — üretimde Storage yüklemesi çalışıyor.** Zincirin tamamı gerçek
cihazda, gerçek altyapıda kanıtlandı: kamera → küçültme → yükleme → kural
denetimi.

Ölçüm: iPhone 13 Pro ile çekilen fiş karesi Storage'a **271.749 bayt (265 KB)**
`image/jpeg` olarak indi. Ham 12 MP HEIC ~2-3 MB olduğuna göre küçültme yaklaşık
10 kat indirmiş ve kuralın 4 MB tavanının çok altında. Bu rakam bugüne dek
varsayımdı; gerçek karede ilk kez ölçüldü.

**Kök sebep ve çözüm.** Kimliği doğrulanmış, projenin SAHİBİ olan kullanıcı
403 alıyordu. Zamanlama yarışı değildi (`[load] proje=1 önbellekten=false`,
belge sunucuda), `contentType` ve boyut da doğruydu. Sebep `isOwner(pid)`
içindeki çapraz servis `firestore.get()`: **proje bu çağrıları çalıştıracak
şekilde yapılandırılmamıştı.** Firebase konsolu Storage → Rules ekranında bunu
kendisi söylüyor ("Your rules make use of cross-service database calls, but
your project is not configured to execute those calls") ve **"Fix issue"**
düğmesiyle çözüyor — eksik olan servis ajanını oluşturup rolü veriyor. IAM
ekranından elle verilemiyordu çünkü ajan henüz YARATILMAMIŞTI.

Düzeltmeden sonra yeni fotoğraf çekmek GEREKMEDİ: `hydrateImages` açılışta
"diskte dosya var, belgede yol yok" olan fişi bulup kendi yeniden yükledi —
madde 17'de yazılan telafi yolu gerçek koşulda çalıştı.

**Bunun anlamı: görsel yükleme yayında HİÇ çalışmıyordu.** Emülatör kuralları
sunucuda koşturuyor ama çapraz servis izinlerini taklit etmiyor; ne simülatör
ne emülatör bunu gösterebilirdi. İlk gerçek kullanıcı fiş çekmeye çalıştığı gün
ortaya çıkacaktı. Gerçek cihaz turunun tek başına kendini haklı çıkardığı bulgu.

**FİŞ OKUMA (OCR) GERÇEK KAREDE ÇALIŞTI.** Madde 24 cihaz üstü Vision ile
yazılmıştı ama yalnızca simülatöre yüklenmiş hazır görsellerle denenmişti.
Gerçek kamera karesinde tarih ve tutarı yakaladı ve tutarı forma KENDİSİ yazdı.
Cihaz üstü olduğu için internet, ücret ve dışarı veri çıkışı yok.

**Kalan Tur B maddeleri:** kesintili şantiye ağı + bekleyen-yazma şeridi,
dolu depolama dalı. (Kamera, gerçek foto boyutu ve OCR KAPANDI.) Emülatör kurulumu: `sh scripts/emulator-device.sh` + cihaz
derlemesine `-- -backend firestore -emulator <IP>:8080` (argümanlardan önce
`--` ayracı ŞART, yoksa devicectl bayrakları kendi bayrağı sanıyor).
iOS yerel ağ izni ilk denemede reddediyor ("Local network prohibited") —
bir denemeyi yakar, `NSLocalNetworkUsageDescription` eklenmeli.

---

## Gerçek cihaz turu — eski not (Tur A öncesi)

iPhone 13 Pro (`51B0D092-721A-5A8C-8C50-3A1D8275EB48`) bağlandı, cihaz
derlemesi imzalandı ve kuruldu. Tur A (gerçek Firebase, `-emulator` YOK)
başladı ve iki gerçek bulgu verdi — ikisi de simülatörde YAPISAL olarak
görünmüyor çünkü orada push hiç çalışmıyor:

1. **`UIBackgroundModes` içinde `remote-notification` yoktu** (düzeltildi,
   commit `800d6b3`). iOS açılışta uyarıyor ve `content-available`
   bildirimlerini güvenilir teslim etmiyor; Firebase telefon doğrulaması tam
   olarak o sessiz push'a dayanıyor.
2. **Kimlik hataları okunamıyordu** (düzeltildi). "Kod Gönder" 17006 alıyor
   ama ekranda "Giriş yapılamadı" yazıyordu; kullanıcı bunu "SMS gelmedi" diye
   okudu. Artık `.providerDisabled` ve `.appVerificationFailed` ayrı durumlar;
   ikincisi APNs sınıfını topluyor (17054, missingAppToken, appNotVerified,
   captchaCheckFailed, invalidAppCredential) — bu turun asıl aradığı hata
   sınıfı o ve eski hâliyle görünmez oluyordu.

**BEKLEYEN — telefonla giriş sağlayıcısı hâlâ KAPALI.** Konsolda açıldığı
söylendi ama sunucu hâlâ 17006 (`ERROR_OPERATION_NOT_ALLOWED`) döndürüyor ve
bağımsız sorgu bunu doğruluyor:

    GET https://identitytoolkit.googleapis.com/v1/projects?key=<API_KEY>
    → signIn: {}          # phoneNumber anahtarı HİÇ YOK

Yani kayıt sunucuya işlenmemiş (Save'e basılmamış olabilir ya da Identity
Platform tarafında ayrı bir adım gerekiyor). Doğru yer:
`console.firebase.google.com/project/insaat-takip-e5683/authentication/providers`
→ Sign-in method → Phone → Enable → **Save**. Aynı sorgu `phoneNumber` anahtarı
döndürdüğünde sağlayıcı gerçekten açıktır; uygulamayı denemeden önce bununla
teyit et.

Tur A'nın kalanı (SMS'in gelmesi, APNs sessiz doğrulamasının çalışıp
çalışmadığı, kod ekranı, isim, dashboard) HENÜZ DENENMEDİ.

Tur B (kamera, gerçek 12-48 MP HEIC küçültme ve bellek, kesintili şantiye ağı
+ bekleyen-yazma şeridi, dolu depolama dalı) hiç başlamadı; kurulumu hazır:
`sh scripts/emulator-device.sh` + cihaz derlemesine `-emulator <IP>:8080`.

Komutlar:

    xcodebuild -project InsaatTakip.xcodeproj -scheme InsaatTakip \
      -destination 'platform=iOS,id=51B0D092-721A-5A8C-8C50-3A1D8275EB48' build
    xcrun devicectl device install app --device 51B0D092-… <app>
    xcrun devicectl device process launch --device 51B0D092-… --console \
      --terminate-existing com.sinanalpagut.insaattakip

Cihaz KİLİTLİ olduğunda başlatma reddediliyor ("Locked") — kilidi açık tut.

---

## Gerçek cihaz turu — simülatörde KANITLANAMAYAN işler

Simülatör hızlı döngü için doğru araç: arayüz, iş mantığı ve sunucu kuralları
(kurallar zaten emülatörde, yani SUNUCUDA koşuyor — cihazın markası kuralı
değiştirmez) orada gerçekten sınanıyor. Ama simülatörün YAPISAL olarak
gösteremediği ve bugüne kadar HİÇ çalıştırılmamış kod yolları var. Bunlar
"muhtemelen çalışır" değil, "hiç denenmedi" kutusunda:

- **Telefon + SMS girişi (gerçek yol).** Simülatörde push HİÇ çalışmıyor; bu
  yüzden emülatör + `appVerificationDisabledForTesting` kullanılıyor. Yani
  APNs sessiz doğrulaması, reCAPTCHA'ya düşme dalı ve yüklenen APNs
  anahtarının (Key `WL72654D5U`) işe yarayıp yaramadığı BİLİNMİYOR. Gerçek
  kullanıcının gördüğü İLK ekran bu.
- **"Fotoğraf Çek" (kamera).** Simülatörde kamera yok; `CameraPicker` kod yolu
  bir kez bile koşmadı. Şantiyede en çok kullanılacak giriş bu olacak.
- **Gerçek fotoğraf boyutları.** Galeriye konan örnekler ~1-2 MP; iPhone 12-48
  MP HEIC üretiyor. Küçültme (madde 13) ve bellek davranışı gerçek karede
  ölçülmeli.
- **Şantiye ağı.** Kesintili/çok yavaş bağlantıda bekleyen-yazma şeridi,
  yeniden deneme ve uygulama arka plana alınınca yüklemenin askıya alınması.
  Simülatörde ağ her zaman mükemmel.
- **Depolama dolu.** Denetimde bulunan "disk yazılamazsa" dalı gerçek bir
  cihazda gerçek bir koşul.

Kurulum hazır: `sh scripts/emulator-device.sh` emülatörü yerel ağ arayüzünde
açıyor ve ekrana Mac'in IP'sini yazıyor; cihaz derlemesine `-emulator <IP>:8080`
verilince iPhone aynı emülatöre bağlanıyor (iPhone ve Mac aynı Wi-Fi'da olmalı).
Telefon girişinin GERÇEK yolunu denemek içinse emülatör değil, gerçek Firebase
projesi kullanılmalı — kurallar zaten yayında.

## Faz 3 — Ürün değeri

- [x] 20. Ortak cari hesabı (`sharePercent` ile pay hesabı) — **TAMAM (18 Ağu 2026)**
      · `sharePercent` ölü veriydi: hiçbir çarpımda geçmiyordu ve GİRİLEMİYORDU
        bile — kurucuya sabit %100, davetle katılana %0, değiştirecek ne ekran
        ne fonksiyon. Pay çarpımı yazılsaydı da her ortağın payı 0 ₺ çıkardı.
      · YÖNTEM: üç bağımsız tasarım (yeni koleksiyonsuz özet / iki defterli
        cari hesap / nakit odaklı), dokuz hakem (dürüstlük, gizlilik,
        gerçekçilik). İki defterli tasarımlar aynı yerde kırıldı: müteahhit
        sermaye ve çekim kayıtlarını girmezse defter BOŞ kalıyor ve ekran ya
        yanıltıcı bir sıfır ya da `openingCost` yüzünden yanıltıcı bir büyük
        eksi üretiyor. En küçük dürüst çözüm seçildi, hakem bulgularıyla
        sertleştirildi.
      · TEK SATIRLIK "PAYIN X ₺" YOK, bilerek: `netAmount` geliri TAHAKKUK
        esasıyla (satılan dairenin tam bedeli), gideri bugüne kadar girilenden
        alıyor. Maketten satışta para önce girer, maliyet sonra çıkar; yarısı
        bitmiş projede tek rakam madde 1'deki hatanın KİŞİSELLEŞMİŞ hâli
        olurdu. Onun yerine dört rakamın paya bölünmüş hâli + kapsam kutusu
        (kalan inşaat maliyeti, rezerve kaporası, vergi/finansman/tedarikçi
        vadesi, sermaye-çekim defterinin henüz olmadığı).
      · `Kurus.split`: paylar EN BÜYÜK KALAN yöntemiyle, toplamları tutara
        birebir eşit. Tek tek yuvarlansa %33/%33/%34'te toplam bozulur ve
        yönetici "toplamı tutmayan üç rakam" görürdü.
      · YAN BULGU 1 — denetim izi YANLIŞ KİŞİYİ yazıyordu: altı kayıt türünün
        "kim" alanı sabit `User.admin.name` idi, yani gerçek projede fişi kim
        girerse girsin denetimde demo adı görünüyordu. Şeffaflık iddiası "kim,
        ne zaman" cevabına dayanıyor; cevap yanlışsa iz kanıt değil süstür.
      · YAN BULGU 2 — `redeemInvite`, profilinde ad olmayan kişinin TELEFON
        NUMARASINI `partners/{id}.name` alanına yazıyordu ve o koleksiyon tüm
        üyelere açık: numara diğer ortakların cihazına iniyordu. Artık
        "Yeni ortak".
      · KALAN (madde 20b, istenirse): gerçek cari hesap — ortağın koyduğu
        sermaye ve çektiği para için ayrı defter. Bugün kapsam kutusunda
        "henüz tutulmuyor" diye AÇIKÇA yazılı.
- [ ] 21. Vade hatırlatıcı + gecikmiş tahsilat listesi
- [x] 22. Daire/alıcı arama ve filtreleme — **TAMAM (18 Ağu 2026)**
      · Arama: daire numarası, tip, alan, kat etiketi, durum metni.
      · ALICI ADIYLA ARAMA YALNIZCA YÖNETİCİDE. Ortakta `buyerName` zaten nil
        geliyor (madde 18), ama koşul kodda AÇIKÇA duruyor: alan bir gün
        ortağa da inse arama kutusu "bu isim bu projede var mı" sorusuna
        cevap veren bir KÂHİN olurdu — eşleşen tek bir daire, gizlenen
        kimliği ele verirdi.
      · Durum çipleri SÜZÜLMEMİŞ listeden sayıyor (çipe basmadan önce kaç
        daire olduğu görünsün); aynı çipe ikinci dokunuş süzgeci kaldırıyor.
- [ ] 23. Belgelerin gerçekten açılabilmesi/indirilmesi
- [x] 24. ~~Fiş OCR'ı~~ — **tamamlandı** (commit `92f1554`, cihaz üstü Vision)
- [x] 25. m² maliyeti ve malzeme fiyat geçmişi — **TAMAM (18 Ağu 2026)**
      · **Fiyat geçmişi.** Veri zaten kayıtlıydı (her giriş fişi kendi birim
        fiyatını donduruyor) ama hiçbir ekranda görünmüyordu. Yazmadan önce üç
        hata düzeltilmek zorundaydı: (1) `logs(for:)` SIRALAMIYORDU ve Firestore
        `getDocuments()` sırasız döndürüyor — grafik gerçek cihazda uydurma
        çıkardı, aynı düzeltme "Son Hareketler" listesini de doğrulttu;
        (2) çıkış fişleri seriye girmemeli, taşıdıkları fiyat o anki güncel
        fiyatın kopyası; (3) `Material.unitPrice` "güncel fiyat" diye
        gösteriliyordu ama SON GİRİLEN fiyattı ve fiş düzeltilince/silinince
        geri alınmıyordu — artık `recalculateMaterial` içinde en yeni giriş
        fişinden türetiliyor. Kapsam ekranda yazılı: devir tarihsiz olduğu için
        seri "kayıtlı giriş fişlerindeki fiyat". Swift Charts getirilmedi.
        Demo veriye gerçekçi zam serisi eklendi (Kas 2024 24,80 → Şub 2025
        28,50), yoksa özellik ekranda düz çizgi gösterip doğrulanamıyordu.
      · **m² maliyeti.** Paydası YOKTU: `Apartment.area` serbest METİNDİ ve
        `parseNumber("111,55 m²")` SESSİZCE 0 döndürüyordu. Alan
        `areaM2: Double?` oldu (optional, çünkü yeni projede alan girilmemiş ve
        0 ile "bilmiyorum" aynı şey değil), giriş kutusu ondalık klavyeye
        geçti, eski metin belgeleri için tek yönlü göç yazıldı.
        Payda TÜM daireler (kat karşılığını da müteahhit inşa etti), pay
        `totalCost` (yalnız malzeme olsa rakam gerçeğin altında kalırdı).
        ORTAK ALAN paydada yok ve bu rakamı YUKARI çekiyor — raporda yazılı.
        Rakam dönem çipinden bağımsız ("proje geneli") ve ortağa giden PDF'e
        giriyor.
      · **GÖÇ SESSİZCE ÇALIŞMIYORDU** ve yalnızca emülatörde eski biçimli
        belge okutarak yakalandı: `parseLegacyArea` süzgeci `isNumber`
        kullanıyordu, Swift'te `Character("²").isNumber` **TRUE** — birim ekinin
        kendisi ayrıştırmayı bozuyor, "111,55²" → nil. Yayındaki her eski alan
        sessizce kaybolacaktı. Süzgeç açıkça ASCII rakama çevrildi.
      · Ders: elle yazılan Firestore belgelerinde kimlikler BÜYÜK harf olmalı;
        Swift'in `UUID.uuidString`i büyük harf üretiyor.
- [ ] 26. CSV/JSON dışa aktarma + portföy özeti

### Faz 4 — Yayın paketi

- [ ] 27. KVKK aydınlatma + gizlilik politikası URL'i
- [ ] 28. Hesap silme akışı (App Store 5.1.1v)
- [ ] 29. Davet deep link'i (WhatsApp bağlantısı çalışsın)
- [ ] 30. `PrivacyInfo.xcprivacy` + Crashlytics + build numarası otomasyonu
- [ ] 31. Erişilebilirlik paketi (kontrast, 44pt hedefler, VoiceOver, Dynamic Type)

---

# İnşaat Takip — Öncelikli Yol Haritası

86 bulgu birleştirildiğinde geriye **5 kümede toplanan gerçek iş** kalıyor. Kilometre taşı olarak **Firebase / kalıcı veri** alınmış; her şey ona göre "öncesi" ve "sonrası" diye konumlandırıldı.

---

## Faz 0 — Bu hafta (küçük efor, yüksek etki)

Bunlar birkaç saatlik işler ama uygulamanın güvenilirliğini doğrudan etkiliyor.

**1. "Net" etiketini dürüstleştir.** `netAmount` = satış − malzeme. İşçilik, taşeron, arsa, harç yok. p1'de ekranda "Net 32,9 M ₺" yazıyor; gerçeğin 2-3 katı. Karonun adını **"Satış − Malzeme"** yap, rapora "işçilik/taşeron dahil değildir" notu ekle. Gerçek çözüm Faz 1'de, ama yanıltmayı bugün durdurabilirsin. *(çok küçük)*

**2. Rol değiştirmeyi DEBUG'a al.** `AccountSheet` → `switchRole` ile ortak kendini iki dokunuşta yönetici yapabiliyor; ViewModel'deki tüm `guard role == .admin` kontrolleri anlamsız. Release'te bu satırı gizle. *(çok küçük, ama ürünün tek güvenlik vaadi bu)*

**3. Satış iptali.** Yanlış daireye satış işlemek çok kolay (boş karta dokunmak yeterli) ve geri dönüş yok. `status = .available` + kaydı temizleyen tek bir aksiyon. *(küçük)*

**4. Uygulama ikonundaki alfa kanalı.** RGBA olduğu için App Store yüklemesi ITMS-90717 ile reddedilir. Tek komutluk düzeltme. *(çok küçük)*

**5. Türkçe büyük harf.** `.textCase(.uppercase)` yüzünden ekranlarda **YÖNETICI, AKTIF PROJELER, FIŞ / İRSALIYE** yazıyor. `smallCapsLabel` içinde `uppercased(with: Fmt.locale)` kullanmak tüm uygulamayı tek seferde düzeltir. Yanına boş bir `tr.lproj` eklersen kamera/galeri/paylaşım ekranları da Türkçeleşir. *(küçük)*

**6. Klavye ve sheet tıkanmaları.** Sayısal klavyede "Bitti" yok, sheet'lerde tek sabit detent var → iPhone SE'de AccountSheet'te "Oturumu Kapat" ekran dışında kalıyor. Klavye toolbar'ı + her sheet'e `.large` detent. *(küçük)*

**7. Görsel tutarsızlıklar.** 7 sheet'te çift sürükleme tutamacı (sistem + kendi kapsülü), kritik stok uyarısı normal renkle 1-3 RGB fark (yani görünmüyor → yanına "KRİTİK" çipi). *(küçük)*

**8. İlerleme güncellenebilsin.** `progress`/`phase` hiçbir ekrandan değiştirilemiyor; kullanıcının açtığı her proje sonsuza dek "%0 · Temel" görünüyor — kartın en büyük görsel öğesi. *(küçük)*

---

## Faz 1 — Firebase'den ÖNCE yapılması gerekenler

Bu maddeler sonraya kalırsa **veri göçü** gerektirir. Şimdi mekanik, sonra pahalı.

**9. Kimlik ve üyelik modeli.** Hiçbir modelde `userId`/`ownerId` yok; Partner ile User arasında bağ yok. Sonuç: davet kodu bir projeye bağlı değil (`validateJoinCode` 6 haneli her kodu kabul ediyor) ve Dashboard tüm projeleri filtresiz listeliyor — **145 Ada'ya davet ettiğin ortak, Kars bloklarının tüm alıcı adlarını ve ciroyu görüyor.** Bu düzeltilmeden Firestore güvenlik kuralı yazılamaz. *(büyük — ama tüm güvenlik hikâyesinin temeli)*

**10. Tip düzeltmeleri.** Tarihler String ("18 Şub 2026") → `Date`; para `Double` → `Int64` kuruş; `Material.id = "p1-Ø12"` gibi iş verisinden türeyen ASCII-dışı kimlikler → UUID. Ayrıca `ActivityItem.section` = "Bugün" kalıcı saklanıyor; yarın da "Bugün" der. *(orta, toplu)*

**11. Gider defteri.** `Expense` modeli: işçilik, taşeron hakedişi, arsa/kat karşılığı, ruhsat-harç-SGK, makine, yakıt. Akış birebir fiş girişiyle aynı olabilir. Bu olmadan kullanıcı paralel Excel tutmaya mecbur. *(orta)*

**12. Tahsilat ve taksit defteri.** Bugün `paidAmount` üzerine yazılıyor — yönetici eski toplamı akıldan toplamak zorunda, ödemenin tarihi/dekontu hiçbir yerde yok. Malzemede her hareket fişiyle kayıtlıyken **paranın geldiği tarafta tek kayıt yok**. `PaymentInstallment` + tahsilat geçmişi. *(orta)*

**13. Silme / düzenleme / geçmiş tarih + denetim izi.** Tüm uygulamada tek silme fonksiyonu `removeApartmentPhoto`. Yanlış girilen 125.000 kg demir kalıcı; fiş hep bugüne yazılıyor (akşam haftalık giriş imkânsız); geçmiş satış sessizce değiştirilebiliyor. Düzenleme + değişiklik kaydı (eski → yeni, kim, ne zaman) birlikte gelmeli — şeffaflık iddiası ancak böyle doğrulanabilir olur. *(orta)*

**14. Daire durum modeli.** Sadece `.sold`/`.available` var. **Kat karşılığı payı, rezerve, iptal** ifade edilemiyor → arsa sahibinin daireleri "Boş" görünüyor, satış oranı ve ciro sistematik yanlış. Ayrıca yeni projede daireler sabit listeden uyduruluyor ("2+1 / 95 m²") ve hiçbir yerden düzeltilemiyor — bu, 1. gün bırakma sebebi. *(orta)*

**15. Repository dikişi.** `ProjectViewModel` 992 satır, 10 global `@Published` dizi, init'te senkron mock, içinde `UIPasteboard` ve WhatsApp açma. Firebase gelince tüm mutasyonlar `async throws` olacak ve **22 view dosyası** etkilenecek. Protokol arkasına almak, geçişi tek seferlik ameliyat olmaktan çıkarır. *(büyük, ama Faz 2'yi ucuzlatır)*

---

## Faz 2 — Kilometre taşı: kalıcılık + Firebase

Kalıcılık olmadan App Store'da **Guideline 2.1 "demo sürüm"** reddi neredeyse kesin: hakem fiş girip uygulamayı kapatınca her şey kaybolacak. Bu fazın kapsamı: Firestore + Auth + güvenlik kuralları, Storage (fiş/daire/belge görselleri için `storagePath`, `uploadState` alanları bugün hiç yok), gizliliğin **sorgu düzeyinde** uygulanması (`partnerVisible: false` belgeler ortağın cihazına inmemeli), ve stok toplamlarının `FieldValue.increment` ile atomik güncellenmesi.

---

## Faz 3 — Firebase sonrası ürün değeri

Sırayla: **ortak cari hesabı** ("payıma ne düşüyor" — `sharePercent` bugün hiçbir çarpımda kullanılmıyor, ürünün asıl satış argümanı burada kırılıyor), vade hatırlatıcı ve gecikmiş tahsilat listesi, daire/alıcı **arama-filtre** (22 daire gözle taranıyor), belgelerin gerçekten açılabilmesi (bugün indirme butonu sadece toast gösteriyor), fiş **OCR**'ı (Vision, cihaz içi, ücretsiz — giriş süresi ~40 sn'den ~5 sn'ye), m² maliyeti, malzeme fiyat geçmişi (veri zaten kayıtlı, sadece görünmüyor), CSV/JSON dışa aktarma, portföy özeti.

---

## Faz 4 — Yayın paketi

KVKK aydınlatma + gizlilik politikası URL'i (zorunlu alan), hesap silme akışı (5.1.1v), davet deep link'i (bugün WhatsApp bağlantısı hiçbir yere gitmiyor), `PrivacyInfo.xcprivacy`, Crashlytics, build numarası otomasyonu, açılış ekranı rengi, erişilebilirlik paketi (kontrast, 44pt hedefler, VoiceOver etiketleri, Dynamic Type).

---

## Şimdi ne yapalım?

1. **Faz 0'ı tek oturumda bitirelim** (önerilen). 8 maddenin tamamı küçük; sonunda uygulama hem daha dürüst hem daha bitmiş görünür.
2. **Doğrudan Faz 1'in tip düzeltmelerine girelim** (madde 10) — Firebase'e en yakın yol, ama görünür bir kazanım yok.
3. **Önce gider defterini yazalım** (madde 11) — "Net" rakamını tek hamlede gerçeğe yaklaştırır; en büyük ürün açığı bu.

---

# Ek: Tüm Bulgular (boyuta göre)

## İçindekiler

- **İş Mantığı & Ürün Kapsamı** — 10 bulgu (2 kritik, 5 yüksek)
- **Ortak Deneyimi & Yetki Modeli** — 8 bulgu (3 kritik, 3 yüksek)
- **Kullanıcı Akışları** — 10 bulgu (2 kritik, 4 yüksek)
- **Veri Modeli & Mimari** — 10 bulgu (2 kritik, 5 yüksek)
- **Gözden Kaçanlar (tamlık eleştirmeni)** — 8 bulgu (2 kritik, 3 yüksek)
- **Yayına Hazırlık** — 10 bulgu (3 kritik, 3 yüksek)
- **Erişilebilirlik & Yerelleştirme** — 10 bulgu (0 kritik, 6 yüksek)
- **Tasarım Sadakati** — 8 bulgu (0 kritik, 4 yüksek)
- **Farklılaştırıcı Fikirler** — 12 bulgu (2 kritik, 6 yüksek)

---

## İş Mantığı & Ürün Kapsamı

### 1. Maliyet tarafı yalnızca malzemeden ibaret — "Net" rakamı ortakları sistematik olarak yanıltıyor

`🔴 Kritik` · `Efor: L` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ProjectDetailView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ReportView.swift`

ProjectViewModel.netAmount (satır 109-112) = totalSales − totalMaterialCost. Başka hiçbir gider kalemi yok: kod tabanının tamamında işçilik, taşeron, hakediş, makine/vinç kirası, arsa bedeli, ruhsat/harç, SGK, finansman/faiz için tek bir model, alan veya ekran bulunmuyor (grep ile doğrulandı, sıfır eşleşme). Bu rakam en görünür yerlerde duruyor: ProjectDetailView koyu başlığındaki "NET" karosu dört sekmede de görünüyor (satır 228), ReportView'da "Dönem net" olarak YEŞİL gösteriliyor (satır 125-126) ve PDF olarak ortaklara dağıtılıyor (satır 186-204). Somut ölçüm: p1 projesinde satış 42,65 M ₺, malzeme 9,79 M ₺ → ekranda "Net 32,9 M ₺" yazıyor; yani malzeme, cironun yalnızca %23'ü olarak modellenmiş. Gerçek bir betonarme konut projesinde malzeme toplam maliyetin ancak %35-45'idir; ortağa gösterilen kâr gerçeğin 2-3 katı. Dahası malzeme dışı gider GİRİLEMİYOR: addReceipt (satır 139) sadece MaterialLog üretir ve miktar × birim fiyat zorunludur; işçilik ödemesi gibi "miktarsız" bir gideri kaydetmek için müteahhit NewMaterialSheet'ten sahte bir malzeme kalemi uydurmak zorunda (addMaterial satır 213-216 birimi zorunlu kılıyor).

**Kullanıcı faydası:** Ortak, projenin gerçek kâr/zararını görür; müteahhit "32,9 M kâr var" diye sorgulanmaktan kurtulur. Uygulamanın var oluş sebebi olan finansal şeffaflık ancak gider tarafı tamamlanınca gerçek olur. Kısa vadeli düzeltme (küçük efor): karonun etiketini "Net" yerine "Satış − Malzeme" yapmak ve rapora "işçilik/taşeron dahil değildir" notu eklemek, yanıltmayı hemen durdurur.

### 2. Taksitli satışta ödeme planı, vade ve gecikme takibi yok

`🔴 Kritik` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Apartment.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/SaleFormSheet.swift`

Apartment modelinde (Models/Apartment.swift) para tarafına ait yalnızca üç alan var: price, paidAmount, paymentStatus. Tarih olarak sadece saleDateText (sözleşme tarihi) tutuluyor. Taksit adedi, taksit tutarı, ilk/son vade, sonraki ödeme tarihi, gecikmiş tutar kavramı hiç yok. PaymentStatus.taksitli yalnızca görsel bir çip; SaleFormSheet'te (satır 69-75) tek bir "TAHSİL EDİLEN (₺)" kutusu var. Mock veride bunun bedeli açıkça görülüyor: kars327'de 18 daire "Taksitli" durumunda ve ProjectViewModel satır 865-867'deki yorum gerçek TOKİ planını (%10 peşinat + bedel×%0,5 aylık taksit, 19-29 ay) tarif ediyor — ama bu plan modelde hiçbir yerde temsil edilmiyor, sadece hesaplanmış tek bir toplam sayı olarak paidAmount'a yazılmış. Kart üzerinde daire hakkında söylenebilen tek şey "Kalan 1,53 M ₺" (Apartment.collectionText).

**Kullanıcı faydası:** Müteahhit "bu ay kimden ne kadar tahsilat bekliyorum", "kim taksitini geciktirdi" sorularını uygulamadan cevaplayabilir; gecikmiş alıcı listesi ve nakit akışı öngörüsü çıkar. Şu an bu bilgi tamamen uygulamanın dışında, defterde/Excel'de kalıyor.

### 3. Tahsilat defteri yok: her yeni ödeme, önceki toplamın üzerine yazılıyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ApartmentDetailSheet.swift`

saveSale (ProjectViewModel satır 266) tahsilatı `apartment.paidAmount = payment == .tamamlandi ? price : min(price, parseNumber(paidText))` şeklinde ÜZERİNE YAZIYOR. Yani alıcı yeni bir taksit ödediğinde yönetici eski toplamı akılda tutup elle toplayarak yeni rakamı girmek zorunda; ödemenin tarihi, tutarı, yöntemi (nakit/havale/çek) hiçbir yerde kayıtlı değil. Bu, uygulamanın malzeme tarafıyla çarpıcı bir tutarsızlık: malzemede her hareket MaterialLog olarak, kim/ne zaman/hangi fişle bilgisiyle ve hatta fiş fotoğrafıyla saklanıyor (addReceipt satır 179-185), ama PARANIN geldiği tarafta tek bir kayıt bile yok. ApartmentDetailSheet'te (satır 56) daire hakkında gösterilen tek ödeme bilgisi "Ödeme durumu: Taksitli" satırı; ödeme geçmişi listesi yok. Ortak, başlıktaki "Tahsilat 28,12 M" rakamının arkasındaki hiçbir kaleme inemiyor.

**Kullanıcı faydası:** Her tahsilat tarih ve dekontuyla kayda geçer; ortak "bu para ne zaman, kimden geldi" diye tek tek görebilir. Ayrıca yöneticinin elle toplama yaparken yaptığı hatalar ve alıcıyla yaşanacak "ben ödemiştim" tartışmaları biter.

### 4. Ortağın hisse payına düşen tutar hiç hesaplanmıyor — sharePercent ölü veri

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Partner.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/PartnersTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

Partner.sharePercent tanımlı ama kod tabanında hiçbir para hesabında kullanılmıyor. Yalnızca iki yerde metin olarak basılıyor: PartnersTabView satır 86'da "%40" ve ProjectDetailView satır 251'de "4 ortak · hisse %100 tanımlı". sharePercent × net, × tahsilat veya × kalan alacak şeklinde tek bir çarpım yok. Ayrıca ortağın sermaye koyması (nakit katkı) ve kâr payı/avans çekmesi kavramları da yok — kimin projeye ne kadar para koyduğu, ne kadar çektiği, dolayısıyla ortaklar arası denge hiç takip edilmiyor. Uygulamanın iddiası "ortaklar arası finansal şeffaflık" ama ortağın soracağı ilk soru olan "benim payıma ne düşüyor" hiçbir ekranda cevaplanmıyor; ortağa gösterilen tek para rakamı projenin tamamına ait toplamlar.

**Kullanıcı faydası:** Ortak kendi kartında "%25 payına düşen: X ₺ kâr, Y ₺ kalan alacak, şu ana kadar koyduğun Z ₺, çektiğin T ₺" görür. Ortaklar arası hesaplaşma tartışması uygulamanın içinde, tek bir kaynaktan çözülür — ürünün asıl satış argümanı budur.

### 5. Tedarikçi / cari hesap yok; her alım peşin ödenmiş sayılıyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`

Tedarikçi diye bir varlık yok — sadece MaterialLog.note içinde serbest metin olarak geçiyor ("İrsaliye #4471 · Yılmaz Yapı"). Tedarikçi bazlı toplam alım, borç bakiyesi, ödendi/ödenmedi bayrağı, vade tarihi yok. ReceiptSheet'te tedarikçi için ayrı bir alan bile yok (satır 96, tek bir "Fiş / İrsaliye" metin kutusu). Daha önemlisi addReceipt (satır 164) girişi anında `material.accruedCost += amount * effectivePrice` yazıyor: yani malzeme şantiyeye girer girmez bedeli ÖDENMİŞ gider olarak kabul ediliyor. 90 gün vadeli alınan 1,4 M ₺'lik demirin borcu uygulamada hiçbir yerde görünmüyor; buna rağmen maliyet olarak nete düşülmüş oluyor. Böylece hem "kime ne kadar borçluyum" sorusu cevapsız kalıyor hem de nakit durumu ile gider tablosu birbirine karışıyor.

**Kullanıcı faydası:** Müteahhit tedarikçi bazında "toplam aldığım / ödediğim / kalan borcum" tablosunu görür, ödeme takvimini kaçırmaz. Ortak da nete bakıp "para var" sanmak yerine ödenmemiş borçları görür.

### 6. Geçmiş tarihli kayıt girilemiyor ve hiçbir kayıt düzeltilemiyor/silinemiyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/SaleFormSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`

İki ayrı somut kısıt: (1) addReceipt satır 181'de tarih sabit olarak `dateText: Fmt.shortDate()` — yani her fiş BUGÜNE yazılıyor. Şantiyeden akşam dönüp haftanın fişlerini girmek imkânsız; hepsi aynı güne düşer. Bu doğrudan raporu bozar, çünkü reportSummary (satır 513-518) ay/çeyrek malzeme giderini log tarihine göre hesaplıyor. Aynı şekilde saveSale bir `dateText` parametresi kabul ediyor (satır 249) ama SaleFormSheet onu hiç göndermiyor (satır 195-200) → yeni satışın tarihi de zorunlu olarak bugün; monthlySales grafiği ve dönem raporu geçmişe dönük satış girildiğinde yanlış aya yazar. (2) Uygulamadaki TEK silme fonksiyonu removeApartmentPhoto (satır 424); fiş, satış, ortak, belge için ne düzenleme ne silme var. Yanlış girilen 12.500 kg demir sonsuza dek stokta ve maliyette kalır; iptal edilen bir satış geri alınamaz (saveSale yalnızca status = .sold yapabiliyor, daireyi tekrar boşa çekmenin yolu yok).

**Kullanıcı faydası:** Sahada ilk hafta içinde mutlaka yaşanacak iki durum çözülür: geriye dönük kayıt girme ve yanlış girişi düzeltme. Bu olmadan veri birkaç hafta içinde güvenilmez hale gelir ve müteahhit uygulamayı bırakır.

### 7. Davet kodu bir projeye bağlanmıyor: katılan ortak BÜTÜN projelerin finansallarını görüyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Onboarding/JoinWithCodeView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/DashboardView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/InviteSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

JoinWithCodeView.submit() (satır 150-159) yalnızca appState.joinAsPartner() çağırıyor: ne bir Partner kaydı oluşuyor, ne katılınan proje belirleniyor, ne hisse yüzdesi atanıyor. validateJoinCode (satır 365-367) 6 haneli HER kodu kabul ediyor ve projenin gerçek inviteCode'uyla karşılaştırmıyor. Sonuç DashboardView satır 35'te görünüyor: `ForEach(viewModel.projects)` — hiçbir üyelik filtresi yok. Yani "145 Ada" projesine davet edilen ortak, Kars'taki iki TOKİ bloğunun ve diğer üç projenin ciro/net rakamlarını, alıcı adlarını ve belgelerini de görüyor. InviteSheet'te davet edilene hisse yüzdesi atanacak bir alan da yok (satır 74-79, sadece kod üretiyor). Mock veri de aynı varsayımı taşıyor: aynı 4 ortak, 5 projenin hepsine aynı hisselerle kopyalanmış (satır 914-919).

**Kullanıcı faydası:** Farklı ortak gruplarıyla birden fazla iş yapan bir müteahhit uygulamayı kullanabilir hale gelir. Şu haliyle bir ortağı davet etmek, ona diğer bütün işlerin finansallarını açmak demek — bu, uygulamanın gerçek sahada kullanılmasının önündeki en somut engel.

### 8. Tek yönetici, yetki devri ve ortak yönetimi yok

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/User.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/AppState.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/PartnersTabView.swift`

UserRole yalnızca admin/partner (Models/User.swift) ve rol KULLANICIYA bağlı, projeye değil: AppState.currentUser tek bir global rol taşıyor, ProjectDetailView isAdmin kontrolünü doğrudan appState.isAdmin üzerinden yapıyor (satır 53). Yani bir projede yönetici olan kişi otomatik olarak TÜM projelerde yöneticidir. Ayrıca User.admin ve User.partner iki sabit örnek (satır 31-32) — şantiye şefi veya muhasebeci gibi ikinci bir veri girici tanımlanamıyor. Ortak yönetimi tarafında da hiçbir işlem yok: ortağın hisse yüzdesini değiştirme, ortağı projeden çıkarma, yöneticiliği devretme, ortaklığı devretme yok (tek silme fonksiyonu removeApartmentPhoto). Yönetici telefonunu kaybederse veya hastalanırsa projeye veri girilemez hale gelir.

**Kullanıcı faydası:** Müteahhit, şantiye şefine malzeme girişi yetkisi, muhasebeciye sadece finans yetkisi verebilir; kendisi her fişi tek başına girmek zorunda kalmaz. Ortak yapısı değiştiğinde (pay devri, ortak ayrılması) uygulama gerçeği yansıtmaya devam eder.

### 9. KDV ve vergisel boyut tamamen yok — tutarların brüt mü net mi olduğu belirsiz

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Apartment.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ReportView.swift`

Kod tabanında KDV, stopaj, tapu harcı için tek bir alan yok. Ne Apartment.price, ne Material.unitPrice, ne de raporda vergi ayrımı var. Bu bir varsayım değil, veri de bunu doğruluyor: ProjectViewModel satır 826'daki yorum Kars daire bedelleri için açıkça "satış bedelleri (KDV hariç)" diyor, ama uygulama bu tutarı doğrudan totalSales'e, dolayısıyla ciroya ve nete yazıyor. Karşı tarafta malzeme birim fiyatlarının KDV dahil mi hariç mi olduğu hiçbir yerde belirtilmiyor (ReceiptSheet satır 70, sadece "BİRİM FİYAT (₺)"). Konut satışında %1/%10/%20 KDV, malzeme alımında %20 indirilecek KDV — bunların hiçbiri görünmüyor, dolayısıyla ne devreden/ödenecek KDV ne de vergi sonrası kâr hesaplanabiliyor. "Dönem net" rakamı vergi öncesi/sonrası ayrımı olmadan sunuluyor.

**Kullanıcı faydası:** Ortak, eline geçecek rakamın vergi sonrası ne olduğunu görür; müteahhit ödenecek KDV yükünü önceden takip eder. En azından fiyat alanlarının KDV dahil/hariç olduğunun işaretlenmesi (küçük efor) bugünkü belirsizliği kaldırır.

### 10. İnşaat ilerlemesi ve aşama hiçbir ekrandan güncellenemiyor; iş programı/termin yok

`🟡 Orta` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Project.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/DashboardView.swift`

Project.progress ve Project.phase alanları yalnızca nesne oluşturulurken atanıyor; kod tabanında bunları değiştiren TEK BİR satır yok (grep ile doğrulandı — atamalar sadece addProject satır 307 ve mock veri satır 616-626'da). addProject yeni projeyi `phase: .temel, progress: 0` ile açıyor, dolayısıyla kullanıcının oluşturduğu bir proje dashboard kartında sonsuza dek "%0 · Temel" olarak kalıyor — oysa bu, kartın en büyük görsel öğesi (DashboardView satır 208-219, ilerleme barı). Mock projelerdeki %68/%34/%96 değerleri de aynı şekilde donmuş durumda. Bunun ötesinde sektörel takvim kavramlarının hiçbiri yok: teslim tarihi, iş programı, imalat kalemleri, taşeron hakediş dönemleri, gecikme uyarısı. Project modelinde hiçbir tarih alanı bulunmuyor.

**Kullanıcı faydası:** Ortak, en çok merak ettiği "inşaat nerede, ne zaman biter" sorusunun cevabını güncel görür. Şu an bu alan yeni projelerde kalıcı olarak yanlış (%0) veri gösteriyor; en azından yöneticinin aşama ve yüzdeyi güncelleyebilmesi küçük bir eforla bu bozukluğu giderir.

---

## Ortak Deneyimi & Yetki Modeli

### 1. Davet kodu doğrulaması tamamen sahte — kod hiçbir projeyle eşleştirilmiyor

`🔴 Kritik` · `Efor: M` · `InsaatTakip/ViewModels/ProjectViewModel.swift`, `InsaatTakip/ViewModels/AppState.swift`, `InsaatTakip/Views/Onboarding/JoinWithCodeView.swift`, `InsaatTakip/Models/Project.swift`

validateJoinCode (ProjectViewModel.swift:365-367) yalnızca `InviteCode.sanitize(code).count == 6` kontrolü yapıyor; üretilmiş kodlarla HİÇBİR karşılaştırma yok. grep sonucu `inviteCode` alanı yalnızca 2 yerde okunuyor: InviteSheet.swift:25 (ekranda göstermek için) ve ProjectViewModel.swift:361 (yazmak için). Hiçbir yerde girilen kodla karşılaştırılmıyor. Zincirin tamamı projectId'yi düşürüyor: JoinWithCodeView.submit() (satır 150-159) `appState.joinAsPartner()` çağırıyor, parametre yok; AppState.joinAsPartner() (AppState.swift:29-33) sadece `currentUser = .partner` yapıyor. Yani 'ABCDEF' yazan herkes ortak olur ve aşağıdaki 2. bulgu nedeniyle TÜM projelerin finansallarına erişir. Uygulamanın tek erişim kapısı kilitsiz.

**Kullanıcı faydası:** Kod gerçekten üretildiği projeye bağlanınca, yönetici bir kodu WhatsApp'tan gönderdiğinde o kodun yalnızca o projeyi açtığını bilir. Şu anda müteahhit farkında olmadan tüm defterini rastgele kod deneyen birine açıyor; bu düzeltilmeden uygulama gerçek para verisiyle sahaya çıkamaz.

### 2. Ortak, davet edilmediği projeler dahil TÜM projeleri görüyor — proje bazlı üyelik kavramı yok

`🔴 Kritik` · `Efor: L` · `InsaatTakip/Views/Dashboard/DashboardView.swift`, `InsaatTakip/Models/Partner.swift`, `InsaatTakip/Models/User.swift`, `InsaatTakip/App/RootView.swift`

DashboardView.swift:35 `ForEach(viewModel.projects)` — rol veya üyelik filtresi yok; ortak 5 projenin de kartını Ciro rakamıyla birlikte görüyor ve NavigationLink(value: Route.project(id)) ile hepsinin detayına girebiliyor. RootView.swift:34'teki rota da membership kontrolü yapmıyor. Kök neden: User ile Partner arasında hiçbir bağ yok — User.swift'te projectId/membership alanı yok, Partner.swift'te userId yok. ProjectViewModel'de partners(for:) var ama 'bu kullanıcı bu projenin ortağı mı' sorusunu soran tek bir satır bile yok. Mock veri bu boşluğu maskeliyor: ProjectViewModel.swift:914-919 aynı 4 ortağı HER projeye ekliyor, dolayısıyla ekranda sorun görünmüyor. Somut sonuç: Kocaeli projesinin ortağı, Kars 327 blokundaki 22 dairenin alıcı adlarını, bedellerini ve tahsilat durumunu görüyor.

**Kullanıcı faydası:** Ortak yalnızca hissedar olduğu projeyi görürse, müteahhit birden fazla ada/parselde farklı ortak gruplarıyla çalışabilir — sektörün gerçek çalışma biçimi bu. Şu anki hâliyle müteahhit ikinci bir proje açtığı anda birinci projenin ortakları onu da görüyor; bu, uygulamayı tek projeli müteahhitler dışında kullanılamaz kılıyor.

### 3. Hesap kartındaki rol değiştirme, ortağın kendini yönetici yapmasına izin veriyor — tüm yetki kontrollerini geçersiz kılıyor

`🔴 Kritik` · `Efor: S` · `InsaatTakip/Views/Dashboard/AccountSheet.swift`, `InsaatTakip/ViewModels/AppState.swift`

AccountSheet.swift:57-61 'Yönetici görünümü' satırını koşulsuz render ediyor; ortak oturumdayken de görünür ve tıklanabilir. Tıklayınca AppState.switchRole(to:) (AppState.swift:36-40) hiçbir kontrol yapmadan `currentUser = .admin` yapıyor. Bu, ProjectViewModel'deki tüm `guard role == .admin` kontrollerini (addReceipt:142, saveSale:250, addProject:295, addDocument:396, addApartmentPhotos:413, removeApartmentPhoto:425, addSitePhotos:432, generateInviteCode:359) anlamsızlaştırıyor — çünkü rolü kullanıcının kendisi serbestçe seçebiliyor. İki dokunuşla ortak; fiş kaydedebilir, satış girebilir/düzenleyebilir, belge silinemese de yükleyebilir, gizli belgeleri görebilir (documents(for:role:) admin'e hepsini verir) ve yeni davet kodu üretebilir. LaunchConfig DEBUG korumalı ama bu ekran değil — release derlemesinde de var.

**Kullanıcı faydası:** Rol geçişi yalnızca DEBUG derlemesine alınır (veya gerçek oturumdan türetilirse), 'salt okunur ortak' rozeti gerçek bir güvence hâline gelir. Şu anda uygulamanın en temel iddiası — 'veri giren tek kişi yöneticidir' — herhangi bir ortak tarafından iki dokunuşla çürütülebiliyor, üstelik bunun iz kaydı da tutulmuyor.

### 4. '48 saat geçerli · tek kullanımlık' iddiası kodda hiç uygulanmıyor — sadece UI metni

`🟠 Yüksek` · `Efor: M` · `InsaatTakip/Models/Project.swift`, `InsaatTakip/ViewModels/ProjectViewModel.swift`, `InsaatTakip/Views/Project/Sheets/InviteSheet.swift`, `InsaatTakip/Views/Onboarding/JoinWithCodeView.swift`

Project.swift:23 `var inviteCode: String?` — tek bir String; oluşturma zamanı, son kullanma tarihi, kullanım sayacı, kime verildiği bilgisi yok. generateInviteCode (ProjectViewModel.swift:358-362) sadece `projects[index].inviteCode = InviteCode.generate()` yazıyor. Yani ne TTL ne de tek kullanım için gereken tek bir veri alanı bile mevcut değil. Buna karşın kullanıcıya iki ayrı yerde açıkça vaat ediliyor: InviteSheet.swift:93 '48 saat geçerli · tek ortak için' ve JoinWithCodeView.swift:90 'Kodlar 48 saat geçerlidir ve tek kişilik kullanım içindir.' Ayrıca 'Yeni Kod' butonu (InviteSheet.swift:33-37) eski kodun üzerine yazıyor ama kodlar zaten hiç doğrulanmadığı için 'iptal etme' kavramı da işlemiyor. Doğrulama düzeltilse bile (bulgu 1) bu alanlar olmadan TTL kurulamaz.

**Kullanıcı faydası:** Yönetici WhatsApp gruplarında dolaşan bir davet kodunun kendiliğinden ölmesine güvenebilir; bir kod bir kişiye bağlandığında ileten kişi ikinci bir kişiyi içeri alamaz. Şu anda paylaşılan kod — doğrulama düzeltilse dahi — sonsuza kadar ve sınırsız kişi tarafından kullanılabilir durumda kalır.

### 5. Ortak kendi hissesine düşen tutarı göremiyor — ürünün asıl satış vaadi tam burada kırılıyor

`🟠 Yüksek` · `Efor: M` · `InsaatTakip/Views/Project/PartnersTabView.swift`, `InsaatTakip/Models/Partner.swift`, `InsaatTakip/ViewModels/ProjectViewModel.swift`, `InsaatTakip/Views/Project/ProjectDetailView.swift`

`sharePercent` için grep sonucu yalnızca 6 satır: Partner.swift:11 (tanım), ProjectViewModel.swift:336 ve 917 (veri üretimi), PartnersTabView.swift:18 ve 86 (yüzde etiketi + toplam), ProjectDetailView.swift:250 (başlık toplamı). HİÇBİR yerde bir para tutarıyla çarpılmıyor. Ortak ProjectDetailView.swift:223-230'daki şeritte 'Net' rakamını, PartnersTabView.swift:86'da ise '%25'i görüyor ve ikisini kafadan çarpması gerekiyor. Dahası PartnerRowView (satır 63-96) 'sen' rozeti taşımıyor — ortak listede hangi satırın kendisi olduğunu ad eşleştirerek bulmak zorunda; giriş akışı zaten kimlik sormadığı için (WelcomeView/JoinWithCodeView'da ad alanı yok) bu bağ hiç kurulamıyor. Yatırılan sermaye, dağıtılan kâr, ortak bazlı cari hesap gibi kavramların hiçbiri modelde yok.

**Kullanıcı faydası:** Ortağın uygulamayı açma sebebi tek bir soru: 'bana ne düşüyor?'. Hisse yüzdesi × net üzerinden hesaplanan kişisel bir kart ve kendi satırının işaretlenmesi bu soruyu tek bakışta yanıtlar. Şu anki hâliyle ortak, ortaklar arası finansal şeffaflık için indirdiği uygulamada kendi payını hesap makinesiyle bulmak zorunda — vaadin merkezindeki değer teslim edilmiyor.

### 6. Ortak çıkarma / erişim iptali hiç yok — davet akışı ortağı listeye bile eklemiyor

`🟠 Yüksek` · `Efor: M` · `InsaatTakip/Views/Project/PartnersTabView.swift`, `InsaatTakip/ViewModels/ProjectViewModel.swift`, `InsaatTakip/Models/Partner.swift`

grep ile `addPartner` ve `removePartner` için sıfır sonuç. PartnersTabView.swift'teki satırlar tamamen salt görüntü: swipe-to-delete, bağlam menüsü veya düzenleme modu yok. ProjectViewModel'de `partners` dizisine yazan TEK yer addProject satır 333-336 (kurucuyu %100 hisseyle ekler) ve mock veri. Yani davet akışı sonuna kadar çalışsa bile katılan ortak `partners` listesine hiç eklenmiyor — Ortaklar sekmesi ile gerçek erişim birbirinden tamamen kopuk iki dünya. Hisse yüzdesi de değiştirilemiyor (Partner.sharePercent `var` ama hiçbir yazma yolu yok), oysa PartnersTabView.swift:25-27 toplam %100 değilse uyarı rengi gösteriyor — kullanıcıya düzeltemeyeceği bir hata bildiriliyor.

**Kullanıcı faydası:** Ortaklık ilişkisi biten, hissesini devreden veya anlaşmazlığa düşen bir kişinin erişimini kesmek inşaat ortaklıklarında sık ve acil bir ihtiyaç. Şu anda müteahhitin elinde tek bir kaldıraç bile yok; ayrıca hisse oranları sahada değiştiğinde uygulama kalıcı olarak yanlış veriyi gösterir ve ekranda kırmızı uyarı verip çözüm sunmaz.

### 7. Gizlilik kademesi yalnızca belgelerde var — finansal veride ve alıcı kimliğinde yok

`🟡 Orta` · `Efor: M` · `InsaatTakip/ViewModels/ProjectViewModel.swift`, `InsaatTakip/Views/Project/ProjectDetailView.swift`, `InsaatTakip/Views/Project/Sheets/ApartmentDetailSheet.swift`, `InsaatTakip/Views/Project/ReportView.swift`

Rol bazlı tek gerçek filtre documents(for:role:) (ProjectViewModel.swift:64-66): `role == .admin || $0.partnerVisible`. Bunun dışında hiçbir veri role göre süzülmüyor. ProjectDetailView.swift:223-230'daki Satış/Malzeme/Net şeridi role bakmadan çiziliyor; ApartmentsTabView ve ApartmentDetailSheet alıcı ADINI, bedelini ve ödeme durumunu ortağa açıyor (ProjectDetailView.swift:73-76 ortağın satılmış daire detayına girmesine izin veriyor). ReportView'da da rol kontrolü yok — ortak PDF'i indirip dışarı paylaşabiliyor. Alıcılar gerçek kişiler (Kars bloklarında 30+ isim); bir 'izleyici' ortağın tüm alıcı adı + tahsilat listesini görmesi KVKK veri minimizasyonu açısından savunulması zor ve yönetici bunu kısıtlayamıyor. Belgeler için düşünülmüş partnerVisible mantığı, çok daha hassas olan finansal ve kişisel veriye uygulanmamış.

**Kullanıcı faydası:** Yönetici 'ortaklar özet finansalları görsün ama alıcı adlarını görmesin' veya 'bu daire pazarlığı henüz kapanmadı, gizli kalsın' diyebilirse uygulamayı gerçek ortaklıklarda güvenle kullanır. Aynı zamanda daire alıcılarının kişisel verisi, sözleşme tarafı olmayan kişilere gereksiz yere açılmamış olur.

### 8. Ortağın haber alma yolu yok: push bildirim yok, akış proje bazlı değil, 'otomatik rapor' boş vaat

`🟡 Orta` · `Efor: L` · `InsaatTakip/Views/Dashboard/ActivityFeedView.swift`, `InsaatTakip/ViewModels/ProjectViewModel.swift`, `InsaatTakip/Views/Project/ReportView.swift`

grep ile `UNUserNotification` için sıfır sonuç — uygulama kapalıyken ortak hiçbir şeyden haberdar olmuyor; yeni satış işlendiğini görmek için uygulamayı kendisi açıp zile bakması gerekiyor. hasUnreadActivity (ProjectViewModel.swift:35) tek bir global Bool, kullanıcı bazlı değil: yönetici fişi kaydettiğinde kendi zilini de yakıyor (addReceipt:196, saveSale:284) ve ActivityFeedView.onAppear'da (satır 41) herkes için birden sıfırlanıyor. Akış filtresi yalnızca tür bazlı (ActivityFilter: Tümü/Malzeme/Satış) — proje filtresi yok, başlıkta 'Tüm projeler · son 7 gün' (ActivityFeedView.swift:57) yazıyor, yani 2. bulgudaki sızıntı burada da tekrarlanıyor. Ayrıca ReportView.swift:43 'Rapor tüm ortaklara otomatik olarak da gönderilebilir.' diyor ama buna karşılık gelen tek satır kod veya buton yok.

**Kullanıcı faydası:** Ortağın uygulamayı kendiliğinden hatırlaması için bir sebep olur: daire satıldığında telefonuna düşen bir bildirim, şeffaflık vaadini pasif bir arşivden canlı bir ilişkiye çevirir. Şu anda ortak haftalarca uygulamayı açmazsa hiçbir gelişmeden haberi olmaz ve ürün kullanılmaz hâle gelir; ekrandaki 'otomatik gönderilebilir' cümlesi de karşılığı olmadığı için güven zedeliyor.

---

## Kullanıcı Akışları

### 1. Kaydedilen fiş hiçbir şekilde silinemiyor/düzeltilemiyor — yanlış rakam finansalları kalıcı bozuyor

`🔴 Kritik` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/MaterialLogSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`

ProjectViewModel'de tek bir silme fonksiyonu var: removeApartmentPhoto (satır 424). Malzeme hareketi için ne silme ne düzenleme fonksiyonu var. addReceipt (satır 139-199) girişte `material.accruedCost += amount * effectivePrice` yapıyor ve bu değeri geri alan hiçbir kod yolu yok (grep: accruedCost yalnızca += ve mock init'te geçiyor). MaterialLogSheet'te (satır 69-79) hareketler düz bir ForEach ile listeleniyor; swipeActions/contextMenu/düzenleme yok, satır tıklanabilir bile değil. Sahada 12.500 yerine 125.000 kg yazan müteahhidin tek 'çaresi' telafi çıkışı girmek; ama çıkış accruedCost'u azaltmıyor (yalnızca totalOut'u artırıyor) ve zaten `guard material.currentStock >= amount` kontrolüne takılıyor. Yani proje kartındaki 'Malzeme', başlıktaki 'Net', dönem raporu ve ortaklara gönderilen PDF kalıcı olarak yanlış kalıyor.

**Kullanıcı faydası:** Uygulamanın tüm amacı ortaklar arası finansal şeffaflık; tek bir parmak hatasının rakamları sonsuza dek bozmaması gerekiyor. Hareket satırında 'Sil / Düzelt' (onaylı) verilirse yönetici hatasını 5 saniyede kapatır, ortağa yanlış rapor gitmez.

### 2. Satış geri alınamıyor — daire bir kez 'satıldı' olunca boşa dönmüyor

`🔴 Kritik` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/SaleFormSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ApartmentDetailSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ProjectDetailView.swift`

saveSale (ProjectViewModel:248-288) yalnızca `apartment.status = .sold` yazıyor; hiçbir yerde .available'a geri dönüş yok. Apartment.Status yalnızca sold/available (Apartment.swift:13-16). SaleFormSheet'te 'Satışı İptal Et' yok, ApartmentDetailSheet'te (satır 61-69) yöneticiye sadece 'Satış Kaydını Düzenle' butonu var. Hata çok kolay: ProjectDetailView:78-80'de yönetici BOŞ bir daire kartına dokunduğu anda doğrudan satış formu açılıyor — yanlış kareye dokunup Kaydet'e basmak yeterli. Üstelik fabTitle (satır 141-149) tüm daireler satıldığında 'Satış Ekle' FAB'ını gizliyor, yani yanlışlıkla son daireyi satmışsanız listeden düzeltmeye giden yol da daralıyor. Yanlış satış; ciro, tahsilat, kalan alacak, aylık satış grafiği ve hareket akışına anında yayılıyor (akış kaydı da silinemiyor).

**Kullanıcı faydası:** Vazgeçilen/iptal edilen satışlar inşaat sektöründe olağan. 'Satışı iptal et / daireyi boşa al' aksiyonu, yöneticinin yanlış daireye satış işlemesi veya alıcının cayması durumunda tabloyu gerçeğe döndürür.

### 3. Proje, ortak ve belge silme/düzenleme yolu hiç yok

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/DashboardView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/PartnersTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/DocumentsTabView.swift`

addProject (ProjectViewModel:292-340) yalnızca ekliyor; removeProject/updateProject yok. Dashboard'da proje kartında ne uzun basma ne kaydırma ne de menü var (DashboardView:35-40 — sadece NavigationLink). Yanlış ada/parselle açılan bir proje kalıcı olarak listede kalıyor ve beraberinde 9 malzeme kalemi + N daire + 1 ortak kaydı üretiyor. PartnersTabView tamamen salt okunur satırlardan ibaret: ortak çıkarma, hisse yüzdesi düzenleme yok — üstelik başlık '%X tanımlı' değeri 100 değilse uyarı rengiyle gösteriliyor (PartnersTabView:25-27) ama kullanıcıya bunu düzeltecek hiçbir kontrol verilmiyor. Belgelerde de addDocument var, silme/yeniden adlandırma/'ortaklar görebilsin' anahtarını sonradan değiştirme yok.

**Kullanıcı faydası:** Yönetici kendi kurduğu yapıyı yönetebilmeli: yanlış projeyi kaldırmak, ayrılan ortağı çıkarmak, hisse dağılımını %100'e tamamlamak. Aksi halde uygulama zamanla çöp kayıtlarla dolup ortaklara yanlış hisse tablosu gösteriyor.

### 4. 22 dairede arama/filtre/sıralama yok — bir alıcıyı bulmanın tek yolu gözle taramak

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ApartmentsTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/ActivityFeedView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/MaterialsTabView.swift`

Kod tabanında `searchable` hiç kullanılmıyor. ApartmentsTabView (satır 29-38) tüm daireleri filtresiz 2 kolonlu LazyVGrid'e basıyor; kart yüksekliği minHeight 142 (satır 115). kars327 projesinde 22 daire = 11 satır, yaklaşık 1.700pt kaydırma; NewProjectSheet 200 daireye kadar izin veriyor (satır 40). 'Kalan alacağı olanlar', 'Boş daireler', 'Kaporalı' gibi filtre veya alıcı adına göre arama yok — oysa müteahhidin en sık sorusu bu. ApartmentsTabView'daki tek özet kart sadece toplam/satılan/kalan sayısını veriyor, tıklanabilir değil. Aynı şekilde ActivityFeedView'da (satır 19-33) proje filtresi yok ('Tüm projeler · son 7 gün' yazıyor ama 5 proje karışık akıyor) ve satırlar tıklanamıyor — hareketten kayda gitmek imkânsız.

**Kullanıcı faydası:** 'Fatma Çelik'in kalan borcu ne kadar?' sorusu tek aramayla cevaplanır; 'kalan alacağı olan daireler' filtresiyle tahsilat takibi mümkün olur. Şu an kullanıcı 22 yeşil kartı tek tek okumak zorunda.

### 5. Sayısal klavyede 'Bitti' butonu yok, alanlar arası geçiş yok, sabit yükseklikli sheet'te Kaydet klavyenin altında kalıyor

`🟠 Yüksek` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/SaleFormSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/NewProjectSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/NewMaterialSheet.swift`

Tüm para/miktar alanları decimalPad veya numberPad kullanıyor (ReceiptSheet:261, SaleFormSheet:156, NewProjectSheet:78, NewMaterialSheet:93). Bu klavyelerde return tuşu YOKTUR. Kod tabanında `.toolbar(placement: .keyboard)`, `submitLabel`, `onSubmit` veya boşluğa dokunup kapatma jesti hiç yok; @FocusState yalnızca JoinWithCodeView'da (satır 14) kullanılmış. Yani kullanıcı miktar alanına dokunduktan sonra klavyeyi kapatmak için sayfayı sürüklemeyi denemek zorunda. Bunu ağırlaştıran şey: sheet'lerin hepsi tek ve sabit detent ile açılıyor — ReceiptSheet .fraction(0.82) (satır 156), SaleFormSheet 0.82 (satır 103), NewMaterialSheet 0.75, UploadSheet 0.85, NewProjectSheet 0.72 — hiçbirinde .large alternatifi yok. Klavye açıkken kalan yükseklikte 'Toplam tutar' satırı, fiş no alanı ve Kaydet butonu sıkışıyor. NewProjectSheet ayrıca sürükleme çubuğunu da gizliyor (satır 65).

**Kullanıcı faydası:** Sahada eldivenle, tek elle veri giren bir müteahhit için 'Bitti' ve 'İleri' tuşları ile detent'e .large eklemek, fiş girişini yarı yarıya hızlandırır ve 'butonu göremiyorum' tıkanmasını bitirir.

### 6. Belge akışı tam çıkmaz sokak: yüklenen dosya saklanmıyor, indirme butonu sadece toast gösteriyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/UploadSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/DocumentsTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

UploadSheet.handlePickedFile (satır 184-210) seçilen URL'den yalnızca dosya adını ve boyutunu okuyup URL'i atıyor; dosyanın kendisi hiçbir yere kopyalanmıyor. uploadProgress animasyonu tamamen sahte (satır 209). addDocument (ProjectViewModel:394-409) sadece meta veri kaydediyor. Karşılığında DocumentsTabView'daki indirme butonu `viewModel.flash("\(doc.name) indiriliyor")` çağırıp hiçbir şey yapmıyor (satır 105-107) ve belge satırının kendisi tıklanabilir değil — önizleme, paylaşma, açma yok. Yani ortak, 'Vaziyet Planı v3'ü görüyor ama asla açamıyor; 'ortak bilgilendirme' vaadinin en somut parçası boşa düşüyor. Fiş fotoğrafında tam ekran önizleme (MaterialLogSheet:88-110) varken belgelerde hiçbir görüntüleme yolu olmaması ayrıca tutarsız.

**Kullanıcı faydası:** Ortakların ruhsatı, kat planını, sözleşmeyi gerçekten açıp görebilmesi bu uygulamanın satış argümanı. Dosyayı uygulama klasörüne kopyalayıp QuickLook/ShareSheet ile açmak, 'indiriliyor' yalanını gerçek bir işleve çevirir.

### 7. Hiçbir yerde onay diyaloğu yok; yarım kalan form uyarısız çöpe gidiyor

`🟡 Orta` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ApartmentDetailSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`

Kod tabanında `.alert` ve `confirmationDialog` hiç kullanılmamış (grep sonucu boş). Var olan tek yıkıcı işlem — daire görselini silme — uzun basma contextMenu'sünün arkasında (ApartmentDetailSheet:180-189), görsel bir ipucu yok ve onay sormadan anında siliyor. Formlarda kirli-durum koruması da yok: ReceiptSheet/SaleFormSheet/UploadSheet'te miktarı, alıcı adını, dosyayı girdikten sonra sheet'i aşağı sürüklemek (presentationDragIndicator .visible ile açıkça davet ediliyor) her şeyi sessizce siler; interactiveDismissDisabled kullanılmıyor. Geri bildirim tarafında ise her başarı aynı 2,6 saniyelik gri toast (Components.swift:238-263) — hata mesajları ('Stok yetersiz', 'Miktar girilmedi') ile başarı mesajları görsel olarak birebir aynı stilde, yeşil tikle gösteriliyor.

**Kullanıcı faydası:** Silmeden önce onay, yarım formdan çıkarken 'vazgeç mi?' sorusu ve hata/başarı toast'larının ayrışması, kullanıcının işlemi doğru yaptığından emin olmasını sağlar; şu anda hata mesajı da yeşil tikle geliyor.

### 8. Fotoğraf akışında yükleniyor durumu yok, fotoğraflar büyütülemiyor ve silinemiyor

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/SitePhotosView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ApartmentDetailSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

SitePhotosView.importPickedPhotos (satır 194-212) ve ApartmentDetailSheet.importPickedPhotos (satır 212-230) 6 fotoğrafa kadar veriyi Task.detached içinde tek tek indirgiyor; bu sırada ekranda hiçbir gösterge yok — ProgressView kod tabanında hiç kullanılmamış. Kullanıcı galeriden 6 fotoğraf seçip döndüğünde ızgara birkaç saniye boş kalıyor, sonra birden toast çıkıyor; 'ekledi mi eklemedi mi' belirsiz, tekrar denemeye açık. Ayrıca şantiye fotoğrafı karesine dokunmak hiçbir şey yapmıyor (currentWeekTile/archiveTile salt görsel, satır 143-190) — fiş fotoğrafının tam ekran önizlemesi varken şantiye kaydında yok. Şantiye fotoğrafı silme fonksiyonu da yok (yalnızca removeApartmentPhoto var). ApartmentDetailSheet'teki 'Tümü (N)' bakır metni (satır 45-47) link gibi duruyor ama düz Text — tıklanmıyor, sahte affordance.

**Kullanıcı faydası:** Haftalık ilerlemeyi fotoğrafla belgeleyen bir yönetici için 'yükleniyor' göstergesi, kareye dokununca tam ekran açılması ve yanlış kareyi silebilmek temel beklenti; ortak da fotoğrafı büyütüp gerçekten inceleyebilir.

### 9. 'Kod ile katıl' akışı başarı mesajı veriyor ama hiçbir şey olmuyor — davet zinciri kopuk

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Onboarding/JoinWithCodeView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/InviteSheet.swift`

validateJoinCode (ProjectViewModel:365) 6 karakterli her kodu kabul ediyor ve JoinWithCodeView.submit (satır 150-159) 'Projeye katıldın · salt okunur erişim' toast'unu gösteriyor. Ancak hiçbir Project veya Partner kaydı eklenmiyor, girilen kod hiçbir projenin inviteCode'u ile karşılaştırılmıyor (generateInviteCode ile üretilen kodu tüketen tek satır kod yok). Zaten ortak olarak oturum açmış bir kullanıcı Dashboard'daki 'Kod ile projeye katıl' kartına (DashboardView:151-178) dokunup kod girdiğinde: yeşil onay toast'ı çıkıyor, sheet kapanıyor, proje listesi değişmiyor. Kullanıcı için bu tam bir çıkmaz sokak — hata da almıyor, sonuç da göremiyor. Ayrıca 'Yeni Kod' butonu (InviteSheet:33-37) eski kodu sessizce geçersizleştiriyor ama kullanıcıya bu söylenmiyor ve geri alınamıyor.

**Kullanıcı faydası:** Davet → katılma zinciri uygulamanın ortaklarla paylaşım vaadinin girişi. Kod eşleşmesi ve gerçek Partner kaydı eklenmesi (ya da en azından dürüst bir 'kod bulunamadı' hatası), ortağın kandırılmadığını hissettirir.

### 10. Boş durumlar tutarsız: yeni projede malzeme detayı ve filtrelenmiş hareket akışı bomboş açılıyor

`🔵 Düşük` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/MaterialLogSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/ActivityFeedView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/NewProjectSheet.swift`

DocumentsTabView (satır 68-89) ve SitePhotosView (satır 108-127) düzgün, yönlendirici boş durum kartlarına sahip. Ama aynı özen diğer ekranlarda yok: MaterialLogSheet'te yeni oluşturulmuş bir projenin malzemesine dokunulduğunda (addProject 9 kalemi sıfır stokla açıyor, hiç hareket yok) 'Son Hareketler' başlığının altı tamamen boş kalıyor (satır 63-79) ve kullanıcı 'Fiş Ekle'ye yönlendirilmiyor. ActivityFeedView'da (satır 19-33) bir filtre hiçbir sonuç döndürmezse — örneğin henüz satış yokken 'Satış' çipi — koyu başlığın altında bomboş bir sayfa kalıyor; 'kayıt yok' mesajı yok. NewProjectSheet'te daire sayısı yalnızca +/- stepper ile giriliyor (satır 40, aralık 1...200): 22 daireli bir blok için 10, 100 daireli için 88 kez dokunmak gerekiyor; doğrudan sayı yazma alanı veya basılı tutunca hızlanma yok.

**Kullanıcı faydası:** Boş ekran yerine 'Henüz hareket yok — ilk fişi ekle' yönlendirmesi, yeni projeye başlayan kullanıcıyı ilk değerli aksiyona taşır; daire sayısını yazarak girebilmek proje kurulumunu dakikalardan saniyelere indirir.

---

## Veri Modeli & Mimari

### 1. Kimlik ve üyelik modeli yok — Firebase güvenlik kuralları yazılamaz

`🔴 Kritik` · `Efor: L` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Project.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Partner.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/User.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/AppState.swift`

Hiçbir modelde kullanıcı kimliği yok: `grep -rn "ownerId|userId|uid" Models/ ViewModels/` sıfır sonuç veriyor. Project'te projeyi kimin kurduğu, Partner'da satırın hangi hesaba ait olduğu bilgisi yok — Partner yalnızca `name: String` + her açılışta yeniden üretilen `let id: UUID` taşıyor. `User.admin`/`User.partner` static let'leri de her süreçte yeni UUID üretiyor. MaterialLog'daki `user: String` de kimlik değil görünen ad; isim değişirse denetim izi kopar. Davet tarafı daha da boş: Project'te tek bir `inviteCode: String?` var, yorumu "48 saat geçerli, tek kullanımlık" diyor ama expiresAt/usedBy/usedAt alanı yok; `validateJoinCode` (satır 365) 6 karakterlik HER kodu kabul ediyor; AppState.switchRole ile kullanıcı hesap kartından kendini admin yapabiliyor. Tüm yetki kontrolü `guard role == .admin` ile istemcide. Firestore'a geçildiğinde bir güvenlik kuralı yazmak için gereken "bu uid bu projenin üyesi mi, rolü ne" bilgisi veri modelinde hiç yok.

**Kullanıcı faydası:** Ortakların verisi gerçekten korunur. Bugünkü modelle Firebase'e çıkılırsa, davet kodunu bilen (hatta uydurabilen) herkes projenin tüm finansal verisine yazma yetkisiyle erişebilir; müteahhit tarafında bu tek başına ürünü yayınlanamaz kılar.

### 2. Stok toplamları oku-değiştir-yaz ile güncelleniyor ve hareketlerden türetilemiyor

`🔴 Kritik` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

`addReceipt` (satır 154-174) malzemeyi kopyalayıp `material.totalIn += amount`, `material.accruedCost += amount * effectivePrice` yapıp geri yazıyor. Firestore'da bu desen klasik kayıp-güncelleme üretir: iki cihaz (ya da bir cihaz çevrimdışıyken) aynı eski değeri okur, ikisi de kendi toplamını yazar, biri sessizce yok olur. `FieldValue.increment` bu sorunu çözer ama mevcut kod buna uygun değil. Daha da kötüsü: toplamlar hareketlerden yeniden hesaplanamıyor. Mock veride p1 demir `totalIn = 48.000` ama kayıtlı giriş fişleri 12.500 + 14.000 = 26.500; yani `sum(logs) != totals` bilinçli olarak kabul edilmiş durumda. Açılış/devir kaydı (opening balance) olmadığı için sapma oluştuğunda onarım yapılamaz — hangi rakamın doğru olduğunu söyleyecek ikinci bir kaynak yok. Ayrıca `guard material.currentStock >= amount` kontrolü (satır 167) oku-kontrol-et-yaz olduğundan atomik değil.

**Kullanıcı faydası:** Müteahhidin stok ve maliyet rakamı güvenilir olur. Bugünkü tasarımla iki cihazdan girilen fişlerin biri sessizce kaybolur; kimse fark etmez ve toplamı gerçeğe geri çekmenin yolu da yoktur — ortaklara gösterilen 'şeffaf' finansal tablo yanlış olur.

### 3. Kimlikler değişken iş verisinden türetiliyor ve ASCII dışı karakter içeriyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Apartment.swift`

Material id'si `"\(projectId)-\(uniqueCode)"` (satır 228, 326, 648) → "p1-Ø12", "kars327-ÇMT", "p1-TĞL". Apartment id'si `"\(project.id)-\(n)"` (satır 315, 803) → daire numarasından türetiliyor. Üç ayrı sorun var. (1) Deterministik id: iki cihazda aynı anda "Seramik" malzemesi tanımlanırsa ikisi de `badgeCode` ile "SER" üretir, ikisi de `p1-SER` doküman kimliğini yazar — biri diğerini ezer. Yerel benzersizlik kontrolü (satır 220-226) yalnızca o cihazın belleğine bakıyor. (2) Unicode normalizasyonu: Swift'te String eşitliği kanonik denkliğe göre çalışır, yani `"Ç"` (U+00C7) ile ayrık gösterimi (C + U+0327) Swift'te EŞİTTİR; Firestore doküman kimliği ise bayt dizisidir ve bunlar FARKLI iki dokümandır. `badgeCode` girdiyi kullanıcı adından türettiği için (klavye/yapıştırma kaynaklı ayrık form mümkün) bellekte tek görünen malzeme sunucuda ikiye bölünebilir. (3) Kimlik değişken veriyi gömüyor: `Material.code` ve `Apartment.apartmentNumber` `var`; ileride düzenlenebilir hale gelirse ilgili MaterialLog ve ApartmentPhoto kayıtları öksüz kalır. Ayrıca Codable modellerde id tipi tutarsız: Project/Material/Apartment `String`, MaterialLog/Partner/ProjectDocument/ActivityItem `UUID` — Firestore `@DocumentID` yalnızca `String?` kabul ettiği için hepsinin tip değiştirmesi gerekecek.

**Kullanıcı faydası:** Malzeme kalemleri ve daireler ikiye bölünmeden, kayıt geçmişi kopmadan senkronize olur. Aksi halde kullanıcı listede iki tane 'Çimento' görür, birinde 40 torba diğerinde 60 torba yazar ve hangisinin doğru olduğunu anlayamaz.

### 4. Tarihler String olarak tutuluyor; göreli etiketler dondurulmuş ve createdAt yok

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/ActivityItem.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Apartment.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/ProjectDocument.swift`

Tüm tarihler "18 Şub 2026" biçiminde metin: `MaterialLog.dateText`, `Apartment.saleDateText`, `ProjectDocument.dateText`, `Partner.joinedText`, `SitePhoto.dateText`. Sonuçları: (a) Sıralama ve dönem filtresi için elle ayrıştırıcı yazılmış — `yearMonth` (satır 468) ve `lastUploadText` (satır 70) metni parçalayıp `monthNames` dizisinde arıyor; `yearMonth` günü tamamen atıyor, dolayısıyla ay içi sıralama imkânsız. (b) Firestore'da `where dateText >= ay başı` sorgusu yazılamaz; her dönem raporu tüm `materialLogs` koleksiyonunu indirip istemcide ayrıştırmayı gerektirir (satır 513) — okuma maliyeti ve mobil veri açısından doğrudan para kaybı. (c) Dil kilidi: format tr-TR ay kısaltmalarına bağlı; ileride İngilizce/Kürtçe/Arapça desteği veya CLDR'de bir kısaltma değişikliği tüm geçmiş veriyi ayrıştırılamaz hale getirir. (d) `ActivityItem.section` ("Bugün"/"Dün"/"Bu Hafta") ve `timeText` ("09:24"/"Sal") GÖRELİ değerler ama kalıcı olarak saklanıyor — bugün oluşan kayıt sunucudan yarın da "Bugün" başlığı altında geri gelir. Şu an her açılışta mock sıfırlandığı için görünmüyor; kalıcı katmanla ilk gün patlar. (e) Hiçbir modelde `createdAt`/`updatedAt` yok; sıralama `insert(at: 0)` dizi konumuna dayanıyor — sunucudan gelen veri için stabil bir sıralama anahtarı yok.

**Kullanıcı faydası:** Hareket akışı ve raporlar doğru tarih gösterir, dönem filtreleri gerçekten çalışır, rapor açmak yüzlerce gereksiz okuma yapmaz. `Date`'e geçiş maliyeti şimdi düşük (5 alan, 3 ayrıştırıcı fonksiyon); Firestore'a String tarihle çıkıldıktan sonra veri göçü gerektirir.

### 5. Para Double ile tutuluyor — kuruş bazlı tamsayıya geçilmeli

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Apartment.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Formatters.swift`

`price`, `paidAmount`, `unitPrice`, `accruedCost` hepsi Double. Tam liralık tutarlar 2^53'e kadar Double'da tam temsil edilir, o yüzden bugünkü mock veri sorunsuz görünüyor; risk ondalıklı birim fiyatlarda ve birikimde: `accruedCost += amount * effectivePrice` (satır 164) her fişte biriktiriliyor, birim fiyat 28,5 / 165,75 gibi değerlerse yüzlerce fiş sonrası sapma oluşur ve bu sapma kalıcı olarak veritabanına yazılır. Somut kullanıcı etkisi: `remainingAmount = max(0, price - paidAmount)` (Apartment.swift:41) sapma yüzünden 0,0000001 kalırsa kart "Kalan 0 ₺" gösterir ama `paymentStatus` hiçbir zaman `.tamamlandi`ye dönmez — daire sonsuza kadar "tahsil edilmedi" görünür. Ayrıca `Fmt.qty` sıfır ondalıkla yuvarladığı için kalem toplamlarının görünen değerleri ile rapor toplamı tutmayabilir. Firestore Double'ı IEEE-754 olarak saklar; web/Android istemcisi eklendiğinde aynı sapma platformlar arasına taşınır.

**Kullanıcı faydası:** Finansal şeffaflık iddiası olan bir uygulamada rakamlar kuruşu kuruşuna tutar; ortak 'benim hesabımla 3 lira tutmuyor' diyemez. Şimdi Int64 kuruşa geçmek mekanik bir değişiklik; veri Firebase'e yazıldıktan sonra göç gerektirir.

### 6. Görsel/dosya katmanı için hiçbir model alanı yok; üç ayrı geçici mekanizma kullanılıyor

`🟠 Yüksek` · `Efor: L` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/ActivityItem.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/ProjectDocument.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Project.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

Görseller üç farklı yerde ve üçü de kalıcılığa kapalı: `SitePhoto.image: UIImage?` ve `ApartmentPhoto.image: UIImage?` (bu iki struct Codable DEĞİL, dolayısıyla hiç serileştirilemez), `receiptImages: [UUID: UIImage]` ise modele hiç girmemiş, ViewModel'de yan tablo (satır 29). `ProjectDocument`'ta ise görselin/dosyanın kendisi hiç yok — sadece `name`, `sizeMB`, `fileType`; yani belge yükleme akışı gerçek bir dosya taşımıyor. Firebase Storage'a geçmek için her görsel modelinde `storagePath`, `downloadURL`, `localCachePath`, `uploadState` (kuyrukta/yükleniyor/başarısız) ve boyut/checksum alanları gerekiyor — hiçbiri yok. Bellek tarafı da tasarlanmamış: `SitePhoto.thumbnailSide = 1200`, 1200×1600 çözülmüş bir UIImage ≈ 7,7 MB; p1 için `photoCount: 48` — hepsi indirilirse ~370 MB. Şu an görseller `nil` yer tutucu olduğu için görünmüyor. Ayrıca `downsample` orijinali atıyor: fiş fotoğrafı (irsaliye) hukuki/mali bir belge, 1200px'e indirgenmiş kopyadan başka nüsha kalmıyor. `Project.photoCount` de elle bakılan bir sayaç: `addSitePhotos` onu güncellemiyor ve hiçbir view okumuyor — ölü, tutarsızlığa açık bir denormalize alan.

**Kullanıcı faydası:** Şantiyede çekilen fiş ve daire fotoğrafları gerçekten saklanır, geri yüklenir ve orijinal çözünürlükte arşivlenir; uygulama 300 MB görsel yüzünden sistem tarafından kapatılmaz. Bugün bu veriyi Firebase'e taşıyacak tek bir alan bile yok.

### 7. ProjectViewModel gerçekten God object — repository katmanı olmadan Firebase 22 view dosyasını kırar

`🟠 Yüksek` · `Efor: L` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

992 satır, 10 adet global `@Published` dizi (tüm projelerin malzemesi, hareketi, dairesi, ortağı, belgesi tek yerde) ve şu sorumlulukların hepsi: veri kaynağı (`init()` içinde senkron `loadMockData()`), filtreleme, finansal hesaplama, rapor mantığı, yetkilendirme, sayı ayrıştırma (`parseNumber`), toast zamanlayıcı, hatta UIKit yan etkileri — `UIPasteboard.general.string` (satır 370) ve `UIApplication.shared.open` ile WhatsApp açma (satır 388). Somut sonuçlar: (a) Test veya SwiftUI preview için VM'yi veri enjekte ederek kuracak hiçbir dikiş yok; init'te mock yükleniyor. (b) Herhangi bir dizideki tek bir değişiklik `objectWillChange` yayınlayıp EnvironmentObject'i gözleyen tüm ağacı geçersiz kılıyor; Firestore dinleyicileri sürekli güncelleme akıttığında bu her push'ta tam yeniden çizim demek. (c) Filtreler `body` içinden çağrılan doğrusal taramalar (`materials(for:)`, `totalMaterialCost(for:)`) — her çizimde tüm koleksiyon taranıyor. (d) `isLoading`/`error` diye bir kavram yok; tüm mutasyonlar senkron `Bool` dönüyor ve hemen toast gösteriyor. Firebase gelince bunların `async throws` olması, iyimser güncelleme + geri alma ve hata durumu gerekecek — `ProjectViewModel`'e dokunan 22 view dosyasının tamamı etkilenir. Önerilen bölünme: `Repository` protokolü (mock + Firestore uygulamaları), proje kapsamlı hafif store'lar, saf hesaplama fonksiyonlarının ayrı bir dosyaya taşınması.

**Kullanıcı faydası:** Firebase entegrasyonu tek seferde tüm ekranları riske atan bir ameliyat olmaktan çıkar, adım adım yapılabilir; ayrıca ekranlar büyük projelerde (yüzlerce hareket) takılmaz. Repository dikişi şimdi açılırsa mock veri de ikinci bir uygulama olarak yaşamaya devam eder.

### 8. Çevrimdışı çalışma kullanıcıya hiç görünmüyor — 'Fiş kaydedildi' yalan olabilir

`🟡 Orta` · `Efor: L` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`

Şantiyede bağlantı kopukluğu bu ürünün normal çalışma koşulu ama modelde ve arayüzde buna dair hiçbir kavram yok: bağlantı durumu, bekleyen yazma sayısı, 'senkronize edildi' işareti, çakışma bildirimi yok. `addReceipt` başarıyla döner dönmez `flash("Fiş kaydedildi")` diyor (satır 197). Firestore'un yerleşik çevrimdışı kalıcılığı yazmayı kuyruklar, ancak: (a) kullanıcı fişin gerçekten sunucuya gittiğini asla göremez; (b) fiş fotoğrafı Storage'a gider ve Storage yüklemeleri uygulama öldürüldüğünde otomatik devam etmez — kuyruğu kalıcı bir 'outbox' tablosu tutmadan basmanda çekilen fotoğraf sessizce kaybolur (bugün zaten sadece bellekte); (c) stok yetersizliği kontrolü (`currentStock >= amount`) çevrimdışı yerel önbellekteki eski değere bakar, dolayısıyla iki cihazın çevrimdışı girdiği çıkışlar toplamda eksi stok üretebilir ve kullanıcı bunu ancak günler sonra görür. Kalıcı bir bekleyen-işlem kuyruğu (outbox) ve modellerde `syncState` alanı gerekiyor.

**Kullanıcı faydası:** Müteahhit bodrum katta girdiği fişin kaybolmadığından emin olur, hangi kayıtların henüz gönderilmediğini görür. Bu olmadan kullanıcı uygulamaya güvenmeyi bırakır — kâğıt deftere geri döner.

### 9. Hiç test yok; rapor mantığı Date()/Calendar.current'a gömülü ve Gregoryen olmayan takvimde bozuluyor

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip.xcodeproj/project.pbxproj`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

`project.pbxproj` içinde tek bir `productType` var (`com.apple.product-type.application`) — test hedefi yok, tek bir birim testi yok. Test edilmesi en değerli kısım (finansal toplamlar ve dönem raporu) aynı zamanda en test edilemez halde: `reportSummary` ve `monthlySales` içinde 6 yerde doğrudan `Calendar.current.component(..., from: Date())` çağrılıyor (satır 71, 472, 479, 495, 529, 530) — zaman dondurulamadığı için 'çeyrek sınırında ne olur', 'yıl atlarken ne olur' senaryoları yazılamaz. Bu aynı zamanda gerçek bir hata: `Calendar.current` cihaz ayarını izler; kullanıcı Ayarlar'da takvimi Hicri veya Budist olarak seçmişse `component(.year)` 1448 veya 2569, `component(.month)` bambaşka bir sayı döner — ay/çeyrek raporu ve `yearMonth`'un varsayılan yılı tamamen yanlış çıkar. Doğrusu `Calendar(identifier: .gregorian)` ve dışarıdan enjekte edilen bir `now`. Ayrıca `yearMonth` `private static` olduğu için dışarıdan doğrulanamıyor; `parseNumber` ve `badgeCode` ise saf ve test edilmeye hazır ama test hedefi yok.

**Kullanıcı faydası:** Firebase geçişi sırasında finansal hesapların bozulmadığı kanıtlanabilir hale gelir — bugün 'rapor doğru mu' sorusunun tek cevabı elle bakmak. Ayrıca farklı takvim kullanan kullanıcılarda raporun sessizce yanlış çıkması engellenir.

### 10. Gizlilik filtresi istemcide — 'ortaklar görmesin' işaretli belgeler yine de ortağın cihazına iner

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/ProjectDocument.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/DocumentsTabView.swift`

`documents(for:role:)` (satır 64-66) gizliliği `role == .admin || $0.partnerVisible` ile istemcide uyguluyor. Firestore'da bu desen doğrudan sızıntıdır: ortak istemcisi tüm belge koleksiyonunu indirir, `partnerVisible: false` olan kayıt (mock veride "İskân Başvurusu · taslak") cihazın yerel önbelleğine yazılır ve sadece ekranda gizlenir. Güvenlik kuralları da bunu düzeltemez — kural sorguyu reddeder ve ekran boş kalır; sorgunun kendisinin `whereField("partnerVisible", isEqualTo: true)` biçiminde ROL'e göre farklı kurulması, bunun için de veri modelinde okunabilirlik alanının indekslenebilir ve kural tarafından doğrulanabilir olması gerekir. Aynı soru maliyet verisi için de cevapsız: `Material.accruedCost`, `unitPrice` ve `MaterialLog` tedarikçi bilgileri ortağa açık mı, hangi alan hangi role görünür — modelde bu ayrımı taşıyan hiçbir yapı yok, bugün her şey tek koleksiyonda ve rol ayrımı yalnızca görünüm katmanında.

**Kullanıcı faydası:** Müteahhidin 'ortaklar görmesin' dediği taslak ruhsat, sözleşme veya tedarikçi fiyatı gerçekten ortağın cihazına hiç inmez. Bu, ürünün temel vaadi (kontrollü şeffaflık) ile doğrudan çelişen sessiz bir sızıntıyı önler.

---

## Gözden Kaçanlar (tamlık eleştirmeni)

### 1. Kat karşılığı ve daire durumu modeli yok: sadece "Satıldı" veya "Boş"

`🔴 Kritik` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Apartment.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ApartmentsTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

`Apartment.Status` yalnızca `.sold` / `.available` içeriyor (InsaatTakip/Models/Apartment.swift). Türkiye'de kentsel projelerin çoğunluğu KAT KARŞILIĞI yapılıyor: dairelerin bir kısmı arsa sahibinin, bir kısmı müteahhidin. Ayrıca günlük iş akışında "rezerve/opsiyonlu" (kapora öncesi 3 gün tutulan daire), "iptal edilen satış", "şirket uhdesinde kalan", "takasla verilen daire" durumları var. Uygulamada bunların hiçbiri ifade edilemiyor. Sonuç: arsa sahibinin 8 dairesi "Boş" görünüyor; ApartmentsTabView'daki "Satış oranı %", "Kalan" sayısı ve `totalSales` sistematik olarak yanlış — ortak yanlış bir tabloya bakıyor. Rezerve edilmiş daire yönetici tarafından işaretlenemediği için müteahhit paralel bir not defteri tutmaya devam eder.

**Kullanıcı faydası:** Müteahhit kendi projesini olduğu gibi (kat karşılığı payı, rezerve, iptal dahil) modelleyebilir; satış oranı, ciro ve "satılabilir kalan stok" rakamları ilk kez gerçeği gösterir. Arsa sahibi de bir "paydaş" olarak sisteme girebilir.

### 2. Yeni proje kurulumu gerçek binaya uymuyor: daire tipleri, m² ve kat düzeni uydurma ve sonradan düzeltilemiyor

`🔴 Kritik` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/NewProjectSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/SaleFormSheet.swift`

`addProject` (ProjectViewModel.swift:290-340) daireleri sabit bir listeden döngüyle üretiyor: `[("2+1","95 m²"),("3+1","128 m²"),("3+1","132 m²"),("2+1","98 m²")]` ve kat dağılımını `daire/kat` varsayımıyla hesaplıyor. Kat numaraları 1'den başlıyor — bodrum ve zemin ifade edilemiyor (oysa kendi gerçek verinizde kars327'de -1. bodrum ve zemin var). NewProjectSheet yalnızca ada/parsel/ilçe/il/kat/daire sayısı soruyor. Ve hiçbir ekranda daire tipi, m², kat veya daire numarası düzenlenemiyor — SaleFormSheet sadece alıcı/bedel/tahsilat alıyor. Yani müteahhit kendi projesini oluşturduğu ilk dakikada 20 tane yanlış daire görüyor ("benim bloğumda 2+1 yok, hepsi 3+1 118 m²") ve bunu düzeltmenin hiçbir yolu yok. Bu, 6. ay değil 1. gün bırakma anı.

**Kullanıcı faydası:** Müteahhit projeyi ilk açtığında kendi bina şemasını (kat listesi, bodrum/zemin, daire numaraları, tip ve m²) girebilir veya sonradan düzeltebilir; ekrandaki daire kartları gerçek binayı temsil ettiği için ortaklara güvenle gösterilebilir.

### 3. Bir fiş = tek malzeme: çok kalemli irsaliye/fatura girilemiyor, günlük veri girişi emeği uygulamayı bıraktırır

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`

`addReceipt` tek bir `materialId` alıyor ve tek `MaterialLog` üretiyor (ProjectViewModel.swift:138-199); ReceiptSheet'te de tek malzeme çipi seçiliyor. Gerçek irsaliye/fatura çok kalemlidir (aynı #4471 irsaliyesinde çimento + kum + demir). Müteahhit aynı fişi 5 kez, aynı fiş numarasını 5 kez elle yazarak girmek zorunda; fiş fotoğrafı da her kayda ayrı ayrı iliştiriliyor. Ayrıca tedarikçi yapısal bir alan değil, `reference` serbest metninin içine gömülü ("İrsaliye #4471 · Yılmaz Yapı") — bu yüzden yazım farkı olan her satır ayrı tedarikçi sayılır. Son kaydı tekrarlama, taslak, toplu giriş veya haftalık toplu kayıt yok. Haftada 20-30 fiş giren bir müteahhit için bu, 6 ay sonunda "her akşam yarım saatimi alıyor" diyerek bırakma sebebidir.

**Kullanıcı faydası:** Tek bir fiş fotoğrafı ve tek fiş numarasıyla çok kalemli irsaliye kaydedilir; giriş süresi 5 kayıttan 1 kayda düşer, tedarikçi seçilebilir bir varlık olduğu için "kime ne kadar alım yaptım" raporu kendiliğinden doğar.

### 4. Denetim izi yok: yönetici geçmiş bir satışı sessizce değiştirebiliyor, ortak asla fark etmiyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/ActivityItem.swift`

`saveSale` yalnızca YENİ satışta akışa kayıt düşüyor (`if isNewSale`, ProjectViewModel.swift:270-285); mevcut bir kaydın bedeli 3,9 M'den 3,2 M'ye çekildiğinde veya tahsilat geri alındığında hiçbir iz kalmıyor — sadece toast. Tüm uygulamada `activities.insert` yalnızca iki yerde çağrılıyor: malzeme hareketi ve yeni satış. Belge yükleme, belge gizlilik anahtarının değiştirilmesi, yeni malzeme tanımlama, proje oluşturma, davet kodu üretme akışa hiç düşmüyor. Kayıtlarda `createdAt`/`updatedAt`/`değiştiren kişi` alanı da yok. Ürünün tek satış vaadi "ortaklar arası finansal şeffaflık" ise, doğrulanamayan bir rakam şeffaflık değildir: ortak sadece yöneticinin BUGÜN gösterdiği tabloyu görebilir, dünkü tabloyla karşılaştıramaz. Ortağın "geçen ay 42 milyon yazıyordu" dediği an ürün güvenilirliğini kaybeder.

**Kullanıcı faydası:** Her değişiklik (eski değer → yeni değer, kim, ne zaman) kalıcı bir kayıt olur; ortak istediği an geçmişi denetleyebilir, yönetici de "ben değiştirmedim" tartışmasını kanıtla bitirir. Şeffaflık vaadi ilk kez doğrulanabilir hale gelir.

### 5. Alıcı bir kayıt değil, sadece bir metin: iletişim, sözleşme ve anahtar teslim takibi yok

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Apartment.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ApartmentDetailSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/SaleFormSheet.swift`

Alıcı, `Apartment.buyerName: String?` olarak tutuluyor; telefon, TC/vergi no, sözleşme tarihi ile satış tarihi ayrımı, sözleşme belgesi bağlantısı yok. `deliveryNote` yalnızca proje oluşturulurken atanıyor ("Anahtar teslim bekliyor"/"Teslim edildi") ve hiçbir ekrandan güncellenemiyor — ApartmentDetailSheet'te salt okunur bir satır. Aynı alıcının iki daire alması hiçbir yerde ilişkilendirilmiyor (aynı isim iki ayrı metin). Sonuç: müteahhit alıcı telefonlarını, sözleşme nüshalarını ve teslim tutanaklarını hâlâ telefon rehberi + WhatsApp + klasörde tutuyor; teslim dönemi geldiğinde uygulama hiçbir işe yaramıyor. "Bu daireyi kime sattım, ne zaman anahtar verdim, tapusu çıktı mı" sorularının hiçbiri cevaplanamıyor.

**Kullanıcı faydası:** Alıcı tek bir kayıt olur: telefonu tek dokunuşla aranır, sözleşme ve tapu belgesi daireye bağlanır, teslim/anahtar durumu tarihiyle işaretlenir. Müteahhit satış dosyasını uygulamada tutmaya başlar; ikinci defter kalkar.

### 6. Blok / etap kavramı yok: bir ada-parselde birden çok blok olduğunda veri parçalanıyor

`🟡 Orta` · `Efor: L` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Project.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

`Project` doğrudan ada/parsel demek (`title` = "145 Ada / 2 Parsel") ve daireler tek düz liste. Oysa gerçek projeler ada/parsel altında A/B/C blok veya 1./2. etap olarak yürür — kendi gerçek verinizde bu sorun zaten görünüyor: kars309 (SF-1 Blok 1) ve kars327 (GB Blok 1) ayrı "proje" olarak, uydurma farklı ada/parsel numaralarıyla modellenmiş ve aynı TOKİ belgeleri (fiyat listesi, kura duyurusu, sözleşme bilgilendirmesi) her ikisine ayrı ayrı kopyalanmış (ProjectViewModel.swift:948-962). 5 bloklu bir müteahhit 5 ayrı proje açmak zorunda kalır: ruhsat ve mimari proje 5 kez yüklenir, ortaklar 5 kez davet edilir, daire numaraları çakışır ve "bu parselin toplam durumu" hiçbir ekranda görünmez.

**Kullanıcı faydası:** Müteahhit tek bir ada/parsel altında bloklarını/etaplarını tanımlar; belge ve ortaklar bir kez girilir, hem blok bazında hem parsel genelinde konsolide finans görülebilir. Malzeme çıkışları blok bazında ayrıştığı için blok maliyeti karşılaştırılabilir hale gelir.

### 7. Ortak ↔ yönetici iletişimi tek yönlü: kayıt bazında soru, açıklama ve mutabakat onayı yok

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/PartnersTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ReportView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/ActivityItem.swift`

Ortak tarafı tamamen pasif bir vitrin: hiçbir ekranda not, yorum, soru veya "onaylıyorum/itiraz ediyorum" mekanizması yok; yöneticinin bir harcamayı açıklayabileceği ("bu ay beton fiyatı neden 2 kat arttı") serbest not alanı da yok — sadece `MaterialLog.note` tek satırlık teknik not. Dönem raporunda ortağın "gördüm/mutabıkım" işareti yok, yönetici raporun okunup okunmadığını bilmiyor. Pratikte her rakam yine WhatsApp'ta konuşulur; uygulama tartışmanın kaydını tutmaz. Bu, ürünün bırakılma anını iki taraftan getirir: ortak "zaten sorularımı buradan soramıyorum" der, yönetici "aynı şeyleri hâlâ telefonda anlatıyorum, bu uygulama bana ne kazandırdı" der.

**Kullanıcı faydası:** Ortak, ilgilendiği kaydın altına sorusunu bırakır; yönetici kaydın yanına açıklamasını yazar; dönem raporu ortak onayıyla kapanır. Tartışma ve mutabakat tek yerde kayıtlı olur — uygulama WhatsApp'ın yerini alır, ona ek olmaktan çıkar.

### 8. Boş dairenin liste fiyatı tutulamıyor: "elimde kalan stok ne eder, projeyi bitirmeye ne lazım" sorusu cevapsız

`🟡 Orta` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/SaleFormSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ApartmentsTabView.swift`

Yeni oluşturulan dairelerin `price` değeri 0 ve fiyat yalnızca satış anında yazılıyor (`saveSale`); boş daireye liste/hedef fiyat girecek bir alan veya ekran yok. Sadece elle girilmiş TOKİ verisinde boş dairelerin fiyatı var ve SaleFormSheet bunu ön dolum için kullanıyor (`prefillListPrice`) — yani veri modeli buna hazır ama ürün akışı yok. Bunun sonucu: uygulama tamamen GEÇMİŞE bakıyor. Müteahhidin her gün sorduğu iki soru — "kalan 8 dairemin değeri ne, bu projeden ne kalacak" ve "kalan imalatı bitirmek için ne kadar nakit lazım" — hiçbir ekranda cevaplanmıyor. Rapor ekranı da yalnızca gerçekleşen dönemleri özetliyor, ileriye dönük tek bir rakam yok.

**Kullanıcı faydası:** Yönetici boş dairelere liste fiyatı girer; dashboard "satılan ciro + kalan stok değeri = proje beklenen hasılatı" gösterir. Ortak da payına düşecek tahmini tutarı görebilir; uygulama geçmişi raporlayan bir defterden karar aldıran bir araca dönüşür.

---

## Yayına Hazırlık

### 1. Uygulama ikonunda alfa kanalı var — yükleme daha ilk adımda reddedilir

`🔴 Kritik` · `Efor: S` · `InsaatTakip/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png`, `InsaatTakip/Assets.xcassets/AppIcon.appiconset/Contents.json`

AppIcon1024.png dosyasını PNG başlığından çözümledim: 1024x1024, 8-bit, colortype 6 (RGBA). Alfa değerleri tamamen opak (min 255 / max 255) ama kanalın kendisi dosyada duruyor. App Store Connect doğrulaması bunu ITMS-90717 ("Invalid App Store Icon ... can't be transparent nor contain an alpha channel") ile reddeder; actool alfa kanalını kendiliğinden düzleştirmez. Yani şu anki hâliyle arşiv oluşturup yüklemeye çalıştığında TestFlight'a bile ulaşamaz. Çözüm tek satırlık: `sips -s format png --setProperty hasAlpha false` benzeri bir düzleştirme ya da ikonu opak zeminle yeniden dışa aktarmak. Not: Contents.json'daki tek "universal / 1024x1024" girdisi Xcode 14+ için yeterlidir, ayrı 60/76/120/180 px varyantları üretmeye gerek yok — oraya vakit harcama.

**Kullanıcı faydası:** Yükleme sırasında saatler kaybettiren, sebebi anlaşılmayan bir doğrulama hatasına takılmadan ilk build'i TestFlight'a gönderebilirsin.

### 2. Kimlik doğrulama hiç yok: tek dokunuşla yönetici olunuyor, ortak da kendini yöneticiye yükseltebiliyor

`🔴 Kritik` · `Efor: L` · `InsaatTakip/ViewModels/AppState.swift`, `InsaatTakip/Views/Onboarding/WelcomeView.swift`, `InsaatTakip/Views/Dashboard/AccountSheet.swift`, `InsaatTakip/ViewModels/ProjectViewModel.swift`

Üç ayrı yerde kapı açık duruyor. (1) WelcomeView.swift:32 → AppState.signInAsAdmin() hiçbir doğrulama yapmadan currentUser'ı .admin yapıyor; uygulamayı indiren herkes yönetici. (2) ProjectViewModel.swift:365 `validateJoinCode` yalnızca `InviteCode.sanitize(code).count == 6` kontrolü yapıyor — üretilen gerçek kodla karşılaştırma yok, süre/tek kullanım kontrolü yok. "AAAAAA" yazan herkes projeye ortak olarak girip tüm satış fiyatlarını, alıcı adlarını ve ciroyu görüyor. Oysa ekranda "Kodlar 48 saat geçerlidir ve tek kişilik kullanım içindir" yazıyor — bu vaat kodda hiç karşılanmıyor. (3) AccountSheet.swift:95 → salt okunur girmiş bir ortak, hesap kartından "Yönetici görünümü"ne tıklayıp yazma yetkisi kazanıyor; switchRole hiçbir yetki kontrolü yapmıyor. Yani ürünün tek güvenlik vaadi olan "ortaklar sadece görüntüler" kuralı UI'da bir düğmeyle çiğneniyor. App Review açısından bu 5.1.1 ve 1.6 (veri güvenliği) kapsamında sorulur; ürün açısından ise finansal şeffaflık uygulamasının temel iddiasını çürütür.

**Kullanıcı faydası:** Müteahhit, ortaklarının verisini yanlışlıkla değiştiremeyeceğinden ve davet kodunu bilmeyenin projeyi göremeyeceğinden emin olur — uygulamaya para/ciro verisi girmeye cesaret edebilir.

### 3. Her açılışta mock veriye dönmek App Review'da "demo sürüm" (2.1 / 4.2) reddi demek

`🔴 Kritik` · `Efor: L` · `InsaatTakip/ViewModels/ProjectViewModel.swift`, `README.md`

Kalıcılık eksikliğini biliyorsun; burada raporladığım şey App Store sonucu. Hakem (reviewer) uygulamayı açtığında karşısına kendisinin oluşturmadığı, hazır dolu "TOKİ Kars Karacaören 309/327" projeleri çıkacak; bir fiş girip uygulamayı kapatıp açtığında girdiği her şey kaybolacak. Bu davranış Guideline 2.1'de açıkça sayılan "demo, trial veya test sürümü gibi görünen uygulama" tanımına ve 4.2 (minimum işlevsellik) maddesine denk düşer — özellikle ilk sürüm gönderiminde en sık verilen retlerden biridir. İkinci bir risk: ProjectViewModel.loadMockData içindeki veri TOKİ'nin gerçek proje/blok adlarını ve gerçek fiyat listesini kullanıyor (alıcı adları kurgu olarak işaretlenmiş, o iyi). Hakem "TOKİ" markasını görüp 5.2.1 kapsamında yetki belgesi isteyebilir. Gönderim öncesi asgari çözüm: en azından JSON/SwiftData ile cihaz üstü kalıcılık + ilk açılışta boş durum (kullanıcı kendi projesini oluştursun), demo veri ise yalnızca DEBUG'ta veya "örnek proje yükle" düğmesiyle gelsin.

**Kullanıcı faydası:** Kullanıcı girdiği fişi ve satışı ertesi gün de görür; uygulama gerçek bir araç gibi davranır ve gönderim ilk turda takılmaz.

### 4. Gizlilik politikası, KVKK aydınlatma metni ve kullanıcı sözleşmesi yok

`🟠 Yüksek` · `Efor: M` · `Config/Info.plist`, `InsaatTakip/Models/Apartment.swift`, `InsaatTakip/Views/Dashboard/AccountSheet.swift`

Tüm kod tabanında "gizlilik", "KVKK", "privacy", "terms" geçen tek bir metin, ekran veya bağlantı yok — yalnızca alakasız "sözleşme" (satış sözleşmesi) eşleşmeleri var. Gizlilik politikası URL'i App Store Connect'te zorunlu alandır; olmadan gönderim formu tamamlanmaz. Uygulama Apartment.buyerName (alıcı adı), satış bedeli, tahsilat ve sözleşme tarihi tutuyor; bu KVKK kapsamında kişisel veri + finansal veridir ve veri sorumlusu sensin. Gereken üç ayrı şey var: (a) yayınlanmış bir gizlilik politikası URL'i, (b) Türkçe KVKK aydınlatma metni ve — ortakların verisi işlendiği için — açık rıza/aydınlatma akışı, (c) sorumluluk reddi içeren bir kullanıcı sözleşmesi (uygulamadaki rakamlar resmî muhasebe kaydı değildir). Ayrıca App Store Connect "App Privacy" anketini dolduracaksın: bugün her şey cihazda kaldığı için "Data Not Collected" savunulabilir, ancak Firebase'e geçtiğin gün bu cevap yanlış hâle gelir ve etiketi güncellemen gerekir.

**Kullanıcı faydası:** Ortakların adı ve daire fiyatları gibi hassas verileri giren müteahhit, bu verinin nerede tutulduğunu ve ne kadar saklandığını görebilir; sen de KVKK ve App Store yükümlülüğünü karşılamış olursun.

### 5. Hesap silme akışı yok — kimlik doğrulama eklendiği an gönderim engeli olur

`🟠 Yüksek` · `Efor: M` · `InsaatTakip/Views/Dashboard/AccountSheet.swift`, `InsaatTakip/ViewModels/AppState.swift`

AccountSheet.swift'te yalnızca "Oturumu Kapat" (signOut) var; hesap veya veri silme seçeneği yok. Guideline 5.1.1(v): hesap oluşturmaya izin veren uygulamalar, uygulama içinden başlatılabilen bir hesap silme yolu sunmak zorunda — "bize e-posta atın" kabul edilmiyor ve silme, oluşturmadan daha zor bir yolda gizlenemiyor. Bugün teknik olarak "hesap" olmadığı için tartışılabilir, fakat 2 numaralı bulgudaki gerçek girişi veya Firebase'i eklediğin anda bu madde sert bir engele dönüşür. Bu uygulamada silme iki katmanlı düşünülmeli: yöneticinin kendi hesabını + projelerini silmesi, ve bir ortağın kendi ortaklık kaydını projeden çıkarması (yöneticinin projesi silinmeden). Şimdi tasarlanması sonradan eklemekten çok daha ucuz.

**Kullanıcı faydası:** Ortak, projeden ayrıldığında kendi kaydını kaldırabilir; yönetici işi biten projeyi ve hesabını tamamen silebilir — kimse veriye hapsolmaz.

### 6. WhatsApp ile paylaşılan davet bağlantısı hiçbir yere gitmiyor

`🟠 Yüksek` · `Efor: M` · `InsaatTakip/Models/Partner.swift`, `InsaatTakip/ViewModels/ProjectViewModel.swift`, `Config/Info.plist`, `InsaatTakip.xcodeproj/project.pbxproj`

Ürünün ortak katılım akışının merkezinde bu bağlantı var: InviteCode.link (Partner.swift:38) "insaattakip.app/katil/X7B-9Q2" üretiyor, ProjectViewModel.shareInviteViaWhatsApp bunu mesaja gömüp gönderiyor. Ama projede hiçbir .entitlements dosyası yok (Associated Domains yok), Config/Info.plist'te CFBundleURLTypes yok ve kodda onOpenURL işleyicisi yok. Ortak WhatsApp'tan gelen bağlantıya dokunduğunda uygulama açılmaz — Safari açılır ve alan adı da yayında değilse hata sayfası gelir. Kullanıcının kurtuluşu yalnızca JoinWithCodeView'daki "Davet bağlantısını yapıştır" düğmesi, yani bağlantıyı elle kopyalaması. Hakem bu akışı deneyecektir çünkü uygulamanın ana özelliği bu. Gereken: alan adının kayıtlı olması, /.well-known/apple-app-site-association dosyasının yayınlanması, Associated Domains entitlement'ı ve onOpenURL ile kodun otomatik doldurulması (ya da en azından mesajdan bağlantıyı çıkarıp sadece kodu paylaşmak).

**Kullanıcı faydası:** Ortak, WhatsApp'tan gelen bağlantıya tek dokunuşla uygulamaya girip kodu elle yazmadan projeye katılır — davet akışı gerçekten çalışır.

### 7. PrivacyInfo.xcprivacy yok — bugün engel değil, Firebase eklendiği gün zorunlu

`🟡 Orta` · `Efor: S` · `InsaatTakip.xcodeproj/project.pbxproj`, `Config/Info.plist`

Projede PrivacyInfo.xcprivacy dosyası yok. İyi haber: kodu "required reason API" listesine göre taradım ve UserDefaults, @AppStorage, Keychain, dosya zaman damgası (attributesOfItem/creationDate), disk alanı, systemUptime veya aktif klavye API'lerinden hiçbiri kullanılmıyor; üçüncü parti SDK de yok. Bu yüzden şu anki hâliyle privacy manifest eksikliği reddedilme sebebi değil — bunu net söylüyorum ki panik yapıp gereksiz iş üretmeyesin. Kötü haber: planladığın Firebase, Apple'ın "commonly used third-party SDKs" listesinde. Eklediğin an hem Firebase'in imzalı manifest'i hem de uygulamanın kendi PrivacyInfo.xcprivacy'si zorunlu olur (Firebase UserDefaults kullanır → NSPrivacyAccessedAPICategoryUserDefaults / CA92.1) ve topladığın veri türlerini — alıcı adı, finansal bilgi, fotoğraf — manifest'te beyan etmen gerekir. Şimdiden boş bir manifest ekleyip Firebase günü sadece doldurmak, o gün sıfırdan uğraşmaktan çok kolay.

**Kullanıcı faydası:** Firebase entegrasyonu tamamlandığında yayın bir hafta gecikmez; gizlilik beyanı en baştan doğru kurulmuş olur.

### 8. İlk gönderimde geri alınamayan kararlar: bundle id, uygulama adı, build numarası düzeni

`🟡 Orta` · `Efor: S` · `InsaatTakip.xcodeproj/project.pbxproj`, `Config/Info.plist`

Ayarlar şu an: PRODUCT_BUNDLE_IDENTIFIER = com.sinanalpagut.insaattakip, DEVELOPMENT_TEAM = 36HVD2S94X, MARKETING_VERSION = 1.0, CURRENT_PROJECT_VERSION = 1, CFBundleDisplayName = "İnşaat Takip", TARGETED_DEVICE_FAMILY = 1 (yalnız iPhone). Dikkat edilecekler: (a) Bundle ID ilk gönderimden sonra ASLA değiştirilemez — kişisel ad yerine kurumsal bir ön ek ("com.<sirket>.insaattakip") istiyorsan karar anı şimdi. (b) "İnşaat Takip" çok jenerik bir ad; App Store Connect'te adı hemen rezerve et, aksi halde başkası alırsa listeleme adını değiştirmek zorunda kalırsın. (c) CURRENT_PROJECT_VERSION her TestFlight yüklemesinde benzersiz olmalı; şu an elle 1'de sabit ve otomasyon yok — ikinci build'i yüklerken "redundant binary" hatası alacaksın, bir Run Script veya agvtool ile artırma kur. (d) ITSAppUsesNonExemptEncryption = false doğru ayarlanmış ve Firebase/HTTPS eklense de doğru kalır — bunu değiştirme, her yüklemede sorulan soruyu atlatıyor. (e) iPhone-only tercihi bilinçliyse App Store görsellerini de yalnız iPhone boyutlarında hazırlaman yeterli.

**Kullanıcı faydası:** Uygulamanın kimliği (id, ad) sonradan taşınamayacak şekilde yanlış çakılmaz ve ikinci TestFlight build'i yüklerken duvara toslanmaz.

### 9. Çökme raporlama ve temel kullanım analitiği yok — sahadaki hataları göremeyeceksin

`🟡 Orta` · `Efor: M` · `InsaatTakip.xcodeproj/project.pbxproj`

Projede hiçbir bağımlılık yok (packageProductDependencies boş), yani Crashlytics/Sentry gibi bir çökme raporlayıcı da yok. Bu uygulamanın kullanıcıları şantiyede, tozlu ellerle, düşük pilli telefonlarla çalışan müteahhitler — bir fiş girerken çöktüğünde sana bunu bildirmeyecekler, sadece uygulamayı silecekler. Xcode Organizer sadece analitiği paylaşmayı kabul eden kullanıcıların çökmelerini, günler gecikmeyle ve sembolleştirilmiş olsa bile bağlamsız gösterir. Firebase'i zaten planladığın için Crashlytics en düşük maliyetli seçenek; yanına 4-5 tane elle atılan olay (proje oluşturuldu, fiş eklendi, davet gönderildi, davet kabul edildi, PDF paylaşıldı) koyman davet akışının gerçekten tamamlanıp tamamlanmadığını görmeni sağlar. Not: analitik eklediğin an App Privacy etiketi ve 4 numaralı bulgudaki gizlilik politikası da güncellenmek zorunda.

**Kullanıcı faydası:** Şantiyedeki bir kullanıcının yaşadığı çökmeyi o şikayet etmeden görüp düzeltebilirsin; davet akışının kaçıncı adımda terk edildiğini bilirsin.

### 10. Açılış ekranı beyaz üretiliyor, mağaza görselleri/metinleri ise hiç hazırlanmamış

`🔵 Düşük` · `Efor: S` · `InsaatTakip.xcodeproj/project.pbxproj`, `InsaatTakip/App/LaunchConfig.swift`, `InsaatTakip/Theme/Palette.swift`, `DemoAssets/fotograflar/KAYNAKLAR.txt`

INFOPLIST_KEY_UILaunchScreen_Generation = YES ayarlı ama arka plan rengi verilmemiş; bu, sistemin systemBackground (açık temada beyaz) bir açılış ekranı üretmesi demek. Uygulama ise ya Palette.ink (#22262E) koyu karşılama ekranıyla ya da koyu ink başlıklı sayfalarla açılıyor — her açılışta gözle görülür bir beyaz parlama oluyor. Düzeltmesi tek satır: bir renk seti ekleyip INFOPLIST_KEY_UILaunchScreen_BackgroundColor ile ink rengini vermek (istersen AppMark'ı da yerleştirebilirsin). Bunun yanında gönderim için henüz hiç dokunulmamış mağaza hazırlığı var: 6.9" ve 6.5" iPhone ekran görüntüleri (LaunchConfig'in -screen/-sheet argümanları bunları üretmek için zaten hazır, iyi bir kaldıraç), Türkçe uygulama açıklaması ve anahtar kelimeler, destek URL'i (zorunlu alan), yaş sınırı anketi ve App Review notları. Ayrıca DemoAssets/fotograflar altındaki TOKİ ve BS Mühendislik görselleri KAYNAKLAR.txt'de "telif sahiplerine aittir, uygulama paketine dahil edilmez" diye işaretlenmiş — doğru; bunları sakın App Store ekran görüntülerine veya tanıtım görsellerine koyma, 5.2 telif reddi gelir.

**Kullanıcı faydası:** Uygulama ilk saniyesinden itibaren kendi kimliğiyle açılır (beyaz parlama yok) ve mağaza sayfası, gönderim gününde eksik alan aranmadan tamamlanır.

---

## Erişilebilirlik & Yerelleştirme

### 1. Kritik stok uyarısı fiilen görünmez: iki renk tonu arasında 1-3 RGB birim fark var

`🟠 Yüksek` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Palette.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/MaterialsTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`

Malzeme kartında kritik stok (kalan oran < %10) SADECE renkle bildiriliyor; hiçbir yerde "Kritik" yazmıyor (MaterialsTabView.swift:57 CodeBadge critical:, :74 stok metni rengi, :82 bar rengi). Sorun şu ki uyarı paleti ile normal palet neredeyse aynı: Palette.swift:31 accentTint = #F5E6DC (245,230,220) ve Palette.swift:54 alertTint = #F6E3DE (246,227,222) — kanal başına 1-3 birim fark. 40x40 kod rozetinin zemini kritikte de normalde de aynı soluk pembe görünüyor. Bar renkleri de aynı aileden: accent #A9633C (169,99,60) vs alertBar #B85A42 (184,90,66) — 5pt yüksekliğinde bir çubukta ayırt edilemez. Yani renk körü olmayan bir kullanıcı bile farkı göremiyor; renk körü veya güneş altında ekrana bakan biri için hiç şansı yok.

**Kullanıcı faydası:** Müteahhit demir/çimento bitmek üzereyken bunu listede tek bakışta görür. Şu an uygulama uyarıyı hesaplıyor ama kullanıcıya iletemiyor — özellik çalışmıyor sayılır. Rozetin yanına "KRİTİK" çipi + belirgin bir uyarı tonu (örn. #B3341F) eklemek şantiyede duran işi önler.

### 2. Türkçe büyük harf dönüşümü bozuk: ekranlarda "YÖNETICI", "AKTIF PROJELER", "FIŞ / İRSALIYE" yazıyor

`🟠 Yüksek` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Typography.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ProjectDetailView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/User.swift`

smallCapsLabel (Typography.swift:52) ve StatusChip (Components.swift:57) `.textCase(.uppercase)` kullanıyor; ProjectDetailView.swift:211'deki rol çipi de öyle. Uygulama paketinde Türkçe yerelleştirme olmadığı için (bkz. diğer bulgu) Locale.current Türkçe değil ve dönüşüm İngilizce kurallarıyla yapılıyor. Swift ile doğruladım: "Yönetici".uppercased() = YÖNETICI (doğrusu YÖNETİCİ), "Aktif Projeler" → AKTIF PROJELER (AKTİF), "Fiş / İrsaliye" → FIŞ / İRSALIYE (FİŞ / İRSALİYE), "Hisse Dağılımı" → HISSE DAĞILIMI (HİSSE), "Mimari Proje" → MIMARI PROJE (MİMARİ), "Taksitli" → TAKSITLI (TAKSİTLİ). Rol çipi her proje detay ekranının başlığında duruyor. İlginç olan: geliştirici sorunu biliyor — User.swift:28'de baş harfler için `uppercased(with: Fmt.locale)` doğru kullanılmış, ama arayüzdeki her .textCase(.uppercase) bunu atlıyor.

**Kullanıcı faydası:** Türk kullanıcı için "YÖNETICI" yazısı yazım hatası gibi okunuyor ve ciddi bir finans uygulamasının güvenilirliğini zedeliyor. smallCapsLabel içinde .textCase yerine metni `uppercased(with: Fmt.locale)` ile üretmek tüm ekranları tek seferde düzeltir.

### 3. Uygulama paketi İngilizce ilan ediliyor: kamera/galeri/paylaşım ekranları Türkçe telefonda İngilizce çıkıyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip.xcodeproj/project.pbxproj`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/Config/Info.plist`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/CameraPicker.swift`

Projede tek bir .lproj klasörü, .strings veya .xcstrings dosyası yok. project.pbxproj:91-95'te knownRegions = (tr, en, Base) yazıyor ama karşılığı hiçbir kaynak yok; DEVELOPMENT_LANGUAGE hiç tanımlanmamış, dolayısıyla CFBundleDevelopmentRegion = en oluyor. iOS, uygulama içindeki sistem denetimlerini uygulamanın desteklediği diller kümesine göre yerelleştirir — sonuç: PhotosPicker (ApartmentDetailSheet.swift:139, SitePhotosView.swift:77), UIImagePickerController kamera arayüzü (CameraPicker.swift), UIActivityViewController PDF paylaşımı (ReportView.swift:57) ve fileImporter (UploadSheet.swift:98) Türkçe bir telefonda bile "Cancel / Choose / Use Photo / Retake" diye çıkıyor. Ayrıca 89 adet Text("...") literali doğrudan koda gömülü; bunlar LocalizedStringKey olarak derleniyor ama arkalarında tablo olmadığı için hem çeviri hem de yukarıdaki Locale sorunu çözülemiyor.

**Kullanıcı faydası:** Boş bir tr.lproj/Localizable.strings eklemek (ve DEVELOPMENT_LANGUAGE = tr) tek başına tüm sistem ekranlarını Türkçeleştirir, Türkçe büyük harf sorununu da kökünden çözer. Metinleri tabloya taşımak ise ileride Kürtçe/Arapça/İngilizce ortak veya yabancı yatırımcı desteğini mümkün kılar — şu anda tek bir kelimeyi bile çevirmek için 30 dosyada kod değiştirmek gerekiyor.

### 4. Yazı boyutu bir kademe büyüyünce iPhone SE'de "Belgeler" sekmesi ekrandan taşıyor ve erişilemez oluyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ProjectDetailView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Typography.swift`

Font.custom(_:size:) iOS 14+ ile .body'ye göre ÖLÇEKLENİR — yani yazılar büyüyor, ama kaplar büyümüyor. ProjectDetailView.swift:293-320'deki sekme çubuğu HStack + .fixedSize() (satır 310) kullanıyor, ScrollView yok ve Spacer sıkıştırmayı engelliyor. Gerçek Manrope-Bold metrikleriyle ölçtüm: 13,5pt varsayılan boyutta çubuk 354,4pt (Malzemeler 101,1 + Daireler 77,7 + Ortaklar 79,3 + Belgeler 80,2 + 16pt padding). iPhone SE genişliği 375pt. Bir kademe büyütmede (xLarge, ~1,12x) 382,5pt → SE'de Belgeler sekmesi ekran dışında kalıyor, sıkıştırma da kaydırma da yok. iPhone 15/16'da (393pt) ikinci kademede (408,3pt) aynı şey oluyor; AX1'de (~1,6x) 495pt ile her iPhone'da kırılıyor. Aynı sorun projede 77 adet sabit .frame(height:) çağrısında var: PrimaryButton 52pt, TextField 52pt, CodeBadge 40x40, DarkHeaderButton 34x34. Ayrıca tüm SF Symbol ikonları .font(.system(size: 13)) ile tanımlı — bu form Dynamic Type'a HİÇ tepki vermiyor, yani yazı 3 kat büyürken geri oku ve kamera ikonu aynı boyutta kalıyor. Projede ne bir @ScaledMetric ne de dynamicTypeSize sınırlayıcısı var.

**Kullanıcı faydası:** Yaşlı bir müteahhit iOS'ta yazıyı büyüttüğünde uygulama şu an kullanılamaz hale geliyor — hem belgeler sekmesi kayboluyor hem butonlardaki yazı kırpılıyor. Sekme çubuğunu yatay ScrollView'a almak ve sabit yükseklikleri @ScaledMetric'e çevirmek, uygulamanın hedef kitlesinin (50+ yaş müteahhitler ve ortaklar) telefonunu kendi ayarıyla kullanabilmesini sağlar.

### 5. VoiceOver: uygulamada tek bir erişilebilirlik etiketi yok, ikon butonları İngilizce sembol adıyla okunuyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/DashboardView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/DocumentsTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/MaterialLogSheet.swift`

Tüm kod tabanında accessibilityLabel / accessibilityHint / accessibilityValue / accessibilityAddTraits / accessibilityElement çağrısı sıfır (grep ile doğrulandı; sadece 5 adet minimumScaleFactor var). Etiketsiz ikon butonları: Components.swift:219 DarkHeaderButton "chevron.left" — üç ekranın tek geri butonu (ProjectDetailView, SitePhotosView, ActivityFeedView, ReportView); ProjectDetailView.swift:205 "ellipsis" menüsü (Şantiye Fotoğrafları + Dönem Raporu'na tek giriş); DocumentsTabView.swift:162 "arrow.down" indirme butonu; DashboardView.swift:82 bildirim zili — okunmamış hareket bilgisi satır 88-93'te SADECE 7x7pt kehribar noktayla veriliyor, ne metin ne accessibilityValue var; Components.swift:146 ve MaterialLogSheet.swift:38 "xmark". Daha kötüsü MaterialLogSheet.swift:149'da fiş fotoğrafı Button değil, düz Image üzerinde .onTapGesture — VoiceOver bunu buton olarak hiç duyurmuyor. Renk-tek-başına anlam: ApartmentsTabView.swift:119 satılan daire yalnızca yeşil zeminle belirtiliyor ("Satıldı" metni yok), boş daire için en azından "Boş" çipi var. ProgressBarView tamamen çizimden ibaret, hiçbir erişilebilirlik değeri sunmuyor.

**Kullanıcı faydası:** Görme engelli ya da ileri yaşta düşük görüşlü bir ortak, uygulamanın amacı olan "finansal şeffaflık"tan tamamen mahrum kalıyor: geri dönemiyor, raporu açamıyor, okunmamış hareket olduğunu anlayamıyor. İkon butonlarına Türkçe etiket vermek ("Geri", "İndir", "Bildirimler") ve daire hücrelerini accessibilityElement(children: .combine) + tek anlamlı etiketle birleştirmek küçük bir işle bu kullanıcı grubunu uygulamaya dahil eder.

### 6. Kontrast: textTertiary 2,33:1 ile WCAG'in yarısında; pasif sekme yazıları 2,55:1

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Palette.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ProjectDetailView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/DashboardView.swift`

WCAG AA küçük metin için 4,5:1 ister. Palette.swift değerlerini beyaz (#FFFFFF) üstünde hesapladım: textTertiary #B0A99F = 2,33:1 (kart istatistik etiketleri DashboardView.swift:250, daire satış tarihi ApartmentsTabView.swift:144, hareket saati ActivityFeedView.swift:115, form dipnotları SaleFormSheet.swift:93 ve NewProjectSheet.swift:56 — hepsi 9,5-11,5pt); tabInactive #A8A199 = 2,55:1 (ProjectDetailView.swift:302 pasif sekme yazıları, 13,5pt bold); textSecondary #8C877F = 3,57:1 (proje meta satırları, ortak katılım tarihi, malzeme alt başlığı — uygulamadaki en yaygın ikincil metin); textFaded #857F76 = 3,97:1 (tüm bölüm başlıkları, 10,5pt). Koyu başlıkta: .white.opacity(0.45) ink #22262E üstünde 4,25:1 (wordmark ve SATIŞ/MALZEME/NET etiketleri, 9,5-10,5pt); JoinWithCodeView.swift:92'deki .opacity(0.35) dipnot 3,14:1. Bakır çip içi: accent #A9633C üstüne accentTint #F5E6DC zemin = 3,80:1 (CodeBadge 11pt, malzeme/daire seçim çipleri 12,5pt). Sadece textMuted #6E6860 (5,51:1) ve beyaz üstünde accent (4,63:1) geçiyor.

**Kullanıcı faydası:** Şantiyede güneş altında telefona bakan bir müteahhit 9,5pt/2,33:1 etiketleri fiilen okuyamıyor. textTertiary'yi ~#8A8378, textSecondary'yi ~#767068, tabInactive'i ~#7C766D seviyesine koyulaştırmak tasarımın karakterini bozmadan tüm ekranları okunur hale getirir; ayrıca App Store erişilebilirlik denetimlerinde risk oluşturmaz.

### 7. Dokunma hedefleri 44pt kuralının altında: geri butonu 34x34, fiş silme 30x30, çipler ~33pt

`🟡 Orta` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ProjectDetailView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/NewProjectSheet.swift`

Apple'ın asgari 44x44pt kuralını ihlal eden kontroller: Components.swift:219-231 DarkHeaderButton 34x34 — bu, ProjectDetailView / SitePhotosView / ActivityFeedView / ReportView ekranlarının TEK geri butonu (navigationBarHidden(true) olduğu için sistem kenar kaydırması dışında alternatif yok); ProjectDetailView.swift:265-272 darkHeaderIcon 34x34 (⋯ menüsü, fotoğraf ve rapora tek giriş); JoinWithCodeView.swift:25-31 kapat 34x34; NewProjectSheet.swift:99 ve :114 stepper +/- 34x34; ReceiptSheet.swift:133-138 fiş kaldırma 30x30 (en küçüğü); MaterialLogSheet.swift:143-149 fiş önizleme 34x34. 40x40 olanlar (sheet kapatma, indirme, zil, avatar) da sınırın altında. Metin çipleri de öyle: .padding(.vertical, 9) + 12,5pt yazı ≈ 33pt yükseklik — DocumentsTabView.swift:55, ReceiptSheet.swift:246, SaleFormSheet.swift:122, UploadSheet.swift:172, ActivityFeedView.swift:72, ReportView.swift:90. Ayrıca ApartmentDetailSheet.swift:45-48'deki "Tümü (n)" bakır renkli olduğu için buton gibi duruyor ama Button içinde değil — dokunulduğunda hiçbir şey olmuyor (ölü ipucu).

**Kullanıcı faydası:** Hedef kullanıcı şantiyede, eldivenli veya tozlu elle, tek başparmakla kullanıyor. 30-34pt hedefler ıskalanıyor ve özellikle geri butonu her ekranda tekrarlanan bir sürtünme noktası. İkon boyutunu değiştirmeden .contentShape(Rectangle()) + 44x44 çerçeve vermek görsel tasarımı hiç bozmadan sorunu çözer.

### 8. Sabit .fraction() sheet yükseklikleri + ScrollView yokluğu: küçük ekranda "Oturumu Kapat" ulaşılamıyor

`🟡 Orta` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/AccountSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/InviteSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`

Alt sayfalar ekran yüksekliğinin sabit bir oranına kilitli ve çoğunda tek detent var: AccountSheet.swift:85 .fraction(0.62), InviteSheet.swift:48 .fraction(0.68), ApartmentDetailSheet.swift:78 .fraction(0.78), ReceiptSheet.swift:156 ve SaleFormSheet.swift:103 .fraction(0.82), UploadSheet.swift:94 .fraction(0.85), NewProjectSheet.swift:64 .fraction(0.72). Tüm projede yalnızca MaterialLogSheet.swift:85 alternatif olarak .large sunuyor. Kritik olan: AccountSheet ve InviteSheet'in içinde hiç ScrollView YOK (AccountSheet.swift:16-88 düz VStack + Spacer). AccountSheet içeriğini kabaca ölçtüğümde ~442pt çıkıyor (başlık 78 + profil kartı 102 + etiket 45 + iki rol satırı 145 + çıkış butonu 72); iPhone SE'de 0,62 x 667 ≈ 413pt kullanılabilir alan var. Yani kırmızı "Oturumu Kapat" butonu SE'de kesiliyor ve kaydırma olmadığı için erişilemiyor. Dynamic Type bir kademe büyüdüğünde aynı sorun daha büyük telefonlarda da ortaya çıkıyor.

**Kullanıcı faydası:** Kullanıcı hesabından çıkamamak veya davet kodunu görememek doğrudan bir çıkmaz. Her sheet'e .large detent'i eklemek ve ScrollView'suz iki sheet'i sarmalamak, hem SE hem büyük yazı senaryosunda içeriği garanti eder — küçük bir değişiklikle tıkanma riski sıfırlanır.

### 9. Koyu mod uygulama genelinde kilitli: gece şantiyede tam parlaklıkta beyaz ekran

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/App/InsaatTakipApp.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Palette.swift`

InsaatTakipApp.swift:17'de .preferredColorScheme(.light) WindowGroup'a uygulanmış; bu, tüm sheet'lere, fullScreenCover'lara ve içlerindeki sistem denetimlerine de miras kalıyor. Palet zaten açık temaya sabitlenmiş: Palette.swift'te surface = Color.white, page = #F6F4F2 gibi ham hex sabitleri var, Assets katalogunda renk seti yok, hiçbir yerde Color(.systemBackground) benzeri uyarlanabilir renk kullanılmıyor. Karşılama, kod girme ve tüm ekran başlıkları zaten koyu (ink #22262E) — yani tasarım dili aslında koyu moda yakın, ama gövde beyaz kalıyor. Ek olarak koyu mod kilidi, bazı düşük görüşlü kullanıcıların dayandığı sistem geneli koyu/Smart Invert tercihini de eziyor.

**Kullanıcı faydası:** Akşam kalıp dökümünden sonra telefonunu koyu modda kullanan bir müteahhit fiş girmek için uygulamayı açtığında tam parlaklıkta beyaz bir ekranla karşılaşıyor — göz yorucu ve uygulamanın "sistemi dinlemediği" hissi veriyor. Paleti Assets renk setlerine taşıyıp koyu varyantlar tanımlamak (ink zaten mevcut) uygulamayı gece kullanımına açar.

### 10. iPad tamamen dışlanmış, buna rağmen projede kullanılmayan iPad yönlendirme ayarı duruyor

`🔵 Düşük` · `Efor: L` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip.xcodeproj/project.pbxproj`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ApartmentsTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ReportView.swift`

project.pbxproj:272 ve :301'de TARGETED_DEVICE_FAMILY = 1 (yalnız iPhone). Aynı dosyada :262 ve :291'de INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "Portrait PortraitUpsideDown LandscapeLeft LandscapeRight" tanımlı — iPad hedeflenmediği için bu ayar hiçbir işe yaramıyor; ayar setinin gözden geçirilmediğini gösteriyor. iPhone tarafında yön yalnızca Portrait (:261, :290). Uygulamanın en veri-yoğun ekranları iPad'e doğal olarak yakışıyor: DocumentsTabView'da mimari/statik proje ve ruhsat dosyaları, ReportView'da PDF dönem raporu (ReportView.swift:206'da PDF zaten 560pt genişliğe render ediliyor), ApartmentsTabView'da 22 daireli TOKİ bloklarının ızgarası — iPhone'da 2 kolon, iPad'de 4-5 kolon olabilirdi. iPad'de şu an yalnızca ölçeklenmiş iPhone penceresinde çalışır.

**Kullanıcı faydası:** Müteahhitler ve mali işlerle ilgilenen ortaklar plan/ruhsat inceleme ile rapor okumayı büyük ekranda yapmak ister; iPad desteği (TARGETED_DEVICE_FAMILY = "1,2" + ızgara kolon sayısının horizontalSizeClass'a bağlanması) uygulamayı ofis masasında da kullanılabilir hale getirir. En azından kullanılmayan iPad yönlendirme anahtarı kaldırılmalı ya da iPad hedefi bilinçli olarak açılmalı.

---

## Tasarım Sadakati

### 1. Sheet'lerde iki tutamaç üst üste çiziliyor

`🟠 Yüksek` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/MaterialLogSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/NewProjectSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`

`SheetHeader` kendi sürükleme kapsülünü çiziyor (Theme/Components.swift:126-133, 38x4, Palette.border), ancak SheetHeader kullanan 7 sheet ayrıca `.presentationDragIndicator(.visible)` veriyor: ReceiptSheet:157, SaleFormSheet:104, UploadSheet:95, InviteSheet:49, NewMaterialSheet:80, ApartmentDetailSheet:79, AccountSheet:86. Sonuç: sistemin gri tutamacı ile tasarımın kendi kapsülü birkaç piksel arayla iki ayrı hap gibi görünüyor. Tek doğru davranan ekran NewProjectSheet:65 (`.hidden`) — yani aynı kod tabanında iki farklı karar var. MaterialLogSheet ise SheetHeader'ı hiç kullanmıyor: kapatma butonunu (40x40 / fillMuted / r13, satır 38-44) SheetHeader'daki ile birebir aynı şekilde elle kopyalamış, tutamaç kapsülü yok, üst boşluk 24 (diğerlerinde 10+14=24 ama kapsül dahil) — bu yüzden başlık hizası diğer sheet'lerden farklı oturuyor. Ayrıca detent kesirleri elle ayarlanmış 7 farklı değer (0.62 / 0.68 / 0.72 / 0.75 / 0.78 / 0.82 / 0.85) ve hepsi tek detent olduğu için tutamaç sürüklense de sheet büyümüyor.

**Kullanıcı faydası:** Alt sayfalar açıldığında ilk görülen şey çift tutamaç; bu tek başına uygulamayı "yarım bitmiş" gösteriyor. Düzeltilince 8 sheet aynı üst kenarla açılır ve MaterialLogSheet de diğerleriyle aynı başlık hizasına gelir.

### 2. Kart yüzeyi için bileşen yok; gölge bazı kartlarda var bazılarında yok

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/DashboardView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/PartnersTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/ActivityFeedView.swift`

"Beyaz zemin + yuvarlak köşe + 1px border + hafif gölge" kalıbı hiçbir yerde bileşene çıkarılmamış; `RoundedRectangle(...).stroke(Palette.border, lineWidth: 1)` 20 ayrı yerde elle yazılmış. İki sorun çıkıyor: (1) Yarıçap dosyadan dosyaya değişiyor — ProjectCardView r18, ApartmentsTabView özet kartı r18, ReportView kartları r18, MaterialCardView r16, DocumentsTabView belge grubu r16, PartnerRowView r15, AccountSheet rol satırı r15, ActivityRow r14. (2) Daha görünür olanı, gölge yalnızca 5 kartta var (DashboardView:244, MaterialsTabView:100, ApartmentsTabView:98, ReportView:132 ve :179) ve hepsinde ham `Color(hex: 0x22262E, alpha: 0.05)` olarak tekrarlanmış; PartnerRowView, ActivityRow, DocumentsTabView belge grubu ve AccountSheet rol satırı gölgesiz. Yani Malzemeler sekmesindeki kartlar zeminden hafifçe kalkıkken, Ortaklar sekmesindeki satırlar düz duruyor — aynı hiyerarşideki iki liste farklı yükseklik hissi veriyor. Aynı kopyala-yapıştır durumu kesikli "boş durum" kartında da var: DocumentsTabView:69-88 ile SitePhotosView:108-127 birebir aynı (ikon 24 light, başlık manrope 13.5 bold, açıklama 11.5 medium, height 170, fillSubtle, r16, dashedBorder), InviteSheet:57-71 ise üçüncü bir varyant (132pt, ikon 26).

**Kullanıcı faydası:** Tüm listeler aynı kart diliyle görünür; kart yarıçapını/gölgesini değiştirmek isteyince tek yerden değişir, 20 dosyayı taramak gerekmez. Palette'e `cardShadow` eklenince de son ham hex kaybolur.

### 3. Seçilebilir çip 7 kez elle yazılmış, metrikleri birbirini tutmuyor

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/SaleFormSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/UploadSheet.swift`

Components.swift'te yalnızca gösterim amaçlı `StatusChip` var; "seçilebilir çip" (seçiliyse accent + accentTint + accent kenarlık, değilse textMuted + surface + border) bileşen değil, 7 ayrı kopya: ReceiptSheet.materialChip:236 (r9, yatay 12, font 12.5), SaleFormSheet.apartmentChip:112 (r9, yatay 13), SaleFormSheet.paymentChip:133 (r10, font 12, maxWidth .infinity), UploadSheet.categoryChip:164 (r9, yatay 13), NewMaterialSheet.unitChip:103 (r9, yatay 13), DocumentsTabView filtre çipleri:48-64 (r10, yatay 14), ReceiptSheet.newMaterialChip:185 (kesikli varyant). Yani aynı kontrol ekrandan ekrana 9pt/10pt köşe, 12/13/14pt yatay boşluk, 12/12.5pt font ile çiziliyor. Koyu zemindeki filtre çipleri de ikinci bir kopya çifti: ActivityFeedView:63-77 ile ReportView:81-95 birebir aynı 15 satır (r11, yatay 16 / dikey 9, beyaz ↔ white .08). Hiçbirinde basılı/devre dışı hâli tanımlı değil (SaleFormSheet:130'daki `.disabled` görsel olarak hiçbir şey değiştirmiyor — kilitli daire çipi seçilebilir görünüyor).

**Kullanıcı faydası:** Fiş, satış, dosya ve malzeme formları aynı çip diliyle görünür; kullanıcı "neyi seçtiğini" her ekranda aynı işaretle okur. Kilitli çipin devre dışı görünmesi de satış düzenlemede kafa karışıklığını bitirir.

### 4. Koyu başlık üç ayrı varyantta; kardeş ekranlar farklı uygulamadan gibi

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/SitePhotosView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ReportView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ProjectDetailView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Onboarding/JoinWithCodeView.swift`

Koyu app bar üç farklı şekilde kurulmuş. A tipi (DashboardView:70, ActivityFeedView:44, ReportView:63): yatay 20, alt köşeler `RoundedCorners(22)`, geri butonu kendi satırında, başlık Sora 26. B tipi (ProjectDetailView:174): yatay 16, düz alt kenar, başlık satır içi Sora 17 — düz kenar burada mantıklı, çünkü hemen altında beyaz sekme çubuğu var. C tipi (SitePhotosView:85): yatay 16, alt boşluk 14, düz alt kenar, satır içi Sora 17 — ama altında sekme çubuğu yok, doğrudan sayfa zemini geliyor; yani B'nin gerekçesi burada yok. Sonuç: aynı "…" menüsünden açılan iki kardeş ekran (Dönem Raporu ↔ Şantiye Kaydı) taban tabana zıt başlık dili gösteriyor — biri 22pt yuvarlatılmış kavisli başlık + büyük Sora 26 başlık, diğeri düz kesilmiş ince şerit. Aynı şekilde `DarkHeaderButton` (Components.swift:219) üç kez var: ProjectDetailView:265 `darkHeaderIcon` olarak birebir kopyalanmış (yalnızca Menu etiketi olsun diye), JoinWithCodeView:25-31 ise aynı ölçülerle ama ikon rengi `.white.opacity(0.7)` — yani aynı buton bir ekranda beyaz, diğerinde soluk.

**Kullanıcı faydası:** Ekranlar arası geçişte başlık "yerinde durur", uygulama tek elden çıkmış hissi verir. Şantiye Kaydı ekranı Rapor/Hareketler ile aynı sınıfa girince kullanıcı nerede olduğunu başlıktan tanır.

### 5. Başlık ile içerik aynı sol kenardan başlamıyor; boşluk/yarıçap ölçeği yok

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/DashboardView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/ActivityFeedView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ReportView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ProjectDetailView.swift`

Üç ekranda koyu başlık ile altındaki içerik farklı yatay boşluk kullanıyor: DashboardView başlık `.padding(.horizontal, 20)` (satır 139) ↔ gövde 16 (satır 49); ActivityFeedView 20 (satır 80) ↔ 16 (satır 36); ReportView 20 (satır 98) ↔ 16 (satır 49). Yani "Projelerim" başlığı hemen altındaki proje kartlarından 4pt içeride duruyor — dikey tarama sırasında sol kenar kırılıyor. ProjectDetailView'da tersi bir kayma var: başlık 16 (satır 233), sekme çubuğu `padding(.horizontal, 8)` + her sekme metninde `padding(.horizontal, 13)` = 21pt (satır 305, 315), içerik yine 16 → "Malzemeler" etiketi hem proje adından hem kartlardan 5pt sağda. Onboarding ekranları ise 26 kullanıyor. Bunun kök nedeni Theme/ altında bir ölçek olmaması: kod içinde 14 farklı köşe yarıçapı (3.5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 22, 24) ve 23 farklı font boyutu (9.5'ten 34'e) serbestçe kullanılıyor; `Spacing`, `Radius` ya da isimlendirilmiş metin stili tanımı yok. Zaten fiilen iki stil oluşmuş ama isimlendirilmemiş: bölüm başlığı `smallCapsLabel(size: 10.5, color: .textFaded, tracking: 1.2)` 10 yerde, form etiketi `smallCapsLabel(size: 10, color: .textControl, tracking: 0.9)` 13 yerde, form kutusu (`height 52` + r13 border) 12 yerde birebir tekrarlanıyor.

**Kullanıcı faydası:** Ekranlar dikey olarak hizalanır (başlık, bölüm etiketi ve kart aynı çizgiden başlar) — bu, tek başına "özenle yapılmış" hissinin en büyük kaynağı. İsimlendirilmiş ölçek sonrası yeni ekran eklerken doğru değeri tahmin etmek gerekmez.

### 6. Dokunma geri bildirimi ve geçiş animasyonu yok; rakamlar sıçrayarak değişiyor

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Palette.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/SaleFormSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/DashboardView.swift`

Tüm arayüzde yalnızca 3 animasyon var: toast (Components.swift:273, spring .24/.86), davet kodu üretimi (InviteSheet:75, spring .3/.85) ve sahte yükleme çubuğu (UploadSheet:209, easeInOut .9) — üçü de farklı eğri. Bunun dışında hiçbir durum değişimi animasyonlu değil. Somut sonuçları: (1) `Palette.accentPressed` palette'te tanımlı ama kod tabanında 0 kez kullanılıyor — hiçbir butonun basılı hâli yok; üstelik kart butonlarında `.buttonStyle(.plain)` kullanıldığı için (DashboardView:39 ve :177, MaterialsTabView:39, ApartmentsTabView:36, AccountSheet:135, UploadSheet:132) sistemin varsayılan sönme efekti de devre dışı — proje kartına basınca hiçbir şey olmuyor, sadece bir sonraki ekran açılıyor. (2) `ProgressBarView`'da animasyon yok: fiş kaydedilince malzeme kartındaki stok barı, satış eklenince Daireler özet barı ve tahsilat barı bir kare içinde sıçrıyor. (3) SaleFormSheet:71 — ödeme durumu "Tamamlandı" dışına çıkınca "TAHSİL EDİLEN" alanı animasyonsuz beliriyor ve yanındaki alanın genişliği anında yarıya iniyor. (4) Daire hücresi satıştan sonra kesikli boş karttan yeşil karta geçiş de anlık.

**Kullanıcı faydası:** Kullanıcı dokunduğunu hisseder ve bir sayının neden değiştiğini gözüyle takip eder — özellikle finans şeridi ve stok barlarında değişimin animasyonla akması, girilen verinin "işlendiğine" dair en güçlü güven sinyali.

### 7. Palet dışı sihirli renkler ve hiç kullanılmayan iki token

`🟡 Orta` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/SitePhotosView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/MaterialLogSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Components.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Palette.swift`

Palette dışında doğrudan renk üretilen 8 yer var. En belirgini SitePhotosView:188 — arşiv kutusu `Color(hex: 0xE8E1D8).opacity(0.55)` ile boyanmış; bu ton palette'te hiç yok (en yakını `track` 0xEFEBE6 ya da `fillMuted` 0xF2EFEB), yani şantiye arşiv kutuları paletin dışında bir bej. İkincisi MaterialLogSheet:92 ve :105 — fiş fotoğrafı tam ekran önizlemesinde `Color.black` ve `Color.black.opacity(0.45)` kullanılıyor, oysa `Palette.scrim` (0x1C1A18, %48) tam bu iş için tanımlanmış ve kod tabanında 0 kez kullanılıyor. Components.swift:258'de toast gölgesi aynı scrim tabanını (`0x1C1A18, alpha: 0.34`) ayrıca elle yazıyor. Kalan 5 tanesi kart gölgesindeki `0x22262E, alpha: 0.05` tekrarı (bkz. kart bulgusu). `Palette.accentPressed` de 0 kullanımda. Kısacası palette'te tanımlı 33 tokendan 2'si ölü, buna karşılık palette'te olmayan 1 renk kodda yaşıyor.

**Kullanıcı faydası:** Renk kararları tek dosyada toplanır; ileride koyu tema ya da marka tonu değişikliği gerektiğinde ekranların bir kısmı eski renkte kalmaz.

### 8. Metin büyüyor ama kutular sabit: web handoff'undan gelen piksel yükseklikleri

`🟡 Orta` · `Efor: L` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/Typography.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ProjectDetailView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ApartmentsTabView.swift`

Tipografi `Font.custom(_:size:)` ile kuruluyor (Theme/Typography.swift:9-16); bu API iOS 14'ten beri gövde metnine göre Dynamic Type ile ölçekleniyor. Buna karşılık tüm kaplar sabit piksel: 12 form alanı `.frame(height: 52)`, ikon çipleri 40x40 / 38x38 / 34x34 / 30x30 / 26x26, kod kutuları 58, daire hücresi 142, görsel şeridi 112, boş durum kartı 170. Kod tabanında tek bir `ScaledMetric` veya `dynamicTypeSize` sınırı yok. Ayrıca 31 yerde `.font(.system(size:))` ile çizilen SF Symbol ikonları — bu API ölçeklenmiyor — yani kullanıcı yazı boyutunu büyüttüğünde etiketler büyürken ikonlar aynı kalıyor; sekme çubuğu, kapatma butonları ve rozetler orantısını kaybediyor. Büyük yazı ayarında en erken kırılan yerler: 52pt form alanları (Sora 16 bold değer metni kırpılır), 34pt koyu başlık butonları ve `ProjectDetailView` finans şeridi (üç kolon `minimumScaleFactor(0.8)` ile kısmen korunmuş ama üstündeki 9.5pt etiket taşıyor).

**Kullanıcı faydası:** Sahada telefonunu büyük yazıyla kullanan (yaş ortalaması yüksek) müteahhit ve ortaklar için tutarlar ve miktarlar kırpılmadan okunur; uygulama iOS'un kendi ayarlarına saygı gösteren bir uygulama gibi davranır.

---

## Farklılaştırıcı Fikirler

### 1. Gider defteri: inşaatın gerçek maliyeti (işçilik, taşeron, arsa, harç)

`🔴 Kritik` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ProjectDetailView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ReportView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`

Uygulamanın merkezî rakamı olan "Net" yalnızca malzemeden hesaplanıyor: ProjectViewModel.netAmount (satır 110-112) = totalSales − totalMaterialCost, o da sadece Material.accruedCost toplamı. Proje detay başlığındaki Net şeridi (ProjectDetailView.swift:228) ve dönem raporundaki "Dönem net" satırı (ReportView.swift:125) işçiliği, taşeron hakedişini, arsa/kat karşılığı bedelini, ruhsat-harç-SGK-iskân giderlerini, makine kirasını ve yakıtı hiç saymıyor. Konut inşaatında malzeme toplam maliyetin kabaca yarısıdır; yani ortağa gösterilen kâr gerçeğin iki katına kadar çıkabiliyor. Öneri: Expense modeli (kategori: işçilik, taşeron hakedişi, arsa/kat karşılığı, ruhsat & harç, makine/ekipman, yakıt, genel yönetim, diğer + tutar, tarih, açıklama, tedarikçi, fiş görseli) ve MaterialLog ile birebir aynı akış — aynı kamera, aynı toast, aynı role == .admin guard'ı. Rapor özet kartı "Malzeme / İşçilik / Diğer gider / Toplam gider" satırlarına açılır.

**Kullanıcı faydası:** Müteahhit "gerçekte ne kazanıyorum" sorusunun cevabını ilk kez uygulamada görür; ortak da şişirilmiş kâr yerine gerçek tabloyu görünce güven oluşur. Bugün rakam eksik olduğu için kullanıcı paralel Excel tutmaya mecbur — bu modül eklenmeden Excel'den kopuş mümkün değil.

### 2. Ortak cari hesabı — "benim payıma ne düşüyor"

`🔴 Kritik` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Partner.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/PartnersTabView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

Uygulamanın varlık sebebi ortaklar arası finansal şeffaflık, ama ortaklar arasındaki PARA hiç modellenmemiş. Partner yalnızca ad + sharePercent taşıyor (Partner.swift:5-17); hisseyi düzenleyen bir fonksiyon veya ekran yok (PartnersTabView.swift:25 toplamın %100 olmadığını uyarıyor ama düzeltmenin yolu yok), davet kodu doğrulaması (ProjectViewModel.swift:365) 6 haneli her kodu kabul ediyor ve katılan kişi için Partner kaydı bile oluşturmuyor. Kim ne kadar sermaye koydu, kim ne kadar avans çekti, kime ne kadar dağıtım yapıldı — hiçbiri yok. Öneri: PartnerLedgerEntry (sermaye girişi / kâr dağıtımı / avans çekimi), hisse düzenleme, ve ortak rolünde açılan "Payım" kartı: hisse × dönem neti, koyduğu sermaye, aldığı ödeme, bakiye. "Ortak hesap özeti" PDF'i ReportView'daki ImageRenderer hattıyla neredeyse bedava gelir.

**Kullanıcı faydası:** Ortaklıkların kavga noktası "hesap kapatma"dır. Ortak telefonunu açıp "koyduğum 5 M ₺, hakkım 7,2 M ₺, aldığım 2 M ₺, alacağım 5,2 M ₺" diye görür; müteahhit her ay aynı soruya sözlü cevap verme yükünden kurtulur. Salt okunur izleme vaadini gerçek bir mutabakat aracına çeviren tek özellik bu.

### 3. Taksit planı ve vade hatırlatıcısı (alacak takibi)

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Apartment.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/SaleFormSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ApartmentDetailSheet.swift`

Apartment tahsilatı tek bir paidAmount alanında tutuyor (Apartment.swift:27); PaymentStatus.taksitli var ama taksit sayısı, vade tarihi ve ödeme geçmişi yok. Model bu yapıyı fiilen istiyor: mock veride TOKİ planı ("%10 peşinat + 19 aylık taksit", "bedel×%0,5 aylık") yorum satırlarında elle hesaplanıp tek bir sayı olarak yazılmış (ProjectViewModel.swift:828-830 ve 866-868). Öneri: PaymentPlan + PaymentInstallment (vade tarihi, tutar, ödendi mi, ödeme tarihi), daire detayında ödeme takvimi, gecikmiş tahsilat listesi ve vadeden 3 gün önce yerel bildirim. Proje detay başlığındaki "Kalan alacak" satırı (ProjectDetailView.swift:247) böylece "bu ay vadesi gelen / gecikmiş" ayrımına kavuşur.

**Kullanıcı faydası:** Küçük müteahhidin en çok vakit harcadığı iş alacak kovalamaktır. Kimin taksidinin geciktiğini uygulama hatırlatınca WhatsApp'tan ve defterden takip biter, tahsilat hızlanır — doğrudan nakit etkisi. Ortak da "satıldı ama parası gelmedi" farkını görür.

### 4. m² maliyeti, daire başına maliyet ve başabaş noktası

`🟠 Yüksek` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Apartment.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ApartmentsTabView.swift`

Apartment.area bugün String ("111,55 m²", Apartment.swift:24) olduğu için m² matematiği teknik olarak imkânsız. Alan sayısallaştırılınca (veya ayrıştırılınca) şu hesaplar ViewModel'e 5-6 computed property olarak eklenebilir: m² maliyeti, m² satış fiyatı, daire başına düşen maliyet, daire bazlı kâr marjı ve "kaçıncı daire satışında masraf kapanıyor" (başabaş). Bu hesabın değerli olduğunu kodun kendisi kanıtlıyor: Kars projeleri için inşaat alanı ve m² katsayıları (40 kg/m² demir, 0,35 m³/m² beton…) mock veri yorumlarında elle hesaplanmış (ProjectViewModel.swift:658-662, 681-682). Gösterim yeri hazır: ApartmentsTabView.swift:48 özet kartı ve dashboard proje kartı.

**Kullanıcı faydası:** Müteahhidin fiyat verirken kafasındaki tek soru "m²'si bana kaça mal oluyor". Uygulama bunu canlı verdiğinde satış fiyatı ve iskonto pazarlığı sezgiyle değil rakamla yapılır; ortak da "bu daireyi neden bu fiyata verdik" sorusunun cevabını görür. #1'deki gider modülüyle birlikte gerçek gücüne kavuşur.

### 5. Malzeme fiyat geçmişi ve zam etkisi projeksiyonu

`🟠 Yüksek` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/MaterialLogSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

Her giriş fişi kendi tarihindeki birim fiyatı donduruyor (Material.swift:47-49, MaterialLog.unitPrice) — yani tam bir fiyat geçmişi ZATEN kayıtlı, ama hiçbir ekranda görünmüyor. Malzeme detayı (MaterialLogSheet.swift:30) sadece son fiyatı gösteriyor. Öneri: kalem bazlı fiyat çizgisi (dağıtım hedefi iOS 16 olduğu için Swift Charts kullanılabilir), "son 6 ayda %X arttı" rozeti ve kalan imalat için zam etkisi projeksiyonu ("kalan 12.000 kg demir geçen yılın fiyatıyla 1,2 M ₺ yerine bugün 1,9 M ₺"). Aynı veriden projeler arası kıyas bedava gelir: aynı demir Kars'ta X, Kocaeli'de Y ₺.

**Kullanıcı faydası:** Enflasyon ortamında müteahhidin en pahalı hatası geçen ayın fiyatıyla teklif vermek. Zam eğrisi görünür olunca alım zamanlaması ve satış fiyatı buna göre ayarlanır. Veri zaten toplanıyor, sadece görünür kılmak gerekiyor — fayda/efor oranı listedeki en yüksek kalem.

### 6. Fiş fotoğrafından otomatik okuma (cihaz içi OCR)

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Theme/CameraPicker.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

ReceiptSheet fişi kamerayla çekip görseli saklıyor (ReceiptSheet.swift:104-145, receiptImages[log.id]) ama görselden hiçbir bilgi çıkarılmıyor; kullanıcı miktarı, birim fiyatı, irsaliye numarasını elle yazıyor. Apple'ın Vision çatısı (VNRecognizeTextRequest) cihaz içinde, ücretsiz, internetsiz ve Türkçe destekli çalışır. Fiş çekildiği anda toplam tutar, tarih, irsaliye/fatura no ve firma adı önerilir; kullanıcı yalnızca onaylar. Ön dolum bire bir uyuyor: form alanları zaten metin ve ProjectViewModel.parseNumber tr-TR girdisini ("12.500", "28,50") sayıya çeviriyor.

**Kullanıcı faydası:** Şantiyede, eldivenli elle, güneş altında rakam yazmak en büyük sürtünme noktası; fiş girişi ~40 saniyeden ~5 saniyeye iner. "Fotoğrafı çek, gerisini uygulama yapsın" rakiplerde olmayan somut bir vaat ve App Store ekran görüntülerinde ilk sırada gösterilecek özellik.

### 7. Ay sonu raporunun ortaklara gerçekten gitmesi

`🟠 Yüksek` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ReportView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

Rapor ekranında kullanıcıya "Rapor tüm ortaklara otomatik olarak da gönderilebilir." yazılı bir vaat veriliyor (ReportView.swift:43) ama böyle bir kod yok; PDF yalnızca UIActivityViewController ile elle paylaşılıyor. Öneri: (a) rapor PDF'ini WhatsApp'a tek dokunuşla gönderen akış — kalıp hazır: shareInviteViaWhatsApp (ProjectViewModel.swift:380); (b) her ayın 1'inde yerel bildirim: "Temmuz raporu hazır, ortaklara gönder"; (c) Ortaklar sekmesinde "son gönderilen rapor" bilgisi. Tam otomatik dağıtım backend ister, ama hatırlat + tek dokunuşla paylaş bugünkü mimariyle çalışır ve vaadi dürüst hale getirir.

**Kullanıcı faydası:** Ortak "benim haberim yok" diyemez, müteahhit ay sonu hesap verme yükünü ritüele çevirir. Şeffaflık, ekranda yazan bir cümle olmaktan çıkıp her ay tekrarlanan somut bir davranış olur — uygulamanın ortaklar tarafından da açılmasını sağlayan alışkanlık budur.

### 8. Kanıtlı ilerleme: imalat kontrol listesi + fotoğrafla doğrulama

`🟠 Yüksek` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Project.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/SitePhotosView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/DashboardView.swift`

Project.progress elle atanmış bir Int ve uygulamada onu değiştiren hiçbir ekran yok — yalnızca mock veride set ediliyor, DashboardView.swift:212-219'da gösteriliyor. Yani dashboard'daki ilerleme çubuğu dekoratif ve ortak açısından doğrulanamaz bir sayı. Öneri: kat/blok bazlı imalat kontrol listesi (temel, kalıp, donatı, beton, duvar, sıva, şap, mantolama, doğrama, boya, teslim); her kalem işaretlenince ilerleme otomatik hesaplanır ve işaretlemeye şantiye fotoğrafı iliştirilir — SitePhotosView zaten haftalık kayıt tutuyor (SitePhotosView.swift). Hareket akışına "5. kat perde betonu döküldü · 3 fotoğraf" düşer.

**Kullanıcı faydası:** Ortağın en çok merak ettiği şey "param nereye gidiyor, iş gerçekten ilerliyor mu". Yüzdeyi müteahhidin yazması değil işaretlenen imalatın üretmesi ve fotoğrafın kanıtlaması güveni bambaşka yere taşır. Müteahhit için de "hangi kat nerede kaldı" tek ekranda toplanır; ProjectPhase çipi kendiliğinden doğru ilerler.

### 9. Tedarikçi cari takibi: kime ne kadar borç var

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/Sheets/ReceiptSheet.swift`

Tedarikçi bilgisi bugün serbest metnin içinde saklı: MaterialLog.note = "İrsaliye #4471 · Yılmaz Yapı" (ProjectViewModel.swift:711). Yapılandırılmış bir tedarikçi alanı olsaydı tedarikçi bazlı toplam alım, ortalama birim fiyat kıyası ve en önemlisi "ödendi / vadeli" ayrımıyla cari borç çıkardı. Şu an her giriş fişi peşin ödenmiş varsayılıyor — addReceipt anında accruedCost'u artırıyor (ProjectViewModel.swift:164) — oysa Türkiye'de malzeme çoğunlukla 30-90 gün vadeli/çekle alınır; yani ekranda görünen gider gerçekleşmiş nakit çıkışı değil.

**Kullanıcı faydası:** Müteahhit "kime ne kadar borcum var, hangi çek ne zaman" listesini defterden değil telefondan görür ve hangi tedarikçinin ucuz olduğunu rakamla bilir. Maliyet (tahakkuk) ile nakit (ödenen) ayrımı yapılınca ortağa gösterilen tablo da ilk kez muhasebe gerçeğiyle örtüşür.

### 10. Excel/CSV dışa aktarma ve tam yedek dosyası

`🟡 Orta` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Project/ReportView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

Bugünkü tek çıktı tek sayfalık PDF (ReportView.exportPDF, satır 185-240). Mali müşavir PDF değil satır satır veri ister. Öneri: malzeme hareketleri, giderler, satışlar ve tahsilatlar için tr-TR uyumlu CSV (Excel'in doğru açtığı ayraç ve kodlama) ve tüm projeyi tek dosyada dışa aktaran JSON yedeği. Altyapı hazır: ShareSheet zaten var (ReportView.swift:250) ve modellerin tamamı Codable (Project, Material, MaterialLog, Apartment, Partner, ProjectDocument).

**Kullanıcı faydası:** "Excel'den vazgeçersem verim uygulamada hapsolur" korkusu, küçük müteahhidin bu tür uygulamalara geçmemesinin bir numaralı sebebi. Dışa aktarma bu korkuyu ortadan kaldırır; ayrıca ay sonu muhasebeye gönderilecek dosya iki dokunuşta hazırlanır ve ortak isterse veriyi kendi kontrol eder.

### 11. Portföy özeti ve projeler arası karşılaştırma

`🟡 Orta` · `Efor: S` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Views/Dashboard/DashboardView.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/ViewModels/ProjectViewModel.swift`

DashboardView proje kartlarını alt alta diziyor ama hiçbir toplam yok; dashboardSubtitle (ProjectViewModel.swift:129) sadece proje ve daire sayısı veriyor ("5 proje · 74 daire"). Beş projesi olan bir müteahhit toplam ciroyu, toplam tahsilatı, kalan alacağı ve "hangi proje daha kârlı" karşılaştırmasını hiçbir yerde göremiyor. Öneri: dashboard başlığının altına portföy şeridi (toplam ciro / tahsilat / kalan alacak / net) ve projeleri m² maliyeti ile kâr marjına göre yan yana koyan bir karşılaştırma kartı. Gerekli tüm veri ViewModel'de mevcut; sadece projeler üzerinden toplama yazılacak.

**Kullanıcı faydası:** "Nakit nerede sıkıştı, hangi projeye yüklenmeliyim, hangisini durdurmalıyım" kararı tek ekranda verilir. Birden fazla projede hissesi olan ortak da toplam pozisyonunu görür — bugün bunun için her projeyi tek tek gezmek gerekiyor.

### 12. Hatırlatıcılar ve ana ekran / kilit ekranı widget'ı

`🟡 Orta` · `Efor: M` · `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/Models/Material.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip/App/InsaatTakipApp.swift`, `/Users/sinanalpagut/Documents/developerProject/inşaattakip/InsaatTakip.xcodeproj/project.pbxproj`

Material.isCritical kritik stoğu zaten hesaplıyor (Material.swift:32-33) ama kimse haber almıyor — kullanıcı uygulamayı açıp o karta bakana kadar demirin bittiğini öğrenmiyor. Ruhsat/iskân süresi, taksit vadesi ve sözleşme tarihleri için de hiçbir hatırlatma yok. Öneri: UNUserNotificationCenter ile yerel bildirimler (kritik stok, gecikmiş tahsilat, ay sonu raporu, ruhsat süresi) ve bir widget: "Bugün: 2 fiş · Tahsilat 480 B ₺ · Kalan alacak 14,5 M ₺". Bildirim tarafı bugünkü mimariyle çalışır; widget yeni bir target + App Group + paylaşılan kalıcı veri gerektirdiği için planlanan kalıcılık/Firebase adımıyla birlikte yapılmalı.

**Kullanıcı faydası:** Uygulama "aklıma gelirse açarım" olmaktan çıkıp kendini hatırlatan bir asistana dönüşür; inşaatta unutulan bir vade ya da biten demir doğrudan para ve zaman kaybıdır. Widget ayrıca uygulamayı günlük alışkanlık haline getirir ve ortağın da her gün göz atmasını sağlar.

---

