# Firestore — kurallar, indeksler, testler

iOS uygulaması Xcode ile derlenir; bu klasördeki npm kurulumu **yalnızca sunucu
tarafı kuralları test etmek** için. Uygulama kodunun npm'e bağımlılığı yok.

## Testleri koşturmak

```bash
npm test
```

96 test, Firestore emülatörüne karşı. Emülatör Java istiyor; bu makinede sistem
Java'sı yok, o yüzden `.tools/` altında yerel bir Temurin JRE tutuluyor
(gitignore'lu). Depoyu yeni klonladıysanız:

```bash
npm install && npm run java:install && npm test
```

`demo-` ile başlayan proje kimliği kullanılıyor — Firebase araçları bu durumda
uzak servise **hiç bağlanmaz**, yani testler gerçek veritabanına dokunamaz.

Kural değiştirdiğinizde testi mutlaka koşturun. Testlerin dişi olduğu iki
mutasyonla doğrulandı: belge gizliliğini kaldırmak 3 testi, proje okuma üyelik
denetimini kaldırmak 3 testi düşürüyor.

## Yayına almak

```bash
firebase login
firebase deploy --only firestore:rules,firestore:indexes --project <proje-kimliği>
```

**ÖNEMLİ — açık kalmış olabilecek pencere:** Firestore konsoldan "test modu" ile
kurulduysa veritabanı, kurulumdan 30 gün boyunca API anahtarını bilen HERKESE
açıktır. Bu depodaki kurallar o pencereyi kapatır; henüz yayına alınmadıysa
öncelikli iş bu. Uygulama şu an Firestore'a hiç okuma/yazma yapmadığı için
kuralları yayına almak mevcut davranışı bozmaz.

## Kuralların dayattığı iki kısıt

### 1. Proje kurulumu iki aşamalı olmak zorunda

Alt koleksiyon yazmaları üst proje belgesini `get()` ile doğruluyor ve kural
değerlendirmesi **aynı partideki henüz işlenmemiş yazmaları görmez**. Bugünkü
`ProjectViewModel.addProject` proje + ~20 daire + 9 malzemeyi tek partide
veriyor; `FirestoreProjectRepository` bunu bölmek zorunda:

1. `projects/{pid}` tek başına,
2. daireler ve malzemeler tek parti.

Bu kısıt testle sabitlendi (*"proje + daire aynı WriteBatch içinde reddedilir"*),
yorumla değil. Kurulum dışındaki her eylemde üst belge zaten var, dolayısıyla
`apply([DocumentChange])`ın atomiklik sözü bozulmuyor.

### 2. Ortağın belge sorgusu süzgeçli kurulmak zorunda

Kurallar süzgeç değildir. Ortak `projects/{pid}/documents` koleksiyonunu
süzgeçsiz sorgularsa Firestore **sorgunun tamamını** reddeder — tek tek gizli
belgeleri saklamaz. İstemci sorgusu role göre kurulmalı:

```swift
// ortak
.whereField("partnerVisible", isEqualTo: true)
// yönetici: kısıt yok
```

## Davet akışı bilerek kapatıldı

Kurallar, davet edilen kişinin kendini `memberUids`'e eklemesine izin
**vermiyor** — aksi halde herkes herhangi bir projeye kendini ekleyebilirdi. Bu
yüzden davet edilen kişi projeyi okuyup kodu doğrulayamaz da.

Sonuç: **davet kodu akışı istemciden çalışmaz.** Bir `redeemInvite` Cloud
Function şart; işlev kodu doğrular, süresini/tek kullanımını denetler ve üyeliği
yönetici adına yazar. Test bunu kanıtlıyor: *"YABANCI kendini üye listesine
EKLEYEMEZ"*.

## Kuralların kapsamadığı gizlilik boşluğu

Bugün projeye üye olan biri **alıcı adlarını, bedelleri ve tahsilatları**
görebiliyor. ANALIZ.md (madde 18) bunun KVKK veri minimizasyonu açısından
savunulması zor olduğunu söylüyor ve finansal/kişisel veri için de
`partnerVisible` benzeri bir ayrım öneriyor.

Kural, veri modelinin taşımadığı bir ayrımı uygulayamaz. O alan modele
eklendiğinde `apartments` / `payments` okuma kuralları da daralacak.
