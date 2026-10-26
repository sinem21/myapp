# Ollama Chat

Android emülatöründe çalışan yerel Ollama modelleri için Flutter sohbet uygulaması.

## Sohbet geçmişini MongoDB'ye kaydetme

Geçmişi saklamak için MongoDB'ye bağlanan API sunucusunu ayrı bir terminalde
başlatın. MongoDB Atlas bağlantı dizesini veya yerel MongoDB URI'sini ortam
değişkeni olarak verin; bağlantı bilgisini uygulama koduna eklemeyin:

```powershell
$env:MONGODB_URI = 'mongodb://localhost:27017/ollama_chat'
dart run bin/history_server.dart
```

API `0.0.0.0:8080` üzerinde dinler ve her uygulama kurulumu için ayrı sohbet
geçmişi tutar. Android emülatörü varsayılan olarak `10.0.2.2:8080` adresini
kullanır. Fiziksel cihazda veya farklı bir API adresinde Flutter'ı şu şekilde
başlatın:

```powershell
flutter run --dart-define=HISTORY_API_URL=http://BILGISAYARIN_LAN_IP_ADRESI:8080
```

Uygulama açılışta geçmişi yükler; her yeni mesajı ve tamamlanan yanıtı MongoDB'ye
yazar. API erişilemiyorsa sohbet ekranda kullanılmaya devam eder ve geçmiş
bağlantısı için hata uyarısı gösterilir.

## Çalıştırma

1. Bilgisayarınızda Ollama'yı başlatın ve en az bir model indirin (ör. `ollama pull qwen3:8b`).
2. Android emülatöründen `http://10.0.2.2:11434` adresine erişilebildiğini doğrulayın.
3. Proje dizininde `flutter pub get` ve ardından `flutter run` komutlarını çalıştırın.

Uygulama `/api/tags` ile mevcut modelleri listeler ve `/api/chat` üzerinden
`stream: true` kullanarak yanıtları anlık gösterir. Model hem `message.thinking`
alanı hem de yanıttaki `<think>...</think>` etiketleriyle düşünme içeriği
gönderiyorsa, arayüzde bu içerik ayrı açılır bir bölümde görüntülenir.

Ollama sunucusu ve modelin kullandığı düşünme biçimi modele göre değişebilir.
Sunucu erişilemiyorsa uygulamadaki yenileme düğmesini kullanın; model adı
bağlantı olmadan da üst çubuktan elle girilebilir.
