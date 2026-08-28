# Yocto Base Platform for Raspberry Pi

This repository serves as a **Yocto Base Platform (BSP / Board Support Package) Repository** for Raspberry Pi 3B+ (and other Raspberry Pi boards) using **Yocto 5.0 LTS (Scarthgap)**.

It is designed to be:
1. **Standalone Build Environment**: Clone it and build a base console/GUI image directly for testing.
2. **Reusable BSP Submodule**: Include it as a Git submodule in higher-level product/project repositories, separating hardware/BSP details from application-specific layers.

---

## Directory Structure

```
rpi-base-platform/
├── configs/                  # Base configuration templates (TEMPLATECONF)
│   ├── bblayers.conf.sample  # Ported layers configured with ##OEROOT## relative paths
│   ├── local.conf.sample     # Default configuration template
│   ├── conf-notes.txt        # Welcome messages and helper commands on initialization
│   └── meta-rpi-base/        # Base hardware BSP layer
│       ├── conf/
│       │   └── layer.conf    # Layer configuration (defines default ENABLE_UART, GPU_MEM)
│       └── recipes-core/     # Contains dummy recipes to satisfy BitBake requirements
├── layers/                   # Upstream Yocto layers managed as Git Submodules
│   ├── poky/                 # Core Yocto metadata and BitBake (scarthgap)
│   ├── meta-openembedded/    # Extra recipes (oe, python, networking, etc.) (scarthgap)
│   └── meta-raspberrypi/     # Raspberry Pi hardware Support BSP (scarthgap)
├── scripts/
│   └── setup-env.sh          # Intelligent environment wrapper script
├── README.md
└── LICENSE
```

---

## 1. Standalone Quickstart (Direct Build)

### Prerequisites

Ensure your build host has the required packages installed for Yocto Scarthgap. For Ubuntu/Debian:

```bash
sudo apt-get install gawk wget git diffstat unzip texinfo gcc build-essential \
     chrpath socat cpio python3 python3-pip python3-pexpect xz-utils \
     debianutils iputils-ping python3-git python3-jinja2 python3-subunit \
     zstd liblz4-tool file locales libsdl1.2-dev xterm lz4
```

### Step 1: Clone the Repository
Clone with `--recurse-submodules` to fetch the locked Yocto branches immediately:

```bash
git clone --recurse-submodules https://github.com/electux/rpi-base-platform.git
cd rpi-base-platform
```

*(If you already cloned without submodules, run `git submodule update --init --recursive`)*.

### Step 2: Initialize the Build Environment
Source the setup wrapper script:

```bash
source scripts/setup-env.sh [optional-build-directory-name]
```

This wrapper script:
- Verifies and initializes missing submodules.
- Detects the absolute repository root path dynamically.
- Automatically points `TEMPLATECONF` to our custom templates in `configs/`.
- Initializes the Yocto build directory (defaults to `build-rpi3-64/`).

### Step 3: Trigger the Build
Run BitBake to build one of the available console-only reference images:

* **Minimal Console Image (`core-image-minimal`)**: The smallest possible bootable image, containing only the kernel, BusyBox, and basic init/shell. Good for quick verification.
  ```bash
  bitbake core-image-minimal
  ```

* **Standard Console Image (`core-image-base`)**: A console-only image with full hardware support on the Raspberry Pi (drivers, Wi-Fi/Bluetooth firmware, etc.) but no graphical desktop. Recommended for headless production/IoT devices.
  ```bash
  bitbake core-image-base
  ```

* **Full Command-Line Console Image (`core-image-full-cmdline`)**: A larger console-only image that replaces BusyBox tools with full GNU/Linux utilities (bash, grep, tar, etc.).
  ```bash
  bitbake core-image-full-cmdline
  ```

### Step 4: Login to the Image
Once the image is built and flashed to an SD card:
* **Username**: `root`
* **Password**: No password (leave blank and press Enter).

This is configured globally via `debug-tweaks` in `local.conf.sample` for easier development.

---


## 2. Integration into a Parent Product Repository

To use this repository as a submodule in a larger project (separating your hardware BSP baseline from your proprietary application metadata):

### Recommended Product Structure

Create a main repository for your product (e.g. `my-product-project`) structured as follows:

```
my-product-project/           # Parent Git repository
├── submodules/
│   └── rpi-base-platform/    # Git submodule: This rpi-base-platform repo
│       ├── layers/
│       │   ├── poky/
│       │   ...
│       └── scripts/
│           └── setup-env.sh
├── project-layers/           # Custom, project-specific layers
│   └── meta-product-app/     # Recipes for your C++ apps, UIs, etc.
├── configs/                  # Configurations specific to this product
│   ├── bblayers.conf.sample  # bblayers configuration including base and product layers
│   └── local.conf.sample     # Product-specific features and variables
├── setup-project.sh          # Wrapper script at the root level
└── README.md
```

### Setting up the Parent's `bblayers.conf.sample`

Because `rpi-base-platform` uses relative paths referenced from the Poky root directory (`##OEROOT##`), you can seamlessly add your custom product layers in the parent's `configs/bblayers.conf.sample`:

```ini
POKY_BBLAYERS_CONF_VERSION = "2"
BBPATH = "${TOPDIR}"
BBFILES ?= ""

BBLAYERS ?= " \
  ##OEROOT##/meta \
  ##OEROOT##/meta-poky \
  ##OEROOT##/meta-yocto-bsp \
  ##OEROOT##/../meta-openembedded/meta-oe \
  ##OEROOT##/../meta-openembedded/meta-python \
  ##OEROOT##/../meta-openembedded/meta-networking \
  ##OEROOT##/../meta-openembedded/meta-multimedia \
  ##OEROOT##/../meta-raspberrypi \
  ##OEROOT##/../../../project-layers/meta-product-app \
  "
```

### Sourcing from the Root via `setup-project.sh`

Add a simple wrapper script `setup-project.sh` in the parent repository root to initialize the environment:

```bash
#!/usr/bin/env bash
# Initialize product workspace

# 1. Initialize submodules if not already done
if [ ! -f "submodules/rpi-base-platform/layers/poky/oe-init-build-env" ]; then
    echo "[!] Initializing submodules..."
    git submodule update --init --recursive
fi

# 2. Point templateconf to the parent project's config
export TEMPLATECONF="$(pwd)/configs"

# 3. Source environment from the BSP submodule
source submodules/rpi-base-platform/layers/poky/oe-init-build-env "build-product"
```

---

## Customization Tips (local.conf)

In your `local.conf` (standalone or product-specific):
* **UART/Serial Console & GPU Memory** (Default: Enabled):
  `ENABLE_UART = "1"` and `GPU_MEM = "128"` are configured globally as default values in `meta-rpi-base`'s `conf/layer.conf` using weak assignments (`??=`). You can override them in your `local.conf` (e.g., `ENABLE_UART = "0"` or `GPU_MEM = "64"`) if needed.
* **Reduce Disk Space consumption**:
  Yocto builds require significant space (50GB+). You can uncomment the line:
  `INHERIT += "rm_work"`
  to delete intermediate build files for completed recipes.
* **Architecture**:
  The default `MACHINE` is `"raspberrypi3-64"`. You can change this to `"raspberrypi3"` for 32-bit compatibility or `"raspberrypi4-64"` for a newer Raspberry Pi board.

---

## Troubleshooting

### Ubuntu 24.04 LTS User Namespace Restriction
Ubuntu 24.04 restricts the use of unprivileged user namespaces by default via AppArmor, which blocks BitBake from setting up its build sandboxes.

To fix this:

* **Temporary Fix** (lasts until reboot):
  ```bash
  echo 0 | sudo tee /proc/sys/kernel/apparmor_restrict_unprivileged_userns
  ```

* **Persistent Fix** (recommended):
  ```bash
  # 1. Create a sysctl rule to disable the restriction
  echo "kernel.apparmor_restrict_unprivileged_userns=0" | sudo tee /etc/sysctl.d/60-apparmor-namespace.conf

  # 2. Apply the configuration immediately
  sudo sysctl -p /etc/sysctl.d/60-apparmor-namespace.conf
  ```
