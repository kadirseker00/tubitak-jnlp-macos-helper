# TUBITAK JNLP Guard for macOS

[English](README.en.md)

TÜBİTAK e-imza sisteminin her işlem için ürettiği yeni `.jnlp` dosyalarında macOS'un tekrar tekrar **Open Anyway** istemesini önleyen, dar kapsamlı bir yardımcı araçtır.

> [!CAUTION]
> **Durum: Deneysel.** Bu araç JNLP dosyasının veya çalıştırılan Java kodunun güvenli olduğunu garanti etmez. TÜBİTAK ile bağlantılı veya TÜBİTAK tarafından onaylanmış değildir. Yalnızca riski anlıyor ve kaynak kodunu inceleyebiliyorsanız kullanın.

## Neden gerekli?

Chrome ve diğer tarayıcılar indirilen JNLP dosyalarına `com.apple.quarantine` özniteliği ekler. TÜBİTAK her imza işi için farklı adlı bir dosya ürettiğinden macOS önceki **Open Anyway** kararını yeni dosyaya uygulamaz.

Bu araç Gatekeeper'ı kapatmaz. Downloads klasörünü izler ve yalnızca tüm aşağıdaki kontrollerden geçen dosyanın karantina özniteliğini kaldırır:

- Dosya normal bir `.jnlp` dosyasıdır; sembolik bağlantı değildir.
- Tarayıcının yazdığı `kMDItemWhereFroms` metadata'sındaki ilk URL, HTTPS üzerinden tam olarak `e-imza.tubitak.gov.tr` alan adına aittir.
- JNLP `codebase` yolu `https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/` altındadır.
- Kök JNLP referansı ve tüm JAR adresleri aynı güvenilir HTTPS codebase yolu içinde kalır.
- `resources` altında yalnızca `jar` ile `java`/`j2se` öğeleri kabul edilir; `nativelib`, `extension`, `property`, `package` ve bilinmeyen kaynak türleri reddedilir.
- Bir Java çalışma zamanı tedarikçisi belirtilmişse yalnızca TÜBİTAK'ın mevcut dosyasında kullandığı sabit eski Oracle adresi kabul edilir.
- Dosya 1 MiB'dan küçüktür ve geçerli XML olarak ayrıştırılabilir.

Araç dosyayı otomatik açmaz ve başka hiçbir genişletilmiş özniteliği silmez.

## Kurulum

Gereksinimler: macOS 13 veya üstü ve Xcode Command Line Tools.

```zsh
git clone https://github.com/kadirseker00/tubitak-jnlp-macos-helper.git
cd tubitak-jnlp-macos-helper
./scripts/install.sh
```

Kurulum sırasında macOS, Downloads klasörüne erişim izni ister. **Allow** seçeneğini kullanın. `sudo` gerekmez.

Kurulum tamamlandıktan sonra TÜBİTAK'tan JNLP dosyasını indirin, yaklaşık 1-2 saniye bekleyin ve normal biçimde çift tıklayın.

## Kaldırma

```zsh
./scripts/uninstall.sh
```

Kaldırıcı LaunchAgent'ı, yerel uygulamayı, günlüğü ve Downloads erişim iznini temizler.

## Nasıl çalışır?

Kurulum betiği kaynak kodu yerel olarak derler ve ad-hoc imzalı küçük bir macOS uygulaması oluşturur. Uygulama yalnızca kullanıcı hesabınızda çalışır. Bir LaunchAgent, Downloads klasörü değiştiğinde uygulamayı başlatır; uygulama doğrulamaları yapar ve uygun dosyalarda `com.apple.quarantine` özniteliğini kaldırır.

Kurulan bileşenler:

```text
~/Library/Application Support/TubitakJnlpGuard/TUBITAK JNLP Guard.app
~/Library/LaunchAgents/org.kadirseker.TubitakJnlpGuard.plist
~/Library/Logs/TubitakJnlpGuard.log
```

## Güvenlik sınırı

Bu araç, TÜBİTAK sunucusundan sunulan Java kodunun güvenli olduğunu kanıtlamaz. `kMDItemWhereFroms` tarayıcı tarafından yazılan yerel metadata'dır; dijital imza veya kriptografik kaynak kanıtı değildir. TÜBİTAK alan adı ya da sunucusu ele geçirilirse veya dosya doğrulamadan sonra değiştirilirse araç koruma sağlayamaz.

Mevcut TÜBİTAK JNLP dosyası eski `http://java.sun.com/products/autodl/j2se` çalışma zamanı tedarikçisi referansını içerir. Araç yalnızca bu tam değeri kabul eder fakat HTTP bağlantısının güvenliğini garanti edemez. Kurulu JNLP istemcisinin bu alanı nasıl işlediği kendi güvenlik sınırının parçasıdır.

İnternette sık önerilen aşağıdaki geniş kapsamlı komutları kullanmaz:

```zsh
sudo spctl --global-disable
xattr -cr ~/Downloads
```

## Geliştirme

```zsh
swift test
./scripts/build-app.sh
```

Testler, güvenilir dosyanın karantinasının kaldırıldığını; benzer görünümlü alan adları, dış veya codebase dışı JAR adresleri, `nativelib`, `extension`, beklenmeyen çalışma zamanı tedarikçileri, kök JNLP yönlendirmeleri ve sembolik bağlantıların engelli kaldığını doğrular.

## Gizlilik

Araç ağ isteği yapmaz ve telemetri toplamaz. Günlük yalnızca sayısal tarama sonuçlarını içerir; JNLP iş kimliklerini veya dosya adlarını kaydetmez.

## Lisans

[MIT](LICENSE)
