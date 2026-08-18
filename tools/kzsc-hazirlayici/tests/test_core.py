from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock


PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT))

from core import (  # noqa: E402
    Component,
    DEFAULT_ENTWARE_PACKAGES,
    DEFAULT_KZSC_COMPONENTS,
    DeviceInfo,
    KZSC_MAX_ARCHIVE_BYTES,
    SetupOptions,
    build_dns_commands,
    build_plan,
    build_wan_selection_targets,
    decode_keenetic_cli_escapes,
    entware_url_for_arch,
    parse_components,
    parse_configured_wan_choices,
    parse_installed_components,
    parse_interface_choices,
    parse_kzsc_release,
    parse_media,
    merge_wan_choices,
    parse_opkg_disk,
    parse_version,
    summarize_wan_sources,
)
from transport import KeeneticCli, _ends_with_cli_prompt, _is_private_ipv4  # noqa: E402


def options(**changes) -> SetupOptions:
    values = {
        "protocol": "both",
        "preset": "Cloudflare",
        "dot_entries": (("1.1.1.1", "cloudflare-dns.com"),),
        "doh_entries": ("https://cloudflare-dns.com/dns-query",),
        "ignore_isp_dns": True,
        "ignore_ipv6_dns": True,
        "wan_interfaces": ("ISP",),
        "storage_target": "storage:/",
        "storage_kind": "internal",
        "keenetic_components": ("opkg", "opkg-kmod-netfilter"),
        "entware_packages": ("curl", "ca-certificates"),
    }
    values.update(changes)
    return SetupOptions(**values)


class ParsingTests(unittest.TestCase):
    def test_private_ipv4_detection_used_by_network_discovery(self) -> None:
        self.assertTrue(_is_private_ipv4("192.168.1.1"))
        self.assertFalse(_is_private_ipv4("8.8.8.8"))

    def test_components(self) -> None:
        raw = """
component:
  name: opkg
  version: 1.0
  installed: yes
component:
  name: dns-tls
  installed: no
"""
        parsed = parse_components(raw)
        self.assertTrue(parsed["opkg"].is_installed)
        self.assertFalse(parsed["dns-tls"].is_installed)

    def test_installed_components_from_show_version(self) -> None:
        raw = '''
        "ndw": {
          "components": "base,dns-https,dns-tls,opkg,opkg-kmod-netfilter"
        }
        '''
        parsed = parse_installed_components(raw)
        self.assertEqual(
            set(parsed), {"base", "dns-https", "dns-tls", "opkg", "opkg-kmod-netfilter"}
        )
        self.assertTrue(all(item.is_installed for item in parsed.values()))

    def test_json_style_show_version(self) -> None:
        parsed = parse_version('  "release": "5.01.C.3.0-1",\n  "arch": "aarch64",\n  "model": "Titan (KN-1812)",')
        self.assertEqual(parsed["arch"], "aarch64")
        self.assertEqual(parsed["model"], "Titan (KN-1812)")

    def test_cli_completion_requires_final_prompt(self) -> None:
        self.assertFalse(_ends_with_cli_prompt("(config)> components list\nfirmware:\n"))
        self.assertTrue(_ends_with_cli_prompt("component:\n name: opkg\n(config)> "))

    def test_cli_reconnects_after_idle_channel_is_closed(self) -> None:
        cli = KeeneticCli.__new__(KeeneticCli)
        cli.channel = MagicMock(closed=True)
        cli.client = MagicMock()
        replacement_channel = MagicMock(closed=False)
        replacement_transport = MagicMock()
        replacement_transport.is_active.return_value = True
        replacement_client = MagicMock()
        replacement_client.get_transport.return_value = replacement_transport

        def reconnect() -> None:
            cli.channel = replacement_channel
            cli.client = replacement_client

        cli._connect = MagicMock(side_effect=reconnect)
        cli._read_until_prompt = MagicMock(return_value="show version\r\nrelease: test\r\n(config)> ")

        output = cli.command("show version")

        cli._connect.assert_called_once_with()
        replacement_channel.send.assert_called_once_with("show version\n")
        self.assertIn("release: test", output)

    def test_cli_reconnects_once_when_send_detects_closed_socket(self) -> None:
        cli = KeeneticCli.__new__(KeeneticCli)
        active_transport = MagicMock()
        active_transport.is_active.return_value = True
        cli.client = MagicMock()
        cli.client.get_transport.return_value = active_transport
        cli.channel = MagicMock(closed=False)
        cli.channel.send.side_effect = OSError("Socket is closed")
        replacement_channel = MagicMock(closed=False)
        replacement_client = MagicMock()
        replacement_client.get_transport.return_value = active_transport

        def reconnect() -> None:
            cli.channel = replacement_channel
            cli.client = replacement_client

        cli._connect = MagicMock(side_effect=reconnect)
        cli._read_until_prompt = MagicMock(return_value="show system\r\nok\r\n(config)> ")

        cli.command("show system")

        cli._connect.assert_called_once_with()
        replacement_channel.send.assert_called_once_with("show system\n")

    def test_opkg_disk_from_running_config(self) -> None:
        self.assertEqual(parse_opkg_disk("interface Home\nopkg disk storage:/\nsystem timezone GMT+3"), "storage:/")
        self.assertEqual(parse_opkg_disk("opkg disk ABCD-1234:/"), "ABCD-1234:/")

    def test_wan_displays_real_connection_names(self) -> None:
        raw = """
interface:
  id: PPPoE0
  name: PPPoE0
  description: TurkNet Fiber
interface:
  id: PPPoE1
  name: PPPoE1
  description: Yedek Hat
interface:
  id: Home
  description: Ev Ağı
"""
        self.assertEqual(
            parse_interface_choices(raw),
            {"TurkNet Fiber": "PPPoE0", "Yedek Hat": "PPPoE1"},
        )

    def test_real_show_interface_blocks_use_internet_role_and_provider_names(self) -> None:
        raw = r'''
Interface, name = "GigabitEthernet0":
 type: GigabitEthernet
 role: none
 security-level: public
 global: yes
Interface, name = "GigabitEthernet1":
 type: GigabitEthernet
 role: inet
 description: VODAFONE F\xc4\xb0BER
 security-level: public
Interface, name = "PPPoE0":
 type: PPPoE
 role: inet
 description: T\xc3\x9cRK TELEKOM F\xc4\xb0BER
 security-level: public
'''
        self.assertEqual(
            parse_interface_choices(raw),
            {
                "VODAFONE FİBER": "GigabitEthernet1",
                "TÜRK TELEKOM FİBER": "PPPoE0",
            },
        )

    def test_bang_ends_running_config_interface_record(self) -> None:
        running = r'''
interface PPPoE1
 description "VODAFONE F\xc4\xb0BER"
 security-level public
 ipcp
!
ip hotspot host aa:bb:cc:dd:ee:ff
 description "S\xc3\x9cPERBOX 5G"
 security-level private
!
'''
        self.assertEqual(
            parse_configured_wan_choices(running),
            {"VODAFONE FİBER": "PPPoE1"},
        )

    def test_keenetic_utf8_hex_escapes_are_decoded_in_wan_names(self) -> None:
        show = r"""
interface:
  id: PPPoE0
  description: T\xc3\x9cRK TELEKOM F\xc4\xb0BER
  security-level: public
interface:
  id: PPPoE1
  description: S\xc3\x9cPERBOX 5G
  security-level: public
"""
        running = r'''
interface PPPoE0
 description "T\xc3\x9cRK TELEKOM F\xc4\xb0BER"
 security-level public
 ipcp
 exit
interface PPPoE1
 description "S\xc3\x9cPERBOX 5G"
 security-level public
 ipcp
 exit
'''
        expected = {"TÜRK TELEKOM FİBER": "PPPoE0", "SÜPERBOX 5G": "PPPoE1"}
        self.assertEqual(parse_interface_choices(show), expected)
        self.assertEqual(parse_configured_wan_choices(running), expected)

    def test_provider_name_replaces_generic_broadband_connection(self) -> None:
        live = {"VODAFONE FİBER": "GigabitEthernet1", "TÜRK TELEKOM FİBER": "PPPoE0"}
        configured = {"Broadband connection": "GigabitEthernet1", "TÜRK TELEKOM FİBER": "PPPoE0"}
        self.assertEqual(
            merge_wan_choices(live, configured),
            {"VODAFONE FİBER": "GigabitEthernet1", "TÜRK TELEKOM FİBER": "PPPoE0"},
        )
        self.assertEqual(
            merge_wan_choices(configured, live),
            {"VODAFONE FİBER": "GigabitEthernet1", "TÜRK TELEKOM FİBER": "PPPoE0"},
        )

    def test_live_physical_parent_is_not_added_when_pppoe_is_configured(self) -> None:
        live = {
            "GigabitEthernet0": "GigabitEthernet0",
            "GigabitEthernet1": "GigabitEthernet1",
            "TÜRK TELEKOM FİBER": "PPPoE0",
            "SOL FİBER": "PPPoE1",
        }
        configured = {"TÜRK TELEKOM FİBER": "PPPoE0", "SOL FİBER": "PPPoE1"}
        self.assertEqual(
            merge_wan_choices(live, configured),
            {"TÜRK TELEKOM FİBER": "PPPoE0", "SOL FİBER": "PPPoE1"},
        )

    def test_duplicate_live_interface_keeps_descriptive_provider_name(self) -> None:
        raw = r"""
interface:
  id: GigabitEthernet1
  description: Broadband connection
  security-level: public
interface:
  id: GigabitEthernet1
  description: VODAFONE F\xc4\xb0BER
  security-level: public
"""
        self.assertEqual(parse_interface_choices(raw), {"VODAFONE FİBER": "GigabitEthernet1"})

    def test_provider_field_beats_generic_description_in_same_live_record(self) -> None:
        raw = r"""
interface:
  id: GigabitEthernet1
  description: Broadband connection
  provider: VODAFONE F\xc4\xb0BER
  security-level: public
"""
        self.assertEqual(parse_interface_choices(raw), {"VODAFONE FİBER": "GigabitEthernet1"})

    def test_cli_escape_decoder_does_not_create_ascii_controls(self) -> None:
        self.assertEqual(decode_keenetic_cli_escapes(r"hat\x0aname"), r"hat\x0aname")
        self.assertEqual(decode_keenetic_cli_escapes(r"quote\x22test"), r"quote\x22test")
        self.assertEqual(decode_keenetic_cli_escapes(r"broken\xc3"), r"broken\xc3")

    def test_all_wan_choice_is_localized_and_last(self) -> None:
        choices = {"TurkNet Fiber": "PPPoE0", "Yedek Hat": "PPPoE1"}
        self.assertEqual(
            build_wan_selection_targets(choices, "Hepsi"),
            {
                "TurkNet Fiber": ("PPPoE0",),
                "Yedek Hat": ("PPPoE1",),
                "Hepsi": ("PPPoE0", "PPPoE1"),
            },
        )
        self.assertEqual(list(build_wan_selection_targets(choices, "All"))[-1], "All")

    def test_public_wan_types_are_not_limited_to_pppoe(self) -> None:
        raw = """
interface:
  id: Ethernet2
  description: Kablolu Yedek
  security-level: public
interface, id = UsbLte0:
  description: Mobil Hat
  global: yes
interface:
  id: Home
  description: Ev Ağı
  security-level: private
"""
        self.assertEqual(
            parse_interface_choices(raw),
            {"Kablolu Yedek": "Ethernet2", "Mobil Hat": "UsbLte0"},
        )

    def test_configured_inactive_wan_is_merged_with_real_name(self) -> None:
        running = '''
interface PPPoE0
 description "Ana Fiber"
 ipcp
 exit
interface UsbLte0
 description "Yedek Mobil"
 mobile no name-servers
 exit
interface Home
 description "Ev Ağı"
 security-level private
 exit
'''
        configured = parse_configured_wan_choices(running)
        self.assertEqual(configured, {"Ana Fiber": "PPPoE0", "Yedek Mobil": "UsbLte0"})
        self.assertEqual(
            merge_wan_choices({"PPPoE0": "PPPoE0"}, configured),
            {"Ana Fiber": "PPPoE0", "Yedek Mobil": "UsbLte0"},
        )

    def test_only_provider_profiles_exclude_physical_lan_and_vpn(self) -> None:
        running = '''
interface GigabitEthernet0
 security-level public
 ip dhcp client name-servers
 exit
interface XGigabitEthernet0
 description "Fiber taşıyıcı"
 security-level public
 ip address 10.0.0.2 255.255.255.0
 exit
interface Bridge0
 description "Ev ağı"
 security-level private
 exit
interface PPPoE0
 description "Birinci sağlayıcı"
 security-level public
 connect via GigabitEthernet0
 exit
interface PPPoE1
 description "İkinci sağlayıcı"
 security-level public
 connect via XGigabitEthernet0
 exit
interface Wireguard0
 description "Uzak VPN"
 security-level public
 exit
'''
        self.assertEqual(
            parse_configured_wan_choices(running),
            {"Birinci sağlayıcı": "PPPoE0", "İkinci sağlayıcı": "PPPoE1"},
        )

    def test_direct_ipoe_provider_is_kept(self) -> None:
        running = '''
interface GigabitEthernet1
 description "Doğrudan IPoE"
 security-level public
 ip dhcp client name-servers
 exit
'''
        self.assertEqual(
            parse_configured_wan_choices(running),
            {"Doğrudan IPoE": "GigabitEthernet1"},
        )

    def test_layered_parent_is_excluded_when_connect_via_uses_rename(self) -> None:
        running = '''
interface GigabitEthernet1
 description "Ethernet ISS"
 security-level public
 rename ISP1
 ip dhcp client name-servers
 exit
interface PPPoE0
 description "Gerçek internet bağlantısı"
 security-level public
 connect via ISP1
 exit
'''
        self.assertEqual(
            parse_configured_wan_choices(running),
            {"Gerçek internet bağlantısı": "PPPoE0"},
        )

    def test_wan_diagnostic_excludes_credentials(self) -> None:
        diagnostic = summarize_wan_sources(
            "interface:\n id: PPPoE0\n description: Superonline Fiber\n username: secret-user\n",
            "interface PPPoE0\n description Superonline Fiber\n password secret-pass\n authentication pap\n",
        )
        self.assertIn("Superonline Fiber", diagnostic)
        self.assertNotIn("secret-user", diagnostic)
        self.assertNotIn("secret-pass", diagnostic)
        self.assertNotIn("password", diagnostic.lower())

    def test_ext_media(self) -> None:
        raw = """
media:
  name: Disk
partition:
  uuid: ABC-123
  label: OPKG
  fstype: ext4
  state: MOUNTED
  free: 1048576
"""
        items = parse_media(raw)
        self.assertEqual(items[0].target, "ABC-123:/")
        self.assertTrue(items[0].usable_for_entware)


class PlanTests(unittest.TestCase):
    def test_dns_is_disabled_only_after_encrypted_upstreams(self) -> None:
        commands = build_dns_commands(options())
        disable_index = commands.index("ip dhcp client no name-servers")
        self.assertLess(commands.index("dns-proxy tls upstream 1.1.1.1 853 sni cloudflare-dns.com"), disable_index)
        self.assertLess(commands.index("dns-proxy https upstream https://cloudflare-dns.com/dns-query dnsm"), disable_index)
        self.assertEqual(commands[-1], "system configuration save")

    def test_ppp_uses_ipcp(self) -> None:
        commands = build_dns_commands(options(wan_interfaces=("PPPoE0",)))
        self.assertIn("ipcp no name-servers", commands)
        self.assertNotIn("ip dhcp client no name-servers", commands)

    def test_qmi_uses_mobile_dns_command(self) -> None:
        commands = build_dns_commands(options(wan_interfaces=("UsbQmi0",)))
        self.assertIn("mobile no name-servers", commands)

    def test_all_wans_receive_isp_dns_commands(self) -> None:
        commands = build_dns_commands(options(wan_interfaces=("PPPoE0", "UsbQmi0", "ISP")))
        self.assertEqual(commands.count("ipcp no name-servers"), 1)
        self.assertEqual(commands.count("mobile no name-servers"), 1)
        self.assertEqual(commands.count("ip dhcp client no name-servers"), 1)
        self.assertIn("no interface PPPoE0 ipv6 name-servers auto", commands)
        self.assertIn("no interface UsbQmi0 ipv6 name-servers auto", commands)
        self.assertIn("no interface ISP ipv6 name-servers auto", commands)

    def test_usb_plan_adds_storage_components(self) -> None:
        info = DeviceInfo(
            host="192.168.1.1",
            arch="aarch64",
            components={
                name: Component(name=name, installed="no")
                for name in ("opkg", "opkg-kmod-netfilter", "storage", "ext", "dns-tls", "dns-https")
            },
        )
        plan = build_plan(info, options(storage_kind="usb", storage_target="ABC:/"))
        self.assertEqual(
            set(plan.components_to_install),
            {"opkg", "opkg-kmod-netfilter", "storage", "ext", "dns-tls", "dns-https"},
        )
        self.assertIn("aarch64-installer.tar.gz", plan.storage_command)

    def test_existing_entware_does_not_need_arch_mapping(self) -> None:
        info = DeviceInfo(
            host="192.168.1.1",
            arch="unknown",
            components={name: Component(name=name, installed="yes") for name in ("opkg", "dns-tls", "dns-https")},
        )
        plan = build_plan(info, options(storage_kind="existing", storage_target="existing:/"))
        self.assertEqual(plan.storage_command, "")
        self.assertEqual(plan.entware_url, "")

    def test_offline_catalog_queues_trusted_missing_components(self) -> None:
        info = DeviceInfo(
            host="192.168.1.1",
            arch="aarch64",
            components={"opkg": Component(name="opkg", installed="yes")},
            component_catalog_complete=False,
        )
        plan = build_plan(info, options())
        self.assertIn("opkg-kmod-netfilter", plan.components_to_install)
        self.assertNotIn("opkg-kmod-netfilter", plan.unavailable_components)
        self.assertTrue(any("kataloğu alınamadı" in warning for warning in plan.warnings))

    def test_supported_architecture_urls_are_https(self) -> None:
        expected = {
            "aarch64": "https://bin.entware.net/aarch64-k3.10/installer/aarch64-installer.tar.gz",
            "arm64": "https://bin.entware.net/aarch64-k3.10/installer/aarch64-installer.tar.gz",
            "mipsel": "https://bin.entware.net/mipselsf-k3.4/installer/mipsel-installer.tar.gz",
            "mips": "https://bin.entware.net/mipssf-k3.4/installer/mips-installer.tar.gz",
        }
        for architecture, url in expected.items():
            with self.subTest(architecture=architecture):
                self.assertEqual(entware_url_for_arch(architecture), url)

    def test_unknown_architecture_can_reuse_existing_entware_only(self) -> None:
        with self.assertRaises(ValueError):
            entware_url_for_arch("unknown")
        info = DeviceInfo(
            host="192.168.1.1",
            model="Future Keenetic",
            arch="unknown",
            components={name: Component(name=name, installed="yes") for name in options().keenetic_components},
        )
        plan = build_plan(info, options(storage_kind="existing", storage_target="existing:/"))
        self.assertEqual(plan.storage_command, "")

    def test_default_base_covers_kzsc_runtime(self) -> None:
        self.assertTrue(
            {"ssh", "opkg", "dns-tls", "dns-https", "opkg-kmod-netfilter", "opkg-kmod-netfilter-addons"}
            <= set(DEFAULT_KZSC_COMPONENTS)
        )
        self.assertTrue(
            {"dropbear", "lighttpd", "lighttpd-mod-cgi", "iptables", "ip-full", "coreutils-sha256sum"}
            <= set(DEFAULT_ENTWARE_PACKAGES)
        )


class ReleaseTests(unittest.TestCase):
    @staticmethod
    def payload() -> dict:
        tag = "v0.11.2.14-generic"
        base = f"https://github.com/ssy1979/keenetic-zapret-smart-control/releases/download/{tag}/"
        archive = f"keenetic-zapret-smart-control-{tag}.tar.gz"
        return {
            "tag_name": tag,
            "draft": False,
            "prerelease": False,
            "html_url": f"https://github.com/ssy1979/keenetic-zapret-smart-control/releases/tag/{tag}",
            "assets": [
                {"name": archive, "size": 150_000, "browser_download_url": base + archive},
                {"name": archive + ".sha256", "size": 128, "browser_download_url": base + archive + ".sha256"},
            ],
        }

    def test_owner_release_contract_is_accepted(self) -> None:
        release = parse_kzsc_release(self.payload())
        self.assertEqual(release.tag, "v0.11.2.14-generic")
        self.assertEqual(release.version, "0.11.2.14-generic")
        self.assertEqual(release.archive_size, 150_000)

    def test_other_repository_asset_is_rejected(self) -> None:
        payload = self.payload()
        payload["assets"][0]["browser_download_url"] = payload["assets"][0][
            "browser_download_url"
        ].replace("ssy1979", "someone-else")
        with self.assertRaises(ValueError):
            parse_kzsc_release(payload)

    def test_oversize_archive_is_rejected(self) -> None:
        payload = self.payload()
        payload["assets"][0]["size"] = KZSC_MAX_ARCHIVE_BYTES + 1
        with self.assertRaises(ValueError):
            parse_kzsc_release(payload)


if __name__ == "__main__":
    unittest.main()
