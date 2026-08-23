# KZSC v0.11.2.49-generic

## Türkçe

- Zapret2 durum paneli artık bakım yenilemesinden tamamen bağımsız çalışır.
- Durum CGI’si doğrudan çağrılır; bakım isteği başarısız olsa bile bilgiler gösterilir.
- Hata halinde sonsuz “Yükleniyor…” yerine açık bir durum mesajı gösterilir.

## English

- The Zapret2 status panel now operates independently of the maintenance refresh.
- The status CGI is queried directly, so information remains visible even if maintenance data fails.
- A clear status error is shown instead of an endless “Loading…” state.
