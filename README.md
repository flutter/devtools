# Dart & Flutter DevTools

[![Build Status](https://github.com/flutter/devtools/workflows/devtools/badge.svg)](https://github.com/flutter/devtools/actions)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/flutter/devtools/badge)](https://deps.dev/project/github/flutter%2Fdevtools)

## What is this?

[Dart & Flutter DevTools](https://docs.flutter.dev/tools/devtools) is a suite of performance tools for Dart and Flutter.

## Getting started


Gezinme Menüsü

Kod
Sorunlar
873
geliştirme araçları
README.md #15780'i güncelleyin
Bu çalışma için iş akışı dosyası
.github/workflows/build.yaml 830241e adresinde
# Telif Hakkı 2020 The Chromium Authors. Tüm hakları saklıdır.
# Bu kaynak kodunun kullanımı, BSD tarzı bir lisans tarafından yönetilir ve bu lisans,
# LICENSE dosyasında bulundu.

isim : devtools

Açık :
  çekme_isteği :
  itmek :
    dallar :
      - usta

# Varsayılan izinleri salt okunur olarak bildirin.
izinler : tümünü oku

çevre :
  GH_TOKEN : ${{ secrets.GITHUB_TOKEN }}
işler :
  çırpınma-hazırlığı :
    kullanımlar : ./.github/workflows/flutter-prep.yaml

  ana :
    isim : ana
    ihtiyaçlar : flutter-prep
    çalışır-üzerinde : ubuntu-latest
    strateji :
      hızlı-başarısız : false
    adımlar :
      - adı : git klonu
        kullanımlar : actions/checkout@3df4ab11eba7bda6032a0b82a6bb43b11571feac
      - adı : Önbelleğe alınmış Flutter SDK'sını yükle
        kullanımlar : actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9
        ile :
          yol : |
            ./araç/flutter-sdk
          anahtar : flutter-sdk-${{ runner.os }}-${{ needs.flutter-prep.outputs.latest_flutter_candidate }}

      - adı : araç/ci/bots.sh
        çevre :
          BOT : ana
        çalıştır : ./tool/ci/bots.sh

  dcm :
    isim : Dart Kod Ölçümleri
    ihtiyaçlar : flutter-prep
    çalışır-üzerinde : ubuntu-latest
    strateji :
      hızlı-başarısız : false
    adımlar :
      - adı : Flutter DevTools'u Klonla
        kullanımlar : actions/checkout@3df4ab11eba7bda6032a0b82a6bb43b11571feac
        ile :
          başvuru : " ${{ github.event.pull_request.head.sha }} "
      - adı : Önbelleğe alınmış Flutter SDK'sını yükle
        kullanımlar : actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9
        ile :
          yol : |
            ./araç/flutter-sdk
          anahtar : flutter-sdk-${{ runner.os }}-${{ needs.flutter-prep.outputs.latest_flutter_candidate }}
      - adı : tool/ci/bots.sh'yi çalıştırın
        çalıştır : ./tool/ci/bots.sh
      - adı : DCM'yi yükleyin
        koş : |
          sudo apt-get güncelleme
          wget -qO- https://dcm.dev/pgp-key.public | sudo gpg --dearmor -o /usr/share/keyrings/dcm.gpg
          echo 'deb [signed-by=/usr/share/keyrings/dcm.gpg arch=amd64] https://dcm.dev/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
          sudo apt-get güncelleme
          sudo apt-get install dcm=1.22.0-1 # Hataları önlemek için sürüme `-1` (derleme numarası) ekleyin
          sudo chmod +x /usr/bin/dcm
          echo "$(dcm --version)"
      - adı : Dart SDK Kurulumu
        kullanımlar : dart-lang/setup-dart@0a8a0fc875eb934c15d08629302413c671d3f672
      - name : DCM'yi kökte çalıştır
        koş : |
          dcm paketleri analiz et/devtools_app paketleri/devtools_app_paylaşılan paketleri/devtools_extensions paketleri/devtools_paylaşılan paketleri/devtools_test
  test paketleri :
    isim : ${{ matrix.package }} test
    ihtiyaçlar : flutter-prep
    çalışır-üzerinde : ubuntu-latest
    strateji :
      hızlı-başarısız : false
      matris :
        paket :
          - devtools_app_shared
          - devtools_uzantıları
          - devtools_paylaşılan
    adımlar :
      - adı : git klonu
        kullanımlar : actions/checkout@3df4ab11eba7bda6032a0b82a6bb43b11571feac
      - adı : Önbelleğe alınmış Flutter SDK'sını yükle
        kullanımlar : actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9
        ile :
          yol : |
            ./araç/flutter-sdk
          anahtar : flutter-sdk-${{ runner.os }}-${{ needs.flutter-prep.outputs.latest_flutter_candidate }}
      - adı : araç/ci/package_tests.sh
        çevre :
          PAKET : ${{ matrix.package }}
        çalıştır : ./tool/ci/package_tests.sh

  deneme :
    isim : ${{ matrix.bot }}
    ihtiyaçlar : flutter-prep
    çalışır-üzerinde : ubuntu-latest
    strateji :
      hızlı-başarısız : false
      matris :
        bot :
          - ddc_oluştur
          - build_dart2js
          - test_ddc
          - test_dart2js
    adımlar :
      - adı : git klonu
        kullanımlar : actions/checkout@3df4ab11eba7bda6032a0b82a6bb43b11571feac
      - adı : Önbelleğe alınmış Flutter SDK'sını yükle
        kullanımlar : actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9
        ile :
          yol : |
            ./araç/flutter-sdk
          anahtar : flutter-sdk-${{ runner.os }}-${{ needs.flutter-prep.outputs.latest_flutter_candidate }}
      - adı : araç/ci/bots.sh
        çevre :
          BOT : ${{ matrix.bot }}
          PLATFORM : vm
        çalıştır : ./tool/ci/bots.sh

  macos-testi :
    ihtiyaçlar : flutter-prep
    isim : macos goldens ${{ matrix.bot }}
    çalışır durumda : macos-latest
    strateji :
      hızlı-başarısız : false
      matris :
        bot :
          - test_dart2js
        sadece_altın :
          - doğru

    adımlar :
      - adı : git klonu
        kullanımlar : actions/checkout@3df4ab11eba7bda6032a0b82a6bb43b11571feac
      - adı : Önbelleğe alınmış Flutter SDK'sını yükle
        kullanımlar : actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9
        ile :
          yol : |
            ./araç/flutter-sdk
          anahtar : flutter-sdk-${{ runner.os }}-${{ needs.flutter-prep.outputs.latest_flutter_candidate }}
      - adı : araç/ci/bots.sh
        çevre :
          BOT : ${{ matrix.bot }}
          PLATFORM : vm
          SADECE_ALTIN ​​: ${{ matrix.only_golden }}
        çalıştır : ./tool/ci/bots.sh

      - adı : Altın Başarısızlık Eserlerini Yükle
        kullanımlar : actions/upload-artifact@89ef406dd8d7e03cfd12d9e0a4a378f454709029
        eğer : başarısızlık()
        ile :
          isim : golden_image_failures.${{ matrix.bot }}
          yol : paketler/devtools_app/test/**/başarısızlıklar/*.png
      - adı : Hızlı Düzeltme Bildirimi
        eğer : başarısızlık()
        çevre :
          İŞ AKIŞI_KIMLIĞI : ${{ github.run_id }}
        koş : |
          echo "::notice title=Altınları Hızlıca Düzeltmek İçin:: Yerel dalınızda \`devtools_tool fix-goldens --run-id=$WORKFLOW_ID\` komutunu çalıştırın."
  devtools-app-entegrasyon-testi :
    isim : devtools_app entegrasyon-testi ${{ matrix.bot }} - ${{ matrix.device }} - parça ${{ matrix.shard }}
    ihtiyaçlar : flutter-prep
    çalışır durumda : macos-latest
    strateji :
      hızlı-başarısız : false
      matris :
        # Entegrasyon testlerini ddc modunda çalıştırmayı da düşünün.
        bot : [integration_dart2js]
        cihaz : [flutter, flutter-web, dart-cli]
        # Seçenek 1/1, bir cihaz için tüm testleri tek bir parçada çalıştıracaktır.
        # Bir cihaz için 2 parçada test çalıştırmak için 1/2 ve 2/2 seçeneği etkinleştirilmelidir.
        parça : [1/1, 1/2, 2/2, 1/3, 2/3, 3/3]
        hariç tutmak :
          # 'Flutter' cihazı üç parçada çalıştırılmalıdır.
          - cihaz : çırpınma
            parça : 1/1
          - cihaz : çırpınma
            parça : 1/2
          - cihaz : çırpınma
            parça : 2/2
          # 'Flutter-web' cihazı iki parçada çalıştırılmalıdır.
          - cihaz : flutter-web
            parça : 1/1
          - cihaz : flutter-web
            parça : 1/3
          - cihaz : flutter-web
            parça : 2/3
          - cihaz : flutter-web
            parça : 3/3
          # 'Dart-cli' aygıtı tek bir parçada çalıştırılabilir.
          - cihaz : dart-cli
            parça : 1/2
          - cihaz : dart-cli
            parça : 2/2
          - cihaz : dart-cli
            parça : 1/3
          - cihaz : dart-cli
            parça : 2/3
          - cihaz : dart-cli
            parça : 3/3
    adımlar :
      - adı : git klonu
        kullanımlar : actions/checkout@3df4ab11eba7bda6032a0b82a6bb43b11571feac
      - adı : Önbelleğe alınmış Flutter SDK'sını yükle
        kullanımlar : actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9
        ile :
          yol :|
            ./araç/flutter-sdk
          anahtar : flutter-sdk-${{ runner.os }}-${{ needs.flutter-prep.outputs.latest_flutter_candidate }}
      - isim :araç/ci/bots.sh
        çevre :
          BOTLAR :${{ matrix.bot }}
          CİHAZ : ${{ matrix.device }}
          PARÇA : ${{ matrix.shard }}
          GELİŞTİRİCİ_ARAÇLARI_PAKETİ : devtools_app
        çalıştır : ./tool/ci/bots.sh

      - isim :Altın Başarısızlık Eserlerini Yükle
        kullanımları :actions/upload-artifact@89ef406dd8d7e03cfd12d9e0a4a378f454709029
        eğer :başarısızlık()
        ile :
          isim :golden_image_failures.${{ matrix.bot }}
          yol : paketler/devtools_app/entegrasyon_testi/**/hatalar/*.png

  devtools-uzantıları-entegrasyon-testi :
    isim : devtools_extensions entegrasyon-testi ${{ matrix.bot }}
    ihtiyaçlar :flutter-prep
    devam ediyor :ubuntu-latest
    strateji :
      hızlı-başarısız :false
      matris :
        # Entegrasyon testlerini ddc modunda çalıştırmayı da düşünün.
        bot :[integration_dart2js]
    adımlar :
      - isim :git klonu
        kullanımlar : actions/checkout@3df4ab11eba7bda6032a0b82a6bb43b11571feac
      - isim :Önbelleğe alınmış Flutter SDK'sını yükle
        kullanımları :actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9
        ile :
          yol :|
            ./araç/flutter-sdk
          anahtar : flutter-sdk-${{ runner.os }}-${{ needs.flutter-prep.outputs.latest_flutter_candidate }}
      - isim :araç/ci/bots.sh
        çevre :
          BOTLAR :${{ matrix.bot }}
          GELİŞTİRİCİ_ARAÇLARI_PAKETİ : devtools_extensions
        çalıştır : ./tool/ci/bots.sh

  kıyaslama performansı :
    isim : benchmark-performance
    ihtiyaçlar :flutter-prep
    devam ediyor :ubuntu-latest
    strateji :
      hızlı-başarısız :false
    adımlar :
      - isim :git klonu
        kullanımlar : actions/checkout@3df4ab11eba7bda6032a0b82a6bb43b11571feac
      - isim :Önbelleğe alınmış Flutter SDK'sını yükle
        kullanımları :actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9
        ile :
          yol :|
            ./araç/flutter-sdk
          anahtar : flutter-sdk-${{ runner.os }}-${{ needs.flutter-prep.outputs.latest_flutter_candidate }}
      - isim : araç/ci/benchmark_performance.sh
        çalıştır : ./tool/ci/benchmark_performance.sh
For documentation on installing and trying out DevTools, please see our
[docs](https://docs.flutter.dev/tools/devtools).

## Contributing and development

Contributions welcome! See our
[contributing page](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md)
for an overview of how to build and contribute to the project.
[devcontainer.json](https://github.com/user-attachments/files/17182209/devcontainer.json)


## Terms and Privacy

By using Dart DevTools, you agree to the [Google Terms of Service](https://policies.google.com/terms). To understand how we use data collected from this service, see the [Google Privacy Policy](https://policies.google.com/privacy?hl=en).
