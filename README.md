# TUBITAK JNLP Guard for macOS

[English](README.en.md)

TÜBİTAK e-imza sisteminin her işlem için ürettiği yeni `.jnlp` dosyalarında macOS'un tekrar tekrar **Open Anyway** istemesini önleyen, dar kapsamlı bir yardımcı araçtır.

> [!WARNING]
> Bu proje TÜBİTAK ile bağlantılı veya TÜBİTAK tarafından onaylanmış değildir. JNLP dosyaları Java kodunu geniş sistem izinleriyle çalıştırabilir. Aracı yalnızca bu riski anlıyorsanız kullanın.

## Neden gerekli?

Chrome ve diğer tarayıcılar indirilen JNLP dosyalarına `com.apple.quarantine` özniteliği ekler. TÜBİTAK her imza işi için farklı adlı bir dosya ürettiğinden macOS önceki **Open Anyway** kararını yeni dosyaya uygulamaz.

Bu araç Gatekeeper'ı kapatmaz. Downloads klasörünü izler ve yalnızca tüm aşağıdaki kontrollerden geçen dosyanın karantina özniteliğini kaldırır:

- Dosya normal bir `.jnlp` dosyasıdır; sembolik bağlantı değildir.
- Gerçek `kMDItemWhereFroms` metadata'sındaki ilk URL, HTTPS üzerinden tam olarak `e-imza.tubitak.gov.tr` alan adına aittir.
- JNLP `codebase` yolu `https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/` altındadır.
- JNLP içindeki tüm JAR adresleri aynı güvenilir HTTPS alan adına çözümlenir.
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

Bu araç, TÜBİTAK sunucusundan sunulan Java kodunun güvenli olduğunu kanıtlamaz. Yalnızca dosyanın beklenen HTTPS kaynağından geldiğini ve dış bir JAR adresine yönlendirmediğini denetler. TÜBİTAK alan adı veya sunucusu ele geçirilirse bu araç koruma sağlayamaz.

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

Testler, güvenilir dosyanın karantinasının kaldırıldığını; benzer görünümlü alan adları, dış JAR adresleri, beklenmeyen codebase yolları ve sembolik bağlantıların engelli kaldığını doğrular.

## Gizlilik

Araç ağ isteği yapmaz ve telemetri toplamaz. Günlük yalnızca sayısal tarama sonuçlarını içerir; JNLP iş kimliklerini veya dosya adlarını kaydetmez.

## Lisans

[MIT](LICENSE)
