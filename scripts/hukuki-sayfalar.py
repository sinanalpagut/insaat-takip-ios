#!/usr/bin/env python3
"""İnşaat Takip hukuki metinlerini benav.com.tr için HTML'e çevirir.

    python3 scripts/hukuki-sayfalar.py [--uzerine-yaz] [hedef-dizin]

Varsayılan hedef: ../benav_com/public/privacy

NEDEN METİN BU DEPODA: gizlilik politikası, uygulamanın GERÇEKTEN ne topladığı
hakkında bir iddia. O iddianın kanıtı `InsaatTakip/PrivacyInfo.xcprivacy` ve
kodun kendisi — ikisi ayrı depolarda dursaydı, veri toplama değiştiğinde metni
güncellemeyi hatırlatan hiçbir şey olmazdı. Burada yan yana duruyorlar.

CANLI SAYFA ELLE DÜZENLENİRSE (31 Ekim 2026'da oldu): metin artık iki
platformu anlatıyor ve Android oturumu bu depoya yazamadığı için 31 Ekim
düzeltmesi doğrudan benav_com'a işlendi. Betik o hâliyle çalışsaydı ÜÇ
sayfayı da geri alırdı — koşullardaki 25 Ekim abonelik maddeleri dahil.
Gövdeler o yüzden canlı sayfalardan bayt bayt geri taşındı ve betik artık
hedefteki sayfa kendisininkinden yeni ya da aynı tarihli ama farklıysa
YAZMIYOR (`--uzerine-yaz` ile geçilir). Hesap silme ve destek sayfaları bu
betikte değil; benav_com'da elle tutuluyor.

METİN KODLA DOĞRULANARAK YAZILDI, şablondan değil:
  · Bağlı Firebase ürünleri: AppCheck, Auth, Core, Firestore, Functions,
    Storage. Analytics ve Crashlytics BAĞLI DEĞİL (madde 30'da bilinçli
    olarak ertelenmişti). Android'de fiş okuyan ML Kit Google'a ölçüm
    gönderiyor; metin bu yüzden "kendi analitik aracımız yok" diyor.
  · `PrivacyInfo.xcprivacy`: NSPrivacyTracking = false, toplanan türler
    telefon / ad / fotoğraf / kullanıcı içeriği, hepsi "AppFunctionality".
  · Veritabanı `eur3` (AB çoklu bölgesi: Belçika + Hollanda); Functions ve
    Storage europe-west1. Telefonla giriş (Firebase Authentication) ABD'de
    işleniyor. Bölge 31 Ekim'de komut satırıyla ölçüldü — önceki
    "europe-west1 (Belçika)" ifadesi veritabanı için yanlıştı.
  · Hesap silme uygulama içinde var (madde 28) ve sunucu tarafı siliyor.

HUKUKİ UYARI: bu metinler avukat tarafından yazılmadı. Özellikle veri
sorumlusu / veri işleyen ayrımı (alıcı adlarını müteahhit giriyor) yayından
önce bir KVKK avukatına okutulmalı.
"""
from __future__ import annotations  # macOS'un python3'ü 3.9: `X | None` için

import re
import sys
from pathlib import Path

EPOSTA = "info@benav.com.tr"
GELISTIRICI = "benav"

# Veri sorumlusu GERÇEK veya TÜZEL KİŞİ olmak zorunda; "benav" bir marka adı,
# tüzel kişiliği yok. KVKK metninde sorumluyu adlandıran yerlerde gerçek kişi
# yazılıyor, marka parantez içinde kalıyor ki iki ad arasındaki bağ görünsün.
# Şirket kurulursa burası tüzel kişi adıyla değişecek.
VERI_SORUMLUSU = "Sinan Alpagut (&ldquo;benav&rdquo; markası ile faaliyet göstermektedir)"

ISKELET = """<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>İnşaat Takip — {baslik} | benav</title>
  <meta name="description" content="İnşaat Takip uygulaması {baslik_kucuk}.">
  <meta name="theme-color" content="#f7f6f3" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#121316" media="(prefers-color-scheme: dark)">
  <link rel="stylesheet" href="/privacy/style.css">
  <link rel="icon" type="image/png" href="/icons/benav.png">
  <link rel="apple-touch-icon" href="/icons/benav.png">
  <script>(function(){{try{{var t=localStorage.getItem('benav-theme');if(!t){{t=window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light';}}document.documentElement.setAttribute('data-theme',t);}}catch(e){{document.documentElement.setAttribute('data-theme','light');}}}})();</script>
</head>
<body>

  <header class="nav">
    <div class="wrap">
      <a class="brand" href="/" aria-label="benav ana sayfa">
        <span class="mark">b</span> benav
      </a>
      <nav class="nav-right">
        <button class="theme-toggle" type="button" aria-label="Temayı değiştir" title="Açık / Karanlık tema">
          <svg class="i-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z"/></svg>
          <svg class="i-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4.2"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M18.4 5.6L17 7M7 17l-1.4 1.4"/></svg>
        </button>
      </nav>
    </div>
  </header>

  <main class="legal">
    <div class="wrap">
      <a class="back-link" href="/">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"/></svg>
        Ana sayfaya dön
      </a>

      <div class="legal-head">
        <span class="eyebrow">{baslik}</span>
        <h1>İnşaat Takip</h1>
        <p class="meta">Son güncelleme: {guncelleme}</p>
      </div>

      <div class="legal-body">
{govde}
      </div>
    </div>
  </main>

  <footer class="footer">
    <div class="wrap">
      <div class="footer-bottom" style="border-top:none;margin-top:0;padding-top:0;">
        <span>© <span id="year">2026</span> İnşaat Takip. Tüm hakları saklıdır.</span>
        <span><a href="/" style="color:inherit;">benav.com.tr</a></span>
      </div>
    </div>
  </footer>

  <script>(function(){{var b=document.querySelector(".theme-toggle");if(b)b.addEventListener("click",function(){{var c=document.documentElement.getAttribute("data-theme")==="dark"?"light":"dark";document.documentElement.setAttribute("data-theme",c);try{{localStorage.setItem("benav-theme",c);}}catch(e){{}}}});var y=document.getElementById("year");if(y)y.textContent=new Date().getFullYear();}})();</script>
</body>
</html>
"""

GIZLILIK = """        <p>İnşaat Takip, müteahhitlerin şantiye kayıtlarını (daire satışları, tahsilatlar, malzeme ve giderler) tutmaları ve bu kayıtları iş ortaklarıyla paylaşmaları için geliştirilmiş bir iPhone ve Android uygulamasıdır. Bu politika, uygulamayı kullanırken hangi verilerin toplandığını, ne için kullanıldığını, kimlerle paylaşıldığını ve nasıl silineceğini açıklar. İki sürüm aynı hesabı ve aynı verileri kullanır; platforma göre farklı olan noktalar ayrıca belirtilmiştir.</p>

        <p><strong>Kısaca:</strong></p>
        <ul>
          <li>Uygulama <strong>reklam göstermez</strong>, <strong>sizi izlemez</strong> ve <strong>konumunuzu okumaz</strong>. <strong>Kendi analitik aracımız yoktur</strong>; ancak Android'de fiş okumayı yapan Google ML Kit kütüphanesi, Google'a tanılama ve kullanım ölçümleri gönderir (bkz. 1-e).</li>
          <li>Hesap açmak için <strong>telefon numarası</strong> gerekir; numaranızı yalnızca giriş ve hesap güvenliği için kullanırız, <strong>ortaklarınıza gösterilmez</strong>. Girişi sağlayan Google, numarayı <strong>ABD'de</strong> işler ve kötüye kullanımı önlemek için kendisi de saklar (bkz. 1-a ve 4).</li>
          <li>Girdiğiniz iş kayıtları ve fotoğraflar, hesabınıza bağlı olarak <strong>Avrupa Birliği içindeki</strong> sunucularda saklanır.</li>
          <li>Bir projeye <strong>ortak davet ederseniz</strong>, o projenin kayıtları davet ettiğiniz kişiyle paylaşılır. <strong>Daire alıcılarının adları ortaklara gösterilmez.</strong></li>
          <li>Hesabınızı ve sunucudaki verilerinizi <strong>uygulamanın içinden</strong> istediğiniz an silebilirsiniz; bazı teknik kayıtların kendiliğinden silinme süreleri 6. bölümde yazılıdır.</li>
        </ul>

        <h2>1. Toplanan veriler</h2>

        <h3>a) Hesap bilgileri</h3>
        <ul>
          <li><strong>Telefon numarası:</strong> Hesap açmak ve giriş yapmak için gereklidir. Numaranız giriş yapmanız ve hesabınızın güvenliği için kullanılır; ortaklarınıza gösterilmez, ortak listesinde adınız görünür. Giriş, Google'ın Firebase Authentication hizmetiyle yapılır ve genellikle doğrulama SMS'i gönderilir. Android'de Google Play hizmetleri bazı cihazlarda numaranızı SMS göndermeden doğrulayabilir; uygulama SMS okuma izni almaz. Google, doğrulama için girilen telefon numaralarını kendi hizmetlerinde istenmeyen ileti ve kötüye kullanımı önlemek amacıyla da saklar.</li>
          <li><strong>Ad:</strong> İlk girişte sorduğumuz görünen adınız. Ortaklarınız bu adı görür; kayıtlarınızın kim tarafından girildiği bu adla yazılır.</li>
          <li><strong>Hesap kimliği:</strong> Girişte Firebase'in hesabınıza verdiği benzersiz kimlik. Sunucuda kayıtların sahibini ve kimin girdiğini bu kimlik belirler.</li>
        </ul>

        <h3>b) Girdiğiniz iş kayıtları</h3>
        <p>Uygulamaya girdiğiniz her şey hesabınıza bağlı olarak saklanır:</p>
        <ul>
          <li>Proje bilgileri (ada, parsel, ilçe, il, kat ve daire sayısı, ilerleme)</li>
          <li>Daire kayıtları (numara, kat, tip, alan, blok/etap, liste ve satış bedeli, tahsilat, taksit planı)</li>
          <li>Malzeme kayıtları, fişler, giderler ve tahsilatlar</li>
          <li>Ortaklar, hisse oranları ve ortak cari hesabı hareketleri</li>
          <li>Belgeler ve notlar</li>
          <li>Değişiklik kaydı: hangi kaydın ne zaman ve kim tarafından değiştirildiği</li>
        </ul>

        <h3>c) Daire alıcılarının adları</h3>
        <p>Bir daireyi sattığınızda alıcının adını girebilirsiniz. Bu ad <strong>size ait olmayan, üçüncü bir kişiye ait kişisel veridir</strong> ve özel olarak korunur:</p>
        <ul>
          <li>Ayrı bir kayıtta tutulur ve <strong>yalnızca projenin yöneticisi</strong> (yani siz) görebilir.</li>
          <li>Projeye davet ettiğiniz <strong>ortaklar alıcı adlarını göremez</strong>; bu kısıt sunucu tarafındaki güvenlik kurallarıyla uygulanır, yalnızca ekranda gizlemekle değil.</li>
          <li>Ortak görünümünden alınan dışa aktarma dosyalarında da alıcı adları bulunmaz.</li>
          <li>Satış iptal edildiğinde alıcı kaydı silinir.</li>
        </ul>
        <p>Alıcı adlarını girmek zorunda değilsiniz; uygulama bu alan boş bırakıldığında da çalışır.</p>

        <h3>d) Fotoğraflar ve dosyalar</h3>
        <ul>
          <li>Fiş, dekont, şantiye ve daire fotoğrafları (kamerayla çektikleriniz veya galeriden seçtikleriniz)</li>
          <li>Yüklediğiniz belgeler</li>
        </ul>
        <p>Kamera ve galeriden eklenen fotoğraflar yüklenmeden önce cihazınızda küçültülür; konum dahil fotoğraf üst verileri bu sırada silinir. Fotoğraflarınızın tamamına erişmeyiz; yalnızca seçtiğiniz kareler uygulamaya girer. Android'de kamera izni istenmez: fotoğraf, cihazın kendi kamera uygulamasıyla çekilir; galeriden seçim için Android'in fotoğraf seçicisi kullanılır. Belgeler bölümüne yüklediğiniz dosyalar ise değiştirilmeden yüklenir; bir fotoğraf dosyasını belge olarak yüklerseniz içindeki konum gibi üst veriler de onunla birlikte saklanabilir.</p>

        <h3>e) Otomatik toplanan teknik veriler</h3>
        <ul>
          <li><strong>Cihaz doğrulaması (App Check):</strong> Sunucuya giden isteklerin gerçekten bu uygulamadan geldiği doğrulanır. iPhone'da Apple'ın App Attest hizmeti kullanılır: cihazın güvenli donanımında bu kuruluma özgü bir anahtar oluşturulur, Apple'ın onayladığı doğrulama bilgisi Firebase'e gönderilir ve Firebase bunu doğrulayıp kısa ömürlü bir jeton verir. Android'de Google'ın Play Integrity hizmeti kullanılır: uygulamanın paket adı, sürümü ve imza sertifikası, cihazdaki Google hesapları için Google Play lisans durumu ve Google Play hizmetlerinin ürettiği cihaz doğrulama bilgisi Google'a gönderilir. Bu bilgiler sizi tanımak için değil, uygulamanın değiştirilmemiş olduğunu ve gerçek bir cihazda çalıştığını doğrulamak için kullanılır; biz bunları kimliğinizle eşleştirmeyiz.</li>
          <li><strong>Telefonla giriş doğrulaması:</strong> Telefonla girişte Google, isteğin gerçek uygulamadan geldiğini ayrıca doğrular: Android'de Google Play Integrity ile, iPhone'da cihazın Apple anlık bildirim (APNs) jetonuyla gönderilen sessiz bir bildirimle. Bu yapılamazsa doğrulama, tarayıcıda açılan bir Google reCAPTCHA sayfasıyla tamamlanır; reCAPTCHA bu sırada tarayıcı ve cihaz bilgilerini Google'ın kurallarına göre işler.</li>
          <li><strong>Altyapının işlediği teknik bilgiler:</strong> Firebase isteklerde IP adresinizi işler (girişte güvenlik ve kötüye kullanımın önlenmesi için, sunucu işlevlerinde isteği çalıştırmak için). İsteklerle birlikte uygulamanın kullandığı Firebase sürümleri, cihaz modeli ve işletim sistemi sürümü gibi teknik bilgiler de gider; Android'de buna uygulamanın yüklendiği mağaza da dahildir. Android'de ayrıca sunucu işlevleri çağrıldığında (davet koduyla katılma, hesap silme) bir Firebase kurulum kimliği ve ona bağlı bir Firebase Cloud Messaging jetonu oluşturulup Google'a gönderilir; uygulama bu jetonu bildirim göndermek için kullanmaz.</li>
          <li><strong>Fiş okuma:</strong> Fişteki yazı cihazınızda okunur; metin tanıma için fotoğraf ya da okunan metin hiçbir yere gönderilmez. Fişi kayda eklerseniz fotoğraf, diğer görseller gibi 1-d ve 4. bölümde anlatıldığı şekilde saklanır. iPhone'da okuma Apple'ın cihaz üstü metin tanıma özelliğiyle yapılır. Android'de okumayı yapan Google ML Kit kütüphanesi Google'a tanılama ve kullanım ölçümleri gönderir; bunlar arasında cihaz üreticisi ve modeli, işletim sistemi sürümü, kullanılabilen donanım hızlandırıcıları, uygulamanın paket adı ve sürümü, kuruluma özgü bir tanımlayıcı, işlem süresi, görüntü biçimi ve çözünürlüğü, özellik sürümü, olay türü ve hata kodları vardır. Google bu ölçümleri ML Kit'in işleyişini ölçmek, hataları gidermek ve ürünü iyileştirmek için kullanır; biz bu ölçümleri görmeyiz.</li>
          <li><strong>Destek e-postası:</strong> Uygulamadan bize e-posta gönderirseniz, sorunu teşhis edebilmek için uygulama sürümü, işletim sistemi sürümü ve cihaz modeli (Android'de üretici ve model) e-postanın içine önceden yazılır. Bu bilgiyi göndermeden önce görür ve silebilirsiniz. E-posta adresiniz ve yazdığınız mesaj da bize ulaşır.</li>
        </ul>

        <h3>f) Hatırlatma bildirimleri</h3>
        <p>Taksit vadesi hatırlatmaları cihazınızda planlanır ve gösterilir; bunun için sunucuya veri gönderilmez.</p>

        <h2>2. Toplamadığımız veriler</h2>
        <p>Uygulamada şunlar <strong>yoktur</strong>:</p>
        <ul>
          <li>Reklam ve reklam kimliği</li>
          <li>Kullanıcı izleme (tracking) — App Store gizlilik bildirimi de bunu beyan eder</li>
          <li>Kendi analitik veya kullanım ölçümü aracımız (Android'de ML Kit'in Google'a gönderdiği ölçümler için bkz. 1-e)</li>
          <li>Çökme raporu toplayan bir araç</li>
          <li>Konumunuzu okuma (Belgeler bölümüne yüklenen fotoğraf dosyalarındaki üst veri için bkz. 1-d)</li>
          <li>Rehberinize, kişilerinize veya takviminize erişim</li>
        </ul>
        <p>Android'de sizden onay istenen tek izin bildirim iznidir (vade hatırlatmaları için, Android 13 ve sonrasında). Kamera, konum, rehber, SMS veya depolama izni istenmez. Kurulumda kendiliğinden verilen ve onay gerektirmeyen diğer izinler internet ve ağ durumuna erişim, cihaz yeniden başladığında hatırlatmaları yeniden kurma ve uygulama kilidi için biyometrik donanımı kullanmadır. Bunlara ek olarak kullandığımız Google kütüphaneleri şu izinleri ekler: cihazı kısa süre uyanık tutma, Google bulut mesajlaşması, Google hizmet yapılandırmasını okuma.</p>

        <h2>3. Verilerin kullanım amacı</h2>
        <p>Topladığımız verileri yalnızca <strong>uygulamanın çalışması</strong> için kullanırız: kayıtlarınızı saklamak, rakamları hesaplamak, ortaklarınıza göstermek, rapor ve dışa aktarma dosyalarını üretmek ve hesabınızı korumak. Verilerinizi pazarlama için kullanmayız, satmayız ve üçüncü kişilere pazarlama amacıyla aktarmayız. Uygulamada kullanılan Google hizmetlerinin kendi amaçlarıyla yaptığı işlemeler (telefon numaralarının kötüye kullanımı önlemek için saklanması, Android'de ML Kit ölçümleri) 1-a ve 1-e'de ayrıca açıklanmıştır.</p>

        <h2>4. Verilerin saklandığı yer</h2>
        <p>Veriler Google'ın Firebase altyapısında saklanır:</p>
        <ul>
          <li><strong>Veritabanı (Cloud Firestore):</strong> Avrupa Birliği içinde, eur3 bölgesinde. Veriler Belçika ve Hollanda'daki veri merkezlerinde tutulur; çoğaltmaya Finlandiya'daki bir yardımcı bölge de katılır. İş kayıtlarınız ile profilinizdeki ad ve telefon numarası burada tutulur.</li>
          <li><strong>Fotoğraf ve belgeler (Cloud Storage) ile sunucu işlevleri (Cloud Functions):</strong> Belçika (europe-west1, Avrupa Birliği).</li>
          <li><strong>Giriş kaydınız (Firebase Authentication):</strong> telefon numaranız, hesap kimliğiniz ve girişte işlenen IP adresi. Google bu hizmeti yalnızca <strong>Amerika Birleşik Devletleri</strong>'ndeki veri merkezlerinden çalıştırır. İş kayıtlarınız ve fotoğraflarınız bu hizmete gitmez.</li>
          <li><strong>Cihaz doğrulaması ile Android'de Firebase kurulum kimliği ve ML Kit ölçümleri:</strong> Google'ın küresel altyapısında işlenir; belirli bir ülkeyle sınırlı değildir.</li>
        </ul>
        <p>Cihazınızda da bir kopya bulunur: uygulama internet olmadığında da çalışsın diye kayıtlar ve görseller cihazda önbelleğe alınır. Android'de bu yerel veriler Google Drive yedeklerine ve cihazdan cihaza taşımaya dahil edilmez; yeni cihazda giriş yaptığınızda sunucudan yeniden yüklenir. iPhone'da fotoğraf ve belge önbellekleri ile profil bilgileriniz, iCloud ya da bilgisayar yedeklemesi açıksa cihaz yedeğine dahil olabilir; bu yedek sizin Apple hesabınızda ya da bilgisayarınızdadır, biz erişemeyiz. Çevrimdışı veritabanı önbelleği iki platformda da yedeğe alınmaz.</p>

        <h2>5. Paylaşım</h2>
        <ul>
          <li><strong>Davet ettiğiniz ortaklar:</strong> Bir projeye ortak davet ettiğinizde, o projenin kayıtlarını (daireler, giderler, tahsilatlar, ortak cari hesabı, raporlar) görebilirler. Ortaklar <strong>salt okurdur</strong>: hiçbir kaydı değiştiremez, silemez veya ekleyemezler. Alıcı adlarını göremezler. Bir ortağı projeden çıkardığınızda erişimi kesilir.</li>
          <li><strong>Google (Firebase):</strong> Verileri bizim adımıza barındıran ve işleyen altyapı sağlayıcısıdır. Google bazı verileri kendi amaçlarıyla da işler: telefonla giriş için girilen numaraları kötüye kullanımı önlemek için saklar; Android'de ML Kit ölçümlerini ürününü ölçüp iyileştirmek için kullanır ve bu ölçümleri üçüncü taraflara aktarmadığını belirtir (bkz. 1-a, 1-e).</li>
          <li><strong>Apple:</strong> iPhone'da abonelik satın alırsanız ödeme Apple tarafından işlenir; kart bilgilerinizi biz görmeyiz, saklamayız. Android sürümünde şimdilik uygulama içi satın alma yoktur.</li>
          <li><strong>Yasal zorunluluk:</strong> Yetkili makamların hukuka uygun talebi hâlinde gerekli veriler paylaşılabilir.</li>
        </ul>
        <p>Bunların dışında verileriniz kimseyle paylaşılmaz.</p>

        <h2>6. Saklama süresi ve silme</h2>
        <p>Verileriniz, siz silene kadar saklanır.</p>
        <p><strong>Hesabınızı uygulamanın içinden silebilirsiniz:</strong> Hesap ekranı → <em>Hesabı Sil</em>. Silme işleminden önce verilerinizi dışa aktarmanız için bir adım sunulur. Uygulamaya erişemiyorsanız <a class="inl" href="/privacy/insaat-takip-hesap-silme.html">hesap silme sayfasındaki</a> adımları izleyebilirsiniz. Silme işlemi geri alınamaz ve şunları kapsar:</p>
        <ul>
          <li>Sahibi olduğunuz projeler ve içlerindeki tüm kayıtlar</li>
          <li>Yüklediğiniz fotoğraf ve belgeler</li>
          <li>Alıcı kayıtları</li>
          <li>Profiliniz ve giriş kaydınız</li>
          <li>Cihazınızdaki yerel kopyalar: fotoğraf ve belge önbellekleri hemen, çevrimdışı veritabanı önbelleği uygulama bir sonraki açılışında silinir. Android'de uygulama yeniden açılmadan aynı cihazda başka bir hesapla (aynı numarayla açılan yeni hesap dahil) giriş yapılırsa bu önbellek, uygulamadan erişilemez biçimde uygulama kaldırılana kadar cihazda kalabilir. Android'de uygulamanın kendi alanındaki dışa aktarma ve belge önizleme kopyaları da hemen silinir. iPhone'da dışa aktarma dosyaları, dönem raporu PDF'leri ve açtığınız belgelerin önizleme kopyaları uygulamanın geçici klasöründe kalır; iOS bu klasörü zamanla kendisi boşaltabilir, ama ne zaman yapacağı belli değildir. Cihaza kaydettiğiniz ya da paylaştığınız dosyalar silinmez.</li>
        </ul>
        <p>Ortak olarak katıldığınız projelerden yalnızca siz çıkarılırsınız; o projeler sahibine ait olduğu için silinmez.</p>
        <p>Silinen verilerin (giriş kaydı, proje kayıtları, fotoğraf ve belgeler) Google'ın iç yedekleme sistemlerinden de tamamen kalkması 180 güne kadar sürebilir; sunucu istek kayıtları (IP adresi) yaklaşık 30 gün içinde kendiliğinden silinir. Google'ın kötüye kullanımı önlemek için sakladığı telefon numarası kaydı, Android'de ML Kit'in gönderdiği ölçümler ile Firebase kurulum kimliği hesap silmeyle kaldırılmaz; bunlar Google'ın kendi saklama kurallarına tabidir. Silmeyle kaldırılmayan diğer veriler hesap silme sayfasında listelenmiştir.</p>

        <h2>7. Güvenlik</h2>
        <ul>
          <li>Tüm iletişim şifreli bağlantı üzerinden yapılır.</li>
          <li>Hangi verinin kim tarafından okunabileceği ve yazılabileceği sunucu tarafındaki güvenlik kurallarıyla belirlenir; bu kısıtlar uygulamadan bağımsızdır.</li>
          <li>İsteklerin gerçekten uygulamadan geldiği cihaz doğrulamasıyla kontrol edilir.</li>
          <li>Doğrulama SMS'leri yalnızca Türkiye numaralarına gönderilecek şekilde sınırlandırılmıştır.</li>
          <li>Dilerseniz uygulamayı cihazınızın kimlik doğrulamasıyla kilitleyebilirsiniz (iPhone'da Face ID / Touch ID / parola, Android'de parmak izi, yüz tanıma ya da ekran kilidi). Biyometrik doğrulamayı işletim sistemi yapar; uygulama parmak izi ya da yüz verinize erişmez. Uygulama kilidini etkinleştirdiğinizde Android'de uygulamanın ekran görüntüsü ve ekran kaydı alınamaz, son uygulamalar ekranında içerik gizlenir.</li>
        </ul>

        <h2>8. Çocukların gizliliği</h2>
        <p>Uygulama bir iş aracıdır ve 18 yaşından küçüklere yönelik değildir. Bilerek 18 yaş altından veri toplamayız.</p>

        <h2>9. Haklarınız</h2>
        <p>Kişisel verilerinize ilişkin haklarınız ve bunları nasıl kullanacağınız <a class="inl" href="/privacy/insaat-takip-kvkk.html">KVKK Aydınlatma Metni</a>'nde açıklanmıştır.</p>

        <h2>10. Değişiklikler</h2>
        <p>Bu politika değişirse sayfanın başındaki "Son güncelleme" tarihi yenilenir. Önemli değişiklikleri uygulama güncellemesinin notlarında da belirtiriz.</p>

        <h2>11. İletişim</h2>
        <ul>
          <li><strong>Geliştirici:</strong> {gelistirici}</li>
          <li><strong>E-posta:</strong> <a class="inl" href="mailto:{eposta}">{eposta}</a></li>
        </ul>
"""

KVKK = """        <p>6698 sayılı Kişisel Verilerin Korunması Kanunu'nun ("KVKK") 10. maddesi uyarınca, İnşaat Takip uygulamasını (iPhone ve Android) kullanırken kişisel verilerinizin nasıl işlendiği hakkında sizi bilgilendiriyoruz.</p>

        <h2>1. Veri sorumlusu</h2>
        <p>Hesap verileriniz (telefon numaranız ve adınız) bakımından veri sorumlusu <strong>{veri_sorumlusu}</strong>. İletişim: <a class="inl" href="mailto:{eposta}">{eposta}</a></p>

        <h2>2. İki ayrı rol: ne zaman veri sorumlusu, ne zaman veri işleyen</h2>
        <p>Bu uygulamada iki farklı veri kümesi vardır ve rolümüz her birinde farklıdır. Bu ayrımın yazılı olması önemlidir:</p>
        <ul>
          <li><strong>Hesap verileriniz</strong> (telefon, ad) bakımından <strong>veri sorumlusu biziz</strong>. Bu verileri kimlik doğrulama ve hizmetin sunulması için işleriz.</li>
          <li><strong>Uygulamaya girdiğiniz iş verileri</strong> — özellikle <strong>daire alıcılarının adları</strong> ve ortaklarınıza ait bilgiler — bakımından <strong>veri sorumlusu sizsiniz</strong>; biz yalnızca <strong>veri işleyen</strong> sıfatıyla bu verileri sizin adınıza barındırırız.</li>
        </ul>
        <p>Bunun pratik anlamı: alıcınızın adını uygulamaya girdiğinizde, o kişiye karşı aydınlatma yükümlülüğü ve işlemenin hukuki sebebini belirleme sorumluluğu <strong>size</strong> aittir. Biz o veriyi sizin talimatınız dışında kullanmayız, başkasına aktarmayız ve yalnızca hizmeti sunmak için saklarız.</p>
        <p>Teknik ve güvenlik verileri (IP adresi, cihaz doğrulama bilgileri, kurulum kimliği) bakımından da veri sorumlusu biziz. Google'ın kendi amaçlarıyla işlediği veriler (telefon numaralarının kötüye kullanımı önlemek için saklanması, Android'de ML Kit ölçümleri) Google'ın kendi gizlilik kurallarına tabidir.</p>

        <h2>3. İşlenen kişisel veriler</h2>
        <ul>
          <li><strong>Kimlik:</strong> Ad (uygulamaya girdiğiniz görünen ad), Firebase'in hesabınıza verdiği hesap kimliği</li>
          <li><strong>İletişim:</strong> Telefon numarası</li>
          <li><strong>Müşteri işlem:</strong> Girdiğiniz proje, daire, satış, tahsilat, gider, malzeme ve ortaklık kayıtları</li>
          <li><strong>Görsel kayıt:</strong> Fiş, dekont, şantiye ve daire fotoğrafları</li>
          <li><strong>Üçüncü kişilere ait kimlik verisi:</strong> Girdiğiniz daire alıcılarının adları (bkz. 2. madde)</li>
          <li><strong>İşlem güvenliği:</strong> Cihaz ve uygulama doğrulama bilgileri (iPhone'da App Attest ve telefonla girişte Apple bildirim jetonu, Android'de Google Play Integrity; gerektiğinde Google reCAPTCHA), IP adresi, değişiklik kayıtları (hangi kaydı kim ne zaman değiştirdi)</li>
          <li><strong>Teknik bilgiler (iki platform):</strong> İsteklerle Firebase'e giden cihaz modeli, işletim sistemi, uygulama ve Firebase sürümleri</li>
          <li><strong>Teknik tanılama (yalnızca Android):</strong> Firebase kurulum kimliği, sunucu işlevleri çağrılırken gönderilen Firebase Cloud Messaging jetonu ve fiş okuma kütüphanesi Google ML Kit'in Google'a gönderdiği tanılama ve kullanım ölçümleri</li>
          <li><strong>Talep ve şikâyet:</strong> Destek e-postasındaki e-posta adresiniz, mesajınız ve e-postaya önceden yazılan uygulama sürümü, işletim sistemi sürümü ve cihaz modeli</li>
        </ul>

        <h2>4. İşleme amaçları</h2>
        <ul>
          <li>Kullanıcı hesabının oluşturulması ve kimlik doğrulama</li>
          <li>Hizmetin sunulması: kayıtların saklanması, hesaplanması, raporlanması ve dışa aktarılması</li>
          <li>Projeye davet edilen ortaklarla paylaşımın sağlanması</li>
          <li>Bilgi güvenliğinin sağlanması, kötüye kullanımın ve sahteciliğin önlenmesi</li>
          <li>Uygulamanın teknik olarak çalışmasının sağlanması ve sorunların teşhisi</li>
          <li>Talep ve şikâyetlerin karşılanması</li>
          <li>Abonelik ilişkisinin yürütülmesi</li>
        </ul>

        <h2>5. Hukuki sebepler</h2>
        <ul>
          <li><strong>Sözleşmenin kurulması veya ifası için gerekli olması</strong> (KVKK m.5/2-c): hesap verileri ve girdiğiniz iş kayıtlarının saklanması</li>
          <li><strong>Hukuki yükümlülüğün yerine getirilmesi</strong> (m.5/2-ç): yasal talepler ve saklama yükümlülükleri</li>
          <li><strong>Meşru menfaat</strong> (m.5/2-f): bilgi güvenliği, kötüye kullanımın önlenmesi, uygulamanın teknik olarak çalışması ve sorunların teşhisi</li>
        </ul>

        <h2>6. Toplama yöntemi</h2>
        <p>Veriler, uygulamayı kullanırken doğrudan sizin tarafınızdan girilerek ve otomatik yollarla (cihaz doğrulaması, değişiklik kayıtları, uygulamada kullanılan Google hizmetlerinin teknik ölçümleri) elektronik ortamda toplanır.</p>

        <h2>7. Aktarım</h2>
        <p>Verileriniz, hizmetin sunulabilmesi için Google Ireland Limited tarafından işletilen Firebase altyapısında barındırılır:</p>
        <ul>
          <li><strong>Veritabanı (iş kayıtları ve profilinizdeki ad ile telefon numarası):</strong> Avrupa Birliği — eur3 bölgesi (Belçika ve Hollanda; çoğaltmaya Finlandiya'daki bir yardımcı bölge katılır)</li>
          <li><strong>Fotoğraf, belge ve sunucu işlevleri:</strong> Avrupa Birliği — Belçika (europe-west1)</li>
          <li><strong>Giriş kaydı (Firebase Authentication: telefon numarası, hesap kimliği, girişte işlenen IP adresi):</strong> Amerika Birleşik Devletleri. Google bu hizmeti yalnızca ABD'deki veri merkezlerinden sunar.</li>
          <li><strong>Cihaz doğrulaması, Firebase kurulum kimliği ve Android'de ML Kit ölçümleri:</strong> Google'ın ABD dahil küresel altyapısında işlenir; belirli bir ülkeyle sınırlı değildir.</li>
        </ul>
        <p><strong>Bu barındırma, verilerinizin Türkiye dışında tutulduğu anlamına gelir.</strong> İş kayıtlarınız ve fotoğraflarınız Avrupa Birliği içindedir; giriş için telefon numaranız ve giriş kaydınız ayrıca ABD'de işlenir. Altyapıyı işleten Google bir yurt dışı hizmet sağlayıcısıdır.</p>
        <p>Google, telefonla giriş için girilen numaraları kendi hizmetlerinde istenmeyen ileti ve kötüye kullanımı önlemek amacıyla da saklar. Android'de fiş okuma kütüphanesi Google ML Kit, kendi ürününü ölçüp iyileştirmek için Google'a tanılama ve kullanım ölçümleri gönderir; ML Kit fiş fotoğrafını ve okuduğu metni Google'a göndermez.</p>
        <p>Projelerinize davet ettiğiniz ortaklar, o projenin kayıtlarını görebilir; <strong>alıcı adları ortaklara aktarılmaz</strong>. iPhone'da abonelik satın alınması hâlinde ödeme işlemi Apple tarafından yürütülür. Yasal olarak yetkili makamların usulüne uygun talebi hâlinde veriler paylaşılabilir. <strong>Bunların dışında</strong> verileriniz başka üçüncü kişilere aktarılmaz; verilerinizi reklam veya pazarlama amacıyla kimseyle paylaşmayız. Analiz amaçlı tek aktarım, yukarıda açıklanan ML Kit ölçümleridir.</p>

        <h2>8. Saklama süresi</h2>
        <p>Veriler, hesabınız silinene kadar saklanır. Hesabınızı uygulama içinden sildiğinizde verileriniz sunuculardan hemen silinir; cihazdaki çevrimdışı veritabanı önbelleği uygulama bir sonraki açılışta temizlenir (istisnaları hesap silme sayfasında yazılıdır). Silinen verilerin Google'ın iç yedekleme sistemlerinden tamamen kalkması 180 güne, sunucu istek kayıtlarının (IP adresi) silinmesi yaklaşık 30 güne kadar sürebilir. Google'ın kötüye kullanımı önlemek için sakladığı telefon numarası kaydı ve Android'de ML Kit ölçümleri Google'ın kendi saklama kurallarına tabidir. Ayrıntılar <a class="inl" href="/privacy/insaat-takip-hesap-silme.html">hesap silme sayfasındadır</a>. Mevzuatın saklamayı zorunlu kıldığı hâller saklıdır.</p>

        <h2>9. KVKK m.11 kapsamındaki haklarınız</h2>
        <p>Veri sorumlusuna başvurarak şu haklarınızı kullanabilirsiniz:</p>
        <ul>
          <li>Kişisel verinizin işlenip işlenmediğini öğrenme, işlenmişse buna ilişkin bilgi talep etme</li>
          <li>İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme</li>
          <li>Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme</li>
          <li>Eksik veya yanlış işlenmişse düzeltilmesini isteme</li>
          <li>Silinmesini veya yok edilmesini isteme</li>
          <li>Düzeltme, silme ve yok etme işlemlerinin aktarıldığı üçüncü kişilere bildirilmesini isteme</li>
          <li>Münhasıran otomatik sistemlerle analiz edilmesi suretiyle aleyhinize bir sonucun ortaya çıkmasına itiraz etme</li>
          <li>Kanuna aykırı işleme sebebiyle zarara uğramanız hâlinde zararın giderilmesini talep etme</li>
        </ul>
        <p>Verilerinizin büyük bölümünü uygulama içinden kendiniz görebilir, düzeltebilir, dışa aktarabilir ve silebilirsiniz. Diğer talepleriniz için <a class="inl" href="mailto:{eposta}">{eposta}</a> adresine yazabilirsiniz; başvurunuz en geç 30 gün içinde sonuçlandırılır.</p>

        <h2>10. İletişim</h2>
        <ul>
          <li><strong>Veri sorumlusu:</strong> {veri_sorumlusu}</li>
          <li><strong>E-posta:</strong> <a class="inl" href="mailto:{eposta}">{eposta}</a></li>
        </ul>
"""

KOSULLAR = """
        <p>Bu koşullar, İnşaat Takip uygulamasını kullanımınızı düzenler. Uygulamayı kullanarak bu koşulları kabul etmiş olursunuz.</p>

        <h2>1. Hizmetin tanımı — ve ne OLMADIĞI</h2>
        <p>İnşaat Takip, şantiye kayıtlarını tutmanıza ve bu kayıtları iş ortaklarınızla paylaşmanıza yarayan bir <strong>kayıt aracıdır</strong>.</p>
        <p>Uygulama bir <strong>muhasebe defteri değildir</strong>, <strong>vergi hesaplamaz</strong> ve <strong>mali müşavirin yerini tutmaz</strong>. Gösterdiği rakamlar yalnızca sizin girdiğiniz kayıtlardan hesaplanır; girilmeyen bir gider rakama girmez. Uygulama, tutarların KDV dahil mi hariç mi girildiğini yalnızca <strong>beyan olarak kaydeder</strong>, vergi hesabı yapmaz. Resmî beyan, muhasebe ve vergi yükümlülükleriniz sizin sorumluluğunuzdadır.</p>

        <h2>2. Hesap</h2>
        <ul>
          <li>Hesap açmak için telefon numaranızla doğrulama yapmanız gerekir.</li>
          <li>Uygulama bir iş aracıdır; 18 yaşından büyük olmalısınız.</li>
          <li>Hesabınızın ve cihazınızın güvenliğinden siz sorumlusunuz.</li>
        </ul>

        <h2>3. Girdiğiniz veriler ve üçüncü kişiler</h2>
        <p>Uygulamaya girdiğiniz kayıtlar size aittir. Bu kayıtlar <strong>üçüncü kişilere ait kişisel veri</strong> içerebilir — özellikle daire alıcılarının adları ve ortaklarınızın bilgileri.</p>
        <p>Bu verileri girerken:</p>
        <ul>
          <li>İlgili kişileri aydınlatma ve gerekli hukuki dayanağı sağlama yükümlülüğü <strong>size</strong> aittir;</li>
          <li>Verilerin doğruluğundan siz sorumlusunuz;</li>
          <li>Biz bu verileri yalnızca hizmeti sunmak için işleriz ve başka bir amaçla kullanmayız.</li>
        </ul>
        <p>Ayrıntı için <a class="inl" href="/privacy/insaat-takip-kvkk.html">KVKK Aydınlatma Metni</a>'ne bakınız.</p>

        <h2>4. Ortaklar</h2>
        <p>Bir projeye davet ettiğiniz ortaklar o projenin kayıtlarını görebilir ve <strong>salt okur</strong> yetkiye sahiptir: kayıt ekleyemez, değiştiremez veya silemezler. Daire alıcılarının adlarını göremezler. Kimi davet edeceğinize siz karar verirsiniz; davet ettiğiniz kişinin kayıtları görmesinin sonuçlarından siz sorumlusunuz. Bir ortağı projeden çıkardığınızda erişimi kesilir.</p>

        <h2>5. Paketler ve ücretlendirme</h2>
        <ul>
          <li><strong>Ücretsiz katman:</strong> 1 aktif proje ve 2 davet edilmiş ortak. Süre sınırı yoktur.</li>
          <li><strong>Ücretli paketler:</strong> Aktif proje sayısına göre belirlenir; ücretli paketlerde davet edilebilecek ortak sayısı sınırsızdır.</li>
          <li><strong>Arşivlenen projeler aktif sayılmaz.</strong> Biten bir projeyi arşivlediğinizde kayıtları durur, kontenjanınız boşalır. Arşivdeki proje <strong>salt okunurdur</strong>: görüntülenebilir ve dışa aktarılabilir; yeni kayıt girmek için arşivden çıkarılması gerekir, bu da aktif proje sınırına tabidir.</li>
          <li>Güncel paket ve fiyatlar uygulama içinde ve App Store'da gösterilir. Tahsil edilen tutar, satın alma onayında App Store'un gösterdiği tutardır.</li>
        </ul>

        <h2>6. Abonelik, yenileme ve iptal</h2>
        <ul>
          <li>Abonelikler App Store üzerinden aylık veya yıllık olarak satın alınır; ödeme, satın almayı onayladığınızda Apple Kimliğinize tanımlı yöntemle alınır.</li>
          <li>Abonelik, dönem bitiminden en az 24 saat önce iptal edilmezse aynı süre ve ücretle <strong>otomatik yenilenir</strong>; yenileme ücreti dönem bitiminden önceki 24 saat içinde alınır.</li>
          <li>İptal işlemi cihazınızın <em>Ayarlar → Apple Kimliği → Abonelikler</em> bölümünden yapılır. Aboneliği iptal ettiğinizde dönem sonuna kadar kullanmaya devam edersiniz.</li>
          <li>İade talepleri Apple'ın iade politikasına tabidir.</li>
          <li>Abonelik sona erdiğinde <strong>verileriniz silinmez</strong> ve kayıtlarınızı görmeye ve dışa aktarmaya devam edebilirsiniz. Geçerli paketinizin aktif proje sınırı kadar proje (en önce açılanlar) düzenlenebilir kalır; sınırı aşan projeler salt okunur olur. Hangi projede çalışacağınızı diğerlerini arşivleyerek seçebilirsiniz.</li>
          <li><strong>Hesabınızı silmek aboneliğinizi iptal etmez.</strong> Ödeme Apple üzerinden sürer; hesabınızı silmeden önce aboneliğinizi iptal etmeniz gerekir.</li>
        </ul>

        <h2>7. Yedekleme</h2>
        <p>Kayıtlarınızı uygulama içinden dışa aktarabilirsiniz (Excel/CSV dosyaları ve yedek dosyası). Önemli verilerinizin düzenli yedeğini almanızı öneririz.</p>

        <h2>8. Kabul edilmeyen kullanım</h2>
        <ul>
          <li>Uygulamayı hukuka aykırı amaçlarla kullanmak</li>
          <li>Başkasının verisini yetkisiz girmek veya paylaşmak</li>
          <li>Hizmete, güvenlik önlemlerine veya diğer kullanıcılara zarar vermeye yönelik girişimlerde bulunmak</li>
          <li>Uygulamayı tersine mühendislikle çözmeye veya otomatik yollarla kötüye kullanmaya çalışmak</li>
        </ul>

        <h2>9. Sorumluluk sınırı</h2>
        <p>Uygulama "olduğu gibi" sunulur. Girdiğiniz kayıtların doğruluğundan ve bu kayıtlara dayanarak aldığınız ticari kararlardan siz sorumlusunuz. Hizmetin kesintisiz veya hatasız olacağı taahhüt edilmez. Mevzuatın izin verdiği ölçüde, dolaylı zararlardan sorumluluk kabul edilmez.</p>
        <p>Bu, kusurlarımızı görmezden geldiğimiz anlamına gelmez: bir hata bildirdiğinizde değerlendirir ve düzeltiriz.</p>

        <h2>10. Hizmetin sonlandırılması</h2>
        <p>Hesabınızı istediğiniz an uygulama içinden silebilirsiniz. Bu koşulların ağır ihlali hâlinde hesabınızın erişimini sınırlandırabilir veya sonlandırabiliriz; böyle bir durumda verilerinizi dışa aktarmanız için makul bir süre tanınır.</p>

        <h2>11. Değişiklikler</h2>
        <p>Koşullar değişirse sayfanın başındaki "Son güncelleme" tarihi yenilenir. Esaslı değişikliklerde uygulama içinde bilgilendirme yapılır.</p>

        <h2>12. Uygulanacak hukuk</h2>
        <p>Bu koşullara Türkiye Cumhuriyeti hukuku uygulanır. Uyuşmazlıklarda Türkiye mahkemeleri ve icra daireleri yetkilidir. Tüketici sıfatıyla sahip olduğunuz dava ve şikâyet hakları saklıdır.</p>

        <h2>13. İletişim</h2>
        <ul>
          <li><strong>Geliştirici:</strong> {gelistirici}</li>
          <li><strong>E-posta:</strong> <a class="inl" href="mailto:{eposta}">{eposta}</a></li>
        </ul>
"""

# Tarih SAYFA BAŞINA: sayfalar ayrı günlerde değişiyor. Tek bir tarih,
# değişmeyen sayfayı da "güncellendi" gösterirdi ya da değişeni eskitirdi.
SAYFALAR = [
    ("insaat-takip.html", "Gizlilik Politikası", "gizlilik politikası", "31 Ekim 2026", GIZLILIK),
    ("insaat-takip-kvkk.html", "KVKK Aydınlatma Metni", "KVKK aydınlatma metni", "31 Ekim 2026", KVKK),
    ("insaat-takip-kosullar.html", "Kullanım Koşulları", "kullanım koşulları", "25 Ekim 2026", KOSULLAR),
]

AYLAR = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz",
         "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]


def tarih(metin: str) -> tuple[int, int, int] | None:
    """"31 Ekim 2026" → (2026, 10, 31); okunamazsa None."""
    m = re.fullmatch(r"(\d{1,2}) (\w+) (\d{4})", metin.strip())
    if not m or m.group(2) not in AYLAR:
        return None
    return int(m.group(3)), AYLAR.index(m.group(2)) + 1, int(m.group(1))


def hedefteki_tarih(html: str) -> tuple[int, int, int] | None:
    m = re.search(r"Son güncelleme: ([^<·]+)", html)
    return tarih(m.group(1)) if m else None


def main() -> int:
    argumanlar = [a for a in sys.argv[1:] if a != "--uzerine-yaz"]
    uzerine_yaz = len(argumanlar) != len(sys.argv) - 1
    hedef = Path(argumanlar[0]) if argumanlar else Path(__file__).resolve().parents[2] / "benav_com" / "public" / "privacy"
    if not hedef.is_dir():
        print(f"hedef dizin yok: {hedef}", file=sys.stderr)
        return 1
    sonuc = 0
    for dosya, baslik, baslik_kucuk, guncelleme, govde in SAYFALAR:
        html = ISKELET.format(
            baslik=baslik,
            baslik_kucuk=baslik_kucuk,
            guncelleme=guncelleme,
            govde=govde.format(eposta=EPOSTA, gelistirici=GELISTIRICI,
                               veri_sorumlusu=VERI_SORUMLUSU).rstrip(),
        )
        yol = hedef / dosya
        # Hedefteki metin bu betikten yeniyse ya da aynı tarihli ama farklıysa
        # biri onu elle düzenlemiş demektir: üzerine yazmak o emeği SESSİZCE
        # geri alırdı. Önce gövdeyi buraya taşı (tarih de gelir), sonra koş.
        if yol.exists() and not uzerine_yaz:
            mevcut = yol.read_text(encoding="utf-8")
            eski, yeni = hedefteki_tarih(mevcut), tarih(guncelleme)
            if mevcut != html and (eski is None or yeni is None or eski >= yeni):
                print(f"YAZILMADI: {yol} — hedefteki sayfa betiktekinden yeni ya da "
                      f"aynı tarihli ama farklı. Önce canlı gövdeyi betiğe taşı "
                      f"(ya da --uzerine-yaz).", file=sys.stderr)
                sonuc = 2
                continue
        yol.write_text(html, encoding="utf-8")
        print(f"yazıldı: {yol}")
    return sonuc


if __name__ == "__main__":
    raise SystemExit(main())
