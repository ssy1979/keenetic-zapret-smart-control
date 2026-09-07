# Kaynaktan derleme

Gereksinimler: Windows, Python 3.12 (Tcl/Tk dahil), pip. Aşağıdaki derleme komutlarını `tools/kzsc-hazirlayici` dizininde çalıştırın.

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt pyinstaller==6.22.1
.venv\Scripts\pyinstaller.exe --noconfirm --clean --windowed `
  --name KZSC-Hazirlayici --add-data "profile.json;." app.py
```

Çıktı `dist\KZSC-Hazirlayici` klasörüdür. EXE tek başına taşınmamalı; klasör, içindeki `_internal` diziniyle birlikte ZIP yapılmalıdır.

Python dağıtımınız Tcl/Tk konumunu PyInstaller'a otomatik bildirmiyorsa `tkinter` paketini, `_tkinter.pyd`, `tcl86t.dll`, `tk86t.dll` ve Tcl/Tk veri klasörlerini ayrıca ekleyin; `pyi_tk_runtime.py` çalışma kancası bu klasörleri donmuş uygulamaya tanıtır. Resmî tam Windows Python kurulumunda standart komut genellikle yeterlidir.

Çekirdek testleri proje kökünden çalıştırmak için:

```powershell
python -m unittest discover -s tools/kzsc-hazirlayici/tests -v
python tools/kzsc-hazirlayici/app.py --smoke-test
```

Paketlemeden sonra EXE'yi de sınayın:

```powershell
$smoke = Start-Process -FilePath 'dist\KZSC-Hazirlayici\KZSC-Hazirlayici.exe' -ArgumentList '--smoke-test' -WindowStyle Hidden -PassThru -Wait
if ($smoke.ExitCode -ne 0) { throw 'KZSC Preparer GUI smoke test failed' }
```

`--smoke-test` ağ taraması veya SSH bağlantısı yapmaz. Tcl/Tk yüklemesini, kaynak profilini ve Türkçe/İngilizce ekranların oluşturulmasını denetleyip kapanır; hata halinde sıfırdan farklı çıkış kodu döndürür. Mevcut kullanıcının dil tercihini değiştirmez.
