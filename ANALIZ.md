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

**KESİNTİLİ ŞANTİYE AĞI GEÇTİ.** Uçak modunda gider kaydedildi; ekranın
altında amber şerit belirdi: **"Bağlantı bekleniyor · 1 kayıt gönderilecek"**.
Uçak modu kapatılınca şerit kayboldu, kayıt gönderildi. Uygulama yeniden
başlatıldı ve veri SUNUCUDAN geldi (`önbellekten=false`) — kayıt yerinde.

Bu, uygulamanın en sinsi hata sınıfına karşı yazılmış korumaydı: çevrimdışıyken
Firestore yazmayı sessizce kuyruğa alıyor, `commit()` hata vermiyor, ekranda
veri görünüyor ve kullanıcı kaydettiğini sanıp şantiyeden ayrılıyor. Şerit
"gönderilmedi" diyor ve kaç kayıt beklediğini sayıyor. Gerçek kesintide ilk kez
çalıştı.

**KALAN TEK MADDE: dolu depolama dalı.** Gerçekçi biçimde denenmesi cihazın
depolamasını doldurmayı gerektiriyor; pratik değil. Denetimde bulunan "disk
yazılamazsa" dalı hâlâ yalnızca kodla doğru, sahada koşmadı. Emülatör kurulumu: `sh scripts/emulator-device.sh` + cihaz
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
- [x] 21. Vade hatırlatıcı + gecikmiş tahsilat listesi — **TAMAM (19 Ağu 2026)**
      · İKİ BOŞLUK vardı: vade/taksit modeli YOK (`Payment` yalnızca
        gerçekleşmiş ödemeyi tutuyor) ve bildirim altyapısı YOK.
        `PaymentStatus.taksitli` bir ETİKETTİ — arkasında sayı, tutar, vade
        hiçbir şey yoktu.
      · **VADE ÖĞLEN 12:00'DE.** Gece yarısı üç yerden ısırırdı: yaz saatinde
        tarih kayar; `DateInterval.contains` iki uçtan kapsayıcı olduğu için ay
        sınırındaki vade iki aya birden sayılır; cihaz saat dilimi farklıysa
        aynı vade farklı güne düşer.
      · **"GECİKMİŞ" GÜN KARŞILAŞTIRMASI.** `vade < Date()` yazılsaydı bugün
        vadesi olan taksit sabah gecikmemiş, akşam gecikmiş görünürdü.
      · **MAHSUP FIFO**, yabancı anahtar değil: müteahhit parayı geldiği gibi
        giriyor, her ödemeyi elle bir taksite işaretlemesi beklenemez ve yanlış
        işaretleme listeyi sessizce bozardı. `Payment` modeline dokunulmadı.
      · **YEREL BİLDİRİM**, sunucu push'u değil: push zamanlanmış işlev + FCM
        jetonu + koleksiyon + kural + test demek, kapsamı ikiye katlardı.
        FirebaseAuth `UNUserNotificationCenter`'a dokunmuyor, telefon girişi
        bozulmuyor.
      · **64 BİLDİRİM SINIRI.** iOS uygulama başına 64 bekleyen bildirim
        tutuyor, fazlasını SESSİZCE atıyor. Taksit başına bildirim kurulsaydı
        12 daire × 12 taksit = 144 istek olur, 80'i çöpe giderdi ve kullanıcı
        hangi vadelerin hatırlatılacağını bilemezdi. Çözüm: GÜNE GÖRE TOPLAMA —
        aynı gün vadesi gelen daireler tek bildirimde.
      · **İZİN İLK PLAN KURULDUĞUNDA** isteniyor, açılışta değil: açılışta
        sorulsa FirebaseAuth'un APNs kaydıyla üst üste gelir ve kullanıcı SMS
        beklerken "İzin Verme"ye basardı. Reddedilirse liste çalışmaya devam
        ediyor ve ekran bunu DÜRÜSTÇE söylüyor.
      · DEMO VERİSİ: gecikme uydurulmadı, senaryodan doğdu — bir alıcı üç ay
        önce ödemeyi kesti. İlk denemede liste boştu çünkü demo alıcıların
        tamamı planın önünde gidiyordu (madde 25'teki düz çizgi dersinin
        tekrarı).
      · **FIFO ELLE DOĞRULANDI:** tahsilat ilk iki vadeyi tam, üçüncüsünü
        kısmen kapatıyor; o vade 5 Temmuz, bugün 19 Ağustos ve uygulama
        "45 gün" diyor — tam olarak doğru. Bildirim kurulumu da ölçüldü:
        24 açık vade → 24 gün, sınırın altında.
      · Kural (`installments`, ortağa açık — ortak zaten ödeme tarihlerini
        görüyor) 158/158 testle korunuyor ve YAYINDA.
- [x] 22. Daire/alıcı arama ve filtreleme — **TAMAM (18 Ağu 2026)**
      · Arama: daire numarası, tip, alan, kat etiketi, durum metni.
      · ALICI ADIYLA ARAMA YALNIZCA YÖNETİCİDE. Ortakta `buyerName` zaten nil
        geliyor (madde 18), ama koşul kodda AÇIKÇA duruyor: alan bir gün
        ortağa da inse arama kutusu "bu isim bu projede var mı" sorusuna
        cevap veren bir KÂHİN olurdu — eşleşen tek bir daire, gizlenen
        kimliği ele verirdi.
      · Durum çipleri SÜZÜLMEMİŞ listeden sayıyor (çipe basmadan önce kaç
        daire olduğu görünsün); aynı çipe ikinci dokunuş süzgeci kaldırıyor.
- [x] 23. Belgelerin gerçekten açılabilmesi/indirilmesi — **TAMAM (18 Ağu 2026)**
      · Özellik İKİ UÇTAN DA VİTRİNDİ: `handlePickedFile` güvenlik kapsamlı
        erişimi açıp yalnızca BOYUTU okuyor, kapatıyor ve URL'i atıyordu —
        baytlara bir daha erişilemiyordu; ardından 0,9 saniyede %100'e giden,
        ağdaki hiçbir şeye bağlı olmayan sahte bir ilerleme çubuğu oynuyordu
        (kodun kendi yorumu "mock" diyordu); "İndir" düğmesi ise yalnızca
        "… indiriliyor" yazan bir bildirim gösteriyordu.
      · `DocumentStore` (yeni): `ImageStore`'un iki katlı deseni ama ayrı tip —
        `ImageStore` baştan sona UIImage/JPEG'e bağlı, belge PDF/DWG olabiliyor
        ve 50 MB'a çıkabiliyor. `copyIn` kapsam AÇIKKEN sandbox'a kopyalıyor.
        Büyük dosya belleğe alınmıyor: `copyItem`, `putFile`, `writeAsync`.
      · Modele `fileExtension`, `contentType`, `storagePath` eklendi. Uzantı
        önce geri dönülemez biçimde atılıyordu; önizleme dosyayı ADINDAN
        tanıyor. `fileType` enum'u yalnızca rozet rengi, gerçek MIME değil.
      · `storage.rules`'ta AYRI blok: görünürlük KOVA değil BELGE bazlı
        (`partnerVisible`), kural kardeş Firestore belgesine çapraz servis
        `get()` ile bakıyor. Kova düzeyinde açılsaydı Firestore'da kapatılan
        sızıntı Storage'dan geri açılırdı. 152/152 test, mutasyonla sınandı.
      · `DocumentPreview` (yeni): projedeki İLK önizleme yüzeyi, QuickLook.
        Paylaşma/yazdırma düğmelerini kendisi getiriyor.
      · Başarısız yükleme artık GÖRÜNÜR ("sonra yeniden denenecek") ve
        `hydrateDocuments` açılışta "belgede yol yok + diskte kopya var" olanları
        yeniden deniyor. İkisinin yokluğu gerçek cihaz turunda görüldü: kural
        eksikken yükleme sessizce reddedildi ve kullanıcının dosyayı yeniden
        seçmekten başka çaresi yoktu.
      · GERÇEK CİHAZDA UÇTAN UCA DOĞRULANDI: PDF seçildi → 232.632 bayt
        `application/pdf` olarak üretim kovasına indi (nesne adı uzantısız belge
        kimliği) → indirme okuna basılınca QuickLook'ta GERÇEK DOSYA ADIYLA
        açıldı. Ad'ın doğru görünmesi uzantı düzeltmesinin doğrudan kanıtı.
      · TUZAK: kural yazılıp emülatörde test edildi ama YAYINA ÇIKARILMADI;
        ilk gerçek yükleme bu yüzden reddedildi. Yeni Storage yolu = kural yaz +
        test et + **deploy et**.
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
- [x] 26. CSV/JSON dışa aktarma + portföy özeti — **TAMAM (18 Ağu 2026)**
      · **CSV.** Tek çıktı tek sayfalık PDF'ti; mali müşavir SATIR SATIR veri
        istiyor ve müteahhit bu yüzden paralel Excel tutuyordu. Türkçe Excel'in
        üç tuzağı açıkça ele alındı ve üretilen dosyada doğrulandı: ayraç `;`
        (tr-TR'de ondalık virgül olduğu için virgüllü dosya tek sütuna
        yapışıyor), UTF-8 BOM (yoksa ş/ğ/İ bozuluyor — `efbbbf` doğrulandı),
        ondalık VİRGÜLLE (`1234.56` Excel'de metin olur, toplama girmez).
        Alan kaçışlama da var: açıklamadaki bir noktalı virgül sütunları
        kaydırıp dosyanın geri kalanını bozardı.
      · **GİZLİLİK:** alıcı sütunu yalnızca yöneticide. Rapor ekranı ortağa
        bilerek açık ve dışa aktarma oradan tetikleniyor; koşulsuz yazılsaydı
        Firestore'da kapatılan kimlik ortağın Excel dosyasına düşerdi.
      · **JSON yedeği ve bir dürüstlük kararı:** `Apartment.CodingKeys`
        `buyerName`i dışarıda bırakıyor, dolayısıyla yedek o kodlamayı
        kullansaydı 13 alıcı adı KENDİLİĞİNDEN düşerdi — "yedek" adı altında
        eksik dosya vermek, kullanıcının kaybı fark etmeyeceği bir yalan
        olurdu. Alıcılar ayrı dizide; ortak yedeğinde boş ve dosya bunu
        `aliciDahil: false` ile söylüyor. Doğrulandı: daire kaydında
        `buyerName` YOK, `alicilar` dizisinde 13 kayıt VAR.
      · **Portföy şeridi.** Dashboard kartları alt alta diziyor ama hiçbir
        toplam vermiyordu. Artık ciro / tahsilat / kalan alacak + projeleri
        m² maliyetine göre sıralayan karşılaştırma. Bu karşılaştırma ancak
        madde 25 (m² maliyeti) geldikten sonra mümkün oldu.
      · Yol üstünde bir kusur: liste `prefix(4)` ile SESSİZCE kırpıyordu, beş
        projeli portföyde biri düşüyor ve kullanıcı "hepsi bu" sanıyordu.
        Sınır duruyor ama artık kaç projenin dışarıda kaldığı yazılı.

### Faz 4 — Yayın paketi

- [x] 27. KVKK aydınlatma + gizlilik politikası URL'i — **TAMAM (15 Eki 2026)**
      · **ÜÇ METİN, ÜÇ AYRI SAYFA** — benav.com.tr/privacy altında, mevcut
        Beje sayfalarıyla aynı iskelet: `insaat-takip.html` (gizlilik),
        `-kvkk.html` (aydınlatma), `-kosullar.html` (kullanım koşulları).
        Üçü de YAYINDA ve HTTP 200 doğrulandı.
      · **KVKK AYRI SAYFA, GİZLİLİĞİN İÇİNDE DEĞİL.** Kanunun istediği
        başlıklar (veri sorumlusu kimliği, hukuki sebep, m.11 hakları) genel
        bir gizlilik metninin içinde erir; Türkiye'deki kullanıcı "KVKK" diye
        arıyor ve aradığı kelimeyi ekranda bulmalı.
      · **METİN ŞABLONDAN DEĞİL KODDAN YAZILDI.** Her iddia doğrulandı:
        bağlı Firebase ürünleri AppCheck/Auth/Core/Firestore/Functions/
        Storage — Analytics ve Crashlytics BAĞLI DEĞİL, yani "analitik
        toplamıyoruz" doğrulanabilir bir cümle. `PrivacyInfo.xcprivacy`
        `NSPrivacyTracking = false`. Sunucu bölgesi europe-west1. Hesap
        silme uygulama içinde (madde 28). Doğrulanamayan tek madde
        yazılmadı.
      · **EN KRİTİK MADDE — ÜÇÜNCÜ KİŞİ VERİSİ.** Müteahhit daire
        ALICILARININ adlarını giriyor. Metinler bu yüzden İKİ ROLLÜ kuruldu:
        hesap verisinde (telefon, ad) veri sorumlusu benav; alıcı adlarında
        veri sorumlusu KULLANICI, benav yalnızca veri işleyen. Tek rollü bir
        metin, müteahhidin kendi aydınlatma yükümlülüğünü sessizce üstlenmek
        olurdu. Alıcı adlarının ortaklara gösterilmediği de yazıldı — kısıt
        güvenlik kurallarında, yalnızca ekranda gizlemekle değil.
      · **KAYNAK UYGULAMA DEPOSUNDA** (`scripts/hukuki-sayfalar.py`), sayfalar
        site deposunda. Gizlilik metni, kodun ne topladığına dair bir
        İDDİA; kanıtı `PrivacyInfo.xcprivacy` ve kodun kendisi. Ayrı
        depolarda dursalardı veri toplama değiştiğinde metni güncellemeyi
        hatırlatan hiçbir şey olmazdı.
      · **UYGULAMADAKİ KARŞILIĞI:** `AppInfo`da üç adres; AccountSheet'te
        gizlilik + KVKK + koşullar satırları, PlansSheet'te koşullar +
        gizlilik. Adresin boş kalmasını kilitleyen test
        (`testPrivacyPolicyIsStillPending`) görevini yaparak düştü ve yerini
        `testLegalURLsAreConfigured` aldı: https şartı + üç adresin
        birbirinden farklı olması. Adreslerin CANLI olduğunu test
        doğrulayamaz (sayfalar başka depoda, ağa çıkan test kırılgan olurdu)
        — yayın öncesi elle açılması şart ve açıldı.
      · **AVUKAT İNCELEMESİ EKSİK:** metinler hukukçu tarafından yazılmadı.
        Özellikle veri sorumlusu/işleyen ayrımı yayından önce bir KVKK
        avukatına okutulmalı. Veri sorumlusu satırında tüzel unvan değil
        "benav" yazıyor — kullanıcının kararı (15 Eki 2026).
- [x] 28. Hesap silme akışı (App Store 5.1.1v) — **TAMAM (19 Ağu 2026)**
      · 5.1.1(v): hesap oluşturmaya izin veren uygulama, hesabın uygulama
        İÇİNDEN silinmesine de izin vermek zorunda. Bugüne kadar silme yolu
        SIFIRDI; tek çıkış "Oturumu Kapat"tı.
      · **SUNUCU TARAFI ZORUNLU** — beş bağımsız sebep: kural proje/profil
        silmeyi istemciye kapatıyor; ORTAK kendi uid'ini `memberUids`'ten
        çıkaramıyor (istemci çözümü matematiksel olarak imkânsız); 13 alt
        koleksiyon otomatik silinmiyor (`recursiveDelete` kullanıldı, elle
        koleksiyon saymak yeni koleksiyon eklenince sessizce eksik kalırdı);
        Storage istemciden listelenemiyor (Admin SDK önek silmesi YETİM
        nesneleri de yakalıyor); Auth kaydı EN SON silinmeli, yoksa uid bir
        daha üretilemez ve veri erişilemez öksüz kalır.
      · **SAHİPLİK:** sahibin projeleri ve tüm verisi silinir; ORTAK olduğu
        projelerden yalnızca kendisi düşer. Devir (ownerUid değişimi) kural
        düzeyinde yasak ve devralanın rızası gerekir — ayrı madde olarak
        bırakıldı.
      · **GÜVENLİK — yanlış hesap silme tuzağı:** onay ekranı `verify()`
        KULLANMIYOR, çünkü o `signIn(with:)` çağırıyor ve kullanıcı başka bir
        numara girerse oturum sessizce o hesaba geçip silme YANLIŞ HESABI
        silerdi. `reauthenticate(with:)` kullanılıyor ve numaranın oturumdakiyle
        aynı olduğu ayrıca denetleniyor.
      · **ONAY EKRANI RAKAMLA KONUŞUYOR:** "geri alınamaz" tek başına bilgi
        taşımıyor. Ekran "5 proje ve içindeki 74 dairenin tüm kayıtları…
        7 ortak erişimini kaybedecek" diyor.
      · Yerel temizlik: profil önbelleği (ad + E.164 telefon, KVKK) siliniyor —
        normalde bilerek tutuluyordu, hesap silinince gereklilik bitiyor.
      · Yol üstünde iki kusur: (a) demo kullanıcısının telefonu yoktu ve akış
        "Telefon numarası geçersiz" diyerek kullanıcıyı hiç yazmadığı bir şeyle
        suçluyordu; (b) silme bitince `RootView` tüm ağacı değiştirdiği için
        özet ekranı hiç görünmüyordu — kullanıcı düğmeye basıp kendini aniden
        giriş ekranında buluyordu. Özet artık oturumdan bağımsız taşınıyor.
      · 162/162 test. En kritik olanı: "ORTAK silince SAHİBİN PROJESİ DURUR" —
        silme fazla geniş yazılsaydı projeden ayrılan bir ortak müteahhidin
        bütün projesini götürürdü. İşlev YAYINDA.
- [x] 29. Davet deep link'i (WhatsApp bağlantısı çalışsın) — **TAMAM (15 Eki 2026)**
      · **KUSUR ORTAĞIN GÖRDÜĞÜ İLK EKRANDAYDI.** `InviteCode.link`
        `insaattakip.app/katil/<kod>` üretiyordu; o alan adı HİÇ ALINMAMIŞTI.
        Bağlantı WhatsApp'tan gönderiliyor ve davet edilen kişi uygulamadan
        önce başka hiçbir şey görmüyor — gördüğü tek şey 404'tü.
      · **ALAN ADI BEKLENMEDİ, VARSAYIM YANLIŞTI.** Madde 27 ile birlikte
        `insaattakip.app`e bağlı sayılmıştı; kullanıcı ayrı alan adı istemedi
        ("tüm uygulamalarım tek yerde gözüksün") ve iş `benav.com.tr/katil/`
        ile çözüldü. Bağımlılık sanılan şey aslında bir tercihmiş.
      · **KISA YOL SEÇİLDİ (`/katil/` — `/insaat-takip/katil/` DEĞİL) ve
        gerekçesi ÖMÜR:** kod 48 saat yaşıyor, yani gönderilmiş hiçbir
        bağlantı iki günden fazla geçerli değil. Adres kalıcı bir taahhüt
        olmadığı için ileride başka bir uygulama da davet linki isterse
        önek eklenebilir; bugün elindeki linki kıracak kimse yok. Kalıcı
        olsaydı namespace şart olurdu.
      · **ÜÇ YER BİRBİRİNE BAĞLI, İKİSİ BAŞKA DEPODA:** `InviteCode.link`,
        `vercel.json` → `/katil/:kod` yazması, `katil.html`in ayrıştırması.
        Ayrıştıkları an bağlantı yine 404 verir — yani bu maddenin kusuru
        geri gelir. `InviteCodeLinkTests` Swift tarafını kilitliyor; en
        değerlisi GİDİŞ-DÖNÜŞ testi (üretilen 200 kod bağlantıya çevrilip
        `sanitize` ile geri çözülüyor), çünkü üretim ile ayrıştırma ayrı
        yerlerde yazılmış ve aralarındaki sözleşme ancak denenerek kanıtlanır.
      · **SAYFA KODU HİÇBİR YERE GÖNDERMİYOR VE DOĞRULAMIYOR.** Doğrulama
        sunucuda, uygulamanın içinde (kurallar + `redeemInvite`). Burada bir
        doğrulama ucu açmak, davet kodlarının geçerliliğini HERKESE
        sorulabilir hâle getirirdi — deneme yanılmaya açık kapı. Sitede
        analitik betiği de yok, yani kod üçüncü tarafa gitmiyor; bir gün
        analitik eklenirse davet kodları URL olarak sızar ve bu uyarı
        `katil.html` içinde yazılı.
      · **ALFABE DENETİMİ, UZUNLUK DENETİMİ DEĞİL.** İlk hâli altı karaktere
        bakıyordu; `/katil.html` doğrudan açılınca temizlik "KATILH" üretiyor
        ve ziyaretçiye UYDURMA bir davet kodu gösterilecekti. Gerçek kodlar
        I/O/S/0/1 içermeyen alfabeden geldiği için katı denetim hiçbir
        geçerli daveti elemiyor. Yerelde yakalandı, yayına çıkmadan düzeltildi.
      · **SAYFA BEKLENTİ DE KURUYOR:** ortaklığın salt okur olduğu ve alıcı
        adlarının gösterilmediği yazılı. Ortak uygulamayı kurmadan ne
        göreceğini biliyor; "neden düzenleyemiyorum" sorusu daveti kabul
        ettikten sonra değil, önce cevaplanıyor.
      · **UNIVERSAL LINK YAPILMADI — bilinçli ve sıralama meselesi.**
        Bağlantıya dokununca uygulamanın doğrudan açılması için
        `apple-app-site-association` + Associated Domains yetkisi gerekiyor.
        (a) Yetki derlemeye eklenip App ID'de açılmazsa İMZALAMA BOZULUR,
        yani kullanıcının derlemesini kırar; (b) asıl mesele, davet edilen
        kişide uygulama genelde KURULU DEĞİL — davetin amacı bu. Yani web
        sayfası her hâlükârda birincil deneyim, Universal Link üstüne
        eklenen bir kolaylık. Tetik: App Store yayını + konsoldan Associated
        Domains açılması. Team ID hazır (`36HVD2S94X`).
- [~] 30. `PrivacyInfo.xcprivacy` + build numarası — **MANİFEST VE BUILD NO TAMAM**,
      Crashlytics madde 27'ye bağlandı (19 Ağu 2026)
      · **Manifest ZORUNLU hâle gelmişti:** Firebase Apple'ın "yaygın kullanılan
        üçüncü parti SDK" listesinde ve eklendiği an hem kendi imzalı manifesti
        hem uygulamanın kendi manifesti gerekiyor.
      · Beyanlar TAHMİNLE değil KODLA doğrulanarak yazıldı: kaynak "required
        reason API" listesine göre tarandı. Sonuç: yalnızca UserDefaults
        (CA92.1). Disk alanı, systemUptime ve aktif klavye API'leri hiç
        çağrılmıyor.
      · **Dosya zaman damgası beyanı GEREKMEDİ, çünkü erişim daraltıldı:**
        `DocumentStore` boyut için `attributesOfItem` çağırıyordu ve o API
        zaman damgalarını da döndürdüğü için Apple'ın listesine giriyor.
        Yalnızca boyut gerektiğinden `.fileSizeKey`e geçildi — kullanılmayan bir
        erişimi beyan etmek yerine erişimin kendisini daraltmak.
      · Toplanan veri türleri beyan edildi: telefon, ad, fotoğraf ve kullanıcı
        içeriği (iş kayıtları + ALICI ADLARI). Hiçbiri izleme amaçlı değil.
      · Paket doğrulandı: manifest Firebase'in kendi manifestlerinin yanında.
      · **BUILD NUMARASI — derleme içi betik ÇALIŞMIYOR ve sessizce
        çalışmıyordu.** Bir Run Script fazı eklendi; `ENABLE_USER_SCRIPT_SANDBOXING
        = YES` olduğu için kum havuzu `.git` okumasını engelledi, `git rev-list`
        BOŞ döndü ve numara hep 1 kaldı — hiçbir uyarı çıkmadan. Kum havuzunu
        kapatmak Apple'ın önerdiği güvenlik ayarını zayıflatmak olurdu; faz
        kaldırıldı ve numara derlemenin DIŞINDA üretiliyor:
        `npm run build:number` (git commit sayısı → `CURRENT_PROJECT_VERSION`).
        Betik sürümün GERİ GİTMESİNİ reddediyor (sığ klonda commit sayısı düşük
        çıkar; App Store küçük build numarasını kabul etmiyor).
        Doğrulandı: pakette `CFBundleVersion = 86`.
      · **KALAN — Crashlytics.** Bilinçli olarak madde 27'ye bağlandı: analitik
        eklendiği an App Privacy etiketi ve GİZLİLİK POLİTİKASI da güncellenmek
        zorunda, o da alan adına bağlı ve henüz yayında değil. Şimdi eklenirse
        politika onu kapsamadan yayına çıkmış olurdu.
- [x] 31. Erişilebilirlik paketi — **TAMAM (19 Ağu 2026)**
      · **EN AĞIR BULGU — büyük yazıda para rakamları kırpılıyordu ve kesilen
        parça TAM OLARAK BÜYÜKLÜK EKİYDİ:** "42,65 M ₺" → "42,...", yani 42 bin
        ile 42 milyon ayırt edilemiyordu. Bu, maddelerin çoğunda kovaladığımız
        "yanıltıcı rakam" sınıfı. Kırpma kaldırıldı; AX boyutunda karolar
        dikeye geçiyor (`AdaptiveTileRow`).
      · **KONTRAST — ironi buradaydı.** Eşik altındaki üç renk (textTertiary
        2,33:1 · textSecondary 3,57:1 · tabInactive 2,55:1) tam olarak KAPSAM
        NOTLARINDA kullanılıyordu: "kalan inşaat maliyeti düşülmemiştir",
        "sermaye henüz tutulmuyor". Rakamları dürüst kılan metinler
        uygulamanın en okunmaz metinleriydi. Tonlar AA'ya çekildi, hiyerarşi
        korundu; koyu zemindeki `.white.opacity(0.45)` (4,22:1) → 0,62 (6,68:1).
      · **`cornerRadius` İÇERİĞİ kırpıyor** (arka planı değil). Sabit
        `.frame(height:)` ile birleşince buton yazıları kesiliyordu ve boş
        durum kutularında yol gösterici cümlenin %42'si gidiyordu → `minHeight`.
      · **`CodeBadge` %100 bilgi kaybı veriyordu** — AX5'te yalnızca "..."
        görünüyordu, malzeme kodunun tamamı kayboluyordu. Kutu yazıyla birlikte
        ölçekleniyor (tavanlı).
      · **56 SF Symbol ikonu Dynamic Type'a hiç tepki vermiyordu**
        (`.font(.system(size:))` ölçeklenmiyor). Hepsi `iconFont` yardımcısına
        dönüştürüldü — ölçeklenir ama tavanlı, yoksa satır düzenleri dağılıyor.
      · **VoiceOver:** uygulamada TEK BİR etiket yoktu; 56 ikon-buton İngilizce
        sembol adıyla okunuyordu. Merkezî bileşenlerden kapatıldı (geri/kapat,
        13 sheet'in ✕'i, arama temizleme, fiş kaldırma, hesap menüsü, zil).
        Daire kartları tek öğe olarak gruplandı ve **satılan dairede yalnızca
        RENKLE taşınan durum** artık etikette geçiyor — renk körü kullanıcı için
        o bilgi hiç yoktu.
      · **Dokunma hedefleri 44pt'ye çıkarıldı**, görsel ölçüler korunarak
        (`.contentShape`): arama temizleme 16×16'ydı (asgarinin %13'ü), fiş
        kaldırma 30×30 ve GERİ ALINAMAZ bir işlem, başlık butonları 34×34.
      · Varsayılan boyutta tasarım BİREBİR korunuyor — simülatörde iki boyutta
        da doğrulandı.
      · **GERÇEK CİHAZDA VOICEOVER İLE DOĞRULANDI** (19 Ağu 2026, iPhone 13
        Pro): daire kartı TEK CÜMLE olarak okunuyor, "Satıldı" cümlede geçiyor
        ve uzunluk doğal. Kartın gruplanması ve renkle taşınan durumun
        seslendirilmesi bu maddenin en kritik iki düzeltmesiydi.
      · KALAN (küçük): AX5'te proje başlığı ve rol çipi kırpılıyor (krom öğe,
        bilgi kaybı değil); fiş küçük resimlerinin dokunma hedefi hâlâ 30–34pt.
        Diğer VoiceOver etiketleri (zil, hesap menüsü, geri, kapat) kodda
        yazılı ama cihazda tek tek DİNLENMEDİ.

---

### Faz 5 — Para zinciri denetimi (19 Ağu 2026)

Uçtan uca cihaz turunda taksit planında bir kusur bulununca (aşağıda 32),
**aynı sınıftan başka kusur var mı** diye dört mercekli bir tarama koşturuldu:
bölme/paylaştırma, türetilen rakamlar, tarih/vade, rapor/dışa aktarma.
Ajanlara kodu iddia etmek yerine **derleyip çalıştırma** aracı verildi
(`Kurus` ve `Installment` yalnız `Foundation` kullanıyor, tek başına
derlenebiliyor); ardından her bulguyu çürütmeye çalışan ayrı bir tur koşturuldu.

**ARANAN SINIF: toplamı doğru, detayı yanlış.** Her toplam denetiminden geçen
ama tek tek rakamları bozan hatalar. Bunlar sessizdir — ekranda tutarlı
görünürler. 32 numaralı kusur tam olarak böyleydi ve bu yüzden aylarca fark
edilmedi.

**18 ayrı bulgu çıktı; 5'i çürütme turundan geçti, 13'ü HENÜZ DOĞRULANMADI**
(tarama teslim edilmeden düştü). Doğrulanmamış olanlar "muhtemel" sayılmalı.

- [x] 32. **Taksit planı eşit bölünmüyordu** — **TAMAM (19 Ağu 2026)**
      · `Installment.plan` eşit taksitleri yüzde üzerinden üretiyordu:
        `byPercents: Array(repeating: 100 / count, count: count)`. `100 / count`
        TAM SAYI bölmesi — count=12'de 8, yüzde toplamı 96, bedelin %4'ü
        dağıtılmadan kalıyor ve "kalanı sona ekle" telafisi artığın TAMAMINI
        son taksite yüklüyordu.
      · Ölçülen: 12 taksitte son taksit **%50**, 36 taksitte **15 kat**,
        60 taksitte **41 kat** şişkin. Form 1...240 arası her sayıya izin
        veriyor; yalnızca 100'ün tam bölenlerinde doğru sonuç çıkıyordu —
        **240 seçenekten 231'i hatalı takvim üretiyordu.**
      · SESSİZ KALMA SEBEBİ: telafi satırı TOPLAMI tutturuyordu. Bozulan şey
        toplam değil, taksitlerin EŞİTLİĞİYDİ. Hiçbir toplam denetimi
        yakalayamazdı; ekranda hiçbir şey yanlış görünmüyordu.
      · ÇÖZÜM yüzdeyi düzeltmek değil, eşit bölmede yüzde kullanmayı bırakmak:
        `Kurus.split(_:into:)` eklendi. Yüzde bir ORAN aracıdır (ortak payları)
        ve tek gerçek çağrısı artık orası.
      · KANIT: 12.960 vaka koşturuldu (6 bedel × 3 kuruş artığı × 3 peşinat ×
        1...240 taksit) — toplam hatası 0, eşitlik hatası 0, taksitler arası en
        büyük fark 1 kuruş. Ayrıca **üretim verisinde** doğrulandı: 4.000.000 ₺
        bedel / 200.000 ₺ peşinat / 12 taksit → 8 adet 316.666,67 ₺ + 4 adet
        316.666,66 ₺.

- [x] 33. **Satış önizlemesi üçüncü yuvarlama noktasıydı** — **TAMAM (19 Ağu 2026)**
      · `rest.raw / Int64(installmentCount)` ile ayrıca hesaplanıyordu; ekranla
        veritabanının sessizce ayrışabildiği bir yer — ve gerçekten ayrışmıştı:
        plan son taksiti şişirirken bu satır DOĞRU eşit tutarı gösteriyordu.
        Ekran doğruyu söylüyor, kaydedilen plan başka şey saklıyordu; farkı
        "yaklaşık" kelimesi örtüyordu.
      · Artık `Kurus.split(rest, into:)` sonucunun ilk payı gösteriliyor.

- [x] 34. **Silmede `objectNotFound` arıza sayılıyordu** — **TAMAM (19 Ağu 2026)**
      · Görsel/belge silme yolu HESAPLAYARAK siliyor (uçuştaki yükleme yetim
        nesne bırakmasın diye). Doğal sonucu: hiç yüklenmemiş bir dosyada
        `objectNotFound`. Bu normal yol "silinemedi" diye günlüğe düşüyordu.
      · Cihaz turlarında tanılama günlüğü **"sessizlik = başarı"** varsayımıyla
        okunuyor; normal akışta düşen bir arıza satırı o varsayımı çürütür ve
        gerçek arızayı yanlış alarmların arasında kaybeder.

#### DOĞRULANMIŞ — çürütme turundan geçti

- [x] 35. **Satış kaydını düzenlemek taksit planını sessizce sıfırlıyor** (YÜKSEK)
      `Views/Project/Sheets/SaleFormSheet.swift:288`
      · `prefill()` kayıtlı planın taksit adedini ve ilk vadesini forma
        YÜKLEMİYOR; `installmentCount` 12 ve `firstDueDate = Date()`
        varsayılanlarında kalıyor. `save()` bu varsayılanları kaydediyor,
        `ProjectViewModel:1974` eski planı silip yenisini
        `downPayment: after.paidAmount` — yani BUGÜNE KADARKİ TÜM TAHSİLAT —
        ile kuruyor.
      · Alıcı adındaki bir yazım hatasını düzeltmek 36 aylık planı 12 aylığa
        çeviriyor, tüm vadeleri bugüne kaydırıyor ve **gecikmiş tahsilatı yok
        ediyor** (333.333,32 ₺ / 110 gün → 0 ₺).
      · GERİ ALINAMAZ: kullanıcı 36'yı ve orijinal vadeyi elle geri girse bile
        peşinat satırı tahsilatla kirlendiği için eski plan geri gelmiyor.
      · Plan toplamı her iki durumda da bedele birebir eşit kaldığı için hiçbir
        toplam denetimi yakalamıyor.
      · **TAMAM (20 Ağu 2026)** — satış düzenlemede plan korunuyor: prefill kayıtlı adedi/ilk vadeyi yüklüyor, peşinat eski planın sequence 0 satırından geliyor. Bulgudaki senaryo koşturuldu — yeniden kurulan plan orijinalle BİREBİR aynı.

- [x] 36. **"İlk vade" seçilen tarihe hiçbir taksit düşmüyor** (YÜKSEK)
      `Models/Installment.swift:155`
      · Vadeler `date(byAdding: .month, value: index + 1, to: firstDueDate)`
        ile üretiliyor — 1. taksit seçilen tarihin kendisine değil, BİR AY
        SONRASINA düşüyor. `firstDueDate` yalnızca peşinat satırına veriliyor;
        peşinat girilmemişse kullanıcının seçtiği tarih planın HİÇBİR yerinde
        yok.
      · Parametre adı, DatePicker etiketi ("İlk vade") ve özet metni üçü birden
        yanlış tarihi vaat ediyor → "yanıltıcı rakam yasak" ilkesinin ihlali.
      · NOT: ay sonu davranışı DOĞRU — çapa sabit olduğu için 31 Ocak'tan
        başlayan planda gün kırpılsa da sonraki aylarda 31'e dönüyor.
      · **TAMAM (20 Ağu 2026)** — planın İLK SATIRI artık firstDueDate'e düşüyor (peşinat varsa o, yoksa 1. taksit). 12.960 vaka: ilk-vade hatası 0.

- [x] 37. **`Kurus.cost` taşmada TUZAK atıyor — fiş formunda yazarken çökme** (YÜKSEK)
      `Models/Kurus.swift:59`
      · `Int64((quantity * Double(unitPrice.raw)).rounded())` — `guard
        quantity.isFinite` yalnızca NaN/sonsuzu eliyor, ÇARPIMIN Int64
        aralığında kalıp kalmadığını kimse denetlemiyor. Swift'te aralık dışı
        `Int64(Double)` sarmalanmaz, **TUZAK atar (SIGTRAP)** — yanlış rakam
        değil, ANINDA ÇÖKME.
      · İki tavan ayrı ayrı "güvenli" seçilmiş ama ÇARPIMLARI denetlenmemiş:
        `parseNumber` 1e12'ye, `parseMoney` 1e14 kuruşa kırpıyor; 1e12 × 1e14 =
        1e26, `Int64.max` = 9,22e18.
      · Çağrı yolu Kaydet düğmesi DEĞİL: `ReceiptSheet:70` `totalAmount` bir
        computed property ve `body` içinde okunuyor — **her tuş vuruşunda**.
        Kullanıcı daha kaydetmeden, alana yazarken uygulama kapanıyor.
      · Ayrıca 2^53 kuruş üstünde çökmeyen ama sessizce yanlış rakam üreten bir
        bant var (ölçüldü: 48 kuruş eksik, hiçbir uyarı yok).
      · **TAMAM (20 Ağu 2026)** — Kurus.cost taşmada DOYURUYOR, tuzak atmıyor. Sınır yuvarlanmış değer üzerinden denetleniyor. Doyurma seçildi çünkü parseNumber/parseMoney de kırpıyor.

- [ ] 38. Ortak kartındaki "Aradaki fark" — **ÇÜRÜTÜLDÜ (mekanizma gerçek, zarar değil)**
      `ViewModels/ProjectViewModel.swift:2153`
      · `share(of:)` beş ayrı `Kurus.split` çağırıyor ve modelde
        `dilim(A−B) ≠ dilim(A)−dilim(B)` gerçekten üretilebiliyor; ancak
        çürütme turu iddia edilen ZARARI doğrulayamadı. Kayıt olarak duruyor.

#### DOĞRULANMADI — tarama teslim edilmeden düştü, "muhtemel" sayılmalı

- [x] 39. **m² maliyetinin PAYDASI eksik** (YÜKSEK) `ViewModels/ProjectViewModel.swift:931`
      · Pay tüm projenin gideri, payda yalnızca **alanı GİRİLMİŞ** dairelerin
        alanı. Kendi doküman yorumu (satır 915-920) tersini söylüyor.
      · Ölçülen şişme: 12/20 daire girili → 1,7 kat; 4/20 → 5 kat; 1/20 → 20 kat.
      · `addProject` her daireyi `areaM2: nil` açıyor, yani müteahhit ilk alanı
        girdiği anda rakam bozuluyor — "1. gün" senaryosu.
      · Dashboard karşılaştırma tablosu kapsamı YAZMIYOR ve YAZAMAZ
        (`ProjectComparison` `missingCount` taşımıyor), üstelik tabloyu bu
        şişmiş rakama göre SIRALIYOR.
      · **TAMAM (20 Ağu 2026)** — rakam düzeltilemezdi (girilmemiş dairenin alanı bilinmiyor, madde 14 uydurma varsayılanları kaldırdı) — kapsam YAZILDI: tabloda 'N/M dairenin alanı girili' satırı + dipnotta sıralama uyarısı. ProjectComparison artık measuredCount/missingCount taşıyor.

- [x] 40. **Rapor "Malzeme gideri" ile Malzeme-Hareketleri.csv iki ayrı taban** (YÜKSEK)
      `Data/ProjectExporter.swift:85`
      · Ekran DEVİR + fişleri topluyor (`accruedCost = openingCost + entries`);
        CSV yalnız `materialLogs` geziyor, `openingCost` hiçbir satırda yok,
        kapsam notu da yok. Ölçülen kayıp: %90–%100.
      · Hiç fişi olmayan projede dosya HİÇ üretilmiyor → mali müşavir malzeme
        maliyeti diye 0 ₺ görüyor.
      · Aynı paylaşımdaki Yedek.json devri TAŞIYOR — iki dosya çelişiyor.
      · **TAMAM (20 Ağu 2026)** — devir kendi satırı olarak CSV'ye giriyor ('Devir' türü) ve dosya üretim koşulu da devri sayıyor — devri olup fişi olmayan projede dosya hiç üretilmiyordu.

- [x] 41. **Daireler.csv "Bedel"/"Kalan" satılmamış daireleri de dolduruyor** (YÜKSEK)
      `Data/ProjectExporter.swift:119`
      · Ekran `countsAsRevenue` ile yalnız satılanı sayıyor; CSV TÜM daireleri
        koşulsuz yazıyor. Boş daire `price` alanında liste fiyatı taşıyor.
      · Ölçülen: ekran "Kalan alacak 14,82 M ₺", CSV sütun toplamı 20,70 M ₺ —
        **%39,7 şişkin**. Sütun adı ekranla AYNI, kapsamı farklı, dosyada bunu
        söyleyen tek satır yok.
      · `scopeNote` yalnızca PDF'e giriyor, CSV'ye değil.
      · **TAMAM (20 Ağu 2026)** — sütunlar ayrıştırıldı: 'Liste Fiyatı' (tüm daireler) ile 'Satış Bedeli/Tahsil Edilen/Kalan Alacak' (yalnız satılan, countsAsRevenue ile birebir) ve 'Kapora' (rezerve dairenin gerçek nakdi).

- [x] 42. Fiş tarayıcı ÜÇÜNCÜ yuvarlama noktası açıyor (ORTA)
      `Views/Project/Sheets/ReceiptSheet.swift:376`
      · Fişten birim fiyat türetiliyor, sonra miktarla çarpılıyor: deftere geçen
        gider fişin toplamı DEĞİL. Ölçülen: 22.345,67 ₺'lik fiş → 22.350,00 ₺
        (fişte olmayan 4,33 ₺).
      · **TAMAM (20 Ağu 2026)** — sapma kaçınılmaz (kayıt miktar+birim fiyat saklayıp tutarı türetiyor) ama SESSİZ olması değil: 'Uygula' sonrası deftere geçecek tutar ve fişten farkı yazılı söyleniyor.

- [x] 43. Rapor özet kartının dört rakamı birbirini tutmuyor (ORTA)
      `Views/Project/ReportView.swift:177,186`
      · Her satır AYRI `compactMoney` yuvarlamasından geçiyor; ortağın kâğıt
        üstünde yaptığı çıkarma karttaki "net" ile tutmuyor. **Ortaklara
        dağıtılan PDF'te de aynı.**
      · **TAMAM (20 Ağu 2026)** — Fmt.exactMoney eklendi, kartın beş para satırı tam hassasiyete geçti. SIKLIK ÖLÇÜLDÜ: 200.000 rastgele dönem özetinde ortağın çıkarması %33,25 oranında tutmuyordu — her üç rapordan biri, tipik fark 10.000 ₺.

- [x] 44. CSV kaçışlaması satır sonunu kaçırıyor (ORTA) `Data/ProjectExporter.swift:70`
      · Swift'te `"\r\n"` TEK grapheme; `contains("\n")` **false** dönüyor.
        Excel'den kopyalanmış iki satırlık açıklama CSV'yi bozuyor.
      · **TAMAM (20 Ağu 2026)** — arama unicodeScalars üzerine alındı; \r\n Swift'te tek grapheme olduğu için contains("\n") false dönüyordu (ölçüldü).

- [x] 45. Malzeme-Hareketleri.csv satırı kendi içinde tutmuyor (ORTA)
      `Data/ProjectExporter.swift:58`
      · Miktar 2 ondalığa kırpılıyor, Tutar tam hassasiyetle yazılıyor;
        Excel'de `=Miktar*BirimFiyat` satırdaki Tutar'ı vermiyor.
      · **TAMAM (21 Ağu 2026)** — `quantity()` miktarı 2 ondalığa kırpıyordu, Tutar ise TAM miktardan hesaplanıyordu; Excel'de =Miktar*BirimFiyat satırdaki Tutar'ı vermiyordu. Dışa aktarma bir VERİ dosyası, kısaltma ekranın işi. Gerçek veride 18/18 satır artık kendi içinde tutuyor.

- [x] 46. Vade günü 09:00–12:00 arasında kurulan plan o günün hatırlatıcısını
      kaybediyor (ORTA) `Data/ReminderScheduler.swift:97` — çalıştırılmadı.
      · **TAMAM (21 Ağu 2026)** — kapı vadeye değil TETİKLEME ANINA taşındı; eleme prefix(maxDays)'ten önce yapılıyor (ölü gün kotadan yer yiyordu); vade bugünse ve 09:00 geçtiyse kısa gecikmeli telafi kuruluyor, teslim edilmişse tekrarlanmıyor. Madde 36'dan sonra bu vaka istisna değil VARSAYILAN olmuştu.

- [x] 47. Demo verisinde ay iki kez ekleniyor (ORTA)
      `Data/InMemoryProjectRepository+Seed.swift:522` — yorum "bir ay sonra"
      diyor, gerçek vade iki ay sonra.
      · **TAMAM (21 Ağu 2026)** — peşinat varsa firstDue artık satış günü. Önceden koşulsuz saleDate+1ay veriliyor, plan bir ay daha eklediği için taksitler İKİ ay sonra başlıyordu.

- [x] 48. `ProjectExporter.money` negatif kuruşta eksi işaretini yiyor (DÜŞÜK)
      `Data/ProjectExporter.swift:51` — `Kurus.kurus(-50)` → `"0,50"`.
      · **TAMAM (20 Ağu 2026)** — işaret ayrı tutuluyor; -1..-99 kuruş aralığında eksi kayboluyordu (ölçüldü).

- [x] 49. Küçük olanlar (DÜŞÜK): `partners(for:)` sıralamasız — artan kuruş
      çağrıdan çağrıya başka ortağa gidebiliyor (`ProjectViewModel:1014`);
      `DateInterval.contains` iki uçtan kapsayıcı, ay sınırındaki kayıt iki
      döneme birden sayılıyor (`ProjectViewModel:2667`); öğlen çapasının saat
      dilimi iddiası UTC−10 ve batısında bozuluyor (`Installment.swift:16`).
      · **TAMAM (21 Ağu 2026)** — 49a ÇÜRÜTÜLDÜ (sıra keyfî ama SABİT). 49b düzeltildi: `inPeriod()` yarı açık denetim, dört çağrı yeri — 1 Eylül 00:00 tarihli kayıt hem Ağustos hem Eylül özetine giriyordu. 49c: çapanın gerekçesi ölçülüp daraltıldı (koruma UTC+14…UTC−07, UTC−10'da kırılıyor) ve DateInterval gerekçesi kaldırıldı — o kusur artık kendi katmanında çözülü.

#### GERÇEK CİHAZDA DOĞRULANDI (21 Ağu 2026, iPhone 13 Pro, üretim Firestore)

Dosyalar cihazdan `devicectl device copy from` ile doğrudan çekildi (uygulamanın
`tmp` kabından) — maile hiç gerek kalmadı.

- **35 GEÇTİ.** Daire 1'in satış kaydında yalnızca alıcı adı değiştirilip
  kaydedildi. Denetim izi düzenlemeyi doğruluyor ("düzenlendi · Alıcı kaydı:
  kayıtlı → güncellendi"). Plan 13 satır kaldı, tutar/vade/sıra BİREBİR aynı.
  KRİTİK AYRINTI: taksit KİMLİKLERİ değişti, yani kod yıkıcı yolu gerçekten
  izledi (planı silip yeniden kurdu) ve buna rağmen aynı planı üretti — düzeltme
  "yeniden kurma"yı engellemiyor, GİRDİLERİNİ düzeltiyor.
  Eski kod aynı işlemde şunu üretecekti: peşinat satırı 450.000 ₺ (200.000
  yerine — biriken tahsilat peşinat sanılıyordu), aylık 295.833,34 ₺
  (316.666,67 yerine), vadeler 19'undan 21'ine kayacaktı.
- **36 GEÇTİ.** Peşinatsız yeni satışta (Daire 2) ilk taksit kullanıcının
  seçtiği 01.09.2026'ya düştü. Eski kodla 01.10.2026 olacaktı.
- **32 GEÇTİ.** İki planda da taksitler arası fark 1 kuruş, toplamlar bedele
  birebir eşit.
- **41 GEÇTİ.** Daireler.csv'nin üç sütunu ekranla birebir (Satış Bedeli
  7.857.500,00 · Tahsil Edilen 450.000,00 · Kalan Alacak 7.407.500,00).
  Ayrıca 145/2 demo verisinde eski davranış ölçüldü: "Kalan" %20,6 şişikti.
- **40 GEÇTİ.** Devri olmayan projede dosya üretilmemesi doğru. 145/2 verisinde
  yeni mantık ölçüldü: Devir 8.934.990 + Giriş 857.510 = 9.792.500 = ekran;
  eski davranışta kayıp %91,2 idi.
- **43 GEÇTİ** (hesaplanarak). Kullanıcının verisinde eski gösterim 5.000 ₺
  sapma üretiyordu (kart 7,77 M, ortağın çıkarması 7,775 M).
- **Dekont GEÇTİ.** Tahsilatın `receiptPath`i dolu — `paymentReceipts` kovası
  çalışıyor.

- **F (belge yükleme) GEÇTİ.** PDF yüklendi: 0,206 MB, `application/pdf`,
  `partnerVisible: false`, `storagePath` DOLU (bulut yolunun varlığı =
  yüklemenin tamamlandığının tek otoritesi). EN KRİTİK AYRINTI: Storage nesne
  adı Firestore belge kimliğiyle BİREBİR aynı ve UZANTISIZ —
  `projects/{pid}/documents/{docId}`. Çapraz servis kuralı
  `firestore.get(.../documents/$(docId))` ile kardeş belgeyi çözdüğü için bu
  şart; daha önce tam bu noktada elle yazılmış küçük harfli kimlikler yüzünden
  "Service call error" alınmıştı.
- **G (davet kodu) GEÇTİ.** Sunucu kodu üretti, `invites/{KOD}` otorite kaydı
  `expiresAt` (createdAt + 48 saat), `usedAt: null`, `projectId` ve `ownerUid`
  ile yazıldı; `redeemInvite` ikisini de İŞLEM İÇİNDE denetliyor
  (`code-used` / `code-expired`). Proje belgesindeki ayna yalnızca
  `{code, createdAt}` taşıyor — kod okuma üyelere kapalı kalsın diye bilerek.
  KALAN: gerçek bir KULLANIM denenmedi, ikinci bir telefon numarası gerekiyor.

**YÖNTEM NOTU — denetim izi bir doğrulama aracıdır.** İlk turda plan
değişmemişti ve bu düzeltmenin kanıtı sanılabilirdi; oysa `denetimIzi`de
"düzenlendi" kaydı YOKTU, yani işlem hiç yapılmamıştı. Değişmeyen veri,
düzeltmenin başarısı kadar adımın atlanmış olmasının da işaretidir.

#### DAVET AKIŞI — yetki modeli ilk kez ikinci bir kimlikle sınandı (21 Ağu 2026)

Davet kodunun gerçekten KULLANILMASI bugüne dek hiç denenmemişti. Emülatörde
iki gerçek telefon kimliği üretilip `redeemInvite` uçtan uca koşturuldu
(23 denetim). Doğrulananlar: ortak katılmadan projeyi okuyamıyor; davet kaydı
istemciye tamamen kapalı; yabancı başkasının projesine kod üretemiyor;
katıldıktan sonra `memberUids` güncelleniyor; **alıcı kimliği ortağa kapalı**
(madde 18'in asıl sınavı); ortak başkası adına proje kuramıyor; kod tek
kullanımlık; süresi dolan reddediliyor; ortak kaydı hisse 0 ile yazılıyor.

- [x] 51. **`redeemInvite` idempotan değildi** — **TAMAM (21 Ağu 2026, yayında)**
      · Üyelik denetimi (`zaten üyeyse başarıyı tekrar döndür`) `usedAt`
        kapısının ARKASINDAYDI. Kullanıcı kodu kullanıp üye olduğu an kod
        harcanıyor, aynı bağlantıya ikinci dokunuşta "bu kod kullanılmış"
        hatası alıyordu — az önce kendisi katılmışken.
      · Ağ yeniden denemesinde de aynısı: çağrı sunucuda başarılı olup yanıt
        kaybolursa kullanıcıya katılamadığı söyleniyordu. O dal işlevin
        İDEMPOTANS çıkışıydı ve kapının arkasında işe yaramıyordu — üstelik
        kendi yorumu tam bu durumu gerekçe gösteriyordu.
      · Denetim kapının ÖNÜNE alındı. Güvenlik zayıflamıyor: üye OLMAYAN biri
        harcanmış kodu hâlâ kullanamıyor.
      · **NEDEN TESTLERDEN KAÇTI:** "ikinci dokunuş HATA DEĞİL" adlı mevcut
        test İKİ FARKLI kod kullanıyordu (TWICE1 → TWICE2), yani "zaten üye
        olan kişi YENİ bir kod kullanıyor" senaryosunu sınıyordu. Yorumu "aynı
        bağlantıya iki kez dokunmak" dediği hâlde o vaka hiç sınanmamıştı.
        **Testin adı kapsamından fazlasını vaat ediyordu.** İki test eklendi;
        164 test geçiyor.
      · KALAN: ortağın EKRANDA ne gördüğü hâlâ görülmedi — ikinci fiziksel
        cihaz + Firebase test numarası gerekiyor.

#### REGRESYON DENETİMİ — düzeltmeler beş kusur üretmişti (21 Ağu 2026)

Bu oturumun 13 düzeltmesi dört mercekli bir denetimden geçirildi. Sonuç edepli
değil: **düzeltmelerin kendisi beş kusur üretmiş.** Hepsi derleyip
çalıştırılarak doğrulandı ve kapatıldı.

1. **`Kurus.split(byPercents:)` taşmada ÇÖKÜYORDU (SIGTRAP).** 37 düzeltilirken
   `Kurus.cost` `Int64.max`a doyurmaya başladı; o değer ortak paylarına
   aktığında `magnitude * Int64(yüzde)` taşıyor. Yani çökme ortadan kalkmamış,
   İKİNCİ KEZ yer değiştirmişti (ilkinde `abs(Int64.min)`e taşımıştım).
   `multipliedFullWidth`/`dividingFullWidth` ile 128 bitte yapılıyor.
2. **Devir satırı `openingOut` taşımıyordu** — dosyadan okunan kalan stok
   şişiyordu; üstelik "Devir" satırının varlığı eksikliği sorgulanamaz
   kılıyordu.
3. **"Tutar" sütunu çıkış fişlerini de sayıyordu** — ekrandaki malzeme gideri
   `openingCost + GİRİŞ`; sütun toplamı ayrışıyordu.
4. **"Liste Fiyatı" satılan dairede satış bedelini tekrar ediyordu** —
   `saveSale` satılan dairede `price`ın üstüne satış bedelini yazıyor.
5. **Fiş sapma mesajı (42) sapmayı yutuyordu** — `Fmt.money` tam liraya
   yuvarladığı için 0,33 ₺ sapmada "fişten 0 ₺ fazla" diyordu; sessiz sapmayı
   engellemek için yazılan cümle sapmayı kendi içinde sessizce yutuyordu.
   Ayrıca çift " ₺". `Fmt.exactMoney`e geçildi.

Ayrıca **35'in yan etkisi**: `saveSale` peşinatı kayıtlı plandan almaya
başlarken ekranın önizlemesi güncellenmedi; ekran "aylık 50.926 ₺" derken
veritabanına 83.333 ₺ giriyordu — madde 33'ün kapattığı kusurun geri açılmış
hali.

**DERS: bir çökmeyi doyurmayla kapatmak, üretilen sınır değerin aktığı HER
YOLU denetlemeyi gerektiriyor.** `Int64.max` ve `Int64.min` sıradan sayılar
değil; `abs`, çarpma ve toplama onları tuzağa çeviriyor. İki kez aynı hataya
düştüm: önce `abs(Int64.min)`, sonra `magnitude * yüzde`.

#### Bu turun yöntem dersi

**Ekrana bakarak bulunamayacak kusurlar var.** 32 numaralı hata üretim
verisinde bile "toplam tutuyor" diyordu ve gözle bakıldığında doğruydu.
Yakalanmasının tek yolu mantığı uygulamadan söküp 12.960 girdiyle koşturmaktı.

**Swift tarafında hâlâ HİÇ birim testi yok** — yalnızca kurallar ve Cloud
Functions için JS testleri var. Para mantığı bugüne dek hiç otomatik
sınanmamış. Kalıcı bir test hedefi kurmak sıradaki iş olmalı; bu turda
kullanılan tek başına derleme yöntemi (`Kurus` + `Installment` + `Shim`)
o hedefin çekirdeği olabilir.

- [x] 50. **Taksit planını gösteren ekran yok.** Müteahhit daireyi 12 ay
      vadeyle satıyor ve o 12 vadeyi listeleyen hiçbir ekran yok. Plan yalnızca
      üç yerde yüzeye çıkıyor: gecikmiş tahsilat listesi (yalnız VADESİ GEÇMİŞ
      olanlar), vade bildirimleri, ve JSON yedeği. "Bu dairenin ödeme takvimi
      ne?" sorusunun cevabı ancak yedek dosyası açılarak bulunabiliyor.
      Bu turda 32'nin düzeldiğini gözle doğrulamak da bu yüzden mümkün olmadı.
      · **TAMAM (21 Ağu 2026)** — daire detayında, tahsilat defterinin ÜSTÜNDE: plan BEKLENENİ, defter GERÇEKLEŞENİ gösteriyor.
      · **MAHSUP TEK KAYNAĞA ALINDI:** aynı FIFO döngüsü `Installment.status` ve `ReminderScheduler` içinde iki kez yazılıydı, ekran üçüncüsünü gerektirecekti. `Installment.settle(_:collected:)` eklendi, her iki mevcut çağıran ona bağlandı.
      · Tutarlar `Fmt.exactMoney` ile — `compactMoney` olsaydı 316.666,67 ₺ '317 B ₺' görünürdü ve ekranın varlık sebebi tam olarak gerçek takvimi göstermek.
      · Kırpma sessiz değil: 6'dan fazla vadede kaç vadenin gizlendiği yazılı ve DOKUNULDUĞUNDA açılıyor.
      · **SİMÜLATÖRDE DOĞRULANDI** (Daire No 5): ekrandaki '3 vade gecikti · 577.500 ₺' Daireler sekmesindeki gecikme rakamıyla birebir aynı; FIFO doğru (peşinat+1. taksit ödendi, 2. kısmi, 3. açık); madde 47'nin düzeltmesi de görünür (peşinat satış gününde).
      · **GERÇEK CİHAZDA ÜRETİM VERİSİYLE DOĞRULANDI** (21 Ağu 2026):
        Daire 1'in 12 taksitlik planı listelendi. 1. taksit 'Kısmi · kalan
        66.666,67 ₺' gösteriyor — 450.000 ₺ tahsilatın 200.000'i peşinatı
        kapatmış, kalan 250.000'i 1. taksidin 316.666,67 ₺'sine gitmiş.
        Madde 32'nin ayrımı ilk kez EKRANDA görünür: 1-8. taksit ...,67 ve
        9-12. taksit ...,66. '+7 vade daha' açıcısı da çalışıyor ve 'İlk 6
        vadeyi göster' ile geri dönüyor.

---

### Faz 6 — Uçtan uca durum analizi (21 Ağu 2026)

Faz 5 bittiğinde "kodla çözülecek iş kalmadı" noktasına gelinmişti. Bunun
doğru olup olmadığını sınamak için altı mercek modül modül kodu, orijinal 86
bulguyu ve testleri okuyup **214 ayrı yetenek** çıkardı; ardından bir tamlık
eleştirmeni "hiçbir merceğin sormadığı ne var" diye baktı.

**ÖLÇÜM — iki farklı yüzde, ikisi de doğru:**

| | oran | neyin ölçüsü |
|---|---|---|
| Yol haritası (Faz 0–5) | %94 | yapmaya KARAR VERDİĞİMİZ iş |
| Yetenek envanteri | %65 | ürünün VAAT ETTİĞİ iş |

Aradaki 29 puan, yol haritasının kapsam dışı bıraktığı alanlar. Modül dağılımı:
daire/satış %80, malzeme/gider %71, ortak/yetki %70, rapor/dışa aktarma %64,
giriş/hesap/belge %59, altyapı/yayın/erişilebilirlik %47.

**ASIL BULGU DOĞRULAMA TARAFINDA: 214 yeteneğin 126'sı (%59) hiçbir düzeyde
doğrulanmamış** — ne birim testi, ne emülatör, ne cihaz. Faz 5'te bulunan 19
kusurun tamamı tam olarak o bölgeden çıkmıştı. Kod hacmi sorun değil (17.297
satır, 11 gün); KANIT hacmi sorun.

**KAYIT DÜZELTMESİ — madde 28:** "Hesap silme akışı TAMAM" diye işaretlenmişti
ama doğrulama notu yalnızca emülatör testlerinden söz ediyor. Simülatör
`FakeAccountDeletionService` kullanıyor (AppState.swift:114), yani gerçek
`reauthenticate` + gerçek silme yolu BİR KEZ BİLE koşmadı. Sunucu tarafı
test edilmiş, istemci yolu edilmemiş — ve bu App Store 5.1.1(v) zorunluluğu.
Aşağıda madde 68 olarak açıldı.

#### Bu turda kapatılanlar

- [x] 52. **Fiş düzenlemek miktarı yuvarlıyordu** — **TAMAM (21 Ağu 2026)**
      · Form `Fmt.qty` ile dolduruluyordu ve o `rounded()` uyguluyor. 12,5 m³
        betonun fişi açılınca kutuda "13" beliriyor, kaydedince gerçekten 13 m³
        oluyordu. Denetim izi de aynı yuvarlanmış metni kullandığı için satır
        "13 m³ → 13 m³" görünüyor, kaybın izi bile kalmıyordu. Aynısı daire
        alanında da vardı: 111,55 m² → 112.
      · İRONİ: `ReceiptSheet`in 259. satırı birim fiyatı `Fmt.moneyText` ile
        dolduruyor ve o fonksiyon TAM BU HATAYI önlemek için yazılmış — yorumu
        "`qty` kullanılamaz, o `rounded()` uygulayıp ondalığı atıyor" diyor.
        Ders paraya uygulanmış, YAN SATIRDAKİ miktara uygulanmamış.
      · `Fmt.qtyText` eklendi; `Fmt.qty` gösterimde yuvarlamaya devam ediyor.

- [x] 53. **Miktar ayrıştırıcısı ondalık noktayı yutuyordu** — **TAMAM (21 Ağu 2026)**
      · `parseQuantity` doğrudan `parseNumber`a bağlıydı ve o TÜM noktaları
        koşulsuz siliyor: cihaz dili Türkçe değilse "12.5" → 125, sessiz 10 kat
        hata. `parseMoney` bu kusur için düzeltilmiş ve yorumu "sessiz 100 kat
        hata" diye anlatıyor; miktar tarafı atlanmıştı.
      · Kural paradan FARKLI olmak zorunda: parada ondalık en fazla 2 hane,
        miktarda 12,345 m³ geçerli. Yeni kural ayraç sayısına ve konumuna
        bakıyor. Rakam süzgeci ASCII'ye bağlandı (`Character("²").isNumber`
        Swift'te TRUE ve alan m² yazımına açık).
      · 7 test eklendi, gidiş-dönüş testi dahil. 26 Swift testi geçiyor.

#### A — MİMARİ (her şeyden önce gelir)

Bu beşi özellik boşluğu değil; hepsi ürünün tamamını etkiliyor ve üstüne yeni
özellik koymak borcu büyütüyor.

- [x] 54. **Veri hiç tazelenmiyor.** `addSnapshotListener` kod tabanında SIFIR
      kez geçiyor, `refreshable` sıfır, `scenePhase` sıfır. `refresh()` yalnızca
      `RootView.swift:57`deki `.task(id:)` içinden, yani pratikte soğuk açılışta
      çağrılıyor. Ortak, yöneticinin girdiği satışı görmek için uygulamayı
      tamamen kapatıp açmak zorunda ve bunu ona söyleyen hiçbir şey yok.
      **Ürünün ortağa verdiği şeffaflık vaadi tam burada kırılıyor.**
      · **TAMAM (21 Ağu 2026)** — üç parça: `lastLoadedAt` (son BAŞARILI yükleme), `scenePhase` ile ön plana geçişte yenileme, ve `.refreshable` (ProjectDetailView'da tek yerde; ortam üzerinden indiği için beş sekme de yakalıyor).
      · **EKRAN TAZELİK KONUSUNDA YALAN SÖYLÜYORDU:** alt başlık `Fmt.clock()`u varsayılanıyla çağırıyordu, yani o anki saati yazıyordu. Veri ne kadar eski olursa olsun 'Bugün 14:32 güncellendi' diyordu. Artık 'az önce' / '09:15'de' / 'dün' / 'sunucudan henüz yüklenmedi'.
      · **CANLI DİNLEYİCİ BİLEREK EKLENMEDİ:** `load()` her görünür proje için 13 koleksiyonun tamamını çekiyor; dinleyici bunu sürekli açık tutmak olurdu. Gerçek zamanlı senkron madde 58 (limit/sayfalama) ile BİRLİKTE ele alınmalı.
      · KAPSAM: iki kişi aynı anda bakarken hâlâ birbirinin değişikliğini kendiliğinden görmüyor. Kapanan şey 'veri yalnızca soğuk açılışta geliyor' ve 'ekran tazelik konusunda yalan söylüyor'.

- [~] 55. **Çakışma denetimi yok — son yazan kazanır.**
      `FirestoreProjectRepository.stage()` her tür için `batch.setData(...)`
      çağırıyor: merge yok, `updatedAt` önkoşulu yok, transaction yok. Madde 19
      yalnızca TÜRETİLEN malzeme alanlarını kodlamayarak çakışmayı çözmüştü;
      daire, tahsilat, taksit, gider, ortak, belge ve denetim kaydı hâlâ açık.
      İki cihaz aynı projeyi düzenlerse biri diğerini SESSİZCE siliyor.
      · **TEMEL ATILDI (21 Ağu 2026), ÖNLEME AÇIK.**
      · RİSK YENİDEN ÇERÇEVELENDİ: ortaklar SALT OKUNUR (14 kural sahip yazması istiyor, üye yazması sıfır), yani çakışma iki farklı kişi değil AYNI KİŞİNİN İKİ CİHAZI demek. En gerçekçi hali kuyruk: çevrimdışı telefon saatlerce yazma biriktirip bağlanınca iPad'deki daha yeni değişikliği eziyor.
      · Her yazma artık `updatedAt` (SUNUCU zamanı), `updatedBy` (uid) ve `updatedFrom` (oturum) taşıyor. Tek kaldıraç noktası `encode()`; fotoğraf belgeleri ayrıca damgalandı. Bugüne kadar bir belgeye en son ne zaman ve hangi oturumdan yazıldığı HİÇBİR YERDE yazılı değildi.
      · **AÇIK KALAN:** önleme (transaction + sürüm önkoşulu) ve çakışmanın kullanıcıya GÖSTERİLMESİ. Önleme toplu yazmanın atomikliğini bozar — satış + taksitler + denetim kaydı bugün TEK partide gidiyor ve o güvence korunmalı. Ayrı bir iş olarak ele alınmalı.
      · Riskli kısım sınandı: modellerin tanımadığı alanlar çözümlemeyi düşürseydi tek belge tüm uygulamayı boşaltırdı (madde 56). Birim testi var; gerçek yazma yolu emülatörde AYRICA doğrulanmadı.

- [~] 56. **Tek bozuk belge tüm veriyi görünmez yapıyor; şema sürümü yok.**
      `fetch` (FirestoreProjectRepository.swift:353) tek çözülemeyen belgede
      fırlatıyor, `apply` hiç çalışmıyor, ekranda hiçbir proje kalmıyor.
      `schemaVersion`/`migration` kavramı yok — bir alan tipi değişirse eski
      kurulumlar boş ekran görür. (Madde 12'de `areaM2` göçü elle yazılmıştı;
      ikinci bir göç için altyapı yok.)
      · **YARIÇAP DARALTILDI (21 Ağu 2026), ŞEMA SÜRÜMÜ AÇIK.**
      · Yalıtım belge düzeyinde DEĞİL proje düzeyinde: bozuk belgeyi atlamak toplamları sessizce yanlış gösterirdi (gerekçe `decode`in başında yazılı). Etkilenen proje bütünüyle dışarıda kalıyor ve `failedProjects`e yazılıyor.
      · Listeden SESSİZCE EKSİLMİYOR: dashboard'da kalıcı şerit kaç projenin düştüğünü, hangileri olduğunu ve 'rakamları toplamlara DAHİL DEĞİL' uyarısını yazıyor.
      · AÇIK: `schemaVersion` ve göç altyapısı yok. Bir alan tipi değişirse eski kurulumlar etkilenen projeyi kaybeder — artık tümünü değil.

- [x] 57. **Yükleme hatası ile "hiç projen yok" ekranı BİREBİR aynı.**
      `refresh()` hatayı sönümlü bir toast'la söylüyor, `latest` boş kaldığı
      için kullanıcı "Henüz projen yok" karşılama kartını görüyor. Kural reddi,
      eksik indeks ya da bozuk belge durumunda üründeki en korkutucu cümle
      gösteriliyor: VERİN YOK. "Tekrar dene" yolu da yok.
      · **TAMAM (21 Ağu 2026)** — `loadError` ayrı bir durum. Hata ekranı SEBEBİ yazıyor, 'verilerin duruyor' diye güvenceliyor ve 'Tekrar dene' veriyor; geri dönüş yolu hiç yoktu.
      · Simülatörde `-backend firestore` ile (sahte kimlik + gerçek Firestore) hata yolu tetiklenip ekran GÖRÜLDÜ.

- [~] 58. **Limit, sayfalama ve tembel liste yok.** `load()` görünür her proje
      için 13 koleksiyonun TAMAMINI çekiyor; `.limit(` kod tabanında sıfır.
      Listeler `ScrollView { VStack { ForEach } }` — tek bir `LazyVStack`/`List`
      yok (desen biliniyor: `SitePhotosView` `LazyVGrid` kullanıyor). Bugün 12
      daireyle görünmüyor, üç yıllık projede görünür.
      · **KISMEN TAMAM (21 Ağu 2026)** — iki parça kapandı, biri açık.
      · **Hareket akışı** sunucuda `order(by: timestamp, desc).limit(200)` ile sınırlandı. Bonus kusur: başlık 'son 7 gün' diyordu ama `activities(filter:for:)` HİÇBİR tarih süzgeci uygulamıyordu — tüm geçmiş 'son 7 gün' başlığı altında listeleniyordu. Başlık artık gösterileni sayıyor ve sınıra dayanınca '(en yeniler)' yazıyor.
      · **Altı liste LazyVStack'e geçti:** malzeme, daire, gider, hareket geçmişi, ortak, belge. Simülatörde düzen bozulmadığı doğrulandı.
      · **AÇIK KALAN — toplamları besleyen koleksiyonlar sınırlanamadı.** malzemeHareketleri, giderler, tahsilatlar, taksitler ve daireler para toplamlarının ham kaynağı; limit koymak rakamları SESSİZCE yanlış yapardı. `auditEntries` de sınırlanamaz (yedeğe `denetimIzi` olarak giriyor). Gerçek çözüm sunucu tarafı toplama (Firestore aggregation); saklanan toplam ilkeye aykırı. **Canlı dinleyici tartışması bu iş bitmeden açılmamalı** — sınırsız koleksiyona dinleyici, sınırsız okuma demek (bkz. madde 54 notu).

#### B — GÜNLÜK KULLANIMI ENGELLEYENLER

- [x] 59. **Devir stoğu girilemiyor.** `openingIn/Out/Cost` yalnızca demo
      tohumunda atanıyor; `addProject` her kalemi sıfırla açıyor. Yarısı bitmiş
      şantiyede eldeki malzeme ancak sahte geçmiş tarihli fişle yazılabiliyor.
- [~] 60. **Proje silinemiyor, arşivlenemiyor, kapatılamıyor.** İlk kurulan
      "deneme" projesi sonsuza dek dashboard'da, portföy toplamlarında ve
      karşılaştırma tablosunda.
- [x] 61. **Daire eklenemiyor/silinemiyor, toplu düzenleme yok.** 12 yerine 14
      girildiyse dönüş yolu yok (proje de silinemediği için baştan başlanamıyor).
      20 daireli blokta aynı tip ve m² 20 kez elle giriliyor; düzenleme ekranına
      yalnızca karta BASILI TUTARAK ulaşılıyor.
- [x] 62. **Çok kalemli irsaliye girilemiyor.** `addReceipt` tek `materialId`
      alıyor; çimento+kum+demir taşıyan tek fiş üç ayrı kayıt ve üç ayrı kamera
      çekimi demek. Haftada 20-30 fiş giren müteahhit için en büyük sürtünme.
- [~] 63. **Fiş ve dekont yalnızca KAMERADAN.** Havale dekontu bankanın ekran
      görüntüsü olarak galeride, fatura PDF olarak e-postada duruyor; ikisi de
      eklenemiyor. Tek yol ekrandaki dekontun fotoğrafını çekmek.
- [x] 64. **Gider ve tahsilat düzenlenemiyor; tahsilat silme ONAYSIZ.** Yanlış
      tutar sil-yeniden gir demek ve belge/dekont o anda kalıcı gidiyor. Malzeme
      fişinde onay diyaloğu var, tahsilatta yok — aynı ürün içinde tutarsız.
- [x] 65. **Altıncıdan sonraki ödemeler hiçbir yerden görülemiyor.**
      "+ N ödeme daha" düz metin, dokunulmuyor. 36 aylık taksitli satışta
      ödemelerin çoğu erişilemez. (Madde 50'de plan tarafı açılır yapıldı,
      tahsilat defteri aynı düzeltmeyi almadı.)
- [~] 66. **Ortak yönetimi eksik:** ayrılan ortağın erişimi KESİLEMİYOR
      (ne ekran ne fonksiyon var), üretilen kod geri alınamıyor ve "Yeni Kod"
      eskisini öldürmüyor, yönetici kodun kullanılıp kullanılmadığını göremiyor
      (`usedAt` okunması herkese kapalı `invites` koleksiyonunda kalıyor).
- [x] 67. **Rezerve dairede alıcı adayının adı yazılamıyor** — `buyerName`i
      yalnızca `saveSale` yazıyor ve o daireyi koşulsuz satıldıya çeviriyor.
      · **TAMAM (21 Ağu 2026)** — `updatePayment` ve `updateExpense` yazıldı (`updateReceipt` deseni: alan alan denetim izi, değişiklik yoksa yazma yok). `paidAmount` elle yazılmıyor, `recalculateCollected` türetiyor.
      · Formlar `Fmt.moneyText` ile dolduruluyor, `Fmt.money` ile DEĞİL — madde 52'nin miktar tarafındaki yuvarlama tuzağından baştan kaçınıldı.
      · **SİLME ONAY SORUYOR:** diyalog hangi kaydın gittiğini yazıyor ve dekont/belge varsa 'o da silinecek' diye ayrıca söylüyor. Malzeme fişinde onay vardı, tahsilat ve giderde yoktu.
      · Simülatörde doğrulandı: menü, onay diyaloğu (Vazgeç ile kayıt korundu) ve düzenleme sheet'i (kayıtlı değerlerle doldu). GİDER tarafı kod olarak aynı desen ama görsel olarak doğrulanmadı.
      · **TAMAM (21 Ağu 2026)** — '+ N ödeme daha' artık dokunulabilir ve açılıyor; madde 50'de taksit planı için yazılan desenin aynısı. 36 aylık taksitli satışta ödemelerin çoğu uygulamada hiçbir yerden görülemiyordu; tek yol yedek dosyasını açmaktı.
      · **ARŞİV TAMAM (21 Ağu 2026), SİLME AÇIK.**
      · Sıra bilinçli: bitmiş projeyi silmek mali kayıt kaybı demek (vergi/muhasebe için rakamlar durmalı). Asıl şikâyet — toplamların kirlenmesi — arşivle çözülüyor ve arşiv GERİ ALINABİLİR.
      · `Project.archivedAt` eklendi; `phase` DEĞİL, ayrı alan (phase inşaat aşaması, arşiv yaşam döngüsü). `visibleProjects`e dokunulmadı — o üyelik kümesi; `activeProjects`/`archivedProjects` eklendi. `portfolio` ve `comparisons` aktifleri topluyor.
      · Arşiv GİZLENMİYOR, katlanıyor ve kapsamı yazılı.
      · YAN DÜZELTME: alt başlık `visibleProjects` sayıyordu, portföy aktifleri — arşivleyince aynı ekranda iki farklı proje sayısı çıkıyordu.
      · Simülatörde doğrulandı: portföy 5→4 projeye ve 134,78 M→92,13 M ciroya düştü, karşılaştırmadan çıktı, arşiv bölümü kapsam notuyla açıldı.
      · AÇIK: proje SİLME. `deleteAccount`un `recursiveDelete` + Storage önek silme mantığı hazır; ayıklanıp `deleteProject` callable yapılabilir.
      · **GALERİ TAMAM (21 Ağu 2026), PDF AÇIK.**
      · Galeri deseni projede ZATEN vardı (şantiye ve daire görselleri), yalnızca fiş/dekont/gider yoluna uygulanmamıştı.
      · DÜĞME değil DAVRANIŞ ortaklaştırıldı: üç ekranın düğme görünümü farklı, ortak bileşen tasarımı bozardı. `.receiptSource(isPresented:image:)` değiştiricisi yazıldı; düzen aynı.
      · `onPicked` geri çağrısı OCR'ı da besliyor — yalnızca kameradan gelen kareye çalışsaydı galeriden eklenen dekont ikinci sınıf olurdu.
      · Galeriden gelen kare de 1200px'e indiriliyor (kamerayla aynı yol).
      · Simülatörde uçtan uca doğrulandı.
      · AÇIK: PDF fatura. `ImageStore` JPEG tutuyor, PDF `DocumentStore`un işi; fiş akışına sokmak dönüştürme ya da ayrı depolama yolu gerektiriyor.
      · **ORTAK ÇIKARMA TAMAM (21 Ağu 2026)** — kod iptali ve kod durumu açık.
      · CLOUD FUNCTION GEREKMEDİ: kural zaten izin veriyordu (`projects` update ve `partners` delete sahibe açık). Eksik olan istemcideki eylemdi.
      · İki yazma TEK partide: `memberUids`ten çıkarma + ortak kaydının silinmesi. Ayrı gitselerdi ara durum kalırdı.
      · Kurucu çıkarılamıyor (kural zaten reddederdi); onay metni bunun bir ERİŞİM İPTALİ olduğunu yazıyor.
      · İki kural testi eklendi (sahip çıkarabilir / ortak çıkaramaz) — izin ileride sessizce kapanmasın diye. 166 emülatör testi geçiyor.
      · AÇIK: davet kodu İPTALİ (`invites` kuralı `update, delete: if false`; aynayı temizlemek sahte güvenlik olur) ve kodun kullanılıp kullanılmadığının görünmesi (`usedAt` istemciye kapalı). İkisi de sunucu işi. NOT: kodlar tek kullanımlık olduğu için çıkarılan ortak eski kodla geri DÖNEMEZ; iptal sorunu sızmış kullanılmamış kodlarla ilgili.
      · **TAMAM (21 Ağu 2026)** — alan 'Daire Bilgisini Düzenle' formunda, YALNIZCA rezerve durumunda. Satılan dairede gösterilmiyor: orada kimlik satış formunun işi ve iki yazma yolu belirsizlik yaratırdı.
      · KVKK yolu birebir korundu: ad `buyers/{apartmentId}` belgesine yazılıyor (madde 18), ekranda 'yalnızca yöneticiye görünür' yazılı.
      · **DENETİM İZİNE AD YAZILMIYOR.** `auditEntries` kuralı ORTAĞA okuma veriyor; adı oraya koymak madde 18'i arka kapıdan açardı. 'Alıcı adayı: yok → kayıtlı' yazılıyor, ad değil.
      · TEST BİR VARSAYIMI ÇÜRÜTTÜ: 'rezerveden çıkarsa temizle' dalı ULAŞILAMAZDI — `isCommitted` koruması bu geçişi zaten reddediyor ve temizlik `cancelSale`de. Ölü dal kaldırıldı.
      · Dört test eklendi (ad sızmıyor / geçiş reddediliyor / iptal kimliği bırakıyor / ortak yazamıyor). 38 Swift testi geçiyor.
      · **TAMAM (21 Ağu 2026)** — model tarafı zaten hazırdı (`recalculate` 'devir + fişler' diye topluyor, CSV'ye madde 40'ta 'Devir' satırı eklenmişti); eksik olan tek şey GİRİŞ YOLUYDU.
      · Devir bir HAREKET DEĞİL, açılış bakiyesi: ayrı sheet'ten giriliyor, hareket listesinde görünmüyor, fiyat geçmişine girmiyor.
      · **DEĞİŞTİRME, EKLEME DEĞİL** — düzeltmek isteyen kullanıcı ikinci kez girince miktar iki katına çıkmasın. Form mevcut değerlerle doluyor ve 'üstüne yazılır' uyarısı ekranda.
      · Giriş noktası Giren/Kullanılan/Kalan kutularının altında (o rakamların anlamını devir belirliyor) ve düğme kayıtlı devri YAZIYOR.
      · Stoğu eksiye düşüremiyor: kayıtlı çıkışlar devirden besleniyor olabilir, devri küçültmek eksi kalan üretirdi.
      · Dört test eklendi. 42 Swift testi geçiyor.
      · **TAMAM (21 Ağu 2026)** — MODEL DEĞİŞMEDİ, değişmemeliydi: her malzemenin stoğu ve maliyeti ayrı izlenmek zorunda, tek fişteki üç kalem modelde üç kayıttır. Sorun modelde değil TEKRAR GİRİLEN BİLGİDEYDİ.
      · 'Kaydet ve Kalem Ekle' formu açık bırakıyor: tarih, fiş numarası ve görsel duruyor. İrsaliye bir kez yazılıyor, fotoğraf BİR KEZ çekiliyor.
      · Eklenenler sayı değil LİSTE olarak gösteriliyor.
      · MÜKERRER KALEM UYARISI — kendi düzeltmemin ürettiği riski kapatıyor: `selectedMaterial` nil olunca `materials.first`e düşüyor, yani kalem eklendikten sonra çip fiilen seçili kalıyor ve aynı malzeme ikinci kez girilebiliyor. Seçimi zorla temizlemek yerine durum SÖYLENİYOR.
      · Simülatörde doğrulandı. KAPSAM: kayıtlar modelde ayrı kalıyor.
      · **TAMAM (21 Ağu 2026)** — üç iş de kapandı: ekleme, silme, toplu düzenleme.
      · `totalApartments` LİSTEYLE SENKRON tutuluyor. Saklanan bir sayı ve ayrışabilirdi; '5 Kat / 20 Daire' yazan projede 21 daire olması 'türetilen rakam saklanmaz' ilkesinin ihlali olurdu.
      · SİLME yalnızca TAAHHÜTSÜZ dairede: satılmış dairenin tahsilatı, taksit planı ve alıcı kaydı var, `cancelSale` onları temizliyor. Menüde seçenek hiç gösterilmiyor. Dairenin GÖRSELLERİ de düşüyor.
      · `AuditEntry.Action`a `create` eklendi — daire eklemeyi 'düzenlendi' diye kaydetmek yanlış olurdu.
      · TOPLU UYGULAMA yalnızca TİP ve ALAN kopyalıyor; bedel, durum ve teslim notu daireye özgü ve toplu yazılsaydı satılmış dairenin bedeli sessizce değişirdi. Bir test tam bunu koruyor.
      · Önce kaydet sonra uygula (yoksa kaynağın kendisi eski kalırdı); değişmeyene yazma üretilmiyor; tek denetim kaydı yazılıyor.
      · On test eklendi. 52 Swift testi geçiyor.

#### C — YAYIN ENGELLERİ (27 ve 29'un ötesinde)

- [x] 68. **Hesap silmenin GERÇEK yolu hiç koşmadı** — madde 28'in düzeltmesi.
      Simülatör sahte servisi kullanıyor; gerçek `reauthenticate` + gerçek silme
      denenmedi. App Store 5.1.1(v) zorunluluğu ve gözden geçiren bunu dener.
- [x] 69. **App Review giriş YAPAMAZ.** Uygulamaya girmenin tek yolu Türkiye
      numarasına gelen SMS. Review notlarına Firebase test telefon numarası +
      sabit kod konmazsa ilk ekran geçilemez → 2.1 reddi.
- [x] 70. **Release yapılandırması bir kez bile derlenip çalıştırılmadı.**
      Firestore'un varsayılan olduğu, launch argümanlarının kapalı olduğu,
      `aps-environment`ın production olduğu yol hiç sınanmadı.
- [~] 71. **App Check ve oran sınırı yok.** Telefon girişi herkese açık, her SMS
      ücretli, callable'larda deneme sayacı yok. Bütçe uyarısı harcamayı
      KESMİYOR — mağazada görünür olmak kötüye kullanıma açık demek.
      · **YENİ BULGU (31 Ağu 2026) — "+90 KISITI YALNIZCA İSTEMCİDE."**
        `PhoneFormat.e164` girişi Türkiye biçimine zorluyor (10/11/12 hane,
        başında 5 ya da 90) ve `FirebaseAuthService.sendCode` başka biçimi
        reddediyor. Ama bu kısıtın uygulandığı tek yer BİZİM istemcimiz:
        API anahtarı `GoogleService-Info.plist` içinde, yani uygulama
        paketinden çıkarılabiliyor ve Identity Toolkit uç noktası doğrudan
        çağrılabiliyor. Saldırgan bizim ekranımızı hiç kullanmaz.
        Sonucu doğrudan PARA: SMS pompalama (premium ücretli hatlara doğrulama
        SMS'i yağdırmak) Firebase telefon girişinin bilinen kötüye kullanım
        yolu ve fatura proje sahibine çıkıyor. Bütçe uyarısı harcamayı
        KESMİYOR — maddenin kendi cümlesi.
        Aynı desenin dokuzuncu tekrarı: "Türkiye numarası" bir iddia,
        uygulayan yok. Davet ömründeki (madde 79) bulgunun kardeşi.
      · **KAPANDI (2 Eyl 2026) — SMS BÖLGE POLİTİKASI YAYINDA.** Firebase
        Console → Authentication → Settings → SMS region policy → **Allow** +
        yalnızca **Türkiye (TR)**; kaydedildiği sayfa yenilenerek doğrulandı.
        Artık kısıtı uygulayan Firebase: anahtarı uygulama paketinden çıkarıp
        Identity Toolkit'i doğrudan çağıran bir saldırgan da bağlanıyor, çünkü
        karar istemcide değil sunucuda veriliyor. Test numaraları (App Review)
        etkilenmiyor — onlar hiç SMS göndermiyor.
      · **KABUL EDİLEN TAKAS, YAZILI OLSUN:** artık YALNIZCA +90 numaralar
        giriş yapabiliyor. Yurt dışı numarasıyla bir ortağı davet etmek
        isteyen kullanıcı giremez. Hedef kitle Türkiye'deki müteahhit ve
        ortakları olduğu için doğru takas; ama "yurt dışındaki ortağım
        giremiyor" sorusunun cevabı bu ayardır.
      · Kod tarafında yapılacak bir şey YOK ve bu bilinçli: istemciye ikinci
        bir denetim eklemek, saldırganın hiç uğramadığı bir kapıya ikinci kilit
        takmak olurdu. Doğru yer sunucu politikası.

### Yöntem: "iddia yazılı, uygulayan yok" taraması (31 Ağu 2026)

Davet ömrü bulgusundan sonra aynı sınıfı sistematik aradım: arayüzdeki her
KISIT CÜMLESİNİ toplayıp uygulayıcısını aradım. Onu bulan on bir cümleden
dokuzu gerçekten uygulanıyordu — alıcı adı (ayrı belge + kural), ortak salt
okur (14 koleksiyonda `ownerWrite`), satılmış daire durumu (`isCommitted`
kapısı), "yalnızca tip ve alan kopyalanır", "payın sessizce değiştirilemez"
(denetim izi), "kapora paya girmez" (`collectedAmount` yalnızca
`countsAsRevenue` sayıyor), "bedelin tamamı tahsil edilince otomatik
Tamamlandı" (`recalculateCollected`), belge görünürlüğü, "uygulama vergi
hesaplamaz" (test). İkisi uygulanmıyordu: davet ömrü (düzeltildi) ve SMS
bölgesi (konsol işi, yukarıda).

**YAPISAL KORUMA EKLENDİ.** `partnerLedger` bugün kurala yazılmasaydı
üretimde sessizce reddedilecekti ve hatayı KULLANICI bulurdu. Artık
`tests/rules.test.mjs` içinde emülatör gerektirmeyen bir test, kodun yazdığı
koleksiyon listesini (`FirestoreProjectRepository.Coll`) kural dosyasındaki
proje altı `match` bloklarıyla karşılaştırıyor ve ayrışmayı adıyla söylüyor.
Testin kendisi UYDURMA BİR KOLEKSİYON eklenerek doğrulandı: kırmızıya döndü,
sonra geri alındı — koşmamış test kanıt değildir.

### GERÇEK KUSUR: blok etiketi Firestore'a hiç yazılmıyordu (31 Ağu 2026)

Aynı taramanın devamında birim testlerinin kör noktası soruldu: hepsi
`InMemoryProjectRepository` kullanıyor, yani modellerin FIRESTORE kodlaması
hiç koşmuyor. `FirestoreCodecTests` yazıldı (gidiş-dönüş) ve İLK KOŞUŞTA
madde 83'ün alanını düşürdü: `Apartment` ELLE YAZILMIŞ bir `encode(to:)`
taşıyor ve `blockLabel` `CodingKeys`e ve çözümleyiciye eklendiği hâlde
KODLAYICIYA eklenmemişti.

Sonucu: blok etiketi ekranda çalışıyor, bellekte duruyor, 147 testten
geçiyor ama gerçek veritabanına HİÇ GİTMİYORDU. Kullanıcı etiketleri girer,
uygulamayı kapatıp açar ve hepsi yok olurdu — üstelik kırılım yalnızca birden
çok etiket varsa göründüğü için ekran "özellik çalışmıyor" gibi değil,
"böyle bir şey yokmuş" gibi görünürdü. Demo veri bellek içi olduğu için
simülatör turu da bunu göstermedi.

Ders yine aynı: **koşmamış kod okunarak doğrulanamaz** — bu sefer kod
"koşuyordu" ama YANLIŞ DEPOYA karşı.



### CİHAZDA BÜYÜK METİN — üç yerde daha kesiliyordu (2 Eyl 2026)

Simülatör turunda bulunanlar düzelmişti; GERÇEK cihazda en büyük metin
boyutuyla üç yeni yer çıktı:
· **Portföy karşılaştırma satırı** — "9999 Ada / …", "100 A…", "140 A…": yani
  tablonun SATIR BAŞLIĞI, hangi projeden bahsedildiği okunamıyordu. Üç sütun
  (ad · yüzde · ₺/m²) AX'te yan yana sığmıyor; satır `AdaptiveTileRow` ile
  dikey açılıyor, ad sarılıyor, sabit 96 pt genişlik yalnızca normal boyutta
  uygulanıyor. Dikey düzende `Spacer()` de koşullu — yoksa satırı uçtan uca
  açardı.
· **"Uygulama kilidi"** ayar başlığı "Uygulam…" oluyordu: ayarın ADI
  okunamıyor, altındaki açıklama sarılıyordu.
· Pano başlığı "Projelerim" kelime ortasından bölünüyor ("Projeleri / m") —
  görsel olarak kötü ama bilgi kaybı yok; kayıt olarak duruyor.

Normal boyutta düzenin değişmediği ayrıca doğrulandı.

### CİHAZ TURU — dosyalar cihazdan çekilip açıldı (2 Eyl 2026)

`devicectl` ile uygulamanın `tmp` klasörü çekildi; PDF ve CSV'ler gerçek
cihazın ürettiği hâlleriyle açıldı. Bugünkü işlerin dördü birden doğrulandı:
kapsam cümleleri TAM (kesilmiyor), KDV beyanı hem PDF metnine hem CSV sütun
başlıklarına işlemiş ("Liste Fiyatı (KDV hariç)"), blok kırılımı PDF'te ve
`Daireler.csv`'de, yeni `Ortak-Cari.csv` doğru biçimde ("Yön", "İşaretli
Tutar", `;` ayracı, BOM).

**BEKLENEN HASILAT "—" ÇIKTI** ve altında sebebi yazılı ("Henüz
hesaplanamıyor: satış yok ve dairelere liste fiyatı girilmemiş") — bugün
eklenen `isUnknown` ayrımının gerçek dünyadaki ilk sınavı yepyeni bir proje
oldu ve geçti.

**KÜÇÜK BULGU:** aynı ayrım DOSYADA eksikti — fiyatı girilmemiş daire için
`Daireler.csv` "0,00" yazıyordu. Mali müşavir bunu "fiyatı sıfır" diye okur;
doğru cevap boş hücre. Düzeltildi ve test eklendi. Ekranda çözülen bir ayrımın
dosyada eksik kalması, bu turun tekrar eden dersi: **üretmek yetmiyor, açmak
gerekiyor.**

### DAVET AKIŞI ÜRETİMDE KOŞTU — projenin en büyük kanıtsız işi kapandı (2 Eyl 2026)

Ağustos turunda "davet akışı üretimde HİÇ koşmadı" diye işaretlenmişti ve
madde 68'in dersi ortadaydı: dağıtıldı ≠ çalışıyor. Bugün uçtan uca koştu.

· Yönetici hesabı davet kodu üretti — **bugün sıkılaştırılan kural yazmayı
  KABUL ETTİ** (`createdAt == request.time` + 49 saat üst sınırı). Ekranda
  "47 saat geçerli" yazıyor, yani ömür artık sunucu saatinden ölçülüyor.
· İkinci gerçek hesap (App Review test numarası) kodu kullandı; `redeemInvite`
  gerçek IAM rolleri, gerçek kurallar ve App Check altında üyeliği yazdı.
· Ortak hesabın yüklemesi: `proje=1 daire=4 cari=1 ortak=2` — yani kendi
  projelerini DEĞİL yalnızca davet edildiğini görüyor.
· Ortak yüzeyinin sınırları ekranda doğrulandı: rozet İZLEYİCİ, hiçbir yazma
  düğmesi yok, ⋯ menüsünde yalnızca Fotoğraflar/Rapor/Kayıt İzi (madde 76'nın
  rolden bağımsız izi), cari hareketi GÖRÜYOR ama "+ Hareket" yok.

**Madde 82'nin gizlilik kararı üretimde doğrulandı:** ortak, hesabın tarafı
olduğu için cari hareketleri okuyor; alıcı gibi üçüncü kişi olmadığı için
karar `buyers/{apartmentId}` ile aynı sınıfta ama TERS yönde alınmıştı.

AÇIK KALAN: davet BAĞLANTISI (`insaattakip.app/katil/<kod>`) hâlâ 404 —
alan adı yok (madde 29). Kod elle girilince çalışıyor, WhatsApp'tan gönderilen
link çalışmıyor.

### CİHAZ TURU BULGUSU — cari hareketler birleştirmede düşüyordu (2 Eyl 2026)

Ortak cari hesabı cihazda ilk kez koştu ve kayıt yeniden başlatmada KAYBOLDU.
Ekranda görünüyordu, hata yoktu, amber şerit yoktu, `[persist]` satırı yoktu.

TANI TAHMİNLE DEĞİL SONDAYLA KONDU. Üç aday vardı (yazma gitmedi / kural
reddetti / okuma boş dönüyor) ve üçü de aynı belirtiyi veriyor. Uygulamaya
geçici iki sonda kondu: yazmadan sonra `getDocuments(source: .server)` ve
okumada ham belge sayısı. Cevap tek satırdı:

    [sonda] okuma partnerLedger pid=323BDD9D belge=1 önbellekten=false
    [load]  alt: daire=52 cari=0 …

Yani belge SUNUCUDA VARDI ve OKUNUYORDU; kayıp arada. `DataSnapshot.merge`
proje başına gelen veriyi birleştirirken on üç koleksiyonu ELLE sayıyor ve
`partnerLedger` listede yoktu — okunan kayıtlar sessizce çöpe gidiyordu.
Aynı gün bulunan `Apartment.encode(to:)` kusuruyla AYNI SINIF: elle yazılmış
bir liste, yeni koleksiyonda sessizce eksik kalıyor.

ÜÇÜNCÜ ELLE LİSTE de kördü: `verifySeam` — tek işi "persist çağırmayı
unutmayı yakalamak" olan denetim — `partnerLedger`ı DA `installments`ı DA
saymıyordu. İkisi de eklendi.

SINIF KAPATILDI: `DataSnapshotMergeTests` artık koleksiyon adı saymıyor,
`Mirror` ile HER dizi özelliğini geziyor; yeni bir koleksiyon eklenip
`merge`e yazılmazsa test kırmızıya döner ve eksik olanın ADINI söyler.
Doğrulandı: düzeltme geri alındığında test "partnerLedger BİRLEŞTİRMEDE
DÜŞÜYOR" diyerek patladı, geri konunca yeşile döndü.

VERİ KAYBI YOK: kullanıcının girdiği 100.000 ₺'lik hareket sunucuda duruyordu,
düzeltmeden sonra ekrana geri geldi (`cari=1`).

**CİHAZDA DOĞRULANDI (2 Eyl 2026).** iPhone 13 Pro + gerçek Firestore: iki
daireye "A Blok" / "B Blok" girildi, uygulama yeniden başlatıldı (yükleme
`önbellekten=false`, yani sunucudan) ve etiketler DURDU. Daireler listesinde
gruplama başlıkları ve raporda blok kırılımı kartı çıktı. Düzeltmeden önce bu
etiketler her açılışta sessizce kaybolacaktı.

### PDF ekranla ayrışmıştı — ve kapsam cümlesi kesiliyordu (31 Ağu 2026)

Aynı sorunun üçüncü biçimi: bugün eklenen `outlookCard` (beklenen hasılat +
beklenen sonuç) ve `blockCard` ekranda vardı, **PDF'te yoktu**. Oysa ortağa
gönderilen ASIL belge PDF: yönetici onu "rapor" diye paylaşınca ortağın
gerçekten merak ettiği ileriye bakan rakamlar belgede hiç görünmüyordu. İki
kart da eklendi (ikisi de dönem çipinden bağımsız ve etiketleri "proje geneli"
diyor).

PDF üretilip **açılarak** denetlendi (simülatörden çekilip görüntüye
dönüştürüldü) ve orada ikinci bir kusur çıktı: kapsam cümleleri tek satıra
sıkıştırılıp "…" ile KESİLİYORDU. `ImageRenderer` yüksekliği önermediği için
çok satırlı `Text` kırpılıyor; ekranda görünmüyordu çünkü `ScrollView`
yüksekliği serbest bırakıyor. Yani "kapsam yazılı olmalı" ilkesi tam da
ilkenin en çok gerektiği yerde — dağıtılan belgede — bozuluyordu.
`fixedSize(horizontal: false, vertical: true)` dört kapsam cümlesine de
eklendi ve PDF yeniden üretilip cümlelerin tamamlandığı görüldü.

Yöntem notu: PDF'i ÜRETMEK yetmiyor, AÇMAK gerekiyor. "Dosya oluştu" ile
"dosya doğru" arasındaki fark, bu turda bulunan üç kusurdan ikisiydi.

### KAPANDI — sheet metin alanları GERÇEK CİHAZDA sorunsuz (2 Eyl 2026)

**CEVAP: (a) — OTOMASYON ARTEFAKTI.** iPhone 13 Pro'da Fiş Ekle → MİKTAR
alanına parmakla dokunuldu: klavye açıldı, imleç göründü, rakam yazıldı.
Uygulamada kusur YOK; `simctl`/HID ile sentezlenen dokunuş modal olarak
sunulmuş bir `UIHostingController` içinde ilk yanıtlayıcı atamasını
tetiklemiyor.

**BUNUN BEDELİ NEYDİ:** bu belirsizlik yüzünden simülatörde iki tur boyunca
veri girişi gerektiren hiçbir akış uçtan uca sürülemedi (cari hareket, yeni
proje, fiş) ve doğrulama "ekran doğru çiziliyor mu"ya indi. Bundan sonra
kural: **simülatörde yazma gerektiren akışlar için tohum veriyi değiştir ya
da cihaza çık; "yazamıyorum" bir kusur raporu değil, aracın sınırı.**

Aşağıdaki gözlem kaydı, aynı soru bir daha sorulmasın diye duruyor.

GÖZLEM: simülatörde enjekte edilen dokunuşla
· `ApartmentsTabView` arama alanı ODAK ALIYOR — "Berk" yazıldı, liste süzüldü.
· ÜÇ AYRI SHEET'te hiçbir metin alanı odak ALMIYOR: `ReceiptSheet`
  (MİKTAR · decimalPad ve FİŞ/İRSALİYE · default), `ProgressSheet` (kalan
  maliyet) ve `NewProjectSheet` (ADA). Yazılan karakterler hiçbir yere
  düşmüyor.
· Aynı sheet'lerde DOKUNUŞ ÇALIŞIYOR: çipler seçiliyor, "Kaydet" basılıyor,
  sayfa kapanıyor. Yani hit-testing sağlam; sorun yalnızca ilk yanıtlayıcı
  (first responder) olma anında.

NEDEN ÖNEMLİ: bu uygulamada VERİ GİRİŞİNİN TAMAMI sheet'lerde — fiş, gider,
satış, daire bilgisi, cari hareket, yeni proje. Gerçekten kullanıcıda da
oluyorsa uygulama kullanılamaz demektir.

İKİ AÇIKLAMA VAR, İKİSİ DE KANITLANMADI:
(a) Otomasyon artefaktı: `simctl`/HID ile sentezlenen dokunuş, modal olarak
    sunulmuş bir `UIHostingController` içinde ilk yanıtlayıcı atamasını
    tetiklemiyor olabilir. Bu durumda gerçek parmakla sorun yoktur.
(b) Gerçek kusur: sheet düzeninde alanın dokunma hedefi ya da odak zinciri
    bozuk.

BUGÜNE KADAR NEDEN GÖRÜLMEDİ: daha önceki yazma denemeleri hep TAM EKRAN
alanlardaydı (telefon numarası, SMS kodu — madde 68/69) ve fiş akışı
`ReceiptScanner` alanları OCR ile DOLDURDUĞU için elle yazmayı hiç
gerektirmedi.

CİHAZDA TEST (kullanıcı · 10 sn): Malzeme sekmesi → "+ Fiş Ekle" → MİKTAR
alanına dokun. Klavye açılıp imleç yanıp sönüyorsa (a) doğrudur ve bu madde
kapanır. Açılmıyorsa (b) doğrudur ve iş yayından ÖNCE gelen her şeyin önüne
geçer.

### Büyük metin turu: kesilen parça yine anlam taşıyordu (31 Ağu 2026)

Hedef kullanıcı 50 yaşında bir müteahhit; iOS'ta yazıyı büyütmesi olağan.
Simülatör en büyük erişilebilirlik boyutuna (AX5) alınıp ekranlar tek tek
açıldı. İyi haber: `financeTile` ve portföy kartı zaten uyum sağlıyor
(dikey diziliyor) ve PARA RAKAMLARI sarılıyor, kesilmiyor — yani daha önce
öğrenilen ders tutmuş.

İki yeni kusur çıktı, ikisi de aynı sınıftan ("kesilen parça anlam taşıyor"):
· **Dönem çipleri** AX5'te "Bu…", "Çeyr…", "Tü…" oluyordu — rapordaki BÜTÜN
  rakamlar bu seçime bağlıyken hangisinin seçili olduğu okunamıyordu. `HStack`
  yerine `FlowLayout`: çipler alt satıra taşıyor, etiket tam kalıyor. Metni
  küçültmek (`minimumScaleFactor`) çözüm değil — kullanıcının açıkça istediği
  büyük yazıyı düzen sığsın diye geri küçültmek olurdu.
· **Yeni projede "Beklenen Hasılat 0 ₺" yazıyordu.** Hiç satış yok ve
  hiçbir daireye liste fiyatı girilmemişken toplam matematiksel olarak sıfır
  çıkıyor, ama anlamı "bu projeden para beklenmiyor" değil "henüz
  bilinmiyor". 24 puntoluk bir "0 ₺", uygulamanın `areaCost`ta nil döndürerek
  ve `remainingCostEstimate`te nil ile sıfırı ayırarak reddettiği hatayı EN
  GÖRÜNÜR yerinde tekrarlıyordu. `StockOutlook.isUnknown` eklendi; o durumda
  ekran rakam yerine "—" ve sebebini yazıyor. Kat karşılığı daireler bilinmeyen
  SAYILMIYOR: orada sıfır gerçekten sıfır (bedelsiz) ve bu bir bilgi. İki test.
· **Proje başlığının alt satırı NORMAL BOYUTTA BİLE kesiliyordu:**
  "Tahsilat 26,88 M ₺ · Kalan alacak 1…" — kesilen parça yine BÜYÜKLÜK EKİ,
  yani 1 milyon ile 15 milyon ayırt edilemiyordu (gerçek değer 15,77 M ₺).
  `financeTile`ın yorumunda yazılı olan hatanın aynısı, iki ekran ötede.
  Başlık da kimlik taşıyor: "145…" parseli yutuyor ve madde 83'ten sonra
  önerilen kurulum tam olarak "parsel başına tek proje" — aynı adada iki
  proje gerçekten olabilir. İkisi de iki satıra çıkabiliyor artık.

### CSV'ler de açıldı: "Ödenen" sütununda kişi adı vardı

Aynı yöntem dosyalara uygulandı — beş CSV ve yedek JSON simülatörden çekilip
AÇILDI. Biçim doğru çıktı (`;` ayracı, UTF-8 BOM, CRLF, ondalık virgül —
"Excel'de doğrudan açılır" iddiası uygulanıyor), yeni sütunlar yerinde
(`Daireler.csv` → "Blok / Etap", yeni `Ortak-Cari.csv` → "Yön" ve "İşaretli
Tutar"). Ama `Giderler.csv` başlığında **"Ödenen" sütununda KİŞİ ADI**
duruyordu ("Şantiye ekibi") ve hemen "Tutar"ın yanındaydı: dosyayı açan mali
müşavir ikisini "ödenen tutar" diye okuyabilirdi. Üstelik model ödemeyi zaten
garanti etmiyor (madde 81 — kayıt tahakkuk esaslı). Başlık "Kime Ödendi"
oldu; uygulamanın kendi form etiketiyle aynı kelime. Bir test kilitliyor.
 Testler artık şunları da kilitliyor:
alıcı adının daire belgesine yazılmadığı (madde 18'in kodlama sınırındaki
kanıtı), malzemenin türetilen toplamlarının kodlanmadığı ("türetilen rakam
saklanmaz" kararının koruyucusu), cari hareketin üç türünün ham değerleriyle
gidip geldiği ve alansız ESKİ belgelerin hâlâ çözüldüğü.
- [x] 72. **Uygulama içinde destek/geri bildirim/sürüm/politika satırı yok.**
      `AccountSheet`te yok, `CFBundleShortVersionString` okuyan kod yok.
      Crashlytics bilinçli ertelendi; ikisi birleşince sahadaki hata İKİ
      KANALDAN DA görünmez.
- [~] 73. **Yerelleştirme paketi yok** (`.lproj` yok): kamera, galeri, paylaşım
      ve dosya seçici ekranlarının Türkçe geldiği hiç ölçülmedi.
- [x] 74. **Build numarası otomasyonu derleme dışında** — arşivden önce ELLE
      çalıştırılması gerekiyor, unutulursa "redundant binary" reddi.
      · **KOD TAMAM (24 Ağu 2026) · GERÇEK TUR AÇIK.** Maddenin tespiti doğruydu ve tahmin edilenden ağırdı: koşmamış yol ON ÜÇ kusur taşıyordu.
      · SUNUCU (6): (a) `getStorage().bucket()` varsayılanı `<proje>.appspot.com` çözüyor, bu projenin kovası ise `.firebasestorage.app` — doğrudan sınandı, eski ad HTTP 404, yeni ad 403. Yanlış kova silme döngüsünün ORTASINDA patlar. Çözücü artık adayları sırayla DENİYOR ve cevabı işin kendisinden alıyor; `bucket.exists()` ile yoklayan sürüm yazıldı ve TERK EDİLDİ, çünkü Storage emülatörü dolu kova için bile false diyor ve o sürüm hiçbir dosyayı silmeden 'silindi' dedi. (b) Sıra tersti: Firestore önce silinince Storage hatası dosyaları KURTARILAMAZ biçimde öksüz bırakıyordu — tekrar çağrı projeyi artık bulamıyor. (c) `recursiveDelete` silme sırasını garanti etmiyor; üst belge artık `listCollections()` sonrası EN SONDA. (d) `invites/{KOD}` üst düzey ve kural `delete: if false` diyor — silinen her hesap, içinde gerçek ad yazan ÖLÜMSÜZ belgeler bırakıyordu. (e) Ayrılan ortağın adı davet belgesinde ve katılma hareketinde kalıyordu; ortak kaydı zaten aynı gerekçeyle siliniyordu. (f) Süre/bellek varsayılandaydı (60 sn).
      · İSTEMCİ (7): (a) Hata çevirisi `as? AuthError` ile yapılıyordu, Functions o tipi hiç fırlatmıyor — `??` yedeği TEK çalışan daldı, her sebep 'Hesap silinemedi' oluyordu. (b) İlk sunucu hatasından sonra akış BİR DAHA TAMAMLANAMIYORDU: tükenmiş kod yeniden gönderiliyor, mesaj kullanıcıdan ekranda bulunmayan bir düğmeyi istiyordu. (c) İş sürerken kapatma açıktı ve hata yok olmuş görünümün `@State`ine yazılıyordu. (d) 'Kalıcı olarak silinecek' denen fotoğraf, belge ve Firestore önbelleği (alıcı adları dahil) CİHAZDA kalıyordu. (e) Sunucu SMS turunun yapıldığını HİÇ denetlemiyordu: kaçırılmış bir jeton tek çağrıyla her şeyi siliyordu. (f) Sahte servisler `DEBUG` şartı olmadan seçiliyordu — Release'i simülatörde koşturmak (madde 70) taklidi sınardı. (g) Üç Auth kodu eşlenmemişti ve `.unknown` metni 'Giriş yapılamadı'ydı.
      · Sekiz emülatör + sekiz birim testi eklendi. Var olan testler işlevin Firestore tarafını doğruluyordu; Auth kaydının gerçekten gidip gitmediği, Storage nesnelerinin silinip silinmediği ve davet belgelerinin akıbeti HİÇ SORULMAMIŞTI — üçü de ekranda iz bırakmadan başarısız olabilecek adımlar.
      · **AÇIK KALAN:** gerçek cihazda gerçek bir hesabın gerçekten silinmesi. Bunun için ATILABİLİR gerçek bir hesap gerekiyor ve o da madde 69'un Firebase test numarası. İki madde tek işin iki yarısı.
      · **GERÇEK TUR KOŞTU (24 Ağu 2026) ve ÜÇÜNCÜ BİR KUSUR ÇIKARDI — kodda değil, KURULUMDA.** Test numarasıyla üretimde hesap açıldı, proje kuruldu (900 Ada / 7 Parsel, 12 daire, 9 malzeme) ve silme çalıştırıldı. İşlev İLK Firestore sorgusunda `7 PERMISSION_DENIED` ile düştü. Çalıştırma hizmet hesabı varsayılan compute hesabı ve Firestore'a erişemiyor. Bu, uygulamanın kodundan bağımsız: düşen sorgu (`projects where ownerUid == uid`) maddenin ilk gününden beri oradaydı. `redeemInvite` günlüğü de aynı tabloyu doğruluyor — üretimde HİÇ doğrulanmış çağrı almamış. Yani Cloud Functions katmanı üretim Firestore'una bugüne kadar HİÇ dokunamamış. Yalnızca gerçekten koşturmak bunu ortaya çıkarabilirdi; maddenin varlık sebebi tam olarak bu.
      · Düşüş KURTARILABİLİR oldu ve bu tesadüf değil: Storage'ı Firestore'dan öne almanın gerekçesi buydu. Hesap ve verinin tamamı yerinde kaldı (1 proje / 12 daire), ekran doğru cümleyi gösterdi ("Sunucu silmeyi tamamlayamadı") ve "Tekrar dene"ye döndü.
      · GERÇEK TURDA DOĞRULANANLAR: `reauthenticate` gerçek Firebase'de çalışıyor; zorla tazelenen jeton sunucudaki `auth_time` kapısını geçiyor; onay ekranı gerçek sayıları okuyor; hata çevirisi doğru sınıfa düşüyor; yeniden deneme yolu kilitlenmiyor.
      · **AÇIK KALAN:** IAM düzeltmesi (kullanıcının işi) ve ardından silmenin baştan sona tekrarı.
      · **YOL AÇILDI (24 Ağu 2026), GİRİŞ UÇTAN UCA KOŞTU.**
      · KODDA DEĞİŞİKLİK GEREKMEDİ ve bu kanıtlandı: `sendCode` sıradan `verifyPhoneNumber` çağırıyor, beyaz listedeki numara için Firebase doğrulama kimliğini SMS göndermeden döndürüyor. `appVerificationDisabledForTesting` EKLENMEDİ — yayın derlemesinde uygulama doğrulamasını tümden kapatırdı.
      · TEST NUMARASI TEK BAŞINA YETMEZDİ. Gerçek turda çıktı ki kod alanına kod YAZILAMIYOR: iki TextField tek bir `Bool` odak durumuna bağlıydı ve odak hiçbirine gitmiyordu — dokunmak da açmıyordu. Gözden geçiren numarayı girse bile ilk ekranı geçemezdi. Odak artık alanı ayırt ediyor; düzeltmeden sonra giriş ilk denemede tamamlandı.
      · DEPO HERKESE AÇIK (doğrulandı). Test numarası ve sabit kod repoya YAZILMADI: şablon `APP_REVIEW.md`de, gerçek değerler `.gitignore`daki `*.local.md` arkasında ve App Store Connect'te.
      · GÖZDEN GEÇİRENİN GÖRECEĞİ EKRAN ÖLÇÜLDÜ: boş hesapla giren yalnızca "Henüz projen yok" görüyor — 2.1 reddinin ikinci biçimi. Test hesabı önceden kurulmuş bir demo projeyle teslim edilecek ve o projede GERÇEK ALICI ADI olmayacak.
      · **AÇIK KALAN:** demo projenin kurulması ve App Store Connect Review Notes alanının doldurulması.
      · **KAPANDI (24 Ağu 2026).** IAM düzeltildikten sonra gerçek silme baştan sona koştu: 1 proje / 12 daire / 9 malzeme silindi, ekran sunucudan gelen sayıyı gösterdi ("1 proje ve tüm kayıtları silindi"), işlev günlüğü temiz. KESİN KANIT: aynı numarayla tekrar giriş "Adın ne?" ekranına düştü — Auth kaydı silinmiş, yeni kimlik açılmış, profil yok, eski proje görünmüyor.
      · KURULUM KUSURU (kodda değil): çalıştırma hizmet hesabında yalnızca *Cloud Build Service Account* rolü vardı. Üç rol eklendi — Cloud Datastore User, Firebase Authentication Admin, Storage Object Admin. Bu eksik `redeemInvite`'i de vuruyordu; iki callable de üretim Firestore'una bugüne kadar hiç dokunamamış.
      · ON DÖRDÜNCÜ KUSUR BENİM DÜZELTMEMDEYDİ: yerel temizlik `terminate()` çağırıyordu ve uygulama ömrü boyunca yaşayan deponun yakaladığı Firestore örneğini öldürüyordu — sil → tekrar gir dizisi `FIRIllegalStateException` ile ÇÖKÜYORDU. Firestore önbelleği artık bayrakla sonraki açılışa devrediliyor (Firebase'in belgelediği yol). Dört test eklendi, cihazda doğrulandı.
      · **KAPANDI (24 Ağu 2026).** Test numarası tanımlandı, giriş uçtan uca koştu ve demo hesap kuruldu: *145 Ada / 2 Parsel · Gebze, Kocaeli · 4 Kat / 12 Daire · 9 malzeme kalemi · 1 taksitli satış* (850.000 ₺ peşinat + 12 × 250.000 ₺). ALICI ADI UYDURMA — gözden geçirene gösterilen veride gerçek kişi yok.
      · **AÇIK KALAN (kullanıcının işi):** App Store Connect → App Review Information → Notes alanına `APP_REVIEW.md` bölüm 2'deki metnin yapıştırılması.
      · **İSTEMCİ TARAFI TAMAM (25 Ağu 2026) · ZORLAMA AÇILMADI.** `FirebaseAppCheck` hedefe eklendi, sağlayıcı `FirebaseApp.configure()`dan ÖNCE kuruluyor (sonra kurulursa Firebase ilk jetonu varsayılan sağlayıcıyla alıp SESSİZCE düşer; sorun ancak üretimde görünür). Cihazda App Attest, DEBUG'da debug sağlayıcı — jeton basıldığı doğrulandı.
      · ZORLAMA BİLİNÇLİ AÇILMADI: istemci jeton gönderiyor, sunucu istemiyor. Konsol ölçümlerinde gerçek trafiğin doğrulandığı görülmeden zorlama açmak, uygulamayı kendi kullanıcılarına kapatmak olur. Callable'lardaki `enforceAppCheck` de aynı sebeple kapalı.
      · ORAN SINIRI (`redeemInvite`): uid başına 15 dakikada 10 BAŞARISIZ deneme. Uid başına çünkü callable'da istemci IP'si güvenilir değil ve uid sınırı saldırganı yeni hesap açmaya zorluyor — her hesap gerçek bir SMS, yani saldırının kendi maliyeti var. Başarı sayacı sıfırlıyor. Sayaç İŞLEMİN DIŞINDA yazılıyor: transaction içinde olsaydı her hata onu da geri alır ve sınır çalışıyor görünüp hiçbir şey yapmazdı.
      · `rateLimits/{uid}` istemciye kapalı ve kural açıkça yazılı (yazma açık olsa kullanıcı sıfırlar, okuma açık olsa saldırgan kalan hakkını görürdü).
      · 8 test. 121 Swift + 192 emülatör testi geçiyor.
      · **(a) YAPILDI (2 Eyl 2026):** uygulama App Check'e **App Attest** ile
        kaydedildi (Team ID `36HVD2S94X` — APNs anahtarıyla aynı takım, yani
        doğru hesap) ve cihazın hata ayıklama jetonu "iPhone 13 Pro ·
        geliştirme" adıyla eklendi (jeton `APP_REVIEW.local.md`'de, gitignore'lu).
        ZORLAMA BİLEREK KAPALI bırakıldı.
      · **NİYE HEMEN ZORLAMIYORUZ:** App Check açıldığı an doğrulanmamış her
        istek reddedilir ve bugüne kadar TEK ÖLÇÜM toplanmadı — App Attest'in
        bu uygulamada gerçekten çalıştığı bilinmiyor. Ölçüm görmeden açmak,
        kendi uygulamasını ve gerçek verisini kapının dışında bırakma riski;
        madde 68'de Cloud Functions'ın IAM rollerinin eksik olduğu da ancak
        DENENDİĞİNDE ortaya çıkmıştı. Sıra: birkaç gün normal kullanım →
        App Check → Request metrics → "Verified requests" oranı → zorlama +
        callable'larda `enforceAppCheck` AYNI ANDA.
      · **(c) YAPILDI (15 Eki 2026) — CALLABLE'LARDA ZORLAMA AÇIK.**
        `redeemInvite` ve `deleteAccount` artık `enforceAppCheck: true` ile
        üretimde. `consumeAppCheckToken` AÇILMADI: o tekrar oynatmayı (replay)
        engelliyor ve her çağrıya ek doğrulama turu getiriyor; buradaki tehdit
        tekrar oynatma değil, uygulamayı hiç kullanmadan ucu dövmek.
      · **ZORLAMANIN GERÇEKTEN UYGULANDIĞI KANITLANDI — ve kanıtı testlerin
        topluca düşmesi oldu.** Bayrak eklenince emülatör paketindeki 39 test
        birden kırmızıya döndü (401). Testler callable'ı düz HTTP ile
        çağırıyordu, yani jeton göndermiyorlardı. Jeton eklenince 205 test
        yeşile döndü.
      · **ZORLAMA ARTIK TESTLE KİLİTLİ.** İki yeni test jetonsuz çağrının 401
        aldığını denetliyor. Gerekçe: `enforceAppCheck: true` tek satırla
        silinebilir ve silindiği HİÇBİR YERDEN anlaşılmaz — diğer tüm testler
        yeşil kalır, uygulama çalışır, yalnızca koruma sessizce gider. Aynı
        sınıf madde 79'da (davet ömrü) ve 87'de (kota) yaşandı.
        `deleteAccount` testi ayrıca hesabın SİLİNMEDİĞİNİ de denetliyor:
        401 dönüp yine de silseydi durum kodu yanıltıcı olurdu.
      · **GÜNLÜKTEKİ TUZAK YAZILI:** reddedilen çağrıda bile emülatör
        `{"app":"MISSING"} ... "verification passed"` basıyor. "passed"
        gövdenin çalıştığı anlamına gelmiyor; doğrulama özeti önce loglanıyor,
        zorlama sonra reddediyor. Kanıt iki yerde: 401 ve işlevin ~0,6 ms'de
        bitmesi (gerçek `deleteAccount` ~11 ms).

      · **BEKLENEN YÖNTEM ÇÜRÜTÜLDÜ: "ÖLÇÜMLERE BAK" SORUYU CEVAPLAYAMAZ.**
        Plan "birkaç gün kullan → Request metrics → Verified requests oranına
        bak → zorlamayı aç" diyordu. O oran bu soruyu cevaplayamaz, çünkü
        **bugüne kadar üretilen HER App Check jetonu hata ayıklama
        jetonundan geldi:**
          · `AppCheckSetup` App Attest'i YALNIZCA `#else` dalında, yani
            Release'de kuruyor; DEBUG'da debug sağlayıcı çalışıyor.
          · Cihaz turu (2 Eyl) DEBUG derlemesiyle yapıldı — `CIHAZ_TURU.md`
            bunu açıkça yazıyor (`-backend firestore` bayrağı zaten yalnızca
            DEBUG'da anlamlı).
          · Tek Release koşusu (25 Ağu) **SİMÜLATÖRDE** yapıldı ve App Attest
            simülatörde hiç çalışmıyor.
        Yani konsol yüksek bir "doğrulanmış" oranı gösterecek, o oran debug
        jetonunun çalıştığını kanıtlayacak ve **App Attest hakkında hiçbir
        şey söylemeyecek.** Bu, projenin avladığı sınıfın yeni bir türü:
        "iddia yazılı, uygulayan yok" değil — **ÖLÇÜM VAR, ÖLÇTÜĞÜ ŞEY
        BAŞKA.** Yanlış sayıya bakıp zorlama açmak, doğru hissettiren bir
        kararla uygulamayı mağazada ölü doğurmak olurdu.

      · **ZORLAMAYI ŞİMDİ AÇMAK DOĞRU, ÇÜNKÜ MALİYET ÖMRÜNÜN EN DÜŞÜĞÜNDE.**
        Uygulama dağıtılmadı, yani kullanıcı yok; kırılırsa kırılan tek şey
        geliştiricinin kendi cihazı ve onun debug jetonu kayıtlı. Dahası
        zorlama AÇIKKEN Release derlemesi cihazda denendiğinde App Attest
        çalışmıyorsa **gürültülü biçimde** başarısız olacak; zorlama kapalı
        olsaydı aynı derleme sessizce "çalışıyor" görünür ve sorun ancak
        mağazada ortaya çıkardı. Kota testlerinin sınırı enjekte ederek yayın
        gününü prova etmesiyle aynı mantık.

      · **YAYIN ÖNCESİ BLOKE EDEN TEK İŞ — APP ATTEST GERÇEK CİHAZDA.**
        TestFlight ya da App Store'a gönderim yapılmadan ÖNCE: Release
        derlemesi FİZİKSEL iPhone'a kurulacak ve App Check jetonunun
        alındığı günlükten doğrulanacak. Geçmezse mağaza derlemesi hiçbir
        veriye erişemez — ne okuma, ne yazma, ne giriş. Simülatör bu testi
        YAPAMAZ. Adımlar `CIHAZ_TURU.md`'de.

      · **KONSOL TARAFI (kullanıcının işi, sırayla):** App Check → APIs →
        Cloud Firestore / Cloud Storage / Firebase Authentication için
        zorlama. Her biri açıldıktan hemen sonra ilgili akış denenmeli;
        kırılırsa aynı düğmeyle geri alınır. Ayrıca bütçe uyarısı harcamayı
        KESMİYOR — kodla çözülemez, bilinen sınır olarak duruyor.
      · **DAĞITILDI VE DOĞRULANDI (25 Ağu 2026).** Kurallar ve iki callable
      üretime çıkarıldı; ardından `redeemInvite` oturumsuz çağrıldı ve
      beklenen `UNAUTHENTICATED · signed-in-required` döndü — yani yeniden
      yapılandırılan işlev (transaction ayrı bir yardımcıya taşındı) üretimde
      sağlıklı koşuyor. Oran sınırının kendisi kimlik kapısının ARKASINDA
      olduğu için bu çağrıyla sınanmıyor; davranışı sekiz emülatör testiyle
      sabit.
      · **KOŞTURULDU (25 Ağu 2026).** Release derlenip simülatöre kuruldu ve `-role admin -backend firestore -screen project` argümanlarıyla başlatıldı: ÜÇÜ DE YOK SAYILDI. DEBUG olsaydı doğrudan sahte oturumla demo panoya düşerdi; Release gerçek karşılama ekranını ve gerçek kimlik yolunu gösterdi. Pakette `tr.lproj`, sürüm 1.0 (169).
      · `aps-environment`ın production olduğu yol hâlâ sınanmadı — imzalı arşiv gerektiriyor, simülatörde doğrulanamaz.
      · **TAMAM (25 Ağu 2026).** Hesap ekranına "Destek" bölümü: geri bildirim, sürüm ve (adres gelince) gizlilik politikası.
      · E-POSTA GÖVDESİ TANI BİLGİSİNİ ÖNCEDEN TAŞIYOR (sürüm, iOS, cihaz modeli). Crashlytics ertelendiği için bu tek kanal; "uygulama açılmıyor" diye gelen bir mesajla çalışılamaz ve bunları kullanıcıdan sormak cevabı günlerce geciktirir. `UIDevice.model` yalnızca "iPhone" dediği için donanım kimliği `uname` ile alınıyor.
      · Sürüm "1.0 (169)" — ikisi birden, çünkü aynı sürümle onlarca build gönderiliyor. Dokununca kopyalanıyor.
      · GİZLİLİK POLİTİKASI SATIRI HİÇ ÇİZİLMİYOR: adres madde 27'ye bağlı ve çalışmayan bağlantı, hiç bağlantı olmamasından kötü. Bir test adres eklendiği gün düşüp satırı doğrulamayı hatırlatıyor. 5 test.
      · **ÖLÇÜLDÜ (25 Ağu 2026) — maddenin şikâyeti zaten buydu.** `tr.lproj` eklendi, `CFBundleDevelopmentRegion = tr` yapıldı ve simülatör İngilizceye alınıp bakıldı.
      · SONUÇ: uygulamanın KENDİ ekranları ve kendi diyalogları ("Görsel kaynağı · Fotoğraf Çek · Galeriden Seç") İngilizce cihazda da TÜRKÇE geliyor. Ama `PHPickerViewController` AYRI SÜREÇTE koşuyor ve CİHAZIN dilini izliyor: İngilizce telefonda "Photos / Collections / Learn More…" görünüyor ve bu uygulamadan değiştirilemiyor.
      · **BİLİNEN SINIR:** hedef kitle Türkçe telefon kullandığı için pratikte sorun değil; ama "uygulama tamamen Türkçe" demek yanlış olur. Paylaşım sayfası ve dosya seçici de aynı kurala tabi.
      · **TAMAM (25 Ağu 2026).** Betik şemanın Archive ÖN-EYLEMİNDE; ön-eylem kum havuzunun DIŞINDA koştuğu için `.git`i okuyabiliyor.
      · DERLEME FAZI DENENDİ VE OLMADI, iki engel de ölçüldü: (a) `git rev-list` kum havuzunda "fatal: not a git repository" veriyor — eski yorumdaki varsayım doğrulandı; (b) üretilen Info.plist'e `plutil -replace` ile yazmak da engelleniyor ve betik hata verip DERLEMEYİ DÜŞÜRÜYOR. Üstelik `ProcessInfoPlistFile` betik fazlarından SONRA koşuyor, yani yazma başarılı olsa bile üzerine yazılırdı (girdi bildirerek sıralama da denendi, yetmedi). Numara derlemenin içinde üretilemez.
      · **DOĞRULANAMAYAN:** ön-eylemin AYNI arşivde etkili olup olmadığı imzalı arşiv gerektirdiği için sınanmadı; en kötü durumda numara bir sonraki arşive yansır ve depoda değişiklik görünür.

#### C-EK — GERÇEK FİŞ TURU (24 Ağu 2026)

Gerçek market ve yemek fişleriyle uçtan uca test. Kullanıcının kendi
fişleri kullanıldı; test bitince hesap silinip demo temizlendi (fişler
kişisel veri ve demo hesabı App Review'a gidiyor). Beş kusur çıktı, beşi de
kapatıldı — hiçbiri kod okunarak bulunamazdı.

- [x] F1. **Fiş okuyucu iki fişte de YANLIŞ toplam okudu** (340,00 → 30,91 ve
      399,00 → 1,00) ve yanlış değeri "FİŞTEN OKUNDU · Toplam 1 ₺" diye KESİN
      bir cümleyle gösterdi; "Uygula" onu doğrudan birim fiyata çeviriyor.
      Kök neden içerik değil DÜZEN: fiş iki sütunlu ve Vision önce etiketlerin
      tamamını, sonra tutarların tamamını veriyor. "Bir sonraki satıra bak"
      kuralı bir sonraki ETİKETİ okuyordu; market fişinde "Banka Kredi Kartı
      (1)" satırındaki 1 tutar sanıldı. Yeni kural: izleyen birkaç satırdan
      YALNIZCA TUTARDAN İBARET olanlar, en büyüğü. 7 test.
- [x] F2. **Miktar alanı sessizce yeniden yorumluyordu.** "12,5" yerine
      "12ö5" girildiğinde geçersiz karakter atılıp rakamlar BİRLEŞİYOR: 125.
      Sayı on katına çıkıyor, alan hâlâ "12ö5" gösteriyor, toplam 118.750 ₺
      diyor ve ayrışmaya dair hiçbir işaret yok. Hoşgörü doğru ("12 500 kg"
      çalışmalı), SESSİZLİK yanlıştı. Artık toplamın altında "miktar 125 ton
      olarak okundu" beliriyor; yalnızca boşluk farkı varsa susuyor. 2 test.
- [x] F3. **Aylık satış grafiği içinde bulunulan ayı dışarıda bırakıyordu.**
      Aynı ekranın üstünde "Satış geliri 3.850.000 ₺" yazarken grafikteki tüm
      çubuklar sıfırdı. İkisi de kendi içinde doğruydu; kusur ÖZETLE GRAFİĞİN
      FARKLI DÖNEM KAPSAMASIYDI. 2 test.
- [x] F4. **Rol önizlemesi gerçek kullanıcıyı sahte biriyle değiştiriyordu.**
      "Ortak görünümü" bambaşka bir kimliğe geçiyor, ekran "0 proje" diyordu;
      geri dönmek de gerçek kullanıcıyı getirmiyordu. Asıl tehlike veri kaybı
      değil YANLIŞ SONUÇ: bu araçla gizlilik sınavı yapan biri boş ekranı
      görüp "ortak projeyi göremiyor" diye yanlış bir sonuca varabilirdi.
      `switchRole` artık kimliği koruyor; `Project.role(for:)` İNDİRMEYİ kabul
      ediyor, yükseltmeyi asla. Bölüm zaten `#if DEBUG` — yayın etkilenmiyor.
- [x] F5. **Temizlik işareti `UserDefaults`ta sessizce kayboluyordu**
      (madde 68'in yerel temizliği). Hesabını silip uygulamayı hemen kapatan
      kullanıcıda işaret diske hiç yazılmıyordu; ölçüldü. İşaret artık dosya.

**DOĞRULANANLAR:** görsel 3,1 MB'tan ~190 KB'a küçülüyor · yükleme ve indirme
üretim Storage'ında çalışıyor (yerel önbellek silinip fiş yeniden açıldı) ·
dönem raporu kuruşu kuruşuna tutuyor (3.850.000 − 11.400 − 340 = 3.838.260) ·
taksit planı 13 satır, peşinat sözleşme tarihinde, 1. taksit bir ay sonra ·
FIFO tahsilat doğru (850.000 + 250.000 = 1,10 M ₺, kalan 2,75 M ₺).

#### D — VERİ GÜVENLİĞİ VE İZLENEBİLİRLİK

- [x] 75. **Yedekten geri dönüş yok.** `Yedek.json` üretiliyor ama okuyan tek
      satır kod yok; "kapsam dışı" notu da yok, yani ERTELENMİŞ DEĞİL ATLANMIŞ.
      Telefon kaybolursa veri kaybolur. Hesap silmede de "önce verini dışa
      aktar" adımı sunulmuyor.
- [~] 76. **Denetim izi ortağın göreceği hiçbir ekranda yok.** `audit(forProject:)`
      tanımlı ama View katmanında ÇAĞIRAN YOK; izi gösteren beş yerin beşi de
      yalnızca yöneticinin açabildiği düzenleme sheet'leri. Kural ortağa okuma
      izni veriyor — yani şeffaflık kuralda var, ekranda yok.
- [x] 77. **Zaman damgası ve "kim yaptı" tamamen istemciden.** `firestore.rules`
      içinde tek bir `request.time` ya da alan doğrulaması yok. Cihaz saati
      yanlışsa ya da kasten değiştirilirse iz yanlış tarih taşıyor.
- [x] 78. **Uygulama kilidi / gizlilik ekranı yok.** `LAContext` sıfır, uygulama
      değiştiricide örtü yok. Oysa uygulama alıcı kimliği, IBAN taşıyan
      dekontlar ve tüm proje finansallarını taşıyor.
- [~] 79. **Arama ve süzgeç yalnızca dairelerde.** Giderler, malzeme hareketleri,
      tahsilatlar ve hareket akışında arama/tarih aralığı/sıralama yok.
      · **GERİ YÜKLEME TAMAM (25 Ağu 2026).** Dosya seçici → çözme → geri yükleme yolu kuruldu ve simülatörde uçtan uca doğrulandı.
      · KİMLİKLER KORUNUYOR, ÇAKIŞMA REDDEDİLİYOR. Yeni kimlik üretmek her referansı yeniden eşlemeyi gerektirirdi; tek hata parayı yanlış daireye yazar. Üzerine yazma ve birleştirme ikisi de reddedildi: yedekten YENİ olan veriyi yok etmek geri dönüşsüz, hangisinin doğru olduğunu ise kimse bilemez.
      · SAHİPLİK GERİ YÜKLEYENE GEÇİYOR — yoksa kurallar dosyayı elinde tutan kişiyi de dışarıda bırakırdı. ORTAKLARIN BAĞLANTISI KOPUYOR (adları/hisseleri kalıyor): dosyaya bakarak erişim açmak davet akışının denetimini atlamak olurdu.
      · TÜRETİLEN RAKAMLAR YEDEKTEN OKUNMUYOR, ham kayıttan yeniden hesaplanıyor — dosya dışarıdan geliyor. Test bunu bilerek bozulmuş toplamlarla sabitliyor.
      · BİLİNMEYEN SÜRÜM REDDEDİLİYOR (madde 56'nın dosya karşılığı): yarım okuma, kullanıcının eksiği aylar sonra fark etmesi demekti.
      · ÖZET GELMEYENİ DE SÖYLÜYOR: belgeler geri gelmiyor (yedek kaydı taşır, dosyayı değil), sahipsiz kayıtlar sayılıyor, alıcı adı eksikse belirtiliyor, ortakların yeniden davet edilmesi yazılıyor.
      · 15 test (90 toplam).
      · ~~AÇIK KALAN: hesap silmede "önce verini dışa aktar" adımı~~ → **KAPANDI (madde 75).** `DeleteAccountView` onay adımında "Önce verilerini indir" düğmesi var ve yalnızca SAHİBİ olunan projeleri indiriyor; bağlantı değil DÜĞME, çünkü "her projenin rapor ekranına tek tek git" demek silmenin hemen öncesinde atlanacak bir yönlendirme olurdu. Belgelerin ve fotoğrafların yedeğe girmesi ayrı bir iş (dosya boyutu kararı gerektiriyor).
      · **EKRAN AÇILDI (25 Ağu 2026).** "Kayıt İzi" proje menüsünde ve girişi ROLDEN BAĞIMSIZ — `isAdmin` arkasına konsaydı maddenin tespit ettiği durum aynen sürerdi. Gün gruplu liste; her satır eski → yeni değeri, işlemi yapanı ve saati gösteriyor.
      · AÇMADAN ÖNCE SIZINTI DENETİMİ KOŞTURULDU. Altı bulgunun altısı da çürütüldü ve çürütme gerekçesi belirleyici: `recordAudit` TEK çağrıda İKİ kayıt yazıyor — `AuditEntry` ve ÖZETİNİ `meta` alanında taşıyan bir `ActivityItem`. Hareket akışı ortağa zaten açık, yani izin içeriği bugüne kadar da ortağa ulaşıyordu. Kodda doğrulandı.
      · GENİŞLEYEN TEK ŞEY ZAMAN PENCERESİ: akış sunucuda 200 kayıtla sınırlı, denetim izi sınırsız. Türü değil süresi genişliyor.
      · DENETİM İKİ GERÇEK EKSİK BULDU: (a) ekranın dayandığı `BuyerPrivacyTests` iddiasından DARDI — yalnızca `updateApartment` yolunu ve yalnızca denetim izini tarıyordu; `saveSale` (adın asıl girildiği yer) ve `cancelSale` kapsam dışıydı, hareket akışına hiç bakılmıyordu. Üç yolu ve iki defteri tarayacak biçimde genişletildi. (b) Maddenin tüm dayanağı olan `allow read: if isMember` kuralı HİÇ test edilmemişti — var olan üç test yalnızca sahiple koşuyordu. Üç kural testi eklendi.
      · 99 Swift + 126 kural testi geçiyor.
      · ~~AÇIK KALAN: dolu satır görünümü doğrulanmadı~~ → **DOĞRULANDI (31 Ağu 2026, simülatör).** İki KDV beyanı kaydı üretilip bakıldı: "BUGÜN" gün başlığı, kayıt başına kart, ÇOK DEĞİŞİKLİKLİ satırın alt alta dizilişi ("Gider KDV tabanı: Belirtilmedi → KDV dahil" + "Satış KDV tabanı: …"), kim/saat ve başlıktaki "2 değişiklik" sayacı doğru. Gerçek CİHAZ turu ayrı iş olarak duruyor.
      · **KURAL YAZILDI (25 Ağu 2026) · YAYINA ALINMADI.** `ownerWrite` artık `serverStamped()` de istiyor: `updatedAt == request.time && updatedBy == uid()`. İlk şart yalnızca `FieldValue.serverTimestamp()` ile sağlanıyor — istemci kendi saatinden Timestamp koyarsa yazma reddediliyor.
      · NEDEN ŞİMDİ: madde 76 ile denetim izi ORTAĞIN gördüğü ekrana taşındı. "Kim ne zaman değiştirdi" cevabı cihaz saatinden geliyorsa iz kanıt değil İDDİADIR.
      · KAPSAM ÖLÇÜLEREK SEÇİLDİ: şartı her yola koymak uygulamayı kendi kuralıyla kilitlerdi. `UserProfileStore` (`users/{uid}`) ve `FirebaseInviteService` (`invites/{KOD}` + proje belgesindeki davet aynası) damgalamadan yazıyor. Kuralı yazmadan ÖNCE tüm istemci yazma yolları sayıldı; koysaydım davet akışı sessizce kırılırdı.
      · EKRANIN TARİHİ DE DÜZELDİ: kural sunucu damgasını doğru tutuyor ama `AuditEntry.date` cihaz saatindendi ve ekranda görünen oydu. `updatedAt` modele decode ediliyor, `trueDate` gösterimde, gün gruplamasında ve SIRALAMADA kullanılıyor — bozuk saatte düzeltmelerin sırası da yanlış görünüyordu.
      · BİLİNEN SINIR: `AuditEntry.user` görünen ad, uid değil; kural onu `request.auth`a bağlayamaz. Pinlenen şey hesap kimliği ve an.
      · 8 kural testi eklendi (cihaz saatinden tarih, ileri tarih, damgasız yazma, başkasının uid'i, eksik alan, güncellemede damga, kapsam). Var olan 14 yazma testi uygulamanın gerçek damgasını aynalıyor. 101 Swift + 184 emülatör testi geçiyor.
      · ~~AÇIK KALAN: kural YAYINA ALINMALI~~ → **YAYINDA (31 Ağu 2026).** `npm run rules:deploy` koşturuldu; `serverStamped` ve madde 82'nin `partnerLedger` bloğu birlikte gitti. **DAVET DAMGASI TAMAM (31 Ağu 2026) ve altından GERÇEK BİR AÇIK çıktı.**
        `invites/{code}` yazmasında `createdAt` ve `expiresAt` CİHAZ SAATİNDEN
        geliyordu ve hiçbir kural onları denetlemiyordu. `redeemInvite` süreyi
        belgedeki `expiresAt`e bakarak ölçüyor (functions/src/index.ts:227),
        yani "kod 48 saat geçerli" cümlesi ekranda yazılıydı ama UYGULAYAN
        KİMSE YOKTU: saati ileri alınmış bir cihaz — ya da değiştirilmiş bir
        istemci — kodu yıllarca geçerli yapabilirdi ve sızan bir kod sonsuza
        kadar açık bir kapı olurdu. Bu, projede yedi kez tekrarlanan desenin
        sekizincisi ("iddia yazılı, uygulayan yok").
        Düzeltme: `createdAt == request.time` (istemci `serverTimestamp()`
        gönderiyor) + `expiresAt <= request.time + 49h`. ÜST SINIR VAR, ALT
        SINIR YOK ve bu bilinçli: saati GERİ alınmış cihaz kendi kodunu kısa
        ömürlü yapar (sinir bozucu ama tehlikesiz, `redeemInvite` zaten
        "süresi dolmuş" diyor); alt sınır konsaydı saati bozuk kullanıcı davet
        ÜRETEMEZ hâle gelirdi ve hata ona sebebini söyleyemezdi. Slack 1 saat:
        `createdAt` sunucu damgası, `expiresAt` istemci hesabı — ağ gecikmesi
        yüzünden tam eşitlik istenemez.
        Proje belgesindeki AYNAYA sunucu damgası KONMADI: o kopya yalnızca
        gösterim, otorite `invites/{KOD}` ve proje kuralı damgayı
        denetlemiyor — kanıt değeri olmayan bir yere kanıt görüntüsü koymak
        olurdu. 4 yeni kural testi (147 kural + 55 işlev testi).
      · **PROFİL DAMGASI YAPILMADI — gerekçesiyle.** `users/{uid}` için
        simetri uğruna kural sıkmak reddedildi: belgeyi yalnızca sahibi
        yazabiliyor (`uid() == userId`), aldatılacak ikinci taraf yok ve
        `createdAt` hiçbir karara girmiyor (yalnızca `AppState`te taşınıyor).
        Buna karşılık maliyeti gerçek: kuralı yayına alırken cihazda ESKİ bir
        derleme varsa profil yazması reddedilir ve kullanıcı "Adın ne?"
        ekranında kilitlenir. Davet damgası bunun tersiydi — orada denetlenen
        değer sunucunun okuduğu bir GÜVENLİK denetimiydi.
      · **YAYIN SIRASI ÖNEMLİ:** yeni kural HENÜZ YAYINA ALINMADI. Yeni
        derleme eski kuralla ÇALIŞIYOR (kural `createdAt`i denetlemiyordu),
        ama eski derleme yeni kuralla davet ÜRETEMEZ. Doğru sıra: önce
        uygulamayı cihaza kur, sonra `npm run rules:deploy`.
      · **TAMAM (25 Ağu 2026).** Opsiyonel uygulama kilidi + uygulama değiştirici örtüsü. Ayar hesap ekranında, VARSAYILAN KAPALI ve ROLDEN BAĞIMSIZ (ortağın ekranları da ciro, tahsilat, taksit planı taşıyor).
      · `deviceOwnerAuthentication` seçildi, `...WithBiometrics` DEĞİL — ve bu ölçülerek doğrulandı: sınama simülatöründe biyometri kayıtlı değil (LAError −7) ama parola yolu var. Biyometri-yalnız politika böyle bir cihazda özelliği tümden kullanılamaz yapar ve yüzü okunmayan kullanıcıyı KENDİ verisinden dışarıda bırakırdı.
      · KİLİT `.background`TA, ÖRTÜ `.inactive`TE — aynı yaşam döngüsünün iki eşiği, iki ayrı sebeple. Fiş fotoğrafı çekmek sahneyi yalnızca `.inactive` yapıyor; kilidi oraya bağlamak en çok kullanılan eylemde her seferinde doğrulama istemek olurdu. Değiştirici anlık görüntüsü ise tam `.inactive` anında alınıyor.
      · FAIL-OPEN: cihaz doğrulama yapamıyorsa kilit açılıyor, ayar da açılamıyor. Tersi uygulamayı kalıcı erişilemez yapardı — hiçbir şey kazandırmadan, çünkü parolasız telefonu eline alan zaten içeride.
      · `NSFaceIDUsageDescription` eklendi; yokken uygulama doğrulama anında ÇÖKER.
      · 10 test. Cihazda uçtan uca doğrulandı: aç → arka plana at → dön → sistem doğrulama istedi (yazılan gerekçe metniyle) → aç → içerik geri geldi. 111 Swift testi geçiyor.
      · **TAMAM (25 Ağu 2026) — üç listede.** Giderler ve malzeme hareketleri arama + dönem süzgeci aldı; hareket akışı arama aldı. Daireler de aynı ortak yardımcıya geçirildi.
      · GEREKÇE: daire sayısı projede SABİT, gider ve fiş sayısı her gün artıyor. Arama en çok ihtiyaç duyulan yerde yoktu.
      · TEK DAVRANIŞ: arama çubuğu ve eşleştirme kuralı ortak bileşende. Her ekranın kendi kuralını yazması, aynı sorgunun bir sekmede bulup diğerinde bulamaması demekti.
      · TÜRKÇE TUZAĞI TESTLE YAKALANDI: aksan katlaması "İ"nin noktasını siliyor, Türkçe küçültme de "I"yı noktasız "ı" yapıyor — "İRSALİYE" → "ırsalıye" olup "irsaliye" ile eşleşmiyordu. i ailesi artık katlamadan ÖNCE elle tek harfe iniyor.
      · "Son 3 ay" TAKVİM AYI, 90 gün değil. Çip sayıları süzülmemiş listeden; başlık sayısı GÖRÜNENİ sayıyor ("1 / 7 kayıt").
      · AKIŞTA DÖNEM ÇİPİ YOK, bilinçli: akış zaten BUGÜN/DÜN/BU HAFTA gruplu, "ne zaman" sorusu ekranda cevaplı; eksik olan "ne"ydi.
      · **KAPSAM DIŞI:** tahsilatlar. Liste daire başına birkaç satır ve proje geneli tahsilat ekranı YOK; olmayan bir listeye süzgeç eklemek yerine o ekran gerekirse ayrı madde olarak açılmalı.
      · 10 test. 121 Swift testi geçiyor. Cihazda doğrulandı.

#### E — PLANLANMAMIŞ ÜRÜN ALANLARI

**KAPSAM KARARLARI VERİLDİ (25 Ağu 2026).** Dört bağımsız mercek + sentez.
Çizilen sınır: uygulama SAHADA OLANIN DEFTERİ ve ortaklar arası şeffaflık
yüzeyi — tek bir tutar tutar, kaydeder ve neyi kapsamadığını YAZAR, ama
HESAPLAMAZ. Dışarıda kalan üçü (vergi hesabı, tedarikçi cari, yasal takvim)
aynı sebeple dışarıda: üçünde de canlı ve hukuken bağlayıcı bir alternatif
var (müşavir + e-fatura · çek defteri + 320 hesabı · belediye tebligatı) ve
uygulamanın üreteceği ikinci rakam, o alternatifle çeliştiği gün yanlış olan
taraf uygulama olur.


Bunlar "ertelendi" değil: yol haritasında maddeleri hiç açılmadı. Kapsam kararı
verilmesi gerekiyor — yapılacaksa madde, yapılmayacaksa yazılı bir "kapsam dışı".

- [x] 80. **KDV / vergi ayrımı** (İş Mantığı#9). "BİRİM FİYAT (₺)" ve gider
      "TUTAR (₺)" alanlarının KDV dahil mi hariç mi olduğu hiçbir ekranda
      yazmıyor; rapor bu belirsizliğin üzerine kuruluyor.
      → **YAPILDI (31 Ağu 2026).** BU BİR DEFTER DEĞİL, KAYIT SÖZLEŞMESİ:
      `TaxBasis` beyanı (KDV dahil / hariç / belirtilmedi), proje düzeyinde,
      menüden → "KDV Beyanı". Uygulama vergi HESAPLAMIYOR ve beyan hiçbir
      tutarı değiştirmiyor — test bunu doğrudan kanıtlıyor (ciro, gider ve
      net beyandan önce ve sonra birebir aynı). Hesaplamak; oran alanı,
      indirilecek/hesaplanan KDV defteri, beyanname dönemi ve düzeltme
      kayıtları demek olurdu; kapsam kararı bunu (b) diye ayırıp dışarıda
      bıraktı.
      **İKİ AYRI BEYAN, TEK BAYRAK DEĞİL** — kararın en önemli düzeltmesi.
      Kapsam kararı "proje düzeyinde tek işaret" diyordu; kodu okuyunca tek
      bayrağın hangi değeri alırsa alsın YARISININ YALAN olacağı görüldü:
      `ReceiptScanner` bilerek fişteki "Ödenecek KDV Dahil Tutar"ı seçiyor
      (gider tarafı dahil), buna karşılık daire bedelleri KDV hariç
      giriliyor. Bu yüzden `expenseTaxBasis` ve `salesTaxBasis` ayrı. Sahada
      da ayrılar: fişin üstünde yazan rakam KDV dahildir, daire ise hariç
      konuşulur.
      **ALANLAR OPSİYONEL — ÖLÇÜLEREK.** Varsayılan değerli ama opsiyonel
      olmayan bir alan, mevcut HER proje belgesini açılamaz yapardı: Swift'in
      türetilmiş çözümleyicisi eksik anahtarda varsayılanı KULLANMIYOR,
      `keyNotFound` atıyor. Küçük bir programla ölçüldü, sonra `nil = beyan
      edilmedi` kalıbına geçildi (`areaM2` ve `remainingCostEstimate` ile
      aynı desen) ve eski belgeyi çözen bir test yazıldı. Göç yok.
      **BEYAN RAKAMIN YANINDA DURUYOR:** form etiketleri ("TUTAR (₺) · KDV
      DAHİL", "LİSTE FİYATI (₺) · KDV HARİÇ", satış bedeli, birim fiyat) ve
      CSV sütun başlıkları ("Tutar (KDV dahil)"). CSV'yi açan mali müşavir
      projenin ayarını göremiyor, yalnızca sayıları görüyordu.
      **SAPMANIN VARLIĞI YAZILI:** iki taban farklı beyan edildiyse rapor
      kapsam cümlesi "Net rakam KDV hariç bir gelirden KDV dahil bir
      maliyeti çıkarıyor; bu fark düzeltilmiş DEĞİLDİR" diyor — ortak
      payının cümlesi de aynı şeyi söylüyor, çünkü pay o netin yüzdeyle
      dilimlenmiş hâli. Eski cümle ("vergi ve finansman giderleri dahil
      değildir") beyan varken TERS yönde okunuyordu: fiş KDV dahil
      giriliyorsa vergi zaten maliyetin içinde.
      **BEYAN DEĞİŞİKLİĞİ DENETİM İZİNDE:** beyan bir gün değiştiğinde
      öncesi ve sonrası aynı defterde farklı anlam taşıyan rakamlar hâline
      gelir; hangi fişin hangi beyan altında girildiği ancak izde kalıyor.
      Geri alınabilir ("Belirtilmedi"e dönüş) — uydurma bir beyan,
      beyansızlıktan kötüdür, çünkü sonrasında sorgulanmaz.
      Testler: TaxBasisTests 8 test. Simülatörde doğrulandı.
- [~] 81. **Tedarikçi / cari hesap, ödendi–vadeli ayrımı** (İş Mantığı#5).
      Uygulama kapsam dışı olduğunu ortağa YAZIYOR ama maddesi yok.
- [x] 82. **Ortak cari hesabı** — sermaye, avans, dağıtım (Farklılaştırıcı#2,
      🔴 Kritik). `PartnersTabView:174` kullanıcıya "henüz tutulmuyor" diyor.
      → **YAPILDI (31 Ağu 2026).** `PartnerLedgerEntry` (tarih, ortak, tür ∈
      {sermaye, çekilen/avans, kâr dağıtımı}, tutar, not) + ortak bazında
      yürüyen bakiye; `Payment` desenini birebir izliyor.
      **NEDEN EN ÖNEMLİSİYDİ:** `share(of:)` hesap TUTMUYOR, proje
      toplamlarını yüzdeyle DİLİMLİYOR — 8 M ₺ koyan ortakla hiç para
      koymamış ortak birebir aynı "Payın %50" kartını görüyordu. Daha ağırı:
      bir dağıtımı kaydetmenin TEK yolu `.diger` kategorisinde bir giderdi ve
      `netAmount = satış − (malzeme + diğer gider)` olduğu için ortağa para
      ödemek inşaat maliyeti gibi görünüp dağıtımın dayandığı rakamı BÜTÜN
      ortaklar için birden düşürüyordu: uygulamanın ürettiği rakam, kendi
      sebep olduğu ortaklık ihtilafının dayanağı oluyordu.
      **KORKULUK 1 — CARİ HAREKET GİDER DEĞİL.** Ayrı koleksiyon, hiçbir
      gider toplamına ve dönem netine girmiyor; test bunu doğrudan kilitliyor
      (dağıtım + sermaye eklendikten sonra `totalCost`, `netAmount`,
      malzeme ve diğer gider toplamları birebir aynı). Sermaye ve çekiş bir
      NAKİT/FİNANSMAN hareketi; madde 35 sınıfı bir sapmanın geri açılmaması
      buna bağlı.
      **KORKULUK 2 — "DAĞITILABİLİR KÂR" HESAPLANMIYOR.** Defter açılır
      açılmaz sorulacak ilk soru bu ve o soru madde 86'nın kalan inşaat
      maliyetini, stoğun gerçekleşme oranını ve vergi yükünü ister. Kart çok
      daha dar bir şey söylüyor: ortak ne koydu, ne çekti, arada ne kaldı.
      **KORKULUK 3 — GİZLİLİK KARARI KURALDA ALINDI, EKRANDA DEĞİL.**
      `firestore.rules · partnerLedger`: A ortağı B'nin çektiğini GÖRÜR.
      `buyers/{apartmentId}` ile aynı sınıfta bir karar ama sonucu TERS ve
      sebebi yazılı: alıcı ÜÇÜNCÜ KİŞİ, ortaklara görünmeyi hiç kabul
      etmedi; ortak ise hesabın TARAFI — kimin ne koyduğu hepsinin aynı havuz
      üzerindeki iddiasını belirliyor. Gizlemek, uygulamanın önlemek için var
      olduğu tartışmayı WhatsApp'a geri gönderir ve yöneticinin her ortağa
      ayrı hikâye anlatmasına izin verirdi. Ortak YAZAMAZ (`ownerWrite`):
      kendi çektiğini kendi yazabilseydi kayıt mutabakat belgesi olmaktan
      çıkardı. Kural testlerinde koleksiyon ortak kalıba eklendi (143 test).
      **TUTAR HER ZAMAN POZİTİF, YÖN TÜRDEN GELİYOR:** tek bir işaretli para
      alanı olsaydı formda "−" yazmayı unutan kullanıcı sessizce ters yönde
      kayıt üretirdi. Bakiye EKSİYE DÜŞEBİLİYOR ve düşmeli — koyduğundan
      fazlasını çekmiş ortak ortaklığa borçludur.
      **PAY KARTI CARİYİ İÇERMİYOR** ve cümle sertleşti: "Ortakların koyduğu
      sermaye ve çektiği para AYRI tutuluyor; bu paylara eklenmez, buradan
      düşülmez." İkisini tek rakama katlamak "payına düşen" ile "sana kalan"
      arasındaki farkı silerdi.
      **YEDEK SÜRÜMÜ 2 VE SÜRÜM DENETİMİ ASİMETRİK OLDU:** eşitlik koşulu
      (`surum == backupVersion`) korunsaydı bu madde kullanıcının kendi
      SÜRÜM 1 yedeklerini okunamaz yapardı — yani veri kaybını önlemek için
      konmuş kural veri kaybına sebep olurdu. Artık eski sürüm kabul, YENİ
      sürüm ret: eskide kaybolacak bir şey yok, yenide sessizce düşen bir
      koleksiyon var. Alan opsiyonel (madde 80'de ölçülen `keyNotFound`
      sebebiyle). Geri yüklemede ortağı yedekte bulunmayan hareket düşüyor ve
      `droppedRecords`ta sayılıyor.
      CSV AYRI DOSYA ("Ortak-Cari.csv") — giderlerin içine konsaydı müşavir
      onları gider sanırdı; "Yön" ve "İşaretli Tutar" sütunları var, çünkü
      "Sermaye"/"Çekilen" kelimeleri Excel'de toplanınca yön kayboluyor.
      Testler: PartnerLedgerTests 11 test. Toplam 166 Swift + 143 kural testi.
      Demo veride Çayırova'ya üç sermaye ve iki çekim kondu; hareketsiz
      ortak (Burak Erdoğan) kartta satır üretmiyor.
- [x] 83. **Blok / etap kavramı** (Gözden Kaçanlar#6). Kanıtı demo verisinin
      içinde: "SF-1 Blok 1" ve "GB Blok 1" iki AYRI proje olarak, uydurma
      ada/parsel numaralarıyla modellenmiş.
      → **DÜZELTME:** ada/parsel numaraları UYDURMA DEĞİL, ikisi de gerçek
      TOKİ verisi (1224/1 ve 1139/3). Gerçek eksik daha dar ve daha net:
      veride "blok" diye bir alan YOKTU; blok adları yalnızca yorum
      satırında yaşıyordu.
      → **YAPILDI (31 Ağu 2026, dar dilim).** `Apartment.blockLabel` —
      serbest metin, boş = belirtilmedi.
      **NEDEN DAİREDE, PROJEDE DEĞİL:** etiket projede olsaydı "proje başına
      tek blok" demek olurdu ve kullanıcı her blok için ayrı proje açmaya
      devam ederdi — maddenin bütün maliyeti orada. Üç bloğu sonradan
      birleştirmek, o projelerin altındaki her daire, malzeme, fiş, gider,
      tahsilat, taksit ve DENETİM İZİ belgesini yeni yola kopyalayıp silmek
      demek; yani madde 77'nin "iz sonradan yazılamaz" kuralını uygulamanın
      kendi eliyle çiğnemesi. Listedeki tek FAİZİYLE BÜYÜYEN madde buydu, o
      yüzden dar dilim bugün girdi.
      **SERBEST METİN:** TOKİ "SF-1 Blok 1", müteahhit "A Blok", belediye
      "2. Etap" diyor; sabit liste, sahadaki adı uygulamanın adına çevirmeyi
      kullanıcıya yıkardı.
      **GİDER BLOĞA DAĞITILMIYOR** — kararın en önemli yarısı. Beton bütün
      şantiyeye dökülüyor, vinç iki bloğu birden kaldırıyor, ruhsat harcı
      parsele ödeniyor. Blok başına maliyet dağıtmak, hiç toplanmamış bir
      veriden blok KÂRI üretmek olurdu: `areaCost`ta nil döndürerek ve m²
      maliyetinin paydasını yazarak defalarca reddedilen sahte hassasiyet.
      Rapor kartı bu yüzden yalnızca daireye KESİN ait rakamları taşıyor
      (adet, ciro, stok) ve eksiği kendi altında yazıyor. Stok satırı
      rezerve sayısını da söylüyor: beklenen hasılat kartı rezerveyi ayrı
      kovada tutuyor, blok kartında sessizce karıştırmak o ayrımı bir kat
      yukarıda silmek olurdu.
      **DAİRE NUMARASI PROJE GENELİNDE TEKİL KALDI:** denetim izi daireyi
      NUMARASINDAN yazıyor (`apartment(in:number:)`); blok başına 1'den
      başlayan numaralandırma geçmiş izleri iki daire arasında belirsiz
      bırakırdı.
      **KIRILIM YALNIZCA BİRDEN ÇOK ETİKET VARSA** görünüyor (liste
      gruplaması ve rapor kartı): tek bloklu her projeye "A Blok · 20 daire"
      kartı koymak hiçbir şey söylemeyen bir kart olurdu. Gruplama süzgecin
      ALTINDA: "Boş" süzgeci açıkken boş dairesi olmayan blok başlığı
      görünmemeli, yoksa başlık var olmayan bir stoğu ima ederdi.
      Etiketsizler her yerde EN SONDA — "belirtilmedi" bir blok adı değil.
      **GÖÇ YOK:** eski belgelerde alan hiç yok, `decodeIfPresent` + boş dize
      zaten geçerli hâl. CSV'de sütun HER ZAMAN var (ekranda kırılım
      koşullu): sütunun bazen olup bazen olmaması müşavirin şablonunu
      bozardı. Toplu "tipi/alanı bütün projeye uygula" etiketi KOPYALAMIYOR —
      tek dokunuşla bütün daireler aynı bloğa taşınırdı.
      Kurulum ekranına yönlendirme cümlesi eklendi ("aynı ada/parselde birden
      çok blok varsa TEK proje aç") — kararın alındığı ve geri dönüşü olan
      tek an orası.
      Testler: BlockLabelTests 8 test. Demo veride Çayırova iki bloğa
      (A: 1-10, B: 11-20) bölündü, Kars projeleri gerçek blok adlarını aldı.
      Simülatörde doğrulandı: A Blok 31.450.000 ₺ (9/10) + B Blok
      11.200.000 ₺ (3/10) = 42.650.000 ₺, başlıktaki satış rakamıyla aynı.
      **KAPSAM DIŞI KALAN:** gerçek Proje → Blok → Daire hiyerarşisi ve blok
      bazlı maliyet dağıtımı. Tetik: aynı sahibin aynı ada/parsel/ilçe ile
      ikinci projeyi açmaya devam etmesi (`addProject` içinde tespit
      edilebilir bir sinyal).
- [~] 84. **Ortak ↔ yönetici iletişimi** (Gözden Kaçanlar#7). Ortağın yüzeyi
      salt okunur bir vitrin: gideri sorgulayamıyor, raporu "gördüm" diye
      işaretleyemiyor. Bildirim de gitmediği için ilişki tek yönlü.
- [x] 85. **Yasal takvim** — ruhsat, iskân, yapı denetim, sözleşme süreleri.
      Tek hatırlatıcı yüzeyi taksit vadesi.
- [x] 86. **Kalan stoğun değeri ve projeyi bitirmenin maliyeti** hiçbir ekranda
      yok; "satılan ciro + kalan stok değeri = beklenen hasılat" gösterilmiyor.
      → **YAPILDI (31 Ağu 2026, iki yarı).**
      **Birinci yarı — beklenen hasılat.** `StockOutlook` +
      `stockOutlook(for:)` (ProjectViewModel.swift) ve ReportView'da
      `outlookCard`. Rakam ÜÇ KOVA hâlinde ayrı duruyor (satılan / rezerve /
      boş stok) çünkü güven düzeyleri farklı: satılan gerçekleşti, rezerve
      sözleşmesi kesinleşmedi, boş dairenin liste fiyatı bir HEDEF. Tek
      rakama katlamak, uygulamanın `countsAsRevenue` / `isSellable` ayrımıyla
      alt katta çözdüğü hatayı üst katta tekrarlamak olurdu. Kat karşılığı
      daire hiçbir kovaya girmiyor; test kalan tüm daireleri 999.999 ₺'lik
      `landOwner` yapıyor, böylece bir sızıntı toplamı patlatarak kendini
      söyler. Liste fiyatı GİRİLMEMİŞ boş daireler sayılıyor ama
      TOPLANMIYOR ve ekran bunu yazıyor (`pricelessCount`) — madde 25'teki
      `missingCount` deseninin aynısı: eksik rakamın sessiz kalması bu kod
      tabanının defalarca düzelttiği hata. Demo veride uyarı gerçekten
      ateşlendi (3 boş daire, 0 ₺).
      **İkinci yarı — bitirmenin maliyeti: ELLE GİRİLİR.** `Project`e
      `remainingCostEstimate: Kurus?`, ProgressSheet'e tek bir alan.
      Uygulama bu rakamı HESAPLAMIYOR: elde yalnızca elle sürülen yüzde var
      ve "harcanan ÷ %ilerleme" ile toplam maliyet türetmek, bu kod tabanının
      `areaCost`ta nil döndürerek reddettiği uydurma rakam sınıfına girerdi
      (maliyet doğrusal ilerlemiyor; kaba inşaatla ince işlerin eğrisi aynı
      değil) — üstelik çıkan rakam ortağa PDF olarak dağıtılıyor.
      Alan ProgressSheet'te, gider ekranında DEĞİL: gider defteri OLMUŞ
      harcamayı yazıyor, bu ise OLACAK olanın tahmini; aynı listeye girseydi
      "harcanan" toplamını şişirirdi. Soru ise ilerleme yüzdesiyle birebir
      aynı soru — proje şu an nerede, bitirmeye ne kalıyor?
      `nil` ile SIFIR ayrı tutuldu: `parseMoney("")` sıfır döndürüyor ama
      burada sıfır "masraf kalmadı" iddiası, nil ise "bilmiyorum". Boş metin
      tahmini SİLİYOR, sıfırlamıyor; `updateProgress`'in parametresi
      opsiyonel, böylece kalan maliyeti taşımayan çağrılar girilmiş tahmini
      sessizce silmiyor. Girilmemişse "Beklenen sonuç" satırı HİÇ
      görünmüyor — nil'i sıfır saymak, temeli yeni atılmış projede kocaman
      bir kâr uydurmak olurdu.
      `PartnersTabView.scopeText` ve ReportView'ın kapsam cümlesi de
      güncellendi: tahmin girildiğinde rakam yazılıyor ama paylardan hâlâ
      DÜŞÜLMÜYOR ve cümle bunu söylüyor — elle girilmiş bir tahmini ortağın
      hissesine karıştırmak, dağıtılabilir tutarı bir tahminin arkasına
      saklamak olurdu.
      Testler: StockOutlookTests 13 test (6 hasılat + 7 maliyet). Test kurulumu
      tohum verisine yaslanmıyor — demo veride ilk projenin tahmini artık DOLU
      (kartın dolu hâli demo'da da görülsün diye), o yüzden `kur()` başlangıç
      durumunu kendisi kuruyor. Simülatörde iki hâl de doğrulandı:
      46.050.000 − 24.397.500 − 14.500.000 = 7.152.500 ₺.
- [x] 87. **Gelir modeli kararı yazılı değil.** StoreKit/abonelik/sınır sıfır;
      her kullanıcı ücretli SMS ve Avrupa Storage maliyeti üretiyor. "Önce
      ücretsiz" gibi bilinçli bir karar da kayıtlı değil.
      → **YAPILDI (31 Ağu 2026) — (a) karar yazıldı, (b) kotanın duracağı yer
      açıldı. (c) StoreKit AYRI ve sonraya.**

      ### GELİR MODELİ KARARI

      **PROJE SAYISINA GÖRE ABONELİK. ORTAKLAR SINIRSIZ VE ÜCRETSİZ.**

      *Neden proje sayısı:* değerle DE maliyetle DE aynı yönde büyüyen tek
      eksen o. Beş şantiyesi olan müteahhit hem daha çok değer alıyor hem
      daha çok Storage, Firestore ve SMS tüketiyor. Kullanıcı sayısı ikisini
      de ölçmüyor. `Projeyi Arşivle` zaten var (madde 60), yani biten proje
      saymıyor ve abonelik doğal olarak projenin ömrüne bağlanıyor.

      *Neden ortak başına ücret ALINMIYOR:* ortak SALT OKUR ve parayı ödeyen
      o değil. Ortak başına ücret, müteahhidi daha az ortak davet etmeye
      iter — yani ürünü ayıran özelliği (ortakla şeffaflık) vergilendirir.
      Üstelik uygulamayı gören her ortak potansiyel müşteri: büyüme
      döngüsünün kendisine ücret koymak olurdu. Kod karşılığı yazıldı ve
      testle kilitlendi: `quotaSnapshot` yalnızca SAHİBİ olunan projeleri
      sayıyor, ortak olarak katılınanları saymıyor.

      *Ücretsiz katman TRIAL DEĞİL, KALICI:* 1 aktif proje + sınırsız ortak.
      Bu uygulama veri girildikten SONRA değer üretiyor; 14 günlük deneme
      dolduğunda kullanıcının elinde henüz yarım girilmiş bir şantiye kaydı
      oluyor ve güven kurulmamış oluyor.

      *Fiyat çapası:* karşılaştırma başka uygulamalar değil — muhasebeci,
      Excel ve "bir daire yanlış hesaplanırsa". Tek dairenin marjı yanında
      aylık ücret önemsiz kalmalı. Yıllık seçenek önemli: hem Firebase
      maliyetini önden karşılar hem müteahhidin proje döngüsüne uyar.

      ### FİYATLAR ONAYLANDI (15 Eki 2026)

      | Paket | Aktif proje | Ortak | Aylık | Yıllık |
      |---|---|---|---|---|
      | Ücretsiz | 1 | 2 | — | — |
      | Şantiye | 3 | sınırsız | 749 ₺ | 7.490 ₺ |
      | Müteahhit | 10 | sınırsız | 1.499 ₺ | 14.990 ₺ |
      | Kurumsal | sınırsız | sınırsız | 4.999 ₺ | 49.990 ₺ |

      **YILLIK = ON AYIN FİYATI** ("iki ay bedava"). İki işi var: iletişimi
      kolay ve Firebase maliyetini önden karşılıyor. Katalogda rakamlar ELLE
      yazılı (`Kurus`ta çarpma operatörü bilerek yok); kuralı `PlanTests`
      koruyor — on ayı tutmayan bir yıllık fiyat testi kırmızıya döndürür.

      **ÇAPA MALİ MÜŞAVİR ÜCRETİ, BAŞKA UYGULAMA DEĞİL.** Müteahhit "şu
      uygulama şu kadarmış" diye değil "ayda şuna şu kadar veriyorum" diye
      düşünüyor. Değer tarafı zaten tartışma götürmüyor: projenin kendi
      verisinde 1 m³ beton 2.450 ₺, bir daire 3,4–3,9 M ₺ — aylık ücret
      gürültü mertebesinde. Sınırlayan şey değer değil, alışkanlık.

      **İKİ KURAL BİRBİRİNİN AYNASI:** sınırlarda *dar başla, gevşet*;
      fiyatta *yüksek başla, indir*. Sebep aynı asimetri — indirim hediyedir,
      zam güven kaybıdır. Önerilen (henüz karar değil) uygulama **kurucu
      fiyatı**: ilk kullanıcılara fiyatı ömür boyu sabitlemek. Üçünü birden
      çözer: erken kullanıcıya gerçek ayrıcalık, sana zam alanı, zam gününde
      kimsenin ihanete uğramaması.

      **NET GELİR:** Apple kesintisi %15 (yıllık 1 M $ altı). 749 ₺'nin
      ~637 ₺'si kalıyor; fiyat net rakamla düşünülmeli.
      **ASIL DEĞİŞKEN MALİYET SMS**, kullanım değil: yeni kullanıcı bir kez
      doğrulama SMS'i yakıyor, sonrası neredeyse bedava (fotoğraflar ~265 KB).
      Ücretsiz katmanı taşınabilir kılan da bu.

      **DOĞRULANACAK:** rakamlar Mayıs 2026 bilgisine dayanıyor, Ekim 2026
      fiyatlarıyla teyit edilmeli. Yöntem: üç müteahhide "öder misin" DEĞİL,
      (a) "mali müşavirine ayda ne ödüyorsun", (b) "bir günlük gecikme kaça
      patlıyor", (c) fiyatı gösterip "pahalı mı ucuz mu" diye sor. Tehlikeli
      cevap "pahalı" değil, **"çok ucuzmuş"**.

      ### REKLAM YOK (15 Eki 2026 kararı)

      Gelir modeli yalnızca abonelik. Üç sebebi de teknik:
      1. Uygulama ciroyu, ortak payını ve alıcı adlarını gösteriyor; bu
         ekranların yanında reklam, ürünün sattığı tek şeyi — güveni — zayıflatır.
      2. Reklam SDK'larının tamamı izleme yapar. `PrivacyInfo.xcprivacy` bugün
         `NSPrivacyTracking = false` diyor; reklam eklemek o BEYANI BOZAR,
         App Store etiketini değiştirir ve verilen sözü geri alır.
      3. Reklam geliri aboneliği zayıflatır: ödeyen kullanıcı neden hâlâ
         reklam gördüğünü sorar, ödemeyen ödemek için sebep bulamaz.

      ### KATMAN KARARLARI (15 Eki 2026)

      **ÜCRETSİZ KATMAN DAR BAŞLIYOR: 1 aktif proje + 2 DAVETLİ ortak.**
      Gerekçe asimetri: *sınırı gevşetmek bedava, sıkmak imkânsız.* Bugün 2
      ortak verip altı ay sonra "artık sınırsız" demek hediyedir; tersi, zaten
      davet etmiş kullanıcıdan geri almaktır — madde 87'nin "ilk yayının
      sınırsızlığı geri alınamaz" gerekçesinin aynısı. Karşı risk de yazılı:
      hedef kitlenin çoğu aynı anda tek şantiye yürütüyorsa 1 proje ücretsiz
      demek "çoğu kullanıcı hiç ödemez" demek olabilir; dar başlamak bu riski
      de dengeliyor.
      ÜCRETLİ KATMANDA ORTAK SINIRSIZ — kişi başına ücret ALINMIYOR; gerekçesi
      yukarıda (ortak salt okur, parayı müteahhit öder, kişi başına ücret
      ürünü ayıran şeyi vergilendirir).
      Kod: `Entitlement.invitedPartnerLimit` + `Quota.canInvitePartner`;
      boğaz `generateInviteCode`. KURUCU SAYILMIYOR — kendi `Partner` kaydı
      sınırı yeseydi ilan edilen "2 ortak" sessizce 1 olurdu. 4 test.

      **PROJEDE TEK YÖNETİCİ KALIYOR — ÜRÜN KARARI, EKSİK DEĞİL.**
      Bugün yetki `ownerUid`den türüyor: projeyi kuran yazar, davet edilen
      herkes salt okur. "İkinci yönetici" rolü SORULDU ve kullanıcı kendi
      ortaklı işlerinde kayıtları hep bir kişinin tuttuğunu söyledi (15 Eki
      2026). Bu yüzden rol EKLENMİYOR.
      Kararın fiyattan ÖNCE alınması gerekiyordu: sonradan eklenseydi ya söz
      verilmemiş bir şey bedava verilmiş ya da satın alınan paketin içeriği
      değiştirilmiş olurdu. Tetik: gerçek bir kullanıcının "ortağım da fiş
      giriyor" demesi — o gün karar yeniden açılır ve eklenirse pakete DAHİL
      olmalı, kişi başına ücretlendirilmemeli.

      **ELENENLER VE GEREKÇELERİ**
      · *Mağazadan ücretli indirme:* en kötüsü. Sunucu maliyeti SÜREKLİ (SMS
        başına ücret, fotoğraf depolama), gelir TEK SEFERLİK. Ayrıca
        denemeden satın alma, veri girmeden değer görmeyen bir üründe yanlış.
      · *Tek seferlik kilit açma:* aynı maliyet sorunu.
      · *Proje başına tek seferlik ("proje aç = X TL"):* TÜMDEN ELENMEDİ,
        ikinci aday — müteahhidin iş başına maliyet düşünme alışkanlığına
        uyuyor ve abonelik direncini aşıyor. Sakıncası veriyi bozması:
        kullanıcıyı her şeyi tek projeye tıkmaya iter (madde 83'ün tam
        tersi yönde bir baskı).
      · *Ortak başına ücret:* yukarıda.

      **YAYIN ÖNCESİ KORKULUKLAR (kodda yazılı — Quota.swift)**
      1. *Abonelik YAZMAYI kilitler, OKUMAYI asla.* Aboneliği biten
         müteahhidi kendi mali kaydından dışarıda bırakmak kabul edilemez:
         veri onun, uygulama yalnızca tutuyor. Ölçüt `AppLock`ın fail-open
         kararıyla aynı — kullanıcıyı kendi verisinden ayıran hata,
         koruduğu şeyden pahalı.
      2. *Sınır KURALDA değil İSTEMCİDE.* Firestore kuralında proje sayısı
         denetlemek her yazmada bir `get()` demek: yazma başına ek okuma, ek
         ücret ve yeni bir kırılma yolu — hak belgesi okunamadığı an TÜM
         yazmalar reddedilirdi. Kuralın işi yetki, kotanın işi ticaret;
         ikisini aynı yere koymak ticari bir hatayı veri kaybı gibi
         gösterir.
      3. *Arşiv sayılmıyor.* İnşaat yıllarca sürüyor; arşivi saymak
         kullanıcıyı yeni proje açabilmek için geçmişini silmeye iterdi.

      **(b) KOTANIN DURACAĞI YER BUGÜN AÇILDI.** `Quota.swift`: `Entitlement`
      (free / subscribed / preLaunchUnlimited), `QuotaSnapshot` (aktif +
      arşiv proje, belge, fotoğraf sayaçları) ve TEK boğaz noktası
      `canCreateProject`. `addProject` bugün de bu boğazdan geçiyor; bugün
      hiçbir şeyi durdurmuyor çünkü hak `preLaunchUnlimited`. Yayında
      değişecek TEK satır `ProjectViewModel.entitlement`.
      Gerekçe geri dönülemezlik: StoreKit sonra yazılabilir, ilk yayının
      SINIRSIZLIĞI geri alınamaz — 12 proje açmış kullanıcıyı sonradan 3
      proje sınırına sokmak ya sonsuza kadar muafiyet ya da güven kaybı.
      Testler sınırı ENJEKTE EDEREK yayın gününün provasını yapıyor
      (QuotaTests, 7 test): açık olmayan bir mekanizmanın çalıştığı iddia
      edilemez.
      Belge ve fotoğraf sayaçları ölçülüyor ama SINIR UYGULAMIYOR:
      `storage.rules` dosya başına 4 MB / 50 MB koyuyor, SAYI sınırı yok.
      Sınırın nereye konacağı gerçek kullanım görülmeden bilinemez; ölçmeden
      konan bir sayı kullanıcıyı maliyet gerekçesi olmadan durdururdu.

      **YAYINDAN ÖNCE KAPATILACAK (madde 71'in kalan yarısı):** App Check
      ZORLAMASI. Bugün `AppCheckSetup` zorlamanın bilerek açılmadığını
      yazıyor, callable'larda `enforceAppCheck` kapalı ve `rateLimits`
      callable'ları koruyor ama Auth'u KORUMUYOR — sökülebilir API
      anahtarıyla ücretli SMS yakılabilir ve Firebase bütçe uyarısı harcamayı
      KESMEZ. Konsol işi kullanıcıda; ardından `enforceAppCheck` açılacak.

      **DOĞRULANACAK TEK DIŞ BİLİNMEYEN — bundan önce StoreKit'e tek satır
      kod yazılmamalı:** Apple'ın uygulama içi satın alma zorunluluğu ve dış
      ödeme bağlantısı kuralı bölgeye göre değişiyor ve son yıllarda değişti.
      (c) parçasının tetiği: ilk ücretli yayından önce ya da Firebase
      harcaması yazılı bir eşiği geçtiğinde.

      ### (d) PAKETLER GÖRÜNÜR OLDU (15 Eki 2026)

      **BULUNAN KUSUR:** katalog kodda vardı ama `Plan` tipi `Views/` altında
      TEK BİR YERDE geçmiyordu. Yani kullanıcının fiyatı öğrenebileceği tek
      an, bir sınıra çarpıp şerit mesajı okuduğu andı — **fiyatı ancak
      reddedilerek öğreniyordu.** Satın alma kararının verilebileceği en kötü
      an bu; üstelik yayın öncesi `preLaunchUnlimited` olduğu için o şerit
      bile hiç çıkmıyordu, yani ürünün ücretli olduğu HİÇ söylenmiyordu.

      **`PlansSheet` (yeni ekran).** Dört paket kartı, fiyat, yıllık rakamıyla
      ("iki ay bedava"), "her pakette olanlar" AYRI kartta, altta koşullar ve
      gizlilik bağlantısı. Ekranda **tek bir rakam elle yazılı değil**; hepsi
      `Plan` kataloğundan. Fiyat etiketi iki ayrı yerde dursaydı biri değişip
      diğeri kalırdı ve kullanıcı, ekranda okuduğu sayıyı vermeyen bir pakete
      para ödemiş olurdu.

      **YALNIZCA GERÇEKTEN FARKLI OLAN İKİ ŞEY YAZIYOR.** Paketler arasında
      özellik farkı YOK; değişen tek şey iki sayı. "Öncelikli destek" gibi
      üçüncü bir madde uydurmak ilk destek e-postasında yalana dönerdi —
      üstelik satın alma kararını o yalan verdirmiş olurdu. `highlights`
      sınırın kendisinden türüyor; `PlanTests` türetmeyi kilitliyor ve
      türetme bilerek bozulup testin ÜÇ pakette birden kırmızıya döndüğü
      görüldü (vakum testi değil).

      **ORTAK ÖZELLİKLER AYRI KARTTA.** "Sınırsız daire/gider kaydı, salt
      okur ortaklar, rapor ve Excel, reklam yok" — bunlar ücretsiz katmanda
      da var. Paket kartlarına kopyalansaydı ücretsiz kullanıcı, zaten sahip
      olduğu şeyler için ödemesi gerektiğini sanırdı. Dördünün de kodda
      karşılığı var; doğrulanamayan madde yazılmadı. Test
      (`testCommonFeaturesAreNotPlanDifferences`) ikisinin karışmasını
      engelliyor.

      **İKİ GİRİŞ NOKTASI, İKİSİ DE SESSİZ.**
      · *Panoda sabit satır* — kullanıcı aramadan görüyor. Tek yol hesap
        kartı olsaydı, avatara dokunmayı akıl etmeyen kullanıcı ürünün bir
        sınırı olduğunu hiç öğrenemezdi. Yalnızca YÖNETİCİDE: paket, projeyi
        kuranın ödeme ilişkisi; ortağın salt okunur ekranında fiyat
        göstermek ödemeyeceği bir şeyi satmaya çalışmak olurdu.
      · *Hesap kartında satır* — "ne ödüyorum" sorusunun sorulduğu yer.
      Başlıklar DURUMA göre: yayın öncesinde "Paketler", ücretsizde
      "Ücretsiz katman · yükselt", ücretlide paket adı. Sabit "Yükselt"
      yazmak, her şeye zaten sahip olan kullanıcıya yalan söylemek olurdu.

      **"ARA ARA ÇIKAN HATIRLATMA" REDDEDİLDİ.** Araya giren tanıtım,
      kendi ürünün için reklamın ta kendisi — ve reklamı reddetme
      gerekçelerinin üçü de bunun için aynen geçerli. Sınıra çarpınca YENİ
      bir kart da belirmiyor: aynı satırın tonu ve cümlesi değişiyor, yoksa
      kullanıcı ekranda yerini kaybeder. Sınırdayken İKİ çıkış da yazılı
      (arşivlemek bedava, paket ücretli); yalnızca paketi göstermek,
      kullanıcının zaten hakkı olan ücretsiz çözümü saklamak olurdu.

      **SATIN ALMA DÜĞMESİ YOK — `Plan.purchasesAvailable = false`.**
      StoreKit bağlanmadan düğme koymak dead UI olurdu: bastıran kullanıcıya
      uygulamanın bakımsız olduğunu söyler, hiç olmaması ise yalnızca "henüz
      satışta değil" der. Ekran bugün BİLGİ ekranı.
      **EN ÖNEMLİ KORKULUK BURADA:** yayın günü değişecek tek satır
      `entitlement`. O satır TEK BAŞINA değiştirilirse kullanıcı ikinci
      projesini açamaz VE ödeyerek açmanın yolu da olmaz — çıkışı olmayan bir
      duvar, ürünün yapabileceği en kötü şey. İki değişikliği birbirine
      bağlayan tek şey `QuotaTests.testLimitsNeedAPaymentPath`: bugün sessizce
      geçiyor, yayın günü kotayı açan kişi satın almayı açmadan yeşil göremez.

      **YAN BULGU:** AccountSheet'in gövdesi sabit yükseklikteydi ve yeni
      bölümlerle küçük ekranlarda taşıyordu. SwiftUI taşan kısmı SESSİZCE
      kırpar — yani "Hesabı Sil", App Store 5.1.1(v) ile zorunlu tek giriş,
      hiç görünmeden kaybolabilirdi ve kırpılma hata vermediği için ancak
      sahada fark edilirdi. Gövde kaydırılabilir yapıldı.
      · **KAPSAM KARARI (25 Ağu 2026): MADDE** — Tutarın KDV tabanı beyan edilsin (hesaplanmasın)
      · Dört mercek de aynı çelişkiyi bağımsız buldu ve kodda doğruladım:
        ReceiptScanner bilerek fişteki 'Ödenecek KDV Dahil Tutar'ı seçip birim
        fiyat alanına taşıyor (ReceiptScanner.swift:106-118), buna karşılık
        seed'deki daire bedelleri açıkça 'KDV hariç'
        (InMemoryProjectRepository+Seed.swift:288). Yani netAmount = satış −
        maliyet, KDV HARİÇ bir gelirden KDV DAHİL bir maliyeti çıkarıyor ve o
        rakam ortağa PDF olarak dağıtılıyor. Konut satışında oran %1-10,
        malzemede %20 olduğu için sapma tek yönlü değil: maliyet şişik, ciro
        düşük. Kararın alındığı an haftada 20-30 kez (her fiş girişi), yani
        listedeki en sık karşılaşılan eksik. Belirleyici olan maliyet
        merceğinin ikiye bölmesi: (a) tabanı KAYDETMEK bugün neredeyse bedava,
        yarın imkânsız — bugün girilen 100.000 ₺'lik fişin hangisi olduğu
        kayıt dışı kalıyor ve hiçbir kod bunu geri getiremiyor; bu, madde
        10c'de 'Firestore'dan ÖNCE yapıldı' denilen sınıfın aynısı. (b)
        İndirilecek/hesaplanan KDV defteri ise unitPrice'ın 77, amount'ın 51
        referansını, ReportSummary'nin 4 para satırını ve yedek şemasını
        katlar. Kapsam (a): proje düzeyinde 'tutarları KDV dahil/hariç
        giriyorum' işareti, alan etiketlerine yazılması, mevcut kayıtlar için
        'belirtilmedi' durumu ve rapor kapsam notuna 'uygulama vergi
        HESAPLAMAZ' cümlesi. Madde metnine 'bu bir defter DEĞİL, kayıt
        sözleşmesidir' açıkça yazılmalı; ayrıca ReportView.scopeNote'taki
        'vergi dahil değildir' cümlesi taban dahilse yanlış yönde okunuyor, o
        da düzelmeli.
      · AYRIŞMA: Ayrışma karar değil MALİYET tahmininde:
        gün/maliyet/alternatif 'küçük', vaat 'orta' dedi. Vaat merceği haklı
        bir uyarı ekliyor — mevcut kayıtların tabanı yok, dolayısıyla
        'belirtilmedi' durumu ve yedek şema sürümü (madde 56 bilinmeyen sürümü
        reddediyor) işin parçası. Bu yüzden kapsamı maliyet merceğinin (a)/(b)
        ayrımıyla sabitledim: (a) yapılır, (b) bu maddenin işi değil.
      · **KAPSAM KARARI (25 Ağu 2026): ERTELENMİŞ** — Tedarikçi cari / ödendi-vadeli ayrımı
      · Listenin en çok ayrışan maddesi: gün 'madde', vaat 'kapsam dışı',
        maliyet ve alternatif 'ertelenmiş' dedi. Kararı belirleyen soru şu:
        uygulamanın GÖSTERDİĞİ bir rakam bozuluyor mu? Hayır. Vaat merceğinin
        analizi burada en güçlüsü — uygulama hiçbir yerde kasa bakiyesi iddia
        etmiyor; ortağın KASA satırları 'Tahsil edilen' ve 'Kalan alacak',
        ikisi de alacak tarafı. Tahakkuk esaslı bir maliyet, fatura 4 ay
        vadeli çeke bağlanmış olsa da DOĞRUDUR; eksik ama yalan değil ve
        PartnersTabView.swift:206 bu eksiği ortağa yazıyor. Buna karşılık gün
        merceğinin 'ay sonu hangi çek var' itirazı da gerçek. Ancak bu bir
        alan değil DEFTER: 14. koleksiyon + tedarikçi kaydı + vade + kısmi
        ödeme mahsubu, ve asıl bedeli raporun ekseninin tahakkuk/nakit diye
        ikiye bölünmesi. Kapsam dışı yapmamamın sebebi: iki mercek birbirinden
        bağımsız olarak AYNI ucuzlama koşulunu buldu — madde 82'nin cari
        defter mekaniği (kayıt tipi + yürüyen bakiye + rules + kural testi +
        yedek şeması + restore + CSV + denetim izi) bir kez kurulduğunda 81
        yeniden icat değil kopyalama olur. 'Sonra bakarız' değil, fiyatı
        ölçülebilir biçimde düşen bir iş. Ertelemenin bir bedeli ŞİMDİ
        ödenmeli: Expense.swift:51-52'deki yorumlar 'Ödenen tutar' ve 'Ödeme /
        hakediş tarihi' diyor — modelin garanti etmediği bir ödeme iddiası;
        'gider / hakediş tutarı' olarak düzeltilmezse kod yanlış bir şey
        söylemeye devam eder. Aynı şekilde ProjectExporter.expensesCSV
        başlığında 'Tutar' ile yan yana duran 'Ödenen' sütununa payee (kişi)
        yazılıyor.
      · TETİK: Madde 82'nin ortak cari defteri yayına girip mekaniği (kayıt
        tipi + yürüyen bakiye + firestore.rules bloğu + kural testi + yedek
        sürüm + restore) kanıtlandığında yeniden değerlendirilir. İkinci ve
        daha erken tetik: gerçek bir kullanıcının 'raporda gider yazıyordu ama
        çek daha ödenmemişti' demesi.
      · **KAPSAM KARARI (25 Ağu 2026): MADDE** — Ortak cari hesabı — sermaye, avans, dağıtım
      · Dört mercekte de 'madde'; sekizinin içinde vaadin (ortaklarla
        şeffaflık) tam merkezinde duran tek iş. İki bulgu kararı kilitliyor.
        Birincisi: share(of:) hesap TUTMUYOR, proje toplamlarını yüzdeyle
        DİLİMLİYOR (ProjectViewModel.swift:2908) — 8 M ₺ koyan ortakla 0 koyan
        ortak birebir aynı 'Payın %50' kartını görüyor ve bakabileceği başka
        yer yok. İkincisi ve daha ağırı: bugün bir dağıtımı kaydetmenin TEK
        yolu .diger kategorisinde bir gider ve netAmount = satış − (malzeme +
        diğer gider); yani ortağa para ödemek inşaat maliyeti gibi görünüp
        dağıtımın dayandığı rakamı, üstelik BÜTÜN ortaklar için aynı anda
        düşürüyor. Uygulamanın ürettiği rakam, kendi sebep olduğu ortaklık
        ihtilafının dayanağı oluyor. Kaybedilen şey ayrıca VERİ: adi
        ortaklıkta sermaye ve avans çekimlerinin çoğu elden dönüyor —
        müşavirin defterinde yok, Excel'de yok; 18 ay sonra banka
        dekontlarından geriye kurmak madde 83'ten sonra geri dönüşü en zor
        ikinci iş. PartnersTabView.swift:207'deki 'HENÜZ tutulmuyor' cümlesi
        de 81'dekinin aksine okuyucuyu bir davranışa götürmüyor; eksik olan
        şey ortağın uygulamayı açma sebebinin ta kendisi. Kapsam:
        PartnerLedgerEntry (tarih, ortak, tür ∈ {sermaye, çekilen/avans,
        dağıtım}, tutar, not) + yürüyen bakiye; Payment desenini birebir
        izler.
      · AYRIŞMA: Verdict'te ayrışma yok, KORKULUKTA var ve üçü birleştirildi:
        (1) gün ve vaat — sermaye ve çekiş NAKİT/FİNANSMAN hareketidir, inşaat
        maliyeti değil; 'Dönem net'in ve malzeme/diğer gider toplamlarının
        DIŞINDA kalmalı, yoksa madde 35 sınıfı bir sapma geri açılır. (2)
        alternatif — dağıtılabilir kâr HESAPLANMAMALI; defter açılır açılmaz
        'ne dağıtabilirim' sorulacak ve o soru madde 86'nın kalan maliyetini
        ister. (3) maliyet — yeni bir gizlilik kararı doğuyor: A ortağı B'nin
        çektiği parayı görecek mi? Bu, buyers/{apartmentId} ile aynı sınıfta
        bir karar ve EKRANDA değil KURALDA alınmalı. Ayrıca scopeText bu
        maddeyle kısalmamalı, sertleşmeli: kart bir mutabakat belgesi gibi
        görünmeye başlarken kalan inşaat maliyeti hâlâ düşülmüyor.
      · **KAPSAM KARARI (25 Ağu 2026): MADDE** — Blok / etap — dar dilim: etiket + tek proje yönlendirmesi
      · Önce maddenin kendi kanıtını düzeltmek gerekiyor: ada/parsel
        numaraları UYDURMA DEĞİL, iki Kars projesi gerçek ve FARKLI TOKİ
        verisi taşıyor (1224/1 ve 1139/3 — Seed.swift:41-51). Ama model sorunu
        aynen duruyor ve daha net: veride 'blok' diye bir alan yok, 'SF-1 Blok
        1' ve 'GB Blok 1' yalnızca yorum satırında yaşıyor;
        Project.swift:18'deki blockNumber ADA demek ve title = '{ada} Ada /
        {parsel} Parsel', yani aynı parseldeki iki blok panoda birebir aynı
        kartı üretir. Üstelik addApartment daire numarasını proje genelinde
        max+1 veriyor (ProjectViewModel.swift:2075) ve apartment(in:number:)
        daireyi numarasından buluyor — tek projede iki blok bugün kapı
        numarası çakışması demek. Kararı belirleyen maliyet merceğinin geri
        dönülemezlik argümanı: bu, listedeki tek FAİZİYLE BÜYÜYEN madde.
        Kullanıcı 3 bloğu 3 ayrı proje olarak kurduktan sonra birleştirmek,
        projects/{pid} altındaki her daire, malzeme, fiş, gider, tahsilat,
        taksit ve DENETİM İZİ belgesini yeni yola kopyalayıp silmek demek —
        madde 77'nin 'iz sonradan yazılamaz' kuralını uygulamanın kendi eliyle
        ihlal etmesi, ve madde 79'un 'birleştirme reddedildi' kararıyla da
        çelişir. Beklemek doğrudan gelecekteki göç faturası. Bu yüzden dar
        dilim BUGÜN girmeli: daire üzerinde serbest metin 'Blok / Etap'
        etiketi + daire listesinde gruplama + raporda blok süzgeci + proje
        kurulumunda 'aynı ada/parselde birden çok blok varsa TEK proje aç'
        yönlendirmesi. Belge ve ortak tek kez girilir, parsel toplamı bugünkü
        proje toplamı olarak bedava gelir.
      · AYRIŞMA: Gün merceği tek başına 'ertelenmiş' dedi (tetik: aynı
        ada/parselle ikinci proje açılması) — ama kendi gerekçesinde 'bugünkü
        tek somut semptomun ucuz karşılığı ayrı bir iş: blok/etap etiketi'
        diyor, yani dört mercek de ilk dilimde AYNI ucuz işte buluşuyor;
        ayrışma o dilimin bu maddeye mi ayrı bir maddeye mi yazılacağıydı.
        Etiketi bu maddeye aldım çünkü maliyet merceğinin göç faturası
        argümanı bekleme süresini fiyatlandırıyor. İkinci ayrışma etiketin
        NEREYE konacağıydı: gün/vaat projeye (çift kart sorunu),
        maliyet/alternatif daireye. DAİREYİ seçtim — yönlendirme zaten 'parsel
        başına tek proje' olduğu için etiket dairede olmazsa veri her gün
        yanlış birikmeye devam eder; projeye konsa çift kartı kapatır ama asıl
        sorunu kapatmaz. Gerçek Proje → Blok → Daire hiyerarşisi ve blok bazlı
        maliyet dağıtımı BU MADDENİN DIŞINDA: dört mercek de blok bazında
        malzeme dağıtımının sahte hassasiyet olduğunda hemfikir (beton bütün
        şantiyeye dökülür) ve hiyerarşi memberUids, Firestore yolları,
        kurallar, yedek biçimi ve ~20 toplayıcıyı açar. O parça ancak aynı
        sahip aynı ada/parsel/ilçe ile ikinci projeyi açmaya devam ederse
        (addProject içinde tespit edilebilir bir sinyal) yeniden açılır. Daire
        numaralandırmasının denetim izinde numaraya sabitlendiği de korkuluk
        olarak yazılmalı.
      · **KAPSAM KARARI (25 Ağu 2026): ERTELENMİŞ** — Ortak → yönetici iletişimi / mutabakat
      · Dört mercek de 'ertelenmiş, büyük' dedi — listedeki tek tam mutabakat.
        Üç bağımsız sebep: (1) Yetki: firestore.rules'taki 13 alt koleksiyonun
        13'ü de ownerWrite(pid) + serverStamped() kullanıyor; ortağın tek bir
        soru yazması sistemdeki İLK sahip-olmayan yazma ve 'ortak SALT OKUR'
        değişmezindeki ilk çatlak olur — ayrı koleksiyon, ayrı kural, ayrı
        kural testleri, yeni kötüye kullanım yüzeyi (spam, çıkarılmış ortağın
        artıkları) şart; asla mevcut belgeye alan olarak eklenemez, yoksa aynı
        belgedeki finansal alanlar da yazmaya açılır. (2) Bildirim:
        ReminderScheduler'ın başlığı sunucu push'unu ÖLÇEREK reddetmiş
        ('kapsamı ikiye katlardı' — zamanlanmış Function + FCM jetonu +
        koleksiyon + kural + emülatör testi). Bildirimsiz bir soru kutusu,
        ortağın sorup yöneticinin hiç görmediği bir kuyruk üretir: vaat edilip
        tutulmayan davet linki sınıfına yeni bir üye. (3) Kanıt yok: davet
        akışı üretimde hiç koşmadı, yani bugüne kadar tek bir gerçek ortak
        katılmadı — henüz gözlenmemiş bir kullanıcının varsayılan sorularına
        göre yüzey tasarlanacak. Ertelemenin bedeli düşük ve maliyet
        merceğinin tespiti belirleyici: sonradan eklemek GÖÇ GEREKTİRMEZ
        (yorumlar mevcut kayıt kimliklerine referansla eklenir, hiçbir belge
        taşınmaz) — sekiz madde içinde 'sonra eklemek şimdi eklemekle aynı
        fiyat' olan tek madde. Ayrıca doğrulama yarısı zaten teslim edildi:
        madde 76 denetim izini ortağın rolden bağımsız açabildiği ekrana
        taşıdı, yani 'yönetici sessizce değiştirdi' sorusu artık uygulamada
        cevaplanıyor. Kalan boşluk: ortak 400 bin ₺'lik bir 'Diğer' giderin NE
        ZAMAN girildiğini görebiliyor ama NE OLDUĞUNU soramıyor. İlk dilim tüm
        mesajlaşma DEĞİL, tek boolean + sunucu damgası olmalı: dönem raporuna
        ortağın 'gördüm / mutabıkım' işareti — ilişkiye değeri en yüksek,
        yazma yüzeyi en dar parça.
      · TETİK: İkisinden biri: (a) davet akışıyla katılan İLK gerçek ortağın
        salt okunur yüzeyi kullanması ve paylaşılan raporun hâlâ WhatsApp'ta
        tartışıldığının gözlenmesi; (b) web ortak portalının başlaması — ortak
        orada birinci sınıf kullanıcı olur, e-posta bildirimi ve yazma yolu
        ikisi de ucuzlar. FCM/sunucu push'unun başka bir sebeple hayata
        girmesi de tetiği açar.
      · **KAPSAM KARARI (25 Ağu 2026): KAPSAM DIŞI** — Yasal takvim (ruhsat, iskân, yapı denetim süreleri)
      · Merceklerin verdiği kararlar dağıldı (2 kapsam dışı, 1 madde, 1
        ertelenmiş) ama GEREKÇELERİ tek noktada birleşiyor: dördü de
        uygulamanın yasal süreleri HESAPLAMASINI reddediyor. Mevzuata gömülü
        bir süre tablosu değiştiği gün uygulama sessizce yanlış tarih
        hatırlatır ve kaçırılan ruhsat yenilemesinin sebebi uygulama olur —
        müteahhit kendi takvimini bıraktığı için zarar, uygulamanın hiç
        olmamasından büyüktür. Maddenin BAŞLIĞI ('yasal takvim') tam olarak bu
        reddedilen şey, o yüzden madde bu haliyle kapanmalı. Kapatmayı
        destekleyen ikinci ayak alternatif merceğinde: dört ayrı takvimin
        dördü de BAŞKASININ yasal yükümlülüğü ve kendi yaptırımı var — yapı
        denetim firması seviye tespit tutanaklarını tutmak zorunda, ruhsat
        süresini belediye izler ve resmî tebligat yolu var, iskân proje
        sonunda bir kerelik süreç. Kalan tek gerçek boşluk kat karşılığı
        sözleşmesindeki teslim tarihi; onu da müteahhit telefonunun kendi
        Takvim/Hatırlatıcılar uygulamasında tutuyor ve o alternatif SAĞLIKLI:
        senkronize oluyor, widget'ı var, paylaşılabiliyor. Sıklık da listenin
        en altında: proje ömrü boyunca 3-5 tarih, buna karşılık haftada 20-30
        fiş. Kaybolan veri yok — tarihler ruhsat belgesinin üzerinde ve o
        belge Belgeler sekmesinde zaten yüklü (ProjectDocument'in .ruhsat ve
        .sozlesme grupları mevcut). Açık bırakılan kapı yazıya geçmeli ki bu
        'atlanmış' değil 'kapatılmış' olsun: kullanıcının KENDİ girdiği tek
        bir tarih için tek seferlik hatırlatma (ProjectDocument'e dueDate +
        hatırlatma bayrağı, mevcut ReminderScheduler'a ikinci kaynak) ayrı ve
        küçük bir madde olarak gelebilir — mevzuat tablosu OLMADAN. O da
        yapılırsa ReminderScheduler.reschedule'ın
        removeAllPendingNotificationRequests ile her şeyi silip yeniden
        kurduğu ve iki kaynağın aynı 30 gün / 64 bildirim bütçesini
        paylaşacağı gözden kaçmamalı.
      · AYRIŞMA: Vaat merceği tek başına 'madde, küçük' dedi ve teknik olarak
        haklı: altyapı hazır, gereken tek şey ProjectDocument üzerine dueDate.
        Ama alternatif merceğinin sorusu efor değil KULLANIM: hiç kimse ikinci
        bir takvimi güncel tutmaz ve güncel tutulmayan bir hatırlatıcı ekranı
        uygulamayı bakımsız gösterir; müteahhit inşaat yazılımını hatırlatıcı
        için seçmiyor, para takibi için seçiyor. Maliyet merceğinin ertelemesi
        de 'yalnızca kullanıcı tanımlı tarih listesi olarak açılabilir' diyor
        — yani o da maddenin kendisini değil, dar kapıyı onaylıyor. Ucuz
        olması bir işi doğru yapmıyor; bu yüzden maddeyi kapattım ve dar
        kapıyı yazılı bıraktım.
      · **KAPSAM KARARI (25 Ağu 2026): MADDE** — Kalan stok değeri ve beklenen hasılat
      · Dört mercekte de 'madde' ve üçünde 'küçük' — maliyetine göre listenin
        en yüksek getirili işi, çünkü VERİ ZATEN YAZILIYOR:
        ApartmentEditSheet.swift:102 boş/rezerve daire için 'LİSTE FİYATI (₺)'
        alanını gösteriyor, updateApartment bunu apartment.price'a kaydediyor
        ve SaleFormSheet.prefillListPrice onu ön dolumda okuyor. Kodda bu
        rakamı yalnızca DIŞLAMAYI bilen bir yer var:
        ProjectExporter.apartmentsCSV yorumu, boş dairenin price alanında
        liste fiyatı taşıması yüzünden 'Kalan' sütununun ekrandaki 'Kalan
        alacak'tan %40'a varan oranda şişik çıktığını ve sütunun bu yüzden
        ayrıştırıldığını yazıyor. Toplayan tek satır yok; kodda yalnızca
        availableCount var (ProjectViewModel.swift:1252). 'Satılan ciro +
        kalan stok değeri = beklenen hasılat' bir reduce ve bir rapor satırı:
        yeni koleksiyon yok, göç yok, kural değişikliği yok, dikiş bedeli
        sıfır. Değeri ise ürünün eksik olan tek yönü: bugün uygulama tamamen
        geçmişe bakıyor, müteahhidin her gün ve ortağın her açılışta sorduğu
        'elimde ne kaldı, ne eder' sorusu ekranda cevapsız — üstelik cevabın
        verisi diskte duruyor. Daha ağırı: uygulama bu boşluğu ortağın okuduğu
        İKİ yerde birden itiraf ediyor (ReportView.scopeNote ve
        PartnersTabView.scopeText: kalan inşaat maliyeti 'henüz düşülmedi —
        aradaki fark kâr değildir'), yani ortağa gördüğü rakamın sandığı şey
        olmadığı söyleniyor ve istediği şey için bakacak yer verilmiyor. Madde
        82 ile AYNI SÜRÜMDE gitmeli: ortak defteri ancak bu rakamla 'payıma ne
        düşTÜ' yerine 'payıma ne düşECEK' cevabını verebiliyor.
      · AYRIŞMA: Maddenin İKİNCİ yarısında ('projeyi bitirmenin maliyeti')
        ayrıştılar: gün 'kapsam dışı', vaat/maliyet/alternatif 'elle girilen
        tek bir alan, girilmemişse hiçbir şey gösterme'. İkincisini seçtim ama
        gün merceğinin yasağını korkuluk olarak aldım: elde yalnızca
        ProgressSheet'te elle sürülen yüzde var ve 'harcanan ÷ %ilerleme' ile
        toplam maliyet türetmek, bu kod tabanının areaCost'ta nil döndürerek
        ve areaM2'de 0 ile 'girilmedi'yi ayırarak defalarca reddettiği uydurma
        rakam sınıfına girer. İkinci korkuluk üç mercekten geliyor: fiyatı
        girilmemiş boş daireler ve kat karşılığı (bedelsiz) daireler toplamı
        SESSİZCE küçültür — ReportView'daki missingCount deseni birebir
        tekrarlanmalı ('N dairenin fiyatı henüz girilmedi'). Üçüncüsü anlam:
        'beklenen hasılat' bir CİRO rakamı, kâr değil; 'Dönem net'in yanına
        konduğu anda ortak ikisini çıkarıp kâr sanar, o yüzden scopeNote ve
        scopeText bu satırla BİRLİKTE genişlemeli (liste fiyatı satış fiyatı
        değildir; kalan inşaat maliyeti hâlâ düşülmemiştir).
      · **KAPSAM KARARI (25 Ağu 2026): MADDE** — Gelir modeli kararının yazılması + maliyet tavanı
      · Dört mercek de 'madde' ve dördü de aynı sınırı çiziyor: bu madde
        StoreKit DEĞİL, KARARIN YAZILMASI. Grep ile doğruladım — kod tabanında
        StoreKit, abonelik, proje sınırı ve kota SIFIR. Buna karşılık her yeni
        kullanıcı en az bir ücretli SMS doğrulaması (Firebase telefon girişi)
        ve süresiz Storage/Functions maliyeti (europe-west1) üretiyor;
        storage.rules dosya BAŞINA 4 MB / 50 MB sınırı koyuyor ama SAYI sınırı
        yok, yani tek proje sınırsız belge ve fotoğraf tutabilir. Sızıntı
        ayrıca açık uçlu: AppCheckSetup zorlamanın bilerek AÇILMADIĞINI
        yazıyor ve callable'larda enforceAppCheck kapalı, rateLimits
        koleksiyonu callable'ları koruyor ama Auth'u korumuyor — sökülebilir
        API anahtarıyla ücretli SMS yakılabilir ve bütçe uyarısı harcamayı
        KESMİYOR. Kararı öne alan asıl argüman maliyet merceğinden: geri
        dönüşü olmayan şey kod değil YAYIN. StoreKit'i sonra yazabilirsin, ilk
        yayının sınırsızlığını geri alamazsın — 12 proje açmış kullanıcıyı
        sonradan 3 proje sınırına sokmak ya sonsuza kadar muafiyet ya da güven
        kaybı demek. Yön zaten belirlenmiş (proje sayısına göre abonelik;
        ortaklar sınırsız ve ÜCRETSİZ — ortak başına ücret almak ürünü ayıran
        cümlenin kendisini vergilendirmek olurdu; kalıcı 1 proje ücretsiz
        katman) ama oturum notlarında yaşıyor, depoda yok: ANALIZ.md ya da
        README okuyan biri hiçbir şey görmüyor. Bu, madde 75'in dersinin
        ("kapsam dışı notu da yok, yani ERTELENMİŞ DEĞİL ATLANMIŞ") aynısı.
        Kapsam üç parça: (a) kararı elenen seçeneklerin gerekçesiyle birlikte
        ANALIZ.md'ye yaz — bir saatlik iş; (b) proje/belge/fotoğraf
        sayaçlarını ve kotanın DURACAĞI yeri şimdi aç + App Check zorlamasını
        yayından ÖNCE kapat (madde 71); (c) StoreKit ayrı ve sonraya.
      · AYRIŞMA: Ayrışma kapsamın (b) parçasında: vaat ve alternatif 'küçük —
        sadece yazılı karar', gün ve maliyet 'orta — asgari sınır ve sayaçlar
        da şimdi'. Sayaçları içeri aldım çünkü maliyet merceğinin geri
        dönülemezlik argümanı yalnızca yazıyla kapanmıyor; sınırın nerede
        duracağı yayından önce belli olmalı. İki korkuluk yazılı olmalı: (1)
        proje sayısı sınırını KURALDA uygulamak her yazmada bir get() demek
        (yazma başına ek okuma, ek ücret) ve yeni bir kırılma yolu — hak
        belgesi okunamazsa TÜM yazmalar reddedilir; (2) 'abonelik bitti'
        kararı uygulama kilidindeki fail-open kararıyla sınanmalı — müteahhidi
        kendi mali kaydından dışarıda bırakmak kabul edilemez, kilitlenecekse
        YAZMA kilitlenir OKUMA değil. Doğrulanacak tek dış bilinmeyen duruyor
        ve ondan önce tek satır kod yazılmamalı: Apple'ın uygulama içi satın
        alma zorunluluğu ve dış ödeme bağlantısı kuralı (bölgeye göre
        değişiyor). (c) parçasının kendi tetiği: ilk ücretli yayından önce, ya
        da Firebase harcaması yazılı bir eşiği geçtiğinde.

#### Bu turun yöntem dersi

**"Kodla çözülecek iş kalmadı" doğru bir cümle değildi; doğru cümle "yol
haritasında iş kalmadı"ydı.** İkisi arasındaki fark 33 maddeymiş.

Aradaki farkı gören şey, envanteri çıkaran altı mercek DEĞİL, onların ne
sormadığını soran tamlık eleştirmeni oldu. Mimari bulguların beşi de
merceklerin kör noktasındaydı: her mercek kendi modülünün özelliklerine
bakarken, "veri nasıl tazeleniyor" ya da "iki cihaz aynı anda yazarsa ne olur"
sorusu hiçbir modülün içinde değil, hepsinin altındaydı.

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

