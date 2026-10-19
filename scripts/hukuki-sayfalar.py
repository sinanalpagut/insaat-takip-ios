#!/usr/bin/env python3
"""İnşaat Takip hukuki metinlerini benav.com.tr için HTML'e çevirir.

    python3 scripts/hukuki-sayfalar.py [hedef-dizin]

Varsayılan hedef: ../benav_com/public/privacy

NEDEN METİN BU DEPODA: gizlilik politikası, uygulamanın GERÇEKTEN ne topladığı
hakkında bir iddia. O iddianın kanıtı `InsaatTakip/PrivacyInfo.xcprivacy` ve
kodun kendisi — ikisi ayrı depolarda dursaydı, veri toplama değiştiğinde metni
güncellemeyi hatırlatan hiçbir şey olmazdı. Burada yan yana duruyorlar.

METİN KODLA DOĞRULANARAK YAZILDI, şablondan değil:
  · Bağlı Firebase ürünleri: AppCheck, Auth, Core, Firestore, Functions,
    Storage. Analytics ve Crashlytics BAĞLI DEĞİL (madde 30'da bilinçli
    olarak ertelenmişti) — yani "analitik toplamıyoruz" cümlesi doğru.
  · `PrivacyInfo.xcprivacy`: NSPrivacyTracking = false, toplanan türler
    telefon / ad / fotoğraf / kullanıcı içeriği, hepsi "AppFunctionality".
  · Sunucu bölgesi europe-west1 (functions/src/index.ts ve Storage kovası).
  · Hesap silme uygulama içinde var (madde 28) ve sunucu tarafı siliyor.

HUKUKİ UYARI: bu metinler avukat tarafından yazılmadı. Özellikle veri
sorumlusu / veri işleyen ayrımı (alıcı adlarını müteahhit giriyor) yayından
önce bir KVKK avukatına okutulmalı.
"""
import sys
from pathlib import Path

GUNCELLEME = "15 Ekim 2026"
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

GIZLILIK = """
        <p>İnşaat Takip, müteahhitlerin şantiye kayıtlarını (daire satışları, tahsilatlar, malzeme ve giderler) tutmaları ve bu kayıtları iş ortaklarıyla paylaşmaları için geliştirilmiş bir iOS uygulamasıdır. Bu politika, uygulamayı kullanırken hangi verilerin toplandığını, ne için kullanıldığını, kimlerle paylaşıldığını ve nasıl silineceğini açıklar.</p>

        <p><strong>Kısaca:</strong></p>
        <ul>
          <li>Uygulama <strong>reklam göstermez</strong>, <strong>sizi izlemez</strong>, <strong>analitik veri toplamaz</strong> ve <strong>konumunuzu almaz</strong>.</li>
          <li>Hesap açmak için <strong>telefon numarası</strong> gerekir; numaranız yalnızca kimlik doğrulama ve ortak davetleri için kullanılır.</li>
          <li>Girdiğiniz iş kayıtları ve fotoğraflar, hesabınıza bağlı olarak <strong>Avrupa Birliği içindeki</strong> (Belçika) sunucularda saklanır.</li>
          <li>Bir projeye <strong>ortak davet ederseniz</strong>, o projenin kayıtları davet ettiğiniz kişiyle paylaşılır. <strong>Daire alıcılarının adları ortaklara gösterilmez.</strong></li>
          <li>Hesabınızı ve tüm verilerinizi <strong>uygulamanın içinden</strong> istediğiniz an silebilirsiniz.</li>
        </ul>

        <h2>1. Toplanan veriler</h2>

        <h3>a) Hesap bilgileri</h3>
        <ul>
          <li><strong>Telefon numarası:</strong> Hesap açmak ve giriş yapmak için gereklidir. Doğrulama SMS'i gönderilir. Numaranız, davet ettiğiniz projelerde sizi tanımlamak için kullanılır.</li>
          <li><strong>Ad:</strong> İlk girişte sorduğumuz görünen adınız. Ortaklarınız bu adı görür; kayıtlarınızın kim tarafından girildiği bu adla yazılır.</li>
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
        <p>Fotoğraflar yüklenmeden önce cihazınızda küçültülür. Fotoğraflarınızın tamamına erişmeyiz; yalnızca seçtiğiniz kareler uygulamaya girer.</p>

        <h3>e) Otomatik toplanan teknik veriler</h3>
        <ul>
          <li><strong>Cihaz doğrulaması (App Check / App Attest):</strong> İsteğin gerçekten bu uygulamadan geldiğini doğrulamak için Apple tarafından üretilen bir doğrulama jetonu kullanılır. Bu jeton sizi değil cihazın uygulamayı çalıştırdığını doğrular ve kimliğinizle ilişkilendirilmez.</li>
          <li><strong>Destek e-postası:</strong> Uygulamadan bize e-posta gönderirseniz, sorunu teşhis edebilmek için uygulama sürümü, iOS sürümü ve cihaz modeli e-postanın içine önceden yazılır. Bu bilgiyi göndermeden önce görür ve silebilirsiniz.</li>
        </ul>

        <h2>2. Toplamadığımız veriler</h2>
        <p>Aşağıdakiler uygulamada <strong>yoktur</strong>:</p>
        <ul>
          <li>Reklam ve reklam kimliği</li>
          <li>Kullanıcı izleme (tracking) — uygulamanın gizlilik bildirimi de bunu beyan eder</li>
          <li>Analitik ve kullanım ölçümü</li>
          <li>Çökme raporu toplama</li>
          <li>Konum bilgisi</li>
          <li>Rehberiniz, kişileriniz veya takviminiz</li>
        </ul>

        <h2>3. Verilerin kullanım amacı</h2>
        <p>Toplanan veriler yalnızca <strong>uygulamanın çalışması</strong> için kullanılır: kayıtlarınızı saklamak, rakamları hesaplamak, ortaklarınıza göstermek, rapor ve dışa aktarma dosyalarını üretmek ve hesabınızı korumak. Verileriniz pazarlama için kullanılmaz, satılmaz ve üçüncü kişilere pazarlama amacıyla aktarılmaz.</p>

        <h2>4. Verilerin saklandığı yer</h2>
        <p>Veriler Google'ın Firebase altyapısında (Cloud Firestore, Cloud Storage, Firebase Authentication, Cloud Functions) saklanır. Veritabanı ve dosya sunucularının bölgesi <strong>europe-west1 (Belçika, Avrupa Birliği)</strong> olarak seçilmiştir; iş kayıtlarınız ve fotoğraflarınız bu bölgede tutulur.</p>
        <p>Cihazınızda da bir kopya bulunur: uygulama internet olmadığında da çalışsın diye kayıtlar ve görseller cihazda önbelleğe alınır. Hesabınızı sildiğinizde bu yerel kopya da temizlenir.</p>

        <h2>5. Paylaşım</h2>
        <ul>
          <li><strong>Davet ettiğiniz ortaklar:</strong> Bir projeye ortak davet ettiğinizde, o projenin kayıtlarını (daireler, giderler, tahsilatlar, ortak cari hesabı, raporlar) görebilirler. Ortaklar <strong>salt okurdur</strong>: hiçbir kaydı değiştiremez, silemez veya ekleyemezler. Alıcı adlarını göremezler. Bir ortağı projeden çıkardığınızda erişimi kesilir.</li>
          <li><strong>Google (Firebase):</strong> Verileri bizim adımıza barındıran altyapı sağlayıcısıdır.</li>
          <li><strong>Apple:</strong> Abonelik satın alırsanız ödeme Apple tarafından işlenir; kart bilgilerinizi biz görmeyiz, saklamayız.</li>
          <li><strong>Yasal zorunluluk:</strong> Yetkili makamların hukuka uygun talebi hâlinde gerekli veriler paylaşılabilir.</li>
        </ul>
        <p>Bunların dışında verileriniz kimseyle paylaşılmaz.</p>

        <h2>6. Saklama süresi ve silme</h2>
        <p>Verileriniz, siz silene kadar saklanır.</p>
        <p><strong>Hesabınızı uygulamanın içinden silebilirsiniz:</strong> Hesap ekranı → <em>Hesabı Sil</em>. Silme işleminden önce verilerinizi dışa aktarmanız için bir adım sunulur. Silme işlemi geri alınamaz ve şunları kapsar:</p>
        <ul>
          <li>Sahibi olduğunuz projeler ve içlerindeki tüm kayıtlar</li>
          <li>Yüklediğiniz fotoğraf ve belgeler</li>
          <li>Alıcı kayıtları</li>
          <li>Profiliniz ve kimlik kaydınız</li>
          <li>Cihazınızdaki yerel kopyalar</li>
        </ul>
        <p>Ortak olarak katıldığınız projelerden yalnızca siz çıkarılırsınız; o projeler sahibine ait olduğu için silinmez.</p>

        <h2>7. Güvenlik</h2>
        <ul>
          <li>Tüm iletişim şifreli bağlantı üzerinden yapılır.</li>
          <li>Hangi verinin kim tarafından okunabileceği ve yazılabileceği sunucu tarafındaki güvenlik kurallarıyla belirlenir; bu kısıtlar uygulamadan bağımsızdır.</li>
          <li>İsteklerin gerçekten uygulamadan geldiği cihaz doğrulamasıyla kontrol edilir.</li>
          <li>Doğrulama SMS'leri yalnızca Türkiye numaralarına gönderilecek şekilde sınırlandırılmıştır.</li>
          <li>Dilerseniz uygulamayı cihazınızın kimlik doğrulamasıyla (Face ID / Touch ID / parola) kilitleyebilirsiniz.</li>
        </ul>

        <h2>8. Çocukların gizliliği</h2>
        <p>Uygulama bir iş aracıdır ve 18 yaşından küçüklere yönelik değildir. Bilerek 18 yaş altından veri toplamayız.</p>

        <h2>9. Haklarınız</h2>
        <p>Kişisel verilerinize ilişkin haklarınız ve bunları nasıl kullanacağınız <a class="inl" href="/privacy/insaat-takip-kvkk.html">KVKK Aydınlatma Metni</a>'nde açıklanmıştır.</p>

        <h2>10. Değişiklikler</h2>
        <p>Bu politika değişirse sayfanın başındaki "Son güncelleme" tarihi yenilenir. Önemli bir değişiklik olduğunda uygulama içinde de bilgilendirme yapılır.</p>

        <h2>11. İletişim</h2>
        <ul>
          <li><strong>Geliştirici:</strong> {gelistirici}</li>
          <li><strong>E-posta:</strong> <a class="inl" href="mailto:{eposta}">{eposta}</a></li>
        </ul>
"""

KVKK = """
        <p>6698 sayılı Kişisel Verilerin Korunması Kanunu'nun ("KVKK") 10. maddesi uyarınca, İnşaat Takip uygulamasını kullanırken kişisel verilerinizin nasıl işlendiği hakkında sizi bilgilendiriyoruz.</p>

        <h2>1. Veri sorumlusu</h2>
        <p>Hesap verileriniz (telefon numaranız ve adınız) bakımından veri sorumlusu <strong>{veri_sorumlusu}</strong>. İletişim: <a class="inl" href="mailto:{eposta}">{eposta}</a></p>

        <h2>2. İki ayrı rol: ne zaman veri sorumlusu, ne zaman veri işleyen</h2>
        <p>Bu uygulamada iki farklı veri kümesi vardır ve rolümüz her birinde farklıdır. Bu ayrımın yazılı olması önemlidir:</p>
        <ul>
          <li><strong>Hesap verileriniz</strong> (telefon, ad) bakımından <strong>veri sorumlusu biziz</strong>. Bu verileri kimlik doğrulama ve hizmetin sunulması için işleriz.</li>
          <li><strong>Uygulamaya girdiğiniz iş verileri</strong> — özellikle <strong>daire alıcılarının adları</strong> ve ortaklarınıza ait bilgiler — bakımından <strong>veri sorumlusu sizsiniz</strong>; biz yalnızca <strong>veri işleyen</strong> sıfatıyla bu verileri sizin adınıza barındırırız.</li>
        </ul>
        <p>Bunun pratik anlamı: alıcınızın adını uygulamaya girdiğinizde, o kişiye karşı aydınlatma yükümlülüğü ve işlemenin hukuki sebebini belirleme sorumluluğu <strong>size</strong> aittir. Biz o veriyi sizin talimatınız dışında kullanmayız, başkasına aktarmayız ve yalnızca hizmeti sunmak için saklarız.</p>

        <h2>3. İşlenen kişisel veriler</h2>
        <ul>
          <li><strong>Kimlik:</strong> Ad (uygulamaya girdiğiniz görünen ad)</li>
          <li><strong>İletişim:</strong> Telefon numarası</li>
          <li><strong>Müşteri işlem:</strong> Girdiğiniz proje, daire, satış, tahsilat, gider, malzeme ve ortaklık kayıtları</li>
          <li><strong>Görsel kayıt:</strong> Fiş, dekont, şantiye ve daire fotoğrafları</li>
          <li><strong>Üçüncü kişilere ait kimlik verisi:</strong> Girdiğiniz daire alıcılarının adları (bkz. 2. madde)</li>
          <li><strong>İşlem güvenliği:</strong> Cihaz doğrulama jetonu, değişiklik kayıtları (hangi kaydı kim ne zaman değiştirdi)</li>
        </ul>

        <h2>4. İşleme amaçları</h2>
        <ul>
          <li>Kullanıcı hesabının oluşturulması ve kimlik doğrulama</li>
          <li>Hizmetin sunulması: kayıtların saklanması, hesaplanması, raporlanması ve dışa aktarılması</li>
          <li>Projeye davet edilen ortaklarla paylaşımın sağlanması</li>
          <li>Bilgi güvenliğinin sağlanması, kötüye kullanımın ve sahteciliğin önlenmesi</li>
          <li>Talep ve şikâyetlerin karşılanması</li>
          <li>Abonelik ilişkisinin yürütülmesi</li>
        </ul>

        <h2>5. Hukuki sebepler</h2>
        <ul>
          <li><strong>Sözleşmenin kurulması veya ifası için gerekli olması</strong> (KVKK m.5/2-c): hesap verileri ve girdiğiniz iş kayıtlarının saklanması</li>
          <li><strong>Hukuki yükümlülüğün yerine getirilmesi</strong> (m.5/2-ç): yasal talepler ve saklama yükümlülükleri</li>
          <li><strong>Meşru menfaat</strong> (m.5/2-f): bilgi güvenliği, kötüye kullanımın önlenmesi</li>
        </ul>

        <h2>6. Toplama yöntemi</h2>
        <p>Veriler, uygulamayı kullanırken doğrudan sizin tarafınızdan girilerek ve otomatik yollarla (cihaz doğrulaması, değişiklik kayıtları) elektronik ortamda toplanır.</p>

        <h2>7. Aktarım</h2>
        <p>Verileriniz, hizmetin sunulabilmesi için Google Ireland Limited tarafından işletilen Firebase altyapısında barındırılır. Sunucu bölgesi <strong>europe-west1 (Belçika, Avrupa Birliği)</strong> olarak seçilmiştir.</p>
        <p><strong>Bu barındırma, verilerinizin Türkiye dışında tutulduğu anlamına gelir.</strong> Sunucular Avrupa Birliği içindedir ve altyapıyı işleten Google Ireland Limited bir yurt dışı hizmet sağlayıcısıdır.</p>
        <p>Projelerinize davet ettiğiniz ortaklar, o projenin kayıtlarını görebilir; <strong>alıcı adları ortaklara aktarılmaz</strong>. Abonelik satın alınması hâlinde ödeme işlemi Apple tarafından yürütülür. Yasal olarak yetkili makamların usulüne uygun talebi hâlinde veriler paylaşılabilir. <strong>Bunların dışında</strong> verileriniz başka üçüncü kişilere aktarılmaz; reklam, pazarlama veya analiz amacıyla hiçbir tarafla paylaşılmaz.</p>

        <h2>8. Saklama süresi</h2>
        <p>Veriler, hesabınız silinene kadar saklanır. Hesabınızı uygulama içinden sildiğinizde verileriniz sunuculardan ve cihazınızdan silinir. Mevzuatın saklamayı zorunlu kıldığı hâller saklıdır.</p>

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
          <li><strong>Arşivlenen projeler aktif sayılmaz.</strong> Biten bir projeyi arşivlediğinizde kayıtları durur, kontenjanınız boşalır.</li>
          <li>Güncel paket ve fiyatlar uygulama içinde gösterilir.</li>
        </ul>

        <h2>6. Abonelik, yenileme ve iptal</h2>
        <ul>
          <li>Abonelikler App Store üzerinden satın alınır; ödeme Apple Kimliğinize tanımlı yöntemle alınır.</li>
          <li>Abonelik, dönem bitiminden en az 24 saat önce iptal edilmezse <strong>otomatik yenilenir</strong>.</li>
          <li>İptal işlemi cihazınızın <em>Ayarlar → Apple Kimliği → Abonelikler</em> bölümünden yapılır. Aboneliği iptal ettiğinizde dönem sonuna kadar kullanmaya devam edersiniz.</li>
          <li>İade talepleri Apple'ın iade politikasına tabidir.</li>
          <li>Abonelik sona erdiğinde <strong>verileriniz silinmez</strong>; yalnızca ücretsiz katmanın sınırları geçerli olur ve kayıtlarınızı görmeye ve dışa aktarmaya devam edebilirsiniz.</li>
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

SAYFALAR = [
    ("insaat-takip.html", "Gizlilik Politikası", "gizlilik politikası", GIZLILIK),
    ("insaat-takip-kvkk.html", "KVKK Aydınlatma Metni", "KVKK aydınlatma metni", KVKK),
    ("insaat-takip-kosullar.html", "Kullanım Koşulları", "kullanım koşulları", KOSULLAR),
]


def main() -> int:
    hedef = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "benav_com" / "public" / "privacy"
    if not hedef.is_dir():
        print(f"hedef dizin yok: {hedef}", file=sys.stderr)
        return 1
    for dosya, baslik, baslik_kucuk, govde in SAYFALAR:
        html = ISKELET.format(
            baslik=baslik,
            baslik_kucuk=baslik_kucuk,
            guncelleme=GUNCELLEME,
            govde=govde.format(eposta=EPOSTA, gelistirici=GELISTIRICI,
                               veri_sorumlusu=VERI_SORUMLUSU).rstrip(),
        )
        (hedef / dosya).write_text(html, encoding="utf-8")
        print(f"yazıldı: {hedef / dosya}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
