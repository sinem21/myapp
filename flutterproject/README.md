# Ollama Chat

Android emülatöründe çalışan yerel Ollama modelleri için Flutter sohbet uygulaması.

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
