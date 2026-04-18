# Logbook App - Modul 6 AI (Vision & Digital Image Processing)

Aplikasi Smart Patrol System dengan fitur Computer Vision dan Pengolahan Citra Digital (PCD), dikembangkan menggunakan Flutter dengan penerapan prinsip SOLID, Camera Lifecycle Management, dan Fourier Transform.

## Fitur Utama

- **Onboarding**: Antarmuka pengenalan aplikasi dengan 3 langkah dan indikator halaman.
- **Authentication**: Sistem login multi-user dengan validasi input, toggle visibilitas password, dan mekanisme lockout setelah 3x gagal login.
- **Reactive Programming**: Manajemen state menggunakan `ValueNotifier` dan `ValueListenableBuilder` sehingga UI terupdate otomatis tanpa `setState` berlebih.
- **Async-Reactive Flow**: Loading indicator saat koneksi ke database, penanganan error koneksi, dan empty state yang informatif.
- **Timestamp Formatting**: Format waktu relatif ("2 menit yang lalu", "3 jam yang lalu", "25 Jan 2026") menggunakan logika waktu lokal Indonesia.
- **Search**: Pencarian catatan secara real-time berdasarkan judul dan deskripsi.
- **Kategori**: Sistem kategori (Pribadi, Pekerjaan, Urgent) dengan warna dan ikon yang berbeda, terpusat di `AppConstants`.
- **Cloud CRUD**: Pencatatan aktivitas dengan fitur Tambah, Edit, dan Hapus yang tersinkronisasi langsung ke database MongoDB.
- **Connection Guard**: Pesan error melalui SnackBar jika koneksi ke database gagal saat aplikasi dimulai.
- **Secure Credentials**: Penyimpanan kredensial database di file `.env` yang terlindungi oleh `.gitignore`.
- **Pull-to-Refresh**: Widget `RefreshIndicator` untuk memperbarui data dari database secara manual.
- **Cloud Sync Indicator**: Ikon cloud pada setiap item yang menunjukkan data tersinkronisasi dengan server.
- **Per-User Log Filtering**: Setiap log ditandai dengan `username` pemiliknya. Saat fetch, hanya data milik user yang sedang login yang ditampilkan.
- **Audit Logging**: Sistem `LogHelper` dengan level verbosity (`LOG_LEVEL`) dan source filtering (`LOG_MUTE`) yang dikonfigurasi melalui `.env`.
- **Offline-First (Hive)**: Penyimpanan data biner secara lokal agar log tetap tersedia instan tanpa koneksi internet.
- **Hybrid Sync Manager**: Sinkronisasi cerdas antara database lokal dan MongoDB Atlas secara *background*.
- **RBAC Gatekeeper**: Validasi keamanan level UI dan Controller berdasarkan *role* (Ketua/Anggota) dan *ownership* (pemilik data).
- **Collaborative Team Isolation**: Pemisahan data *(multi-tenancy)* menggunakan filter `teamId` agar kelompok mahasiswa dapat bekerja secara kolaboratif.
- **Markdown Editor**: Pengolahan dan formatting dokumen laporan kaya (*rich-text*) dengan tab khusus Editor & Preview menggunakan `flutter_markdown`.
- **Data Sovereignty & Privacy Badge**: Sistem catatan privat *(Private)* dan publik *(Public)* yang membatasi hak akses kerahasiaan antar rekan satu tim.
- **Connectivity Awareness**: Menampilkan *dashboard header* indikator status sinyal (Offline/Online) *real-time* berbasis paket `connectivity_plus`.
- **Unit Testing**: Menguji logic aplikasi menggunakan Flutter Test dengan pendekatan white box testing, termasuk mocking dependencies dan AAA pattern.
- **[NEW] Smart Patrol Vision**: Integrasi kamera real-time dengan live preview menggunakan `camera` plugin dan permission handler.
- **[NEW] Digital Overlay System**: CustomPainter untuk menggambar bounding box deteksi kerusakan jalan (RDD-2022: D00, D10, D20, D40) di atas preview kamera.
- **[NEW] Image Processing Pipeline**: Pengolahan citra digital dengan operasi Brightness/Contrast, Histogram Equalization, Gaussian Blur, Sharpening, Edge Detection (Canny), Thresholding, Median Filter, dan Gamma Correction menggunakan `opencv_dart`.
- **[NEW] Fourier Transform Analysis**: Transformasi domain frekuensi dengan visualisasi magnitude spectrum, FFT shift (DC centering), dan inverse DFT untuk kembali ke domain spasial.
- **[NEW] Domain State Management**: Sistem pelacakan domain gambar (spatial/frequency) dengan validasi operasi sesuai domain aktif.
- **[NEW] Modular Vision Architecture**: Pemisahan kode vision ke dalam folder terstruktur: `models/`, `services/`, dan `widgets/`.

## Screenshots (Modul 6 AI)

|                       Vision Camera Preview                        |                          Brightness & Contrast                           |                          Thresholding                           |                       Fourier Transform                       |
| :----------------------------------------------------------------: | :----------------------------------------------------------------------: | :-------------------------------------------------------------: | :-----------------------------------------------------------: |
| ![Vision Preview](.screenshots/modul-6-ai/smart-patrol-vision.jpg) | ![Image Processing](.screenshots/modul-6-ai/pcd-brightness-contrast.jpg) |     ![Threshold](.screenshots/modul-6-ai/pcd-threshold.jpg)     | ![Fourier Transform](.screenshots/modul-6-ai/pcd-fourier.jpg) |
|                         **Edge Detection**                         |                        **Histogram Equalization**                        |                        **Gaussian Blur**                        |                        **Sharpening**                         |
| ![Edge Detection](.screenshots/modul-6-ai/pcd-edge-detection.jpg)  | ![Histogram Equalization](.screenshots/modul-6-ai/pcd-histogram-eq.jpg)  | ![Gaussian Blur](.screenshots/modul-6-ai/pcd-gaussian-blur.jpg) |    ![Sharpening](.screenshots/modul-6-ai/pcd-sharpen.jpg)     |

## Instalasi dan Cara Menjalankan

### Prasyarat

- Flutter SDK >= 3.41.x
- Android SDK
- Git

### Langkah Instalasi

1. **Clone Repository**
   ```bash
   git clone https://github.com/ikhsan3adi/PY4_2C_D3_2024_Modul6_080.git
   cd PY4_2C_D3_2024_Modul6_080
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Setup Environment Variables**
   - Buat file `.env` di root project
   - Isi dengan konfigurasi MongoDB dan pengaturan lainnya:
     ```sh
     MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/
     # ...
     ```

4. **Cek Issues (Opsional)**
   ```bash
   flutter analyze
   ```

5. **Jalankan Test (Opsional)**
   ```bash
   flutter test
   ```

6. **Build Project**
   ```bash
   # Untuk release APK
   flutter build apk --release

   # Untuk release dengan split ABI
   flutter build apk --split-per-abi
   ```

7. **Install APK**
   Pastikan telah terhubung ke device android dan menyalakan opsi **USB Debugging** dan **Install via USB** (Developer Option)
   ```bash
   adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk # dari --split-per-abi
   # atau
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

## Lesson Learned (Refleksi Akhir)

1. **Konsep Baru**:
   - Memahami arsitektur Vision pada mobile dengan konsep Layering UI (Background Layer untuk CameraPreview dan Foreground Layer untuk CustomPaint overlay). Memisahkan Hardware Stream dari UI Layering mengikuti prinsip Separation of Concerns untuk mencegah spaghetti code.
   - Mempelajari konsep Pengolahan Citra Digital (PCD) menggunakan OpenCV Dart, termasuk: (a) transformasi domain frekuensi dengan DFT/FFT, (b) operasi spasial seperti filtering dan edge detection, (c) manajemen tipe data Mat (CV_8UC1, CV_32FC1) untuk kompatibilitas antar operasi.
   - Memahami pentingnya Camera Lifecycle Management (init, pause, resume, dispose) untuk mencegah memory leak dan mengelola izin akses hardware secara elegan menggunakan `permission_handler`.
2. **Kemenangan Kecil**:
   - Berhasil mengimplementasikan Fourier Transform dengan FFT shift untuk memindahkan komponen DC ke tengah spektrum, serta sistem domain state management yang memvalidasi operasi sesuai domain aktif (spatial/frequency).
   - Berhasil membangun modular architecture untuk fitur vision dengan memisahkan models (enum, DTO), services (image processing logic), dan widgets (UI components) ke dalam struktur folder yang terorganisir.
   - Mengatasi error tipe data OpenCV (`CV_32FC1` required untuk DFT) dengan konversi tepat menggunakan `convertTo()`, serta memastikan semua operasi (edge detection, threshold) dapat menerima input baik color maupun grayscale.
3. **Target Berikutnya**:
   - Integrasi model AI YOLO untuk deteksi kerusakan jalan secara real-time, menggantikan sistem mock detection yang ada.
