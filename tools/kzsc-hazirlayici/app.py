from __future__ import annotations

import json
import os
import queue
import re
import sys
import threading
import time
import tkinter as tk
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from tkinter import messagebox, scrolledtext, ttk

import paramiko

from core import (
    APP_NAME,
    APP_VERSION,
    DEFAULT_ENTWARE_PACKAGES,
    DEFAULT_KZSC_COMPONENTS,
    DNS_PRESETS,
    DeviceInfo,
    KZSC_ASSET_PREFIX,
    KZSC_MAX_ARCHIVE_BYTES,
    KZSC_MAX_CHECKSUM_BYTES,
    KZSC_RELEASE_API,
    KZSC_REPOSITORY,
    KzscRelease,
    SetupOptions,
    SetupPlan,
    build_wan_selection_targets,
    build_plan,
    has_cli_error,
    parse_components,
    parse_installed_components,
    parse_custom_doh,
    parse_custom_dot,
    parse_configured_wan_choices,
    parse_interface_choices,
    parse_interfaces,
    parse_media,
    parse_kzsc_release,
    merge_wan_choices,
    parse_opkg_disk,
    parse_version,
    summarize_wan_sources,
    validate_hostname,
    validate_interface,
    validate_packages,
)
from transport import (
    EntwareShell,
    HostKeyMismatch,
    KeeneticCli,
    UnknownHostKey,
    app_data_dir,
    discover_keenetic,
    forget_host_key,
    is_port_open,
    probe_host_key,
    trust_host_key,
    verify_host_key,
    wait_for_port,
)


DEFAULT_PROFILE = {
    "profile_name": "KZSC",
    "profile_version": 3,
    "keenetic_components": list(DEFAULT_KZSC_COMPONENTS),
    "entware_packages": list(DEFAULT_ENTWARE_PACKAGES),
    "kzsc_release": {
        "repository": KZSC_REPOSITORY,
        "asset_prefix": KZSC_ASSET_PREFIX,
        "channel": "latest",
    },
}


ENGLISH = {
    "Dil": "Language",
    "KZSC Keenetic Hazırlayıcı": "KZSC Keenetic Preparer",
    "SSH 22 ile cihazı hazırlar; OPKG/Entware işlemlerini SSH 222 üzerinde tamamlar.":
        "Prepares the device over SSH 22 and completes OPKG/Entware tasks over SSH 222.",
    "1  Bağlantı ve analiz": "1  Connection and analysis",
    "2  Kurulum seçenekleri": "2  Setup options",
    "3  Plan ve kurulum": "3  Plan and installation",
    "Günlük": "Log",
    "Yerel ağ taraması başlatılıyor…": "Starting local network scan…",
    "Cihazı bul": "Find device",
    "Bulunan cihazlar": "Discovered devices",
    "Ağı yeniden tara": "Scan network again",
    "Tarama yalnızca yerel /24 ağda yapılır. Sonuç yoksa aşağıya IP veya alan adı yazın.":
        "Scanning is limited to the local /24 network. Enter an IP address or host name below if no result is found.",
    "IP / alan adı": "IP / host name",
    "Kullanıcı": "User",
    "Yönetici parolası": "Administrator password",
    "Parola diske kaydedilmez.": "The password is never saved to disk.",
    "Parola": "Password",
    "Yeni Entware kurulumunda varsayılan genellikle root / keenetic'tir; mevcut kurulumda kendi parolanızı girin.":
        "A new Entware installation normally uses root / keenetic; enter your own password for an existing installation.",
    "Bağlan ve cihazı analiz et": "Connect and analyze device",
    "Kayıtlı SSH anahtarını unut": "Forget saved SSH key",
    "Henüz analiz yapılmadı.": "The device has not been analyzed yet.",
    "Şifreli DNS": "Encrypted DNS",
    "Protokol": "Protocol",
    "Sağlayıcı": "Provider",
    "Özel": "Custom",
    "DoT IP'leri": "DoT IP addresses",
    "DoH URL'leri": "DoH URLs",
    "İSS DNS'lerini yoksay": "Ignore ISP DNS",
    "Şifreli DNS eklendikten sonra IPv4 İSS DNS'ini yoksay":
        "Ignore IPv4 DNS supplied by the ISP after encrypted DNS is configured",
    "IPv6 İSS DNS'ini de yoksay": "Also ignore IPv6 DNS supplied by the ISP",
    "Keenetic WAN arayüzü": "Keenetic WAN interface",
    "Hepsi": "All",
    "İSS DNS'ini yoksaymak için en az bir WAN bağlantısı seçin.":
        "Select at least one WAN connection to ignore ISP DNS.",
    "PPTP/L2TP sunucusu alan adı kullanıyorsa İSS DNS'ini kapatmak bağlantıyı kesebilir.":
        "Ignoring ISP DNS may break a PPTP/L2TP connection when its server is specified by host name.",
    "Birden fazla internet bağlantısında tek tek veya Hepsi seçilebilir.":
        "For multiple Internet connections, select one connection or All.",
    "OPKG / Entware depolaması": "OPKG / Entware storage",
    "Önce cihaz analizi yapın": "Analyze the device first",
    "Hedef": "Target",
    "USB yalnızca bağlı ve EXT2/3/4 olarak bağlı bölümlerde gösterilir. Uygulama disk biçimlendirmez.":
        "Only mounted EXT2/3/4 USB partitions are shown. The application never formats a disk.",
    "KZSC son sürüm kurulumu": "Latest KZSC release",
    "Taban hazır olunca yalnızca bana ait KZSC'nin son sürümünü otomatik kur":
        "Automatically install the latest release of my KZSC after the base is ready",
    "KZSC taban OPKG paketleri": "KZSC base OPKG packages",
    "Gelişmiş ayarlar": "Advanced settings",
    "Eksik Keenetic bileşenleri ve OPKG paketleri otomatik belirlenip kurulacaktır.":
        "Missing Keenetic components and OPKG packages will be detected and installed automatically.",
    "Kurulum planını oluştur": "Create installation plan",
    "Planı uygula": "Apply plan",
    "Günlüğü kaydet": "Save log",
    "Keenetic yönetici parolasını girin.": "Enter the Keenetic administrator password.",
    "SSH anahtarı ve cihaz bilgileri denetleniyor…": "Checking the SSH key and device information…",
    "Keenetic bileşen kataloğu alınıyor…": "Retrieving the Keenetic component catalogue…",
    "Analiz tamamlandı. Kurulum seçeneklerini gözden geçirin.":
        "Analysis completed. Review the installation options.",
    "Önce cihaz analizini çalıştırın.": "Analyze the device first.",
    "Geçerli bir OPKG depolama hedefi seçin.": "Select a valid OPKG storage target.",
    "Plan hazır. Uygulamadan önce özeti okuyun.": "The plan is ready. Review the summary before applying it.",
    "Kurulum başladı…": "Installation started…",
    "DoT/DoH ayarları uygulanıyor…": "Applying DoT/DoH settings…",
    "Entware seçilen depolamaya kuruluyor…": "Installing Entware on the selected storage…",
    "SSH 222 üzerinde OPKG tabanı tamamlanıyor…": "Completing the OPKG base over SSH 222…",
    "Kurulum ve doğrulama başarıyla tamamlandı.": "Installation and verification completed successfully.",
    "Kayıt silindi.": "Saved key removed.",
    "Bu cihaz için kayıtlı anahtar yok.": "No saved key exists for this device.",
    "İşlem sürerken dil değiştirilemez.": "The language cannot be changed while an operation is running.",
    "Yerel ağda Keenetic aranıyor…": "Searching the local network for Keenetic devices…",
    "Yerel /24 ağ taraması başlatıldı.": "Local /24 network scan started.",
    "Otomatik keşif sonuç vermedi; IP adresini elle girebilirsiniz.":
        "Automatic discovery found no device; you can enter the IP address manually.",
    "Otomatik keşifte SSH 22 açık bir Keenetic adayı bulunamadı.":
        "Automatic discovery found no Keenetic candidate with SSH 22 open.",
    "SSH kimlik doğrulaması başarısız": "SSH authentication failed",
    "22 portu için kullanıcı adı/parolayı kontrol edin.": "Check the user name and password for port 22.",
    "SSH anahtarı değişmiş": "SSH host key changed",
    "Cihaz analizi başarısız": "Device analysis failed",
    "Yeni SSH sunucu anahtarı": "New SSH host key",
    "SSH anahtarı onaylanmadı.": "The SSH host key was not approved.",
    "Dahili depolama komutla doğrulanamadı; kurulum cihaz tarafından reddedilebilir.":
        "Internal storage could not be verified by command; the device may reject installation.",
    "Dahili NAND alanı sınırlıdır; KZSC paketleri için yeterli boş alan bulunduğunu doğrulayın.":
        "Internal NAND space is limited; verify that enough free space exists for KZSC packages.",
    "Tünel sunucusu alan adıyla tanımlıysa İSS DNS'ini kapatmak bağlantıyı kesebilir.":
        "Ignoring ISP DNS may break the connection if the tunnel server is specified by host name.",
    "Cihaz bileşen kataloğunda bulunmayan öğeler otomatik kurulamayacak.":
        "Items absent from the device component catalogue cannot be installed automatically.",
    "Çevrimiçi bileşen kataloğu alınamadı; kurulu bileşenler cihazın yerel sürüm bilgisinden okundu. Eksik bileşenler Keenetic önizleme adımında yeniden doğrulanacak.":
        "The online component catalogue was unavailable; installed components were read from local device version data. Missing components will be verified again during Keenetic preview.",
    "Plan uygulanamaz: cihaz kataloğunda zorunlu bileşenler bulunamadı.":
        "The plan cannot be applied because required components are absent from the device catalogue.",
    "22 ve 222 portları için gerekli parolaları girin.": "Enter the required passwords for ports 22 and 222.",
    "Yapılandırılmış Entware ve SSH 222 etkinleştiriliyor…": "Activating configured Entware and SSH 222…",
}


PROTOCOL_VALUES = {
    "dot": "dot",
    "DoT": "dot",
    "doh": "doh",
    "DoH": "doh",
    "both": "both",
    "Both": "both",
    "Her ikisi de": "both",
}


def resource_path(name: str) -> Path:
    base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    return base / name


def load_profile() -> dict:
    candidates = []
    if getattr(sys, "frozen", False):
        candidates.append(Path(sys.executable).resolve().parent / "kzsc-profile.json")
    candidates.extend((Path.cwd() / "kzsc-profile.json", resource_path("profile.json")))
    for path in candidates:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            release = data.get("kzsc_release", {})
            if not isinstance(release, dict):
                raise ValueError("kzsc_release nesne olmalıdır")
            repository = str(release.get("repository", ""))
            asset_prefix = str(release.get("asset_prefix", ""))
            channel = str(release.get("channel", ""))
            if (repository, asset_prefix, channel) != (KZSC_REPOSITORY, KZSC_ASSET_PREFIX, "latest"):
                raise ValueError("Yalnızca sabit, sahip kontrollü KZSC GitHub kaynağı kabul edilir")
            return {
                "profile_name": str(data.get("profile_name", "KZSC")),
                "profile_version": int(data.get("profile_version", 1)),
                "keenetic_components": list(
                    validate_packages(data.get("keenetic_components", DEFAULT_KZSC_COMPONENTS))
                ),
                "entware_packages": list(
                    validate_packages(data.get("entware_packages", DEFAULT_ENTWARE_PACKAGES))
                ),
                "kzsc_release": {
                    "repository": repository,
                    "asset_prefix": asset_prefix,
                    "channel": channel,
                },
            }
        except (OSError, ValueError, TypeError, json.JSONDecodeError):
            continue
    return json.loads(json.dumps(DEFAULT_PROFILE))


class KzscApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title(f"{APP_NAME} {APP_VERSION}")
        self.root.geometry("1040x790")
        self.root.minsize(900, 680)
        self.profile = load_profile()
        self.info: DeviceInfo | None = None
        self.plan: SetupPlan | None = None
        self.plan_blocked = False
        self.discovered: dict[str, str] = {}
        self.discovered_hosts = []
        self.storage_targets: dict[str, tuple[str, str]] = {}
        self.wan_targets: dict[str, tuple[str, ...]] = {"ISP": ("ISP",)}
        self.run_config: dict[str, object] = {}
        self.busy = False
        self.language_code = self._load_language()
        self.pending_key: tuple[str, paramiko.PKey] | None = None
        self._ui_queue: queue.Queue[tuple] = queue.Queue()
        self._configure_style()
        self._build_ui()
        self.root.after(100, self._drain_ui_queue)
        self.root.after(350, self.start_discovery)

    def _configure_style(self) -> None:
        style = ttk.Style(self.root)
        try:
            style.theme_use("vista")
        except tk.TclError:
            pass
        style.configure("Title.TLabel", font=("Segoe UI Semibold", 18), foreground="#123B57")
        style.configure("Sub.TLabel", font=("Segoe UI", 10), foreground="#4D6575")
        style.configure("Card.TLabelframe", padding=12)
        style.configure("Card.TLabelframe.Label", font=("Segoe UI Semibold", 10))
        style.configure("Accent.TButton", font=("Segoe UI Semibold", 10), padding=(14, 7))
        style.configure("Status.TLabel", font=("Segoe UI Semibold", 10), foreground="#145A32")

    def _t(self, text: str) -> str:
        return ENGLISH.get(text, text) if self.language_code == "en" else text

    def _protocol_labels(self) -> tuple[str, str, str]:
        return ("DoT", "DoH", "Both") if self.language_code == "en" else ("DoT", "DoH", "Her ikisi de")

    def _protocol_label(self, value: str) -> str:
        protocol = PROTOCOL_VALUES.get(value, value.lower())
        return {"dot": "DoT", "doh": "DoH", "both": self._protocol_labels()[2]}.get(protocol, value)

    @staticmethod
    def _protocol_value(label: str) -> str:
        return PROTOCOL_VALUES.get(label, label.lower())

    @staticmethod
    def _load_language() -> str:
        try:
            data = json.loads((app_data_dir() / "settings.json").read_text(encoding="utf-8"))
            return "en" if data.get("language") == "en" else "tr"
        except (OSError, ValueError, TypeError, json.JSONDecodeError):
            return "tr"

    def _save_language(self) -> None:
        try:
            (app_data_dir() / "settings.json").write_text(
                json.dumps({"language": self.language_code}, ensure_ascii=False, indent=2), encoding="utf-8"
            )
        except OSError:
            pass

    def _language_changed(self, _event=None) -> None:
        requested = "en" if self.language_var.get() == "English" else "tr"
        if requested == self.language_code:
            return
        if self.busy:
            self.language_var.set("English" if self.language_code == "en" else "Türkçe")
            messagebox.showwarning(APP_NAME, self._t("İşlem sürerken dil değiştirilemez."))
            return

        values = {}
        for name in (
            "host_var", "user22_var", "pass22_var", "user222_var", "pass222_var", "protocol_var",
            "provider_var", "dot_ips_var", "dot_sni_var", "doh_urls_var", "ignore_isp_var",
            "ignore_ipv6_var", "wan_var", "install_kzsc_var", "advanced_var",
        ):
            variable = getattr(self, name, None)
            if variable is not None:
                values[name] = variable.get()
        old_storage = self.storage_targets.get(self.storage_var.get()) if hasattr(self, "storage_var") else None
        old_wans = self.wan_targets.get(self.wan_var.get()) if hasattr(self, "wan_var") else None
        packages = self.packages_text.get("1.0", "end").strip() if hasattr(self, "packages_text") else ""
        log = self.log_text.get("1.0", "end").rstrip() if hasattr(self, "log_text") else ""
        tab_index = self.notebook.index(self.notebook.select()) if hasattr(self, "notebook") else 0

        self.language_code = requested
        self._save_language()
        for child in self.root.winfo_children():
            child.destroy()
        self._build_ui()

        if self.discovered_hosts:
            self._render_discovery(self.discovered_hosts)
            selected = next((label for label, host in self.discovered.items() if host == values.get("host_var")), "")
            self.discovery_var.set(selected)
        if self.info:
            self._analysis_done(self.info)
        for name, value in values.items():
            variable = getattr(self, name, None)
            if variable is not None:
                if name == "provider_var" and value in {"Özel", "Custom"}:
                    value = self._t("Özel")
                elif name == "protocol_var":
                    value = self._protocol_label(value)
                elif name == "wan_var":
                    continue
                variable.set(value)
        if old_wans:
            selected_wan = next((label for label, targets in self.wan_targets.items() if targets == old_wans), "")
            if selected_wan:
                self.wan_var.set(selected_wan)
        if old_storage:
            selected_storage = next((label for label, target in self.storage_targets.items() if target == old_storage), "")
            if selected_storage:
                self.storage_var.set(selected_storage)
        self.packages_text.delete("1.0", "end")
        self.packages_text.insert("1.0", packages or " ".join(self.profile["entware_packages"]))
        if log:
            self.log_text.configure(state="normal")
            self.log_text.insert("1.0", log + "\n")
            self.log_text.configure(state="disabled")
        self._toggle_advanced()
        if self.plan:
            self.make_plan()
        self.notebook.select(min(tab_index, self.notebook.index("end") - 1))
        self.status_var.set("Language changed." if self.language_code == "en" else "Dil değiştirildi.")
        self._set_busy(False)

    def _toggle_advanced(self) -> None:
        if not hasattr(self, "advanced_var"):
            return
        if self.advanced_var.get():
            self.dns_advanced.grid()
            self.packages_frame.pack(fill="both", expand=True, pady=(10, 0))
        else:
            self.dns_advanced.grid_remove()
            self.packages_frame.pack_forget()

    def _build_ui(self) -> None:
        self.root.title(f"{'KZSC Preparer' if self.language_code == 'en' else APP_NAME} {APP_VERSION}")
        header = ttk.Frame(self.root, padding=(20, 16, 20, 8))
        header.pack(fill="x")
        header.columnconfigure(0, weight=1)
        title_box = ttk.Frame(header)
        title_box.grid(row=0, column=0, rowspan=2, sticky="ew")
        ttk.Label(title_box, text=self._t("KZSC Keenetic Hazırlayıcı"), style="Title.TLabel").pack(anchor="w")
        ttk.Label(
            title_box,
            text=self._t("SSH 22 ile cihazı hazırlar; OPKG/Entware işlemlerini SSH 222 üzerinde tamamlar."),
            style="Sub.TLabel",
        ).pack(anchor="w", pady=(3, 0))
        ttk.Label(header, text=self._t("Dil")).grid(row=0, column=1, sticky="e", padx=(14, 8))
        self.language_var = tk.StringVar(value="English" if self.language_code == "en" else "Türkçe")
        self.language_combo = ttk.Combobox(
            header, textvariable=self.language_var, values=("Türkçe", "English"), state="readonly", width=11
        )
        self.language_combo.grid(row=0, column=2, sticky="e")
        self.language_combo.bind("<<ComboboxSelected>>", self._language_changed)

        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True, padx=16, pady=(4, 10))
        self.connection_tab = ttk.Frame(self.notebook, padding=16)
        self.options_tab = ttk.Frame(self.notebook, padding=16)
        self.plan_tab = ttk.Frame(self.notebook, padding=16)
        self.log_tab = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(self.connection_tab, text=self._t("1  Bağlantı ve analiz"))
        self.notebook.add(self.options_tab, text=self._t("2  Kurulum seçenekleri"))
        self.notebook.add(self.plan_tab, text=self._t("3  Plan ve kurulum"))
        self.notebook.add(self.log_tab, text=self._t("Günlük"))
        self._build_connection_tab()
        self._build_options_tab()
        self._build_plan_tab()
        self._build_log_tab()

        footer = ttk.Frame(self.root, padding=(18, 0, 18, 12))
        footer.pack(fill="x")
        self.status_var = tk.StringVar(value=self._t("Yerel ağ taraması başlatılıyor…"))
        ttk.Label(footer, textvariable=self.status_var, style="Status.TLabel").pack(side="left")
        self.progress = ttk.Progressbar(footer, mode="indeterminate", length=180)
        self.progress.pack(side="right")

    def _build_connection_tab(self) -> None:
        discover = ttk.LabelFrame(self.connection_tab, text=self._t("Cihazı bul"), style="Card.TLabelframe")
        discover.pack(fill="x")
        discover.columnconfigure(1, weight=1)
        ttk.Label(discover, text=self._t("Bulunan cihazlar")).grid(row=0, column=0, sticky="w", padx=(0, 10))
        self.discovery_var = tk.StringVar()
        self.discovery_combo = ttk.Combobox(discover, textvariable=self.discovery_var, state="readonly")
        self.discovery_combo.grid(row=0, column=1, sticky="ew")
        self.discovery_combo.bind("<<ComboboxSelected>>", self._on_discovered_selected)
        ttk.Button(discover, text=self._t("Ağı yeniden tara"), command=self.start_discovery).grid(row=0, column=2, padx=(10, 0))
        ttk.Label(
            discover,
            text=self._t("Tarama yalnızca yerel /24 ağda yapılır. Sonuç yoksa aşağıya IP veya alan adı yazın."),
            style="Sub.TLabel",
        ).grid(row=1, column=1, sticky="w", pady=(7, 0))

        credentials = ttk.LabelFrame(self.connection_tab, text="KeeneticOS SSH (22)", style="Card.TLabelframe")
        credentials.pack(fill="x", pady=(14, 0))
        for col in (1, 3):
            credentials.columnconfigure(col, weight=1)
        self.host_var = tk.StringVar(value="192.168.1.1")
        self.user22_var = tk.StringVar(value="admin")
        self.pass22_var = tk.StringVar()
        ttk.Label(credentials, text=self._t("IP / alan adı")).grid(row=0, column=0, sticky="w")
        ttk.Entry(credentials, textvariable=self.host_var).grid(row=0, column=1, sticky="ew", padx=(8, 18))
        ttk.Label(credentials, text=self._t("Kullanıcı")).grid(row=0, column=2, sticky="w")
        ttk.Entry(credentials, textvariable=self.user22_var, width=16).grid(row=0, column=3, sticky="ew", padx=(8, 0))
        ttk.Label(credentials, text=self._t("Yönetici parolası")).grid(row=1, column=0, sticky="w", pady=(10, 0))
        ttk.Entry(credentials, textvariable=self.pass22_var, show="●").grid(
            row=1, column=1, sticky="ew", padx=(8, 18), pady=(10, 0)
        )
        ttk.Label(credentials, text=self._t("Parola diske kaydedilmez."), style="Sub.TLabel").grid(
            row=1, column=2, columnspan=2, sticky="w", pady=(10, 0)
        )

        entware = ttk.LabelFrame(self.connection_tab, text="Entware / BusyBox SSH (222)", style="Card.TLabelframe")
        entware.pack(fill="x", pady=(14, 0))
        entware.columnconfigure(3, weight=1)
        self.user222_var = tk.StringVar(value="root")
        self.pass222_var = tk.StringVar(value="keenetic")
        ttk.Label(entware, text=self._t("Kullanıcı")).grid(row=0, column=0, sticky="w")
        ttk.Entry(entware, textvariable=self.user222_var, width=18).grid(row=0, column=1, sticky="w", padx=(8, 22))
        ttk.Label(entware, text=self._t("Parola")).grid(row=0, column=2, sticky="w")
        ttk.Entry(entware, textvariable=self.pass222_var, show="●").grid(row=0, column=3, sticky="ew", padx=(8, 0))
        ttk.Label(
            entware,
            text=self._t("Yeni Entware kurulumunda varsayılan genellikle root / keenetic'tir; mevcut kurulumda kendi parolanızı girin."),
            style="Sub.TLabel",
        ).grid(row=1, column=0, columnspan=4, sticky="w", pady=(8, 0))

        actions = ttk.Frame(self.connection_tab)
        actions.pack(fill="x", pady=(16, 0))
        self.analyze_button = ttk.Button(actions, text=self._t("Bağlan ve cihazı analiz et"), style="Accent.TButton", command=self.start_analysis)
        self.analyze_button.pack(side="left")
        ttk.Button(actions, text=self._t("Kayıtlı SSH anahtarını unut"), command=self.forget_key).pack(side="left", padx=(10, 0))

        self.device_summary = tk.StringVar(value=self._t("Henüz analiz yapılmadı."))
        ttk.Label(self.connection_tab, textvariable=self.device_summary, wraplength=920, justify="left").pack(
            fill="x", pady=(18, 0), anchor="w"
        )

    def _build_options_tab(self) -> None:
        notice = ttk.Label(
            self.options_tab,
            text=self._t("Eksik Keenetic bileşenleri ve OPKG paketleri otomatik belirlenip kurulacaktır."),
            style="Status.TLabel",
        )
        notice.pack(fill="x", pady=(0, 8))
        dns = ttk.LabelFrame(self.options_tab, text=self._t("Şifreli DNS"), style="Card.TLabelframe")
        dns.pack(fill="x")
        for col in (1, 3):
            dns.columnconfigure(col, weight=1)
        self.protocol_var = tk.StringVar(value=self._protocol_label("both"))
        self.provider_var = tk.StringVar(value="Cloudflare")
        ttk.Label(dns, text=self._t("Protokol")).grid(row=0, column=0, sticky="w")
        ttk.Combobox(
            dns,
            textvariable=self.protocol_var,
            values=self._protocol_labels(),
            state="readonly",
            width=18,
        ).grid(row=0, column=1, sticky="ew", padx=(8, 18))
        ttk.Label(dns, text=self._t("Sağlayıcı")).grid(row=0, column=2, sticky="w")
        provider = ttk.Combobox(
            dns,
            textvariable=self.provider_var,
            values=tuple(DNS_PRESETS) + (self._t("Özel"),),
            state="readonly",
        )
        provider.grid(row=0, column=3, sticky="ew", padx=(8, 0))
        provider.bind("<<ComboboxSelected>>", lambda _event: self._provider_changed())
        self.dot_ips_var = tk.StringVar()
        self.dot_sni_var = tk.StringVar()
        self.doh_urls_var = tk.StringVar()
        self.dns_advanced = ttk.Frame(dns)
        self.dns_advanced.grid(row=1, column=0, columnspan=4, sticky="ew", pady=(10, 0))
        for col in (1, 3):
            self.dns_advanced.columnconfigure(col, weight=1)
        ttk.Label(self.dns_advanced, text=self._t("DoT IP'leri")).grid(row=0, column=0, sticky="w")
        ttk.Entry(self.dns_advanced, textvariable=self.dot_ips_var).grid(row=0, column=1, sticky="ew", padx=(8, 18))
        ttk.Label(self.dns_advanced, text="DoT SNI").grid(row=0, column=2, sticky="w")
        ttk.Entry(self.dns_advanced, textvariable=self.dot_sni_var).grid(row=0, column=3, sticky="ew", padx=(8, 0))
        ttk.Label(self.dns_advanced, text=self._t("DoH URL'leri")).grid(row=1, column=0, sticky="w", pady=(10, 0))
        ttk.Entry(self.dns_advanced, textvariable=self.doh_urls_var).grid(
            row=1, column=1, columnspan=3, sticky="ew", padx=(8, 0), pady=(10, 0)
        )
        self._provider_changed()

        isp = ttk.LabelFrame(self.options_tab, text=self._t("İSS DNS'lerini yoksay"), style="Card.TLabelframe")
        isp.pack(fill="x", pady=(12, 0))
        isp.columnconfigure(3, weight=1)
        self.ignore_isp_var = tk.BooleanVar(value=True)
        self.ignore_ipv6_var = tk.BooleanVar(value=True)
        self.wan_var = tk.StringVar(value="ISP")
        ttk.Checkbutton(isp, text=self._t("Şifreli DNS eklendikten sonra IPv4 İSS DNS'ini yoksay"), variable=self.ignore_isp_var).grid(
            row=0, column=0, columnspan=2, sticky="w"
        )
        ttk.Checkbutton(isp, text=self._t("IPv6 İSS DNS'ini de yoksay"), variable=self.ignore_ipv6_var).grid(
            row=0, column=2, columnspan=2, sticky="w", padx=(18, 0)
        )
        ttk.Label(isp, text=self._t("Keenetic WAN arayüzü")).grid(row=1, column=0, sticky="w", pady=(10, 0))
        self.wan_combo = ttk.Combobox(isp, textvariable=self.wan_var, values=("ISP",), state="readonly")
        self.wan_combo.grid(row=1, column=1, sticky="ew", padx=(8, 18), pady=(10, 0))
        ttk.Label(
            isp,
            text=self._t("Birden fazla internet bağlantısında tek tek veya Hepsi seçilebilir."),
            style="Sub.TLabel",
        ).grid(row=1, column=2, columnspan=2, sticky="w", pady=(10, 0))

        # Secure DNS is owned by KZSC.  Keep the variables for backwards
        # compatible plans, but do not expose or mutate DNS from the preparer.
        dns.pack_forget()
        isp.pack_forget()
        ttk.Label(
            self.options_tab,
            text=self._t("DNS ayarları hazırlayıcı tarafından değiştirilmez; kurulumdan sonra KZSC DNS sekmesinden yönetilir."),
            style="Sub.TLabel",
        ).pack(fill="x", pady=(4, 0))

        storage = ttk.LabelFrame(self.options_tab, text=self._t("OPKG / Entware depolaması"), style="Card.TLabelframe")
        storage.pack(fill="x", pady=(12, 0))
        storage.columnconfigure(1, weight=1)
        self.storage_var = tk.StringVar(value=self._t("Önce cihaz analizi yapın"))
        ttk.Label(storage, text=self._t("Hedef")).grid(row=0, column=0, sticky="w")
        self.storage_combo = ttk.Combobox(storage, textvariable=self.storage_var, state="readonly")
        self.storage_combo.grid(row=0, column=1, sticky="ew", padx=(8, 0))
        ttk.Label(
            storage,
            text=self._t("USB yalnızca bağlı ve EXT2/3/4 olarak bağlı bölümlerde gösterilir. Uygulama disk biçimlendirmez."),
            style="Sub.TLabel",
        ).grid(row=1, column=1, sticky="w", pady=(7, 0))

        product = ttk.LabelFrame(self.options_tab, text=self._t("KZSC son sürüm kurulumu"), style="Card.TLabelframe")
        product.pack(fill="x", pady=(12, 0))
        for col in (1, 3):
            product.columnconfigure(col, weight=1)
        release = self.profile["kzsc_release"]
        self.install_kzsc_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(
            product,
            text=self._t("Taban hazır olunca yalnızca bana ait KZSC'nin son sürümünü otomatik kur"),
            variable=self.install_kzsc_var,
        ).grid(row=0, column=0, columnspan=4, sticky="w")
        ttk.Label(
            product,
            text=(
                f"Trusted GitHub source: {release['repository']} · channel: latest · "
                "SHA256 + safe archive + internal manifest verification"
                if self.language_code == "en"
                else f"Güvenilir GitHub kaynağı: {release['repository']} · kanal: latest · "
                "SHA256 + güvenli arşiv + iç manifest doğrulaması"
            ),
            style="Sub.TLabel",
        ).grid(row=1, column=0, columnspan=4, sticky="w", pady=(6, 0))

        self.advanced_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(
            self.options_tab,
            text=self._t("Gelişmiş ayarlar"),
            variable=self.advanced_var,
            command=self._toggle_advanced,
        ).pack(anchor="w", pady=(10, 0))
        self.packages_frame = ttk.LabelFrame(
            self.options_tab, text=self._t("KZSC taban OPKG paketleri"), style="Card.TLabelframe"
        )
        self.packages_text = tk.Text(self.packages_frame, height=3, wrap="word", font=("Consolas", 9))
        self.packages_text.pack(fill="both", expand=True)
        self.packages_text.insert("1.0", " ".join(self.profile["entware_packages"]))
        self._toggle_advanced()

    def _build_plan_tab(self) -> None:
        action = ttk.Frame(self.plan_tab)
        action.pack(fill="x")
        self.plan_button = ttk.Button(action, text=self._t("Kurulum planını oluştur"), style="Accent.TButton", command=self.make_plan)
        self.plan_button.pack(side="left")
        self.run_button = ttk.Button(action, text=self._t("Planı uygula"), style="Accent.TButton", command=self.start_setup, state="disabled")
        self.run_button.pack(side="right")
        self.plan_text = scrolledtext.ScrolledText(self.plan_tab, wrap="word", font=("Consolas", 9), state="disabled")
        self.plan_text.pack(fill="both", expand=True, pady=(14, 0))

    def _build_log_tab(self) -> None:
        top = ttk.Frame(self.log_tab)
        top.pack(fill="x", pady=(0, 8))
        ttk.Button(top, text=self._t("Günlüğü kaydet"), command=self.save_log).pack(side="right")
        self.log_text = scrolledtext.ScrolledText(
            self.log_tab, wrap="word", font=("Consolas", 9), background="#101820", foreground="#E8F1F5", insertbackground="white"
        )
        self.log_text.pack(fill="both", expand=True)
        self.log_text.configure(state="disabled")

    def _post(self, action: str, *args) -> None:
        self._ui_queue.put((action, *args))

    def _drain_ui_queue(self) -> None:
        try:
            while True:
                action, *args = self._ui_queue.get_nowait()
                if action == "log":
                    self._append_log(args[0])
                elif action == "status":
                    self.status_var.set(self._t(args[0]))
                elif action == "busy":
                    self._set_busy(args[0])
                elif action == "discovery_done":
                    self._discovery_done(args[0])
                elif action == "analysis_done":
                    self._analysis_done(args[0])
                elif action == "unknown_key":
                    self._confirm_unknown_key(args[0], args[1])
                elif action == "error":
                    self._show_error(args[0], args[1])
                elif action == "setup_done":
                    self._setup_done(args[0])
        except queue.Empty:
            pass
        self.root.after(100, self._drain_ui_queue)

    def _set_busy(self, value: bool) -> None:
        self.busy = value
        if value:
            self.progress.start(12)
        else:
            self.progress.stop()
        self.analyze_button.configure(state="disabled" if value else "normal")
        self.plan_button.configure(state="disabled" if value else "normal")
        if value:
            self.run_button.configure(state="disabled")
        elif self.plan and not self.plan_blocked:
            self.run_button.configure(state="normal")

    def start_discovery(self) -> None:
        if self.busy:
            return
        self._set_busy(True)
        self.status_var.set(self._t("Yerel ağda Keenetic aranıyor…"))
        self._append_log(self._t("Yerel /24 ağ taraması başlatıldı."))
        threading.Thread(target=self._discovery_worker, daemon=True).start()

    def _discovery_worker(self) -> None:
        try:
            hosts = discover_keenetic()
            self._post("discovery_done", hosts)
        except Exception as exc:
            self._post("error", "Ağ taraması tamamlanamadı", str(exc))
        finally:
            self._post("busy", False)

    def _discovery_done(self, hosts) -> None:
        # A gateway can also be returned by the /24 probe. Keep one row per
        # IP; discovery labels must never make one physical router look like
        # two devices.
        unique = {}
        for item in hosts:
            key = item.host.strip()
            previous = unique.get(key)
            if previous is None or (item.label == "Varsayılan ağ geçidi" and previous.label != item.label):
                unique[key] = item
        hosts = list(unique.values())
        self.discovered_hosts = hosts
        self._render_discovery(hosts)
        if hosts:
            self.discovery_var.set(next(iter(self.discovered)))
            self.host_var.set(hosts[0].host)
            if self.language_code == "en":
                self.status_var.set(f"{len(hosts)} Keenetic candidate(s) found.")
                self._append_log("Discovered candidates: " + ", ".join(item.host for item in hosts))
            else:
                self.status_var.set(f"{len(hosts)} Keenetic adayı bulundu.")
                self._append_log("Bulunan adaylar: " + ", ".join(item.host for item in hosts))
        else:
            self.discovery_var.set("")
            self.status_var.set(self._t("Otomatik keşif sonuç vermedi; IP adresini elle girebilirsiniz."))
            self._append_log(self._t("Otomatik keşifte SSH 22 açık bir Keenetic adayı bulunamadı."))

    def _render_discovery(self, hosts) -> None:
        discovered = {}
        by_host = {}
        for item in hosts:
            key = item.host.strip()
            previous = by_host.get(key)
            if previous is not None and previous.label == "Varsayılan ağ geçidi":
                continue
            by_host[key] = item
        for item in by_host.values():
            host = item.host.strip()
            flags = []
            if item.ssh22:
                flags.append("SSH 22")
            if item.web_hint:
                flags.append("Keenetic web")
            if self.language_code == "en":
                label = {
                    "Varsayılan ağ geçidi": "Default gateway",
                    "Yerel ağdaki olası Keenetic": "Possible Keenetic on the local network",
                }.get(item.label, item.label)
                discovered[f"{host} — {label} ({', '.join(flags) or 'candidate'})"] = host
            else:
                discovered[f"{host} — {item.label} ({', '.join(flags) or 'aday'})"] = host
        self.discovered = discovered
        self.discovery_combo.configure(values=tuple(discovered))

    def _on_discovered_selected(self, _event=None) -> None:
        host = self.discovered.get(self.discovery_var.get())
        if host:
            self.host_var.set(host)

    def start_analysis(self, trusted: bool = False) -> None:
        if self.busy:
            return
        if not self.pass22_var.get():
            messagebox.showwarning(APP_NAME, self._t("Keenetic yönetici parolasını girin."))
            return
        try:
            validate_hostname(self.host_var.get())
        except ValueError as exc:
            messagebox.showerror(APP_NAME, str(exc))
            return
        self.info = None
        self.plan = None
        self.plan_blocked = False
        self.run_button.configure(state="disabled")
        self._set_busy(True)
        self.status_var.set(self._t("SSH anahtarı ve cihaz bilgileri denetleniyor…"))
        connection = (
            self.host_var.get().strip(),
            self.user22_var.get().strip(),
            self.pass22_var.get(),
        )
        threading.Thread(target=self._analysis_worker, args=(trusted, *connection), daemon=True).start()

    def _analysis_worker(self, trusted: bool, host: str, username: str, password: str) -> None:
        cli = None
        try:
            key = probe_host_key(host, 22)
            if not trusted:
                try:
                    verify_host_key(host, key, 22)
                except UnknownHostKey:
                    self._post("unknown_key", host, key)
                    return
            self._post("log", f"SSH 22 anahtarı doğrulandı: {key.get_name()}")
            cli = KeeneticCli(host, username, password, 22)
            version_raw = cli.command("show version", timeout=25)
            if has_cli_error(version_raw):
                raise RuntimeError("Keenetic 'show version' komutunu kabul etmedi; yönetici CLI yetkisini kontrol edin.")
            version = parse_version(version_raw)
            self._post("log", f"Cihaz: {version.get('model', 'bilinmiyor')} · {version.get('release', '?')} · {version.get('arch', '?')}")
            installed_components = parse_installed_components(version_raw)
            self._post("status", "Keenetic bileşen kataloğu alınıyor…")
            components_raw = cli.command("components list", timeout=120, idle=1.5)
            components = parse_components(components_raw)
            component_catalog_complete = bool(components)
            if component_catalog_complete:
                # The local list is authoritative for installed state even if
                # an online catalogue entry omits that flag on an OS variant.
                components.update(installed_components)
            elif installed_components:
                components = installed_components
                excerpt = " ".join(components_raw.split())[:500] or "yanıt yok"
                self._post(
                    "log",
                    "UYARI: Çevrimiçi bileşen kataloğu alınamadı; show version içindeki yerel kurulu "
                    f"bileşen listesi kullanılıyor. CLI yanıtı: {excerpt}",
                )
            else:
                excerpt = " ".join(components_raw.split())[:500] or "yanıt yok"
                raise RuntimeError(
                    "Bileşen kataloğu ve yerel kurulu bileşen listesi okunamadı. "
                    "Cihazın İnternet bağlantısını/CLI yetkisini kontrol edin. CLI yanıtı: " + excerpt
                )
            media_raw = cli.command("show media", timeout=25)
            interfaces_raw = cli.command("show interface", timeout=35)
            running_raw = cli.command("show running-config", timeout=35)
            live_wans = parse_interface_choices(interfaces_raw)
            configured_wans = parse_configured_wan_choices(running_raw)
            interface_choices = merge_wan_choices(live_wans, configured_wans)
            self._post(
                "log",
                summarize_wan_sources(interfaces_raw, running_raw)
                + "\nALGILANAN WANLAR\n"
                + ("\n".join(f"{label} => {interface_id}" for label, interface_id in interface_choices.items()) or "(yok)"),
            )
            internal_raw = cli.command("ls storage:/", timeout=15)
            system_raw = cli.command("show system", timeout=15)
            info = DeviceInfo(
                host=host,
                model=version.get("model") or version.get("device") or "Bilinmiyor",
                hw_id=version.get("hw_id", ""),
                release=version.get("release", ""),
                arch=version.get("arch", ""),
                hostname=re.search(r"^\s*hostname:\s*(.+)$", system_raw, re.M).group(1).strip()
                if re.search(r"^\s*hostname:\s*(.+)$", system_raw, re.M)
                else "",
                components=components,
                component_catalog_complete=component_catalog_complete,
                partitions=parse_media(media_raw),
                interfaces=list(interface_choices.values()),
                interface_choices=interface_choices,
                internal_storage=not has_cli_error(internal_raw),
                entware_ready=is_port_open(host, 222, 1.0),
                opkg_disk=parse_opkg_disk(running_raw),
            )
            self._post("analysis_done", info)
        except (paramiko.AuthenticationException, paramiko.BadAuthenticationType):
            self._post("error", "SSH kimlik doğrulaması başarısız", "22 portu için kullanıcı adı/parolayı kontrol edin.")
        except HostKeyMismatch as exc:
            self._post("error", "SSH anahtarı değişmiş", str(exc) + "\n\nCihazı sıfırladıysanız kayıtlı anahtarı unutun ve yeniden bağlanın.")
        except Exception as exc:
            self._post("error", "Cihaz analizi başarısız", str(exc))
        finally:
            if cli:
                cli.close()
            self._post("busy", False)

    def _confirm_unknown_key(self, host: str, key: paramiko.PKey) -> None:
        from transport import fingerprint_sha256

        fingerprint = fingerprint_sha256(key)
        accepted = messagebox.askyesno(
            "Yeni SSH sunucu anahtarı",
            f"{host} ilk kez görülüyor. Cihaz ekranı/etiketiyle doğrulayabiliyorsanız anahtarı kaydedin.\n\n"
            f"Tür: {key.get_name()}\nParmak izi: {fingerprint}\n\nBu anahtara güvenilsin mi?",
        )
        self._set_busy(False)
        if accepted:
            trust_host_key(host, key, 22)
            self._append_log(f"SSH 22 anahtarı kullanıcı onayıyla kaydedildi: {fingerprint}")
            self.root.after(50, lambda: self.start_analysis(trusted=True))
        else:
            self.status_var.set("SSH anahtarı onaylanmadı.")

    def _analysis_done(self, info: DeviceInfo) -> None:
        self.info = info
        installed = sum(1 for item in info.components.values() if item.is_installed)
        usb = [item for item in info.partitions if item.usable_for_entware]
        if self.language_code == "en":
            catalogue = "online catalogue" if info.component_catalog_complete else "local installed list"
            self.device_summary.set(
                f"Connected: {info.model} {info.hw_id} · KeeneticOS {info.release} · {info.arch} · "
                f"{installed} installed components ({catalogue}) · Entware 222: "
                f"{'ready' if info.entware_ready else 'not ready'}"
            )
        else:
            catalogue = "çevrimiçi katalog" if info.component_catalog_complete else "yerel kurulu liste"
            self.device_summary.set(
                f"Bağlandı: {info.model} {info.hw_id} · KeeneticOS {info.release} · {info.arch} · "
                f"{installed} kurulu bileşen ({catalogue}) · Entware 222: "
                f"{'hazır' if info.entware_ready else 'hazır değil'}"
            )
        if info.interfaces:
            choices = info.interface_choices or {name: name for name in info.interfaces}
            self.wan_targets = build_wan_selection_targets(choices, self._t("Hepsi"))
            self.wan_combo.configure(values=tuple(self.wan_targets))
            # Multi-WAN installations normally need the same DNS policy on
            # every Internet connection.  Default to the explicit all-WAN
            # option so an incidental physical port is never chosen silently.
            all_wan_label = self._t("Hepsi")
            self.wan_var.set(all_wan_label if all_wan_label in self.wan_targets else next(iter(self.wan_targets)))
        self.storage_targets = {}
        if info.entware_ready:
            label = "Existing Entware /opt (will not be reinstalled)" if self.language_code == "en" else "Mevcut Entware /opt (yeniden kurulmayacak)"
            self.storage_targets[label] = ("existing", "existing:/")
        elif info.opkg_disk:
            label = (
                f"Configured Entware · {info.opkg_disk} (SSH 222 will be activated)"
                if self.language_code == "en"
                else f"Yapılandırılmış Entware · {info.opkg_disk} (SSH 222 etkinleştirilecek)"
            )
            self.storage_targets[label] = ("configured", info.opkg_disk)
        if info.internal_storage:
            label = "Internal device storage · storage:/" if self.language_code == "en" else "Dahili cihaz hafızası · storage:/"
            self.storage_targets[label] = ("internal", "storage:/")
        for item in usb:
            if self.language_code == "en":
                name = item.label or item.uuid or "Unnamed partition"
                free = str(item.free) if item.free else "unknown"
                label = f"USB · {name} · {item.fstype.upper()} · free {free} bytes"
            else:
                label = item.display
            self.storage_targets[label] = ("usb", item.target)
        self.storage_combo.configure(values=tuple(self.storage_targets))
        if self.storage_targets:
            preferred = next(
                (x for x, value in self.storage_targets.items() if value[0] in {"existing", "configured"}), None
            )
            self.storage_var.set(preferred or next(iter(self.storage_targets)))
        else:
            self.storage_var.set(
                "No suitable EXT USB partition or internal storage was found"
                if self.language_code == "en"
                else "Uygun EXT USB veya dahili storage bulunamadı"
            )
        self.status_var.set(self._t("Analiz tamamlandı. Kurulum seçeneklerini gözden geçirin."))
        self.notebook.select(self.options_tab)

    def _provider_changed(self) -> None:
        name = self.provider_var.get()
        preset = DNS_PRESETS.get(name)
        if preset:
            self.dot_ips_var.set(", ".join(item[0] for item in preset.dot))
            self.dot_sni_var.set(preset.dot[0][1] if preset.dot else "")
            self.doh_urls_var.set(", ".join(preset.doh))
        elif hasattr(self, "advanced_var"):
            self.advanced_var.set(True)
            self._toggle_advanced()

    def _collect_options(self) -> SetupOptions:
        if not self.info:
            raise ValueError("Önce cihaz analizini çalıştırın.")
        storage = self.storage_targets.get(self.storage_var.get())
        if not storage:
            raise ValueError("Geçerli bir OPKG depolama hedefi seçin.")
        kind, target = storage
        provider = self.provider_var.get()
        if provider in DNS_PRESETS:
            preset = DNS_PRESETS[provider]
            dot_entries, doh_entries = preset.dot, preset.doh
        else:
            dot_entries = parse_custom_dot(self.dot_ips_var.get(), self.dot_sni_var.get())
            doh_entries = parse_custom_doh(self.doh_urls_var.get())
        packages = validate_packages(self.packages_text.get("1.0", "end").split())
        wan_interfaces = self.wan_targets.get(self.wan_var.get(), ())
        if self.ignore_isp_var.get() and not wan_interfaces:
            raise ValueError(self._t("İSS DNS'ini yoksaymak için en az bir WAN bağlantısı seçin."))
        return SetupOptions(
            protocol=self._protocol_value(self.protocol_var.get()),
            preset=provider,
            dot_entries=dot_entries,
            doh_entries=doh_entries,
            ignore_isp_dns=self.ignore_isp_var.get(),
            ignore_ipv6_dns=self.ignore_ipv6_var.get(),
            wan_interfaces=tuple(validate_interface(item) for item in wan_interfaces),
            storage_target=target,
            storage_kind=kind,
            keenetic_components=tuple(self.profile["keenetic_components"]),
            entware_packages=packages,
        )

    def make_plan(self) -> None:
        try:
            options = self._collect_options()
            plan = build_plan(self.info, options)
            kzsc_source = self._kzsc_source() if self.install_kzsc_var.get() else None
            self.plan = plan
            self.plan_blocked = bool(plan.unavailable_components)
            if self.language_code == "en":
                lines = [
                    f"TARGET DEVICE\n  {self.info.model} {self.info.hw_id} · {self.info.release} · {self.info.arch}",
                    f"\nKEENETICOS COMPONENTS\n  To install automatically: {', '.join(plan.components_to_install) or 'none'}",
                ]
                if plan.unavailable_components:
                    lines.append(f"  Not in device catalogue: {', '.join(plan.unavailable_components)}")
                lines.append("\nSECURE DNS\n  Managed after installation from the KZSC DNS tab; the preparer does not change DNS.")
                if self.info.entware_ready:
                    lines.append("\nENTWARE\n  Already available on port 222; storage will not be reinstalled.")
                elif self.info.opkg_disk and not plan.storage_command:
                    lines.append(f"\nENTWARE\n  Existing {self.info.opkg_disk} will be activated and port 222 verified.")
                else:
                    lines.append(f"\nENTWARE\n  {plan.storage_command}")
                lines.append("\nOPKG PACKAGES\n  " + " ".join(plan.packages))
                if kzsc_source:
                    lines.append(
                        "\nLATEST KZSC RELEASE\n"
                        f"  Repository: https://github.com/{kzsc_source['repository']}\n"
                        f"  Channel: {kzsc_source['channel']} (resolved through the GitHub API when applied)\n"
                        "  Verification: exact asset URL + external SHA256 + safe archive + internal SHA256SUMS\n"
                        "  Final checks: kzsc status · kzsc preflight · kzsc audit full"
                    )
                else:
                    lines.append("\nLATEST KZSC RELEASE\n  Disabled by the user; only the complete base will be prepared.")
                if plan.warnings:
                    lines.append("\nWARNINGS\n  - " + "\n  - ".join(self._t(item) for item in plan.warnings))
                lines.append(
                    "\nSAFETY\n  Passwords are not saved. Existing Entware is not deleted. Disks are not formatted. "
                    "A KeeneticOS component change may restart the device."
                )
            else:
                lines = [
                    f"HEDEF CİHAZ\n  {self.info.model} {self.info.hw_id} · {self.info.release} · {self.info.arch}",
                    f"\nKEENETICOS BİLEŞENLERİ\n  Otomatik kurulacak: {', '.join(plan.components_to_install) or 'yok'}",
                ]
                if plan.unavailable_components:
                    lines.append(f"  Cihaz kataloğunda yok: {', '.join(plan.unavailable_components)}")
                lines.append("\nGÜVENLİ DNS\n  DNS ayarları kurulumdan sonra KZSC DNS sekmesinden yönetilir; hazırlayıcı DNS'i değiştirmez.")
                if self.info.entware_ready:
                    lines.append("\nENTWARE\n  222 portunda mevcut; depolama yeniden kurulmayacak.")
                elif self.info.opkg_disk and not plan.storage_command:
                    lines.append(f"\nENTWARE\n  Mevcut {self.info.opkg_disk} etkinleştirilip 222 portu doğrulanacak.")
                else:
                    lines.append(f"\nENTWARE\n  {plan.storage_command}")
                lines.append("\nOPKG PAKETLERİ\n  " + " ".join(plan.packages))
                if kzsc_source:
                    lines.append(
                        "\nKZSC SON SÜRÜM\n"
                        f"  Depo: https://github.com/{kzsc_source['repository']}\n"
                        f"  Kanal: {kzsc_source['channel']} (uygulama anında GitHub API ile çözümlenir)\n"
                        "  Doğrulama: exact asset URL + dış SHA256 + güvenli arşiv + iç SHA256SUMS\n"
                        "  Son test: kzsc status · kzsc preflight · kzsc audit full"
                    )
                else:
                    lines.append("\nKZSC SON SÜRÜM\n  Kullanıcı tarafından kapatıldı; yalnızca eksiksiz taban hazırlanacak.")
                if plan.warnings:
                    lines.append("\nUYARILAR\n  - " + "\n  - ".join(plan.warnings))
                lines.append(
                    "\nGÜVENLİK\n  Parolalar kaydedilmez. Mevcut Entware silinmez. Disk biçimlendirilmez. "
                    "KeeneticOS bileşen değişikliği cihazı yeniden başlatabilir."
                )
            self._set_text(self.plan_text, "\n".join(lines))
            self.run_button.configure(state="disabled" if self.plan_blocked else "normal")
            self.notebook.select(self.plan_tab)
            if self.plan_blocked:
                self.status_var.set(self._t("Plan uygulanamaz: cihaz kataloğunda zorunlu bileşenler bulunamadı."))
            else:
                self.status_var.set(self._t("Plan hazır. Uygulamadan önce özeti okuyun."))
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc))

    def _kzsc_source(self) -> dict[str, str]:
        release = self.profile.get("kzsc_release", {})
        source = {
            "repository": str(release.get("repository", "")),
            "asset_prefix": str(release.get("asset_prefix", "")),
            "channel": str(release.get("channel", "")),
        }
        if source != {
            "repository": KZSC_REPOSITORY,
            "asset_prefix": KZSC_ASSET_PREFIX,
            "channel": "latest",
        }:
            raise ValueError("KZSC kaynağı sabit sahip deposuyla eşleşmiyor; kurulum reddedildi.")
        return source

    def start_setup(self) -> None:
        if self.busy or self.plan_blocked or not self.plan or not self.info:
            return
        if not self.pass22_var.get() or not self.pass222_var.get():
            messagebox.showwarning(APP_NAME, self._t("22 ve 222 portları için gerekli parolaları girin."))
            return
        if self.language_code == "en":
            summary = (
                f"The plan will be applied to {self.info.model}.\n\n"
                f"KeeneticOS components to install automatically: {len(self.plan.components_to_install)}\n"
                f"OPKG packages to verify/install: {len(self.plan.packages)}\n"
                f"Automatic KZSC installation: {'yes (GitHub latest)' if self.install_kzsc_var.get() else 'no'}\n\n"
                "The device may restart and Internet access may be interrupted briefly during a component update. Continue?"
            )
        else:
            summary = (
                f"{self.info.model} üzerinde plan uygulanacak.\n\n"
                f"Otomatik kurulacak KeeneticOS bileşeni: {len(self.plan.components_to_install)}\n"
                f"Denetlenecek/kurulacak OPKG paketi: {len(self.plan.packages)}\n"
                f"KZSC otomatik kurulum: {'evet (GitHub latest)' if self.install_kzsc_var.get() else 'hayır'}\n\n"
                "Bileşen güncellemesi sırasında cihaz yeniden başlayabilir ve İnternet kısa süre kesilebilir. Devam edilsin mi?"
            )
        if not messagebox.askyesno(self._t("Planı uygula"), summary):
            return
        try:
            kzsc_source = self._kzsc_source() if self.install_kzsc_var.get() else None
        except ValueError as exc:
            messagebox.showerror(APP_NAME, str(exc))
            return
        self.run_config = {
            "host": self.host_var.get().strip(),
            "user22": self.user22_var.get().strip(),
            "pass22": self.pass22_var.get(),
            "user222": self.user222_var.get().strip(),
            "pass222": self.pass222_var.get(),
            "kzsc_source": kzsc_source,
            "install_kzsc_requested": self.install_kzsc_var.get(),
        }
        self._set_busy(True)
        self.notebook.select(self.log_tab)
        self.status_var.set(self._t("Kurulum başladı…"))
        threading.Thread(target=self._setup_worker, daemon=True).start()

    def _setup_worker(self) -> None:
        assert self.info and self.plan
        host = str(self.run_config["host"])
        cli = None
        shell = None
        report = []
        try:
            kzsc_release = None
            if self.run_config.get("install_kzsc_requested"):
                self._post("status", "GitHub üzerinde yayımlanmış son KZSC sürümü doğrulanıyor…")
                kzsc_release = self._resolve_latest_kzsc_release()
                self._post("log", f"KZSC Release doğrulandı: {kzsc_release.tag} · {kzsc_release.html_url}")
            if self.plan.unavailable_components:
                self._post(
                    "log",
                    "UYARI: Katalogda bulunmayan bileşenler: " + ", ".join(self.plan.unavailable_components),
                )
            if self.plan.components_to_install:
                self._post("status", "Eksik KeeneticOS bileşenleri sıraya alınıyor…")
                cli = self._new_cli()
                for name in self.plan.components_to_install:
                    self._run_cli_checked(cli, f"components install {name}", 35)
                preview = cli.command("components preview", timeout=35)
                self._post("log", "Bileşen önizlemesi:\n" + preview)
                if has_cli_error(preview):
                    raise RuntimeError("KeeneticOS bileşen önizlemesi başarısız: " + preview)
                self._post("status", "KeeneticOS bileşenleri kuruluyor; cihaz yeniden başlayabilir…")
                result = cli.command("components commit", timeout=120, idle=1.5)
                self._post("log", "components commit:\n" + result)
                if has_cli_error(result):
                    raise RuntimeError("KeeneticOS bileşen güncellemesi başlatılamadı: " + result)
                cli.close()
                cli = None
                time.sleep(5)
                wait_for_port(host, 22, 360, True, lambda sec: self._post("status", f"Cihazın yeniden açılması bekleniyor… {sec} sn"))
                # Authentication proves that the CLI really returned.
                cli = self._new_cli(retries=18)
                confirmed_version = cli.command("show version", timeout=35)
                confirmed = parse_installed_components(confirmed_version)
                if not confirmed:
                    confirmed_raw = cli.command("components list", timeout=120, idle=1.5)
                    confirmed = parse_components(confirmed_raw)
                still_missing = [
                    name
                    for name in self.plan.components_to_install
                    if name not in confirmed or not confirmed[name].is_installed
                ]
                if still_missing:
                    raise RuntimeError(
                        "Yeniden başlatma sonrasında zorunlu KeeneticOS bileşenleri doğrulanamadı: "
                        + ", ".join(still_missing)
                    )
                report.append("KeeneticOS bileşenleri tamamlandı")
            else:
                cli = self._new_cli()
                report.append("KeeneticOS bileşenleri zaten hazır")

            report.append("DNS ayarları KZSC'ye bırakıldı; hazırlayıcı mevcut DNS kayıtlarını değiştirmedi")

            entware_ready = is_port_open(host, 222, 1.2)
            if not entware_ready:
                if not self.plan.storage_command:
                    if not self.info.opkg_disk:
                        raise RuntimeError(
                            "Analizde mevcut görünen Entware SSH 222 artık erişilebilir değil ve yapılandırılmış "
                            "OPKG diski bulunamadı. Cihaz analizini yeniden çalıştırın."
                        )
                    self._post("status", "Yapılandırılmış Entware ve SSH 222 etkinleştiriliyor…")
                    self._activate_entware_222(cli, host, self.info.opkg_disk, initial_wait=90)
                    report.append("Yapılandırılmış Entware yeniden etkinleştirildi ve SSH 222 açıldı")
                else:
                    self._post("status", self._t("Entware seçilen depolamaya kuruluyor…"))
                    storage_result = cli.command(self.plan.storage_command, timeout=240, idle=2.0)
                    self._post("log", self.plan.storage_command + "\n" + storage_result)
                    if has_cli_error(storage_result):
                        raise RuntimeError(
                            "Entware çevrimiçi kurulumu cihaz tarafından reddedildi. "
                            "KeeneticOS 4.2+ ve desteklenen depolama gerekir. Ayrıntı: " + storage_result
                        )
                    # "Disk is unchanged" means no installer is running; a
                    # five-minute first wait only lets the SSH 22 CLI expire.
                    # Move to the service recovery path promptly in that case.
                    first_wait = 60 if "disk is unchanged" in storage_result.lower() else 300
                    self._activate_entware_222(
                        cli, host, self.plan.storage_command.split()[2], initial_wait=first_wait
                    )
                    report.append("Entware kuruldu ve SSH 222 açıldı")
            else:
                report.append("Mevcut Entware korundu")
            cli.close()
            cli = None

            self._post("status", "SSH 222 üzerinde OPKG tabanı tamamlanıyor…")
            shell = self._new_entware_shell(retries=12)
            code, out, err = shell.command("PATH=/opt/bin:/opt/sbin:$PATH; opkg --version; uname -m; df -k /opt", 60)
            self._post("log", "Entware doğrulama:\n" + out + err)
            if code != 0:
                raise RuntimeError("222 portunda Entware/opkg doğrulanamadı: " + err)
            code, out, err = shell.command("PATH=/opt/bin:/opt/sbin:$PATH; opkg update", 240)
            self._post("log", "opkg update:\n" + out + err)
            if code != 0:
                raise RuntimeError("OPKG paket listesi güncellenemedi: " + (err or out))
            code, out, err = shell.command("PATH=/opt/bin:/opt/sbin:$PATH; opkg list-installed", 120)
            installed = {line.split(" - ", 1)[0].strip() for line in out.splitlines() if " - " in line}
            missing = [name for name in self.plan.packages if name not in installed]
            if missing:
                command = "PATH=/opt/bin:/opt/sbin:$PATH; opkg install " + " ".join(missing)
                code, out, err = shell.command(command, 600)
                self._post("log", "Eksik OPKG paketleri:\n" + out + err)
                if code != 0:
                    raise RuntimeError("Bazı KZSC taban paketleri kurulamadı: " + (err or out)[-1800:])
            code, out, err = shell.command("PATH=/opt/bin:/opt/sbin:$PATH; opkg list-installed", 120)
            if code != 0:
                raise RuntimeError("Kurulum sonrası OPKG paket listesi doğrulanamadı: " + (err or out)[-1800:])
            installed_after = {line.split(" - ", 1)[0].strip() for line in out.splitlines() if " - " in line}
            missing_after = [name for name in self.plan.packages if name not in installed_after]
            if missing_after:
                raise RuntimeError("Kurulum sonrasında hâlâ eksik OPKG paketleri var: " + ", ".join(missing_after))
            report.append(f"OPKG tabanı hazır ({len(self.plan.packages)} paket denetlendi)")
            # Entware's lighttpd package installs S80lighttpd on port 80. Keep
            # Keenetic's own admin UI on that port; KZSC starts its isolated
            # lighttpd instance on 9090 via S99kzsc after installation.
            code, out, err = shell.command(
                "if [ -x /opt/etc/init.d/S80lighttpd ]; then "
                "/opt/etc/init.d/S80lighttpd stop >/dev/null 2>&1 || true; "
                "mv /opt/etc/init.d/S80lighttpd /opt/etc/init.d/disabled-S80lighttpd 2>/dev/null || true; "
                "if [ -x /opt/etc/init.d/S80lighttpd.disabled ]; then mv /opt/etc/init.d/S80lighttpd.disabled /opt/etc/init.d/disabled-S80lighttpd 2>/dev/null || true; fi; "
                "fi",
                60,
            )
            if code != 0:
                raise RuntimeError("Entware lighttpd çakışması güvenli biçimde kapatılamadı: " + (err or out))
            report.append("Entware lighttpd port 80 çakışması engellendi")

            self._verify_kzsc_base(shell, report)

            if kzsc_release:
                self._install_kzsc(shell, report, kzsc_release)

            code, out, err = shell.command(
                "PATH=/opt/bin:/opt/sbin:$PATH; "
                "printf 'opkg='; opkg --version; "
                "printf 'curl='; curl --version | head -n1; "
                "printf 'space='; df -k /opt | tail -n1",
                90,
            )
            self._post("log", "Son doğrulama:\n" + out + err)
            if code != 0:
                raise RuntimeError("Son taban doğrulaması başarısız oldu.")
            self._write_report(report, True)
            self._post("setup_done", report)
        except (paramiko.AuthenticationException, paramiko.BadAuthenticationType):
            detail = "SSH kimlik doğrulaması başarısız. 22 veya 222 portu parolasını kontrol edin."
            self._write_report(report + [detail], False)
            self._post("error", "Kurulum durduruldu", detail)
        except Exception as exc:
            self._write_report(report + [str(exc)], False)
            self._post("error", "Kurulum güvenli biçimde durduruldu", str(exc))
        finally:
            if cli:
                cli.close()
            if shell:
                shell.close()
            self._post("busy", False)

    def _activate_entware_222(
        self, cli: KeeneticCli, host: str, disk_target: str, initial_wait: int = 120
    ) -> None:
        """Configure Entware autostart and prove that its SSH service listens on 222."""

        self._run_cli_checked(cli, "opkg initrc /opt/etc/init.d/rc.unslung", 35, allow_not_found=True)
        self._run_cli_checked(cli, "opkg timezone auto", 35, allow_not_found=True)
        self._run_cli_checked(cli, "system configuration save", 35)
        if wait_for_port(
            host, 222, initial_wait, True,
            lambda sec: self._post("status", f"Entware SSH 222 bekleniyor… {sec} sn"),
        ):
            return

        # Reasserting the already configured target is non-destructive and asks
        # Keenetic's OPKG manager to mount /opt and execute rc.unslung again.
        self._post("log", "SSH 222 henüz açılmadı; OPKG diski ve başlangıç betiği yeniden etkinleştiriliyor.")
        self._run_cli_checked(cli, f"opkg disk {disk_target}", 120)
        self._run_cli_checked(cli, "opkg initrc /opt/etc/init.d/rc.unslung", 35, allow_not_found=True)
        self._run_cli_checked(cli, "system configuration save", 35)
        if wait_for_port(host, 222, 120, True):
            return

        # ``opkg initrc`` records the boot script but does not start it on every
        # KeeneticOS/Entware combination.  Use Keenetic's restricted exec bridge
        # to start the configured tree.  Keenetic may have closed the SSH 22
        # channel during the waits above; KeeneticCli.command reconnects it.
        self._post("status", "Entware başlangıç servisleri güvenli biçimde yeniden çalıştırılıyor…")
        self._run_cli_recovery(cli, "exec /opt/etc/init.d/rc.unslung restart", 90)
        if wait_for_port(host, 222, 60, True):
            return

        # A partially prepared or older Entware tree may not contain Dropbear.
        # Repair only that package through the already trusted Keenetic exec
        # bridge, then start the service again.  Each step is best-effort so the
        # final SSH port check remains the authoritative result.
        self._post("log", "SSH 222 hâlâ kapalı; Entware Dropbear paketi doğrulanıp servis yeniden başlatılıyor.")
        self._run_cli_recovery(cli, "exec /opt/bin/opkg update", 240)
        self._run_cli_recovery(cli, "exec /opt/bin/opkg install dropbear", 240)
        self._run_cli_recovery(cli, "exec /opt/etc/init.d/S51dropbear restart", 90)
        if not wait_for_port(host, 222, 120, True):
            raise RuntimeError(
                "Entware /opt etkinleştirildi ancak otomatik rc.unslung/Dropbear kurtarmasından sonra SSH 222 "
                "doğrulanamadı. Cihaz günlüğünde 'Entware 5/5', OPKG diski ve S51dropbear durumunu kontrol edin."
            )

    def _new_cli(self, retries: int = 1) -> KeeneticCli:
        last = None
        for attempt in range(retries):
            try:
                return KeeneticCli(
                    str(self.run_config["host"]),
                    str(self.run_config["user22"]),
                    str(self.run_config["pass22"]),
                    22,
                    12,
                )
            except (OSError, EOFError, paramiko.SSHException) as exc:
                last = exc
                if attempt + 1 < retries:
                    time.sleep(5)
        raise RuntimeError(f"Keenetic SSH 22 yeniden bağlanamadı: {last}")

    def _new_entware_shell(self, retries: int = 1) -> EntwareShell:
        last = None
        for attempt in range(retries):
            try:
                return EntwareShell(
                    str(self.run_config["host"]),
                    str(self.run_config["user222"]),
                    str(self.run_config["pass222"]),
                    222,
                    12,
                )
            except (OSError, EOFError, paramiko.SSHException) as exc:
                last = exc
                if attempt + 1 < retries:
                    time.sleep(5)
        raise RuntimeError(f"Entware SSH 222 bağlanamadı: {last}")

    def _run_cli_checked(
        self, cli: KeeneticCli, command: str, timeout: float, allow_not_found: bool = False
    ) -> str:
        output = cli.command(command, timeout=timeout)
        self._post("log", f"> {command}\n{output}")
        if has_cli_error(output):
            if allow_not_found and "not found" in output.lower():
                return output
            raise RuntimeError(f"Keenetic komutu başarısız: {command}\n{output}")
        return output

    def _run_cli_recovery(self, cli: KeeneticCli, command: str, timeout: float) -> bool:
        """Run a bounded Entware recovery command and retain its diagnostics."""
        try:
            output = cli.command(command, timeout=timeout)
        except (OSError, EOFError, paramiko.SSHException) as exc:
            self._post("log", f"> {command}\nBağlantı yenileme/kurtarma adımı başarısız: {exc}")
            return False
        self._post("log", f"> {command}\n{output}")
        return not has_cli_error(output)

    def _resolve_latest_kzsc_release(self) -> KzscRelease:
        request = urllib.request.Request(
            KZSC_RELEASE_API,
            headers={
                "Accept": "application/vnd.github+json",
                "User-Agent": f"KZSC-Hazirlayici/{APP_VERSION}",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=25) as response:
                declared = response.headers.get("Content-Length")
                if declared and int(declared) > 1_048_576:
                    raise RuntimeError("GitHub Release yanıtı güvenlik boyutu sınırını aşıyor.")
                raw = response.read(1_048_577)
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                raise RuntimeError(
                    "KZSC GitHub deposu hazır ancak henüz yayımlanmış kararlı bir Release bulunmuyor. "
                    "Release yayımlandıktan sonra yeniden deneyin."
                ) from exc
            raise RuntimeError(f"GitHub KZSC Release sorgusu başarısız oldu (HTTP {exc.code}).") from exc
        except (OSError, ValueError) as exc:
            raise RuntimeError(f"GitHub KZSC Release bilgisine erişilemedi: {exc}") from exc
        if len(raw) > 1_048_576:
            raise RuntimeError("GitHub Release yanıtı güvenlik boyutu sınırını aşıyor.")
        try:
            payload = json.loads(raw.decode("utf-8"))
            return parse_kzsc_release(payload)
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
            raise RuntimeError(f"GitHub KZSC Release doğrulaması başarısız: {exc}") from exc

    def _verify_kzsc_base(self, shell: EntwareShell, report: list[str]) -> None:
        self._post("status", "KZSC taban araçları, web modülü ve NFQUEUE yetenekleri doğrulanıyor…")
        verify = """set -eu
export PATH=/opt/bin:/opt/sbin:$PATH
[ \"$(id -u)\" = 0 ]
[ -x /opt/bin/sh ]
command -v ndmc >/dev/null
command -v lighttpd >/dev/null
[ -f /opt/lib/lighttpd/mod_cgi.so ] || [ -f /opt/lib/lighttpd/mod_cgi.so.0 ]
for cmd in awk sed grep tr cut head tail sort find xargs tar gzip sha256sum wc ip iptables iptables-save ps date curl; do
  command -v \"$cmd\" >/dev/null
done
iptables -t mangle -S >/dev/null
iptables -t filter -S >/dev/null
iptables -m multiport -h >/dev/null 2>&1
iptables -m connbytes -h >/dev/null 2>&1
iptables -m mark -h >/dev/null 2>&1
nfqh=\"$(iptables -j NFQUEUE -h 2>&1)\"
printf '%s\n' \"$nfqh\" | grep -q -- '--queue-bypass'
free_kb=\"$(df -Pk /opt | awk 'NR==2 {print $4; exit}')\"
case \"$free_kb\" in ''|*[!0-9]*) exit 61;; esac
[ \"$free_kb\" -ge 32768 ]
printf 'lighttpd=%s\nfree_kb=%s\nNFQUEUE=ok\n' \"$(lighttpd -v 2>&1 | head -n1)\" \"$free_kb\"
"""
        code, out, err = shell.command(verify, 180)
        self._post("log", "KZSC taban yetenek doğrulaması:\n" + out + err)
        if code != 0:
            raise RuntimeError(
                "OPKG paketleri kuruldu ancak KZSC için gerekli araç/mod_cgi/iptables/NFQUEUE tabanı doğrulanamadı: "
                + (err or out)[-2200:]
            )
        report.append("KZSC araçları, lighttpd/mod_cgi ve NFQUEUE yetenekleri doğrulandı")

    def _clean_preparer_dns(self, cli: KeeneticCli) -> None:
        """Remove every global DNS record before applying the selected preset."""
        # running-config is authoritative for replay, while show dns-proxy
        # also exposes runtime records that may be omitted from the config.
        outputs = [cli.command("show running-config", timeout=35)]
        try:
            outputs.append(cli.command("show dns-proxy", timeout=35))
        except Exception:
            pass
        seen: set[str] = set()
        for raw in "\n".join(outputs).splitlines():
            line = raw.strip()
            if line.startswith("dns-proxy "):
                line = line[len("dns-proxy "):]
            if line.startswith("tls upstream "):
                parts = line.split()
                if len(parts) >= 3:
                    command = f"no dns-proxy tls upstream {parts[2]}"
                    if command not in seen:
                        cli.command(command, timeout=35); seen.add(command)
                continue
            if line.startswith("https upstream "):
                parts = line.split()
                if len(parts) >= 3:
                    command = f"no dns-proxy https upstream {parts[2]}"
                    if command not in seen:
                        cli.command(command, timeout=35); seen.add(command)
                continue
            if line.startswith("ip name-server ") or line.startswith("ipv6 name-server "):
                if line not in seen:
                    cli.command(f"no {line}", timeout=35); seen.add(line)

    def _install_kzsc(self, shell: EntwareShell, report: list[str], release: KzscRelease) -> None:
        self._post("status", f"KZSC {release.tag} indiriliyor ve çok katmanlı doğrulanıyor…")
        command = f"""set -eu
export PATH=/opt/bin:/opt/sbin:$PATH
umask 077
tmp=/opt/tmp/kzsc-install.$$
cleanup() {{ rm -rf \"$tmp\"; }}
trap cleanup EXIT
trap 'cleanup; exit 130' HUP INT TERM
mkdir -p /opt/tmp \"$tmp\"
archive_name='{release.archive_name}'
checksum_name='{release.checksum_name}'
root='{release.root_name}'
archive=\"$tmp/$archive_name\"
checksum=\"$tmp/$checksum_name\"
list=\"$tmp/archive.list\"
curl -fL --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 2 --connect-timeout 20 --max-time 300 --max-filesize {KZSC_MAX_ARCHIVE_BYTES} '{release.archive_url}' -o \"$archive\"
curl -fL --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 2 --connect-timeout 20 --max-time 120 --max-filesize {KZSC_MAX_CHECKSUM_BYTES} '{release.checksum_url}' -o \"$checksum\"
bytes=\"$(wc -c <\"$archive\" 2>/dev/null | tr -d ' ')\"
case \"$bytes\" in ''|*[!0-9]*) exit 41;; esac
[ \"$bytes\" -gt 0 ] && [ \"$bytes\" -le {KZSC_MAX_ARCHIVE_BYTES} ]
matches=\"$(awk -v n=\"$archive_name\" '$2==n || $2==\"*\"n {{c++}} END{{print c+0}}' \"$checksum\")\"
[ \"$matches\" = 1 ]
expected=\"$(awk -v n=\"$archive_name\" '$2==n || $2==\"*\"n {{print tolower($1); exit}}' \"$checksum\")\"
printf '%s\n' \"$expected\" | grep -Eq '^[0-9a-f]{{64}}$'
actual=\"$(sha256sum \"$archive\" | awk '{{print tolower($1)}}')\"
[ \"$actual\" = \"$expected\" ]
tar -tzf \"$archive\" >\"$list\"
awk -v r=\"$root/\" '
  NF==0 {{bad=1}}
  $0!=r && index($0,r)!=1 {{bad=1}}
  /^[/]/ {{bad=1}}
  {{n=split($0,a,\"/\"); for(i=1;i<=n;i++) if(a[i]==\"..\" || a[i]==\".\") bad=1; count++}}
  END{{exit bad || count>500}}
' \"$list\"
tar -tvzf \"$archive\" | awk 'substr($1,1,1)==\"l\" || substr($1,1,1)==\"h\" {{bad=1}} END{{exit bad}}'
tar -xzf \"$archive\" -C \"$tmp\"
[ -f \"$tmp/$root/install.sh\" ] && [ -f \"$tmp/$root/SHA256SUMS\" ]
(cd \"$tmp/$root\" && sha256sum -c SHA256SUMS)
(cd \"$tmp/$root\" && /opt/bin/sh install.sh)
printf 'KZSC_RELEASE=%s\nKZSC_SHA256=%s\n' '{release.tag}' \"$actual\"
"""
        # Exit 75 means the installer staged KeeneticOS components and will
        # resume after the router reboot; it is not a failed download.
        command = command.replace(
            '(cd "$tmp/$root" && /opt/bin/sh install.sh)\n',
            'install_rc=0\n(cd "$tmp/$root" && /opt/bin/sh install.sh) || install_rc=$?\n'
            'if [ "$install_rc" -ne 0 ] && [ "$install_rc" -ne 75 ]; then exit "$install_rc"; fi\n'
            'if [ "$install_rc" -eq 75 ]; then printf "KZSC_REBOOT_PENDING=1\\n"; exit 0; fi\n',
        )
        code, out, err = shell.command(command, 1500)
        self._post("log", "KZSC indirme, doğrulama ve kurulum:\n" + out + err)
        if code != 0:
            raise RuntimeError(
                "KZSC arşivi indirilemedi, güvenlik doğrulamasını geçemedi veya kurulum başarısız oldu: "
                + (err or out)[-2500:]
            )

        if "KZSC_REBOOT_PENDING=1" in out:
            try:
                reboot_code, reboot_out, reboot_err = shell.command(
                    "ndmc -c 'system reboot 5'", 60
                )
                self._post("log", "Otomatik router yeniden başlatma:\n" + reboot_out + reboot_err)
            except Exception as exc:
                self._post("log", f"Otomatik router yeniden başlatma bağlantısı kesildi: {exc}")
            report.append(
                f"KZSC {release.tag} bileşen kurulumu başlattı; router yeniden başlatıldıktan sonra kurulum otomatik tamamlanacak"
            )
            return

        verify = (
            "set -e; export PATH=/opt/bin:/opt/sbin:$PATH; "
            "/opt/bin/kzsc status; /opt/bin/kzsc preflight; /opt/bin/kzsc audit full"
        )
        code, out, err = shell.command(verify, 900)
        self._post("log", "KZSC son doğrulama (status/preflight/audit full):\n" + out + err)
        if code != 0:
            raise RuntimeError(
                f"KZSC {release.tag} kuruldu ancak status/preflight/audit doğrulaması başarısız: "
                + (err or out)[-2500:]
            )
        report.append(
            f"KZSC {release.tag} güvenilir GitHub Release'den SHA256 ve iç manifest doğrulamasıyla kuruldu"
        )
        report.append("KZSC status, preflight ve tam audit başarıyla tamamlandı")

    def _setup_done(self, report: list[str]) -> None:
        host = self.host_var.get().strip()
        if self.language_code == "en":
            report.extend((
                f"Keenetic admin panel: http://{host}/ (HTTPS may also be enabled)",
                f"KZSC panel: http://{host}:9090/",
            ))
        else:
            report.extend((
                f"Keenetic yönetim paneli: http://{host}/ (HTTPS etkinse https://{host}/)",
                f"KZSC paneli: http://{host}:9090/",
            ))
        self.status_var.set("Kurulum ve doğrulama başarıyla tamamlandı.")
        self._append_log("BAŞARILI:\n- " + "\n- ".join(report))
        messagebox.showinfo(APP_NAME, "Kurulum tamamlandı.\n\n" + "\n".join("✓ " + item for item in report))

    def _show_error(self, title: str, detail: str) -> None:
        self.status_var.set(title)
        self._append_log(f"HATA — {title}: {detail}")
        messagebox.showerror(title, detail)

    def forget_key(self) -> None:
        try:
            host = validate_hostname(self.host_var.get())
            removed22 = forget_host_key(host, 22)
            removed222 = forget_host_key(host, 222)
            messagebox.showinfo(APP_NAME, "Kayıt silindi." if removed22 or removed222 else "Bu cihaz için kayıtlı anahtar yok.")
        except Exception as exc:
            messagebox.showerror(APP_NAME, str(exc))

    def _append_log(self, text: str) -> None:
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.log_text.configure(state="normal")
        self.log_text.insert("end", f"[{timestamp}] {text.rstrip()}\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    def save_log(self) -> None:
        directory = app_data_dir() / "logs"
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / f"kzsc-{datetime.now():%Y%m%d-%H%M%S}.log"
        path.write_text(self.log_text.get("1.0", "end"), encoding="utf-8")
        messagebox.showinfo(APP_NAME, f"Günlük kaydedildi:\n{path}")

    def _write_report(self, entries: list[str], success: bool) -> None:
        directory = app_data_dir() / "reports"
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / f"report-{datetime.now():%Y%m%d-%H%M%S}.txt"
        content = [
            f"{APP_NAME} {APP_VERSION}",
            f"Zaman: {datetime.now().isoformat(timespec='seconds')}",
            f"Cihaz: {self.info.model if self.info else '?'} ({self.info.host if self.info else '?'})",
            f"Sonuç: {'BAŞARILI' if success else 'BAŞARISIZ'}",
            "",
            *[f"- {item}" for item in entries],
        ]
        try:
            path.write_text("\n".join(content), encoding="utf-8")
            self._post("log", f"Rapor: {path}")
        except OSError:
            pass

    @staticmethod
    def _set_text(widget: tk.Text, value: str) -> None:
        widget.configure(state="normal")
        widget.delete("1.0", "end")
        widget.insert("1.0", value)
        widget.configure(state="disabled")


def main() -> None:
    root = tk.Tk()
    try:
        root.iconname(APP_NAME)
    except tk.TclError:
        pass
    KzscApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
