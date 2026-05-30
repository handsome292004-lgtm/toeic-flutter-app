# TOEIC Flutter App

Bộ source này được chuyển từ app Python/Tkinter sang Flutter.

## Dữ liệu đã chuyển

- File Excel nguồn: `tu_vung.xlsx`
- Sheet dùng để tạo JSON: `All Vocabulary`
- Số từ vựng trong `assets/vocabulary.json`: 301
- Số câu Part 5 trong `assets/grammar_part5.json`: 10

## Tính năng

- Chọn topic từ vựng
- Học từ vựng theo danh sách
- Phát âm bằng `flutter_tts`
- Kiểm tra Việt → Anh
- Gợi ý từng chữ
- Nối từ Anh - Việt
- Trắc nghiệm Part 5
- Lưu điểm và số lần đúng bằng `shared_preferences`

## Cách chạy

### Cách 1: Tạo project Flutter mới rồi copy source

```bash
flutter create toeic_flutter_app
```

Sau đó copy đè các mục trong gói này vào project:

```text
lib/main.dart
assets/vocabulary.json
assets/grammar_part5.json
pubspec.yaml
```

Rồi chạy:

```bash
flutter pub get
flutter run
```

Build APK:

```bash
flutter build apk --release
```

File APK sẽ nằm tại:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Cách 2: Dùng trực tiếp thư mục này

Nếu máy đã có Flutter, bạn có thể mở thư mục này bằng VS Code/Android Studio, chạy:

```bash
flutter pub get
flutter create .
flutter run
```

`flutter create .` sẽ tạo thêm thư mục Android/iOS/Web cần thiết nếu chưa có.
