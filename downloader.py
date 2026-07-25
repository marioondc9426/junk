import json
import subprocess
import sys
import math
from pathlib import Path
import webview

BASE_DIR = Path(__file__).parent
CONFIG_FILE = BASE_DIR / "config.json"
VMS_FILE    = BASE_DIR / "vms.json"
BIOS_FILE   = BASE_DIR / "bios.json"

DEFAULT_CONFIG = {
    "qemu_binary": "qemu-system-x86_64",
    "default_ram_mb": 2048,
    "default_cpus": 2,
    "default_display": "gtk",
    "default_accel": "kvm",
    "iso_dirs": [],
}

OS_PROFILES = [
    (["win11","windows 11","threshold","25h2"],
     {"type":"modern","bios":"OVMF","chipset":"Q35","ram":8192,"cpus":4,
      "vga":"qxl-vga","nic":"virtio-net-pci","usb":"qemu-xhci","tpm":True,
      "cpu_model":"host","clock_faithful":False}),
    (["win10","windows 10","windows-10","1507","1709","1903"],
     {"type":"modern","bios":"OVMF","chipset":"Q35","ram":4096,"cpus":4,
      "vga":"qxl-vga","nic":"virtio-net-pci","usb":"qemu-xhci","tpm":False,
      "cpu_model":"host","clock_faithful":False}),
    (["win8","windows 8","winpe"],
     {"type":"modern","bios":"SeaBIOS","chipset":"Q35","ram":2048,"cpus":2,
      "vga":"qxl-vga","nic":"e1000","usb":"qemu-xhci","tpm":False,
      "cpu_model":"host","clock_faithful":False}),
    (["win7","windows 7","vista","longhorn","whistler"],
     {"type":"legacy","bios":"Award","chipset":"i440FX","ram":1024,"cpus":2,
      "vga":"std","nic":"rtl8139","usb":"usb-ehci","tpm":False,
      "cpu_model":"pentium3","clock_faithful":True}),
    (["winxp","xp professional","windows xp","neptune","xp_"],
     {"type":"legacy","bios":"Award","chipset":"i440FX","ram":512,"cpus":1,
      "vga":"std","nic":"rtl8139","usb":"usb-ehci","tpm":False,
      "cpu_model":"pentium3","clock_faithful":True}),
    (["win98","98se","windows 98","chicago","memphis","win95","windows 95","win 95"],
     {"type":"legacy","bios":"Award","chipset":"i440FX","ram":256,"cpus":1,
      "vga":"std","nic":"ne2k_pci","usb":"none","tpm":False,
      "cpu_model":"pentium","clock_faithful":True}),
    (["linux","ubuntu","debian","arch","fedora","cachy","pop-os","kubuntu","dsl"],
     {"type":"modern","bios":"SeaBIOS","chipset":"Q35","ram":4096,"cpus":4,
      "vga":"virtio-vga","nic":"virtio-net-pci","usb":"qemu-xhci","tpm":False,
      "cpu_model":"host","clock_faithful":False}),
]

def get_cpu_models(self):
    return [
        # Opções especiais
        {"key":"host",      "label":"host — mesmo do PC", "hz":None},
        {"key":"max",       "label":"max — tudo disponível", "hz":None},
        {"key":"base",      "label":"base — sem recursos extras", "hz":None},
        
        # QEMU genéricos
        {"key":"qemu64",    "label":"QEMU 64-bit", "hz":None},
        {"key":"qemu32",    "label":"QEMU 32-bit", "hz":None},
        {"key":"kvm64",     "label":"KVM 64-bit", "hz":None},
        {"key":"kvm32",     "label":"KVM 32-bit", "hz":None},
        
        # Intel - Clássicos
        {"key":"486",       "label":"Intel 486", "hz":100_000_000},
        {"key":"pentium",   "label":"Intel Pentium", "hz":100_000_000},
        {"key":"pentium2",  "label":"Intel Pentium II", "hz":300_000_000},
        {"key":"pentium3",  "label":"Intel Pentium III", "hz":800_000_000},
        {"key":"pentium4",  "label":"Intel Pentium 4", "hz":2_000_000_000},
        {"key":"n270",      "label":"Intel Atom N270", "hz":1_600_000_000},
        
        # Intel Core 2
        {"key":"coreduo",   "label":"Intel Core Duo T2600", "hz":2_160_000_000},
        {"key":"core2duo",  "label":"Intel Core 2 Duo T7700", "hz":2_400_000_000},
        {"key":"Conroe",    "label":"Intel Celeron 4x0 (Conroe)", "hz":2_000_000_000},
        {"key":"Penryn",    "label":"Intel Core 2 Duo P9xxx (Penryn)", "hz":2_600_000_000},
        
        # Intel Core i - Gerações
        {"key":"Nehalem",   "label":"Intel Core i7 9xx (Nehalem)", "hz":2_800_000_000},
        {"key":"Westmere",  "label":"Intel Westmere E56xx/L56xx", "hz":3_000_000_000},
        {"key":"SandyBridge","label":"Intel Xeon E312xx (Sandy Bridge)", "hz":3_200_000_000},
        {"key":"IvyBridge", "label":"Intel Xeon E3-12xx v2 (Ivy Bridge)", "hz":3_400_000_000},
        {"key":"Haswell",   "label":"Intel Core (Haswell)", "hz":3_500_000_000},
        {"key":"Broadwell", "label":"Intel Core (Broadwell)", "hz":3_600_000_000},
        {"key":"Skylake-Client","label":"Intel Core (Skylake)", "hz":3_800_000_000},
        
        # Intel Xeon/Servidor
        {"key":"Skylake-Server","label":"Intel Xeon (Skylake-Server)", "hz":3_800_000_000},
        {"key":"Cascadelake-Server","label":"Intel Xeon (Cascadelake)", "hz":3_800_000_000},
        {"key":"Cooperlake","label":"Intel Xeon (Cooperlake)", "hz":3_900_000_000},
        {"key":"Icelake-Server","label":"Intel Xeon (Icelake-Server)", "hz":4_000_000_000},
        {"key":"SapphireRapids","label":"Intel Xeon (Sapphire Rapids)", "hz":4_200_000_000},
        {"key":"GraniteRapids","label":"Intel Xeon (Granite Rapids)", "hz":4_400_000_000},
        {"key":"DiamondRapids","label":"Intel Xeon (Diamond Rapids)", "hz":4_600_000_000},
        {"key":"SierraForest","label":"Intel Xeon (Sierra Forest)", "hz":4_200_000_000},
        {"key":"ClearwaterForest","label":"Intel Xeon (Clearwater Forest)", "hz":4_400_000_000},
        
        # Intel Atom
        {"key":"Denverton", "label":"Intel Atom (Denverton)", "hz":2_400_000_000},
        {"key":"Snowridge", "label":"Intel Atom (Snowridge)", "hz":2_600_000_000},
        
        # Intel Xeon Phi
        {"key":"KnightsMill","label":"Intel Xeon Phi (Knights Mill)", "hz":1_500_000_000},
        
        # AMD - Clássicos
        {"key":"athlon",    "label":"AMD Athlon (QEMU)", "hz":1_400_000_000},
        {"key":"Opteron_G1","label":"AMD Opteron 240 (Gen 1)", "hz":1_800_000_000},
        {"key":"Opteron_G2","label":"AMD Opteron 22xx (Gen 2)", "hz":2_200_000_000},
        {"key":"Opteron_G3","label":"AMD Opteron 23xx (Gen 3)", "hz":2_600_000_000},
        {"key":"Opteron_G4","label":"AMD Opteron 62xx", "hz":3_000_000_000},
        {"key":"Opteron_G5","label":"AMD Opteron 63xx", "hz":3_200_000_000},
        {"key":"phenom",    "label":"AMD Phenom 9550", "hz":2_200_000_000},
        
        # AMD EPYC
        {"key":"EPYC",      "label":"AMD EPYC", "hz":2_800_000_000},
        {"key":"EPYC-Rome", "label":"AMD EPYC-Rome", "hz":3_000_000_000},
        {"key":"EPYC-Milan","label":"AMD EPYC-Milan", "hz":3_400_000_000},
        {"key":"EPYC-Genoa","label":"AMD EPYC-Genoa", "hz":3_800_000_000},
        {"key":"EPYC-Turin","label":"AMD EPYC-Turin", "hz":4_000_000_000},
        
        # Outros
        {"key":"Dhyana",    "label":"Hygon Dhyana", "hz":2_800_000_000},
        {"key":"YongFeng",  "label":"Zhaoxin YongFeng", "hz":2_500_000_000},
    ]

# Mapeamento para compatibilidade com o código existente
CPU_CLOCK_MAP = {
    "486":      {"model":"486",      "hz":100_000_000},
    "pentium":  {"model":"pentium",  "hz":100_000_000},
    "pentium2": {"model":"pentium2", "hz":300_000_000},
    "pentium3": {"model":"pentium3", "hz":800_000_000},
    "pentium4": {"model":"qemu64",   "hz":2_000_000_000},
    "n270":     {"model":"n270",     "hz":1_600_000_000},
    "coreduo":  {"model":"coreduo",  "hz":2_160_000_000},
    "core2duo": {"model":"core2duo", "hz":2_400_000_000},
    "Conroe":   {"model":"Conroe",   "hz":2_000_000_000},
    "Penryn":   {"model":"Penryn",   "hz":2_600_000_000},
    "Nehalem":  {"model":"Nehalem",  "hz":2_800_000_000},
    "Westmere": {"model":"Westmere", "hz":3_000_000_000},
    "SandyBridge": {"model":"SandyBridge", "hz":3_200_000_000},
    "IvyBridge": {"model":"IvyBridge", "hz":3_400_000_000},
    "Haswell":  {"model":"Haswell",  "hz":3_500_000_000},
    "Broadwell": {"model":"Broadwell", "hz":3_600_000_000},
    "Skylake-Client": {"model":"Skylake-Client", "hz":3_800_000_000},
    "Skylake-Server": {"model":"Skylake-Server", "hz":3_800_000_000},
    "Cascadelake-Server": {"model":"Cascadelake-Server", "hz":3_800_000_000},
    "Cooperlake": {"model":"Cooperlake", "hz":3_900_000_000},
    "Icelake-Server": {"model":"Icelake-Server", "hz":4_000_000_000},
    "SapphireRapids": {"model":"SapphireRapids", "hz":4_200_000_000},
    "GraniteRapids": {"model":"GraniteRapids", "hz":4_400_000_000},
    "DiamondRapids": {"model":"DiamondRapids", "hz":4_600_000_000},
    "SierraForest": {"model":"SierraForest", "hz":4_200_000_000},
    "ClearwaterForest": {"model":"ClearwaterForest", "hz":4_400_000_000},
    "Denverton": {"model":"Denverton", "hz":2_400_000_000},
    "Snowridge": {"model":"Snowridge", "hz":2_600_000_000},
    "KnightsMill": {"model":"KnightsMill", "hz":1_500_000_000},
    "athlon":   {"model":"athlon", "hz":1_400_000_000},
    "Opteron_G1": {"model":"Opteron_G1", "hz":1_800_000_000},
    "Opteron_G2": {"model":"Opteron_G2", "hz":2_200_000_000},
    "Opteron_G3": {"model":"Opteron_G3", "hz":2_600_000_000},
    "Opteron_G4": {"model":"Opteron_G4", "hz":3_000_000_000},
    "Opteron_G5": {"model":"Opteron_G5", "hz":3_200_000_000},
    "phenom":   {"model":"phenom", "hz":2_200_000_000},
    "EPYC":     {"model":"EPYC", "hz":2_800_000_000},
    "EPYC-Rome": {"model":"EPYC-Rome", "hz":3_000_000_000},
    "EPYC-Milan": {"model":"EPYC-Milan", "hz":3_400_000_000},
    "EPYC-Genoa": {"model":"EPYC-Genoa", "hz":3_800_000_000},
    "EPYC-Turin": {"model":"EPYC-Turin", "hz":4_000_000_000},
    "Dhyana":   {"model":"Dhyana", "hz":2_800_000_000},
    "YongFeng": {"model":"YongFeng", "hz":2_500_000_000},
    "qemu64":   {"model":"qemu64", "hz":None},
    "qemu32":   {"model":"qemu32", "hz":None},
    "kvm64":    {"model":"kvm64",  "hz":None},
    "kvm32":    {"model":"kvm32",  "hz":None},
    "host":     {"model":"host", "hz":None},
    "max":      {"model":"max",  "hz":None},
    "base":     {"model":"base", "hz":None},
}

def _load(path, default):
    if not path.exists():
        path.write_text(json.dumps(default, indent=2, ensure_ascii=False), encoding="utf-8")
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default

def _save(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")

def detect_profile(name):
    n = name.lower()
    for keys, profile in OS_PROFILES:
        if any(k in n for k in keys):
            return dict(profile)
    return {"type":"legacy","bios":"SeaBIOS","chipset":"i440FX","ram":1024,"cpus":1,
            "vga":"std","nic":"rtl8139","usb":"usb-ehci","tpm":False,
            "cpu_model":"host","clock_faithful":False}


class Api:
    def __init__(self):
        self.config    = _load(CONFIG_FILE, DEFAULT_CONFIG)
        self.vms       = _load(VMS_FILE, [])
        self.bios_list = _load(BIOS_FILE, [])
        self._procs    = {}

    # ---------- VMs ----------
    def list_vms(self):
        out = []
        for vm in self.vms:
            p = self._procs.get(vm["id"])
            out.append({**vm, "running": p is not None and p.poll() is None})
        return out

    def add_vm(self, vm):
        if not vm.get("id") or not vm.get("name"):
            return {"success":False,"message":"id e name obrigatorios"}
        if any(v["id"]==vm["id"] for v in self.vms):
            return {"success":False,"message":f"id '{vm['id']}' ja existe"}
        self.vms.append(vm); _save(VMS_FILE, self.vms)
        return {"success":True}

    def remove_vm(self, vm_id):
        self.vms = [v for v in self.vms if v.get("id")!=vm_id]
        _save(VMS_FILE, self.vms); return {"success":True}

    def update_vm(self, vm_id, fields):
        for vm in self.vms:
            if vm.get("id")==vm_id:
                vm.update(fields); _save(VMS_FILE, self.vms)
                return {"success":True}
        return {"success":False,"message":"nao encontrada"}

    # ---------- execucao ----------
    def start_vm(self, vm_id):
        vm = next((v for v in self.vms if v.get("id")==vm_id), None)
        if not vm: return {"success":False,"message":"nao encontrada"}
        p = self._procs.get(vm_id)
        if p and p.poll() is None: return {"success":False,"message":"ja rodando"}
        cmd = self._build(vm)
        try:
            proc = subprocess.Popen(cmd)
            self._procs[vm_id] = proc
            return {"success":True,"message":f"pid {proc.pid}","cmd":" ".join(cmd)}
        except FileNotFoundError:
            return {"success":False,"message":f"QEMU nao encontrado: {cmd[0]}"}
        except Exception as e:
            return {"success":False,"message":str(e)}

    def stop_vm(self, vm_id):
        p = self._procs.get(vm_id)
        if not p or p.poll() is not None: return {"success":False,"message":"nao rodando"}
        p.terminate(); return {"success":True}

    def preview_cmd(self, vm_id):
        vm = next((v for v in self.vms if v.get("id")==vm_id), None)
        if not vm: return {"success":False}
        return {"success":True,"cmd":" ".join(self._build(vm))}

    def _build(self, vm):
        cfg = self.config
        cmd = [cfg.get("qemu_binary","qemu-system-x86_64")]

        accel   = vm.get("accel", cfg.get("default_accel","kvm"))
        chipset = vm.get("chipset","i440FX")
        machine = "pc" if chipset=="i440FX" else "q35"
        cmd += ["-accel",accel,"-machine",machine]

        # cpu
        cpu_key = vm.get("cpu_model","host")
        info    = CPU_CLOCK_MAP.get(cpu_key, CPU_CLOCK_MAP["host"])
        cmd    += ["-cpu", info["model"]]

        # clock fiel
        if vm.get("clock_faithful") and info["hz"]:
            ns    = 1_000_000_000 / info["hz"]
            shift = max(0, round(math.log2(ns)))
            cmd  += ["-icount",f"shift={shift},align=off"]

        # clock personalizado (mhz manual)
        custom_mhz = vm.get("custom_cpu_mhz")
        if custom_mhz and not vm.get("clock_faithful"):
            ns    = 1_000_000_000 / (int(custom_mhz)*1_000_000)
            shift = max(0, round(math.log2(ns)))
            cmd  += ["-icount",f"shift={shift},align=off"]

        # ram
        ram  = vm.get("ram_mb", cfg.get("default_ram_mb",2048))
        cpus = vm.get("cpus",   cfg.get("default_cpus",2))
        sockets = vm.get("sockets",1)
        cores   = vm.get("cores", cpus)
        threads = vm.get("threads",1)
        cmd += ["-m",str(ram),"-smp",f"{cpus},sockets={sockets},cores={cores},threads={threads}"]

        # hugepages (ajuda latencia de RAM)
        if vm.get("hugepages"):
            cmd += ["-mem-path","/dev/hugepages","-mem-prealloc"]

        # disco
        disk = vm.get("disk_path","")
        if disk and Path(disk).exists():
            cmd += ["-drive",f"file={disk},format={vm.get('disk_format','qcow2')}"]
        iso = vm.get("iso_path","")
        if iso: cmd += ["-cdrom",iso]

        # bios
        bios = vm.get("bios","SeaBIOS")
        if bios=="OVMF":
            if vm.get("pflash_code"): cmd += ["-drive",f"if=pflash,format=raw,readonly=on,file={vm['pflash_code']}"]
            if vm.get("pflash_vars"): cmd += ["-drive",f"if=pflash,format=raw,file={vm['pflash_vars']}"]
        elif bios in ("Award","Phoenix","AMI","custom") and vm.get("bios_path"):
            cmd += ["-bios", vm["bios_path"]]

        # vga
        vga  = vm.get("vga","std")
        disp = vm.get("display_backend", cfg.get("default_display","gtk"))
        cmd += ["-vga",vga,"-display",disp]
        if vm.get("vram_mb"): cmd += ["-global",f"VGA.vgamem_mb={vm['vram_mb']}"]

        # rede
        nic      = vm.get("nic","rtl8139")
        net_type = vm.get("net_type","user")
        if net_type=="user":
            ns = "user"
            if vm.get("port_forward"): ns += f",{vm['port_forward']}"
            cmd += ["-netdev",f"{ns},id=net0","-device",f"{nic},netdev=net0"]
        elif net_type=="bridge":
            cmd += ["-netdev",f"bridge,id=net0,br={vm.get('bridge_iface','br0')}","-device",f"{nic},netdev=net0"]

        # usb
        usb = vm.get("usb","none")
        if usb=="qemu-xhci": cmd += ["-device","qemu-xhci"]
        elif usb=="usb-ehci": cmd += ["-device","usb-ehci"]

        # tpm
        if vm.get("tpm"):
            cmd += ["-chardev","socket,id=chrtpm,path=/tmp/mytpm0/swtpm-sock",
                    "-tpmdev","emulator,id=tpm0,chardev=chrtpm",
                    "-device","tpm-tis,tpmdev=tpm0"]

        # audio
        audio = vm.get("audio","none")
        if audio!="none": cmd += ["-device",audio]

        # rtc
        cmd += ["-rtc",f"base={vm.get('rtc','utc')}"]

        # extras
        extra = vm.get("extra_args","")
        if isinstance(extra,str) and extra.strip(): cmd += extra.split()
        elif isinstance(extra,list): cmd += extra

        return cmd

    # ---------- utilidades ----------
    def detect_profile(self, iso_name): return detect_profile(iso_name)

    def get_cpu_models(self):
        return [
            # Opções especiais
            {"key":"host",      "label":"host — mesmo do PC", "hz":None},
            {"key":"max",       "label":"max — tudo disponível", "hz":None},
            {"key":"base",      "label":"base — sem recursos extras", "hz":None},
            
            # QEMU genéricos
            {"key":"qemu64",    "label":"QEMU 64-bit", "hz":None},
            {"key":"qemu32",    "label":"QEMU 32-bit", "hz":None},
            {"key":"kvm64",     "label":"KVM 64-bit", "hz":None},
            {"key":"kvm32",     "label":"KVM 32-bit", "hz":None},
            
            # Intel - Clássicos
            {"key":"486",       "label":"Intel 486", "hz":100_000_000},
            {"key":"pentium",   "label":"Intel Pentium", "hz":100_000_000},
            {"key":"pentium2",  "label":"Intel Pentium II", "hz":300_000_000},
            {"key":"pentium3",  "label":"Intel Pentium III", "hz":800_000_000},
            {"key":"pentium4",  "label":"Intel Pentium 4", "hz":2_000_000_000},
            {"key":"n270",      "label":"Intel Atom N270", "hz":1_600_000_000},
            
            # Intel Core 2
            {"key":"coreduo",   "label":"Intel Core Duo T2600", "hz":2_160_000_000},
            {"key":"core2duo",  "label":"Intel Core 2 Duo T7700", "hz":2_400_000_000},
            {"key":"Conroe",    "label":"Intel Celeron 4x0 (Conroe)", "hz":2_000_000_000},
            {"key":"Penryn",    "label":"Intel Core 2 Duo P9xxx (Penryn)", "hz":2_600_000_000},
            
            # Intel Core i - Gerações
            {"key":"Nehalem",   "label":"Intel Core i7 9xx (Nehalem)", "hz":2_800_000_000},
            {"key":"Westmere",  "label":"Intel Westmere E56xx/L56xx", "hz":3_000_000_000},
            {"key":"SandyBridge","label":"Intel Xeon E312xx (Sandy Bridge)", "hz":3_200_000_000},
            {"key":"IvyBridge", "label":"Intel Xeon E3-12xx v2 (Ivy Bridge)", "hz":3_400_000_000},
            {"key":"Haswell",   "label":"Intel Core (Haswell)", "hz":3_500_000_000},
            {"key":"Broadwell", "label":"Intel Core (Broadwell)", "hz":3_600_000_000},
            {"key":"Skylake-Client","label":"Intel Core (Skylake)", "hz":3_800_000_000},
            
            # Intel Xeon/Servidor
            {"key":"Skylake-Server","label":"Intel Xeon (Skylake-Server)", "hz":3_800_000_000},
            {"key":"Cascadelake-Server","label":"Intel Xeon (Cascadelake)", "hz":3_800_000_000},
            {"key":"Cooperlake","label":"Intel Xeon (Cooperlake)", "hz":3_900_000_000},
            {"key":"Icelake-Server","label":"Intel Xeon (Icelake-Server)", "hz":4_000_000_000},
            {"key":"SapphireRapids","label":"Intel Xeon (Sapphire Rapids)", "hz":4_200_000_000},
            {"key":"GraniteRapids","label":"Intel Xeon (Granite Rapids)", "hz":4_400_000_000},
            {"key":"DiamondRapids","label":"Intel Xeon (Diamond Rapids)", "hz":4_600_000_000},
            {"key":"SierraForest","label":"Intel Xeon (Sierra Forest)", "hz":4_200_000_000},
            {"key":"ClearwaterForest","label":"Intel Xeon (Clearwater Forest)", "hz":4_400_000_000},
            
            # Intel Atom
            {"key":"Denverton", "label":"Intel Atom (Denverton)", "hz":2_400_000_000},
            {"key":"Snowridge", "label":"Intel Atom (Snowridge)", "hz":2_600_000_000},
            
            # Intel Xeon Phi
            {"key":"KnightsMill","label":"Intel Xeon Phi (Knights Mill)", "hz":1_500_000_000},
            
            # AMD - Clássicos
            {"key":"athlon",    "label":"AMD Athlon (QEMU)", "hz":1_400_000_000},
            {"key":"Opteron_G1","label":"AMD Opteron 240 (Gen 1)", "hz":1_800_000_000},
            {"key":"Opteron_G2","label":"AMD Opteron 22xx (Gen 2)", "hz":2_200_000_000},
            {"key":"Opteron_G3","label":"AMD Opteron 23xx (Gen 3)", "hz":2_600_000_000},
            {"key":"Opteron_G4","label":"AMD Opteron 62xx", "hz":3_000_000_000},
            {"key":"Opteron_G5","label":"AMD Opteron 63xx", "hz":3_200_000_000},
            {"key":"phenom",    "label":"AMD Phenom 9550", "hz":2_200_000_000},
            
            # AMD EPYC
            {"key":"EPYC",      "label":"AMD EPYC", "hz":2_800_000_000},
            {"key":"EPYC-Rome", "label":"AMD EPYC-Rome", "hz":3_000_000_000},
            {"key":"EPYC-Milan","label":"AMD EPYC-Milan", "hz":3_400_000_000},
            {"key":"EPYC-Genoa","label":"AMD EPYC-Genoa", "hz":3_800_000_000},
            {"key":"EPYC-Turin","label":"AMD EPYC-Turin", "hz":4_000_000_000},
            
            # Outros
            {"key":"Dhyana",    "label":"Hygon Dhyana", "hz":2_800_000_000},
            {"key":"YongFeng",  "label":"Zhaoxin YongFeng", "hz":2_500_000_000},
        ]

    def list_isos(self):
        isos = []
        for d in self.config.get("iso_dirs",[]):
            p = Path(d)
            if p.exists():
                for f in sorted(p.iterdir()):
                    if f.suffix.lower()==".iso":
                        prof = detect_profile(f.name)
                        isos.append({"name":f.stem,"filename":f.name,"path":str(f),
                                     "size_mb":round(f.stat().st_size/1024/1024),
                                     "profile":prof})
        return isos

    def list_bios(self):   return self.bios_list
    def add_bios(self,e):  self.bios_list.append(e); _save(BIOS_FILE,self.bios_list); return {"success":True}
    def remove_bios(self,path):
        self.bios_list=[b for b in self.bios_list if b.get("path")!=path]
        _save(BIOS_FILE,self.bios_list); return {"success":True}

    def get_config(self):       return self.config
    def save_config(self,cfg):  self.config.update(cfg); _save(CONFIG_FILE,self.config); return {"success":True}


def main():
    api = Api()
    webview.create_window("QEMU Hub", str(BASE_DIR/"index.html"),
                          js_api=api, width=1100, height=700, min_size=(800,560))
    webview.start(debug=False)

if __name__=="__main__":
    main()