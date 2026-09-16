# SmartStock Inventory System
### Version 1.0.0 — Desktop Inventory Management for Small Business

---

## Table of Contents

1. [What is SmartStock?](#what-is-smartstock)
2. [System Requirements](#system-requirements)
3. [Installation](#installation)
4. [First Launch & Windows Security Warning](#first-launch--windows-security-warning)
5. [Getting Started](#getting-started)
6. [Pages & Features](#pages--features)
7. [Keyboard Shortcuts](#keyboard-shortcuts)
8. [Data & Security](#data--security)
9. [Backup & Recovery](#backup--recovery)
10. [Uninstalling](#uninstalling)
11. [Troubleshooting](#troubleshooting)
12. [Dependencies](#dependencies)

---

## What is SmartStock?

SmartStock is a professional desktop inventory management system designed for small to medium businesses. It lets you track stock levels, manage suppliers, generate reports, and maintain a full audit trail of every change — all stored privately and securely on your own computer with no internet connection required.

---

## System Requirements

| Requirement | Minimum |
|---|---|
| Operating System | Windows 10 or Windows 11 (64-bit) |
| RAM | 4 GB |
| Storage | 200 MB free disk space |
| Display | 1280 × 720 resolution or higher |
| Internet | Not required (fully offline) |

---

## Installation

1. Run `SmartStock_Setup.exe`
2. If Windows shows a security warning, see the **[First Launch & Windows Security Warning](#first-launch--windows-security-warning)** section below before continuing
3. Choose your install location — the default is `C:\Program Files\SmartStock` which is recommended
4. Optionally check **"Create a desktop shortcut"**
5. Click **Install** and wait for it to complete
6. Click **Finish** — optionally check **"Launch SmartStock now"** to open immediately

---

## First Launch & Windows Security Warning

> ⚠️ **Important — Please read this before running the installer or the app for the first time.**

Because SmartStock is independently developed and does not yet carry a commercial code-signing certificate, Windows may block it from running. This is **not** because the app is dangerous — it is simply because Windows does not recognise it yet as a widely-distributed signed application. You will likely see one of the following:

---

### Option A — Windows SmartScreen popup ("Windows protected your PC")

This is the most common warning. To bypass it:

1. Click **"More info"** (small text link below the main message)
2. A **"Run anyway"** button will appear at the bottom
3. Click **"Run anyway"**
4. The installer or app will launch normally
5. This is a **one-time step** — you will not see this again after install

---

### Option B — Smart App Control blocks the app entirely

On newer Windows 11 machines, **Smart App Control** may block the app outright with no "Run anyway" option. If this happens:

**To disable Smart App Control:**

1. Open **Windows Security** (search for it in the Start menu)
2. Click **App & Browser Control** in the left sidebar
3. Click **Smart App Control Settings**
4. Under "Smart App Control", select **Off**
5. Confirm when prompted
6. Re-run the SmartStock installer or `.exe`

> 💡 **Note:** Smart App Control can only be turned **Off** permanently — once off, it cannot be set back to "On" without resetting Windows. However, you can set it to **"Evaluation"** mode instead of fully off, which is less restrictive than "On" while still providing protection from actually malicious software.
>
> SmartStock does not make any network connections, does not collect any data, and stores everything locally on your machine. Disabling Smart App Control for this installation is safe.

---

### Option C — Antivirus flags the .exe

Some antivirus software (especially third-party tools like Avast, AVG, or Norton) may flag newly built `.exe` files as suspicious. If this happens:

1. Open your antivirus software
2. Find the **Quarantine** or **Blocked Items** section
3. Mark `SmartStock.exe` or `SmartStock_Setup.exe` as **trusted / safe**
4. Re-run the file

---

## Getting Started

When you launch SmartStock for the first time:

1. The app opens on the **Inventory Dashboard**
2. Four default categories are pre-loaded: Electronics, Stationery, Groceries, Hardware
3. Use the **Add New Item** form on the left to register your first product
4. Navigate between pages using the **top navigation bar**
5. Head to **System Settings** to add your own categories, choose a theme, or back up your data

---

## Pages & Features

### 📦 Inventory Dashboard
- Add, edit, update, and delete inventory items
- Live search — filters by item name, category, or SKU as you type
- Paginated table — 50 items per page, use Next/Previous to browse
- Low stock items (under 5 units) are highlighted in red automatically
- Click any row to load it into the form for editing
- Barcode preview — select a row to see its Code128 SKU barcode
- Restock button for quickly adding quantity to an existing item

### 📊 Stock Reports
- Live KPI summary: Total Items, Low Stock Alerts, Total Inventory Value (₱)
- Category Balance Summary table
- Visual analytics charts (theme-aware colours)
- Export full inventory to CSV
- Export formatted PDF report

### 📋 Audit Log
- Complete, immutable history of every stock change
- Columns: Timestamp, Item, Change Type, Quantity Delta, Price Snapshot, Notes
- Filter by date range, item, or change type
- Export audit log to CSV
- Rollback a specific entry to undo a quantity change

### 🏢 Suppliers
- Add, edit, and delete supplier records
- Fields: Company Name, Email, Phone, Notes
- Click a row to edit that supplier's details

### ⚙️ System Settings
- Switch between 4 themes: Default (Light), Dark, Blue Steel, Forest Green
- Dark Mode toggle (synced with theme selector)
- Add and remove inventory categories
- Back up your database to any location
- Reset all inventory data (categories are preserved)

---

## Keyboard Shortcuts

| Key | Action |
|---|---|
| **F11** | Toggle fullscreen (true OS-level, hides taskbar) |
| **Esc** | Exit fullscreen |
| **F1** | Open keyboard shortcut help |
| **Ctrl + N** | Focus the Item Name field |
| **Ctrl + S** | Save / Add item |
| **Ctrl + R** | Refresh table |
| **Ctrl + E** | Export to CSV |
| **Enter / Space** | Edit selected row |
| **Delete** | Delete selected row |

---

## Data & Security

SmartStock takes your data privacy seriously:

- **All data is stored locally** on your computer — nothing is sent to any server or cloud service
- **The database is encrypted** every time you close the app using AES-256 encryption (via Python `cryptography` / Fernet). The file on disk is unreadable without the app
- **The database location is hidden** from the Settings page intentionally so casual users cannot find or tamper with the file directly
- **The database is stored in your user AppData folder**, not in the installation directory:
  - Windows: `C:\Users\YourName\AppData\Local\SmartStock\`
- **Confirmation dialogs** are shown before any destructive action (delete item, delete category, reset all data)

> ⚠️ **Important:** If the app is force-closed (via Task Manager or a power outage) instead of closed normally, the database may temporarily remain as a readable `.db` file in AppData until the next normal close re-encrypts it. Always close the app properly using the window's close button.

---

## Backup & Recovery

### Creating a backup

1. Go to **System Settings**
2. Click **Backup Database**
3. Choose a save location (external drive, USB, cloud folder)
4. A timestamped copy is saved (e.g. `smartstock_backup_20260916_143022.db`)

### Restoring from a backup

If you need to restore from a backup:

1. Close SmartStock completely
2. Navigate to `C:\Users\YourName\AppData\Local\SmartStock\`
3. Delete (or rename) the existing `smartstock.db.enc` file
4. Copy your backup `.db` file into that folder
5. Rename it to `smartstock.db`
6. Launch SmartStock — it will use the restored data and re-encrypt on close

> 💡 **Tip:** Keep regular backups on a separate drive or USB. Since the database is local-only, your backup is your only recovery option if something goes wrong.

---

## Uninstalling

1. Open **Windows Settings → Apps → Installed Apps**
2. Search for **SmartStock Inventory System**
3. Click **Uninstall**

> ⚠️ Uninstalling removes the application files from `Program Files` but does **not** delete your database or data files in AppData. To fully remove all data, also manually delete:
> `C:\Users\YourName\AppData\Local\SmartStock\`

---

## Troubleshooting

### The app won't open / is blocked by Windows
See **[First Launch & Windows Security Warning](#first-launch--windows-security-warning)** above.

### The app opens but shows no data
This is normal on first launch. Use the **Add New Item** form to start adding inventory.

### I accidentally reset all data
Immediately check if you have a backup (System Settings → Backup Database saves a copy to wherever you chose). If no backup exists, the data cannot be recovered — the reset is permanent.

### The app was force-closed and I'm worried about my data
Launch the app normally — it will re-read the database (which was saved by SQLite before the crash) and re-encrypt it on the next normal close. Your data should be intact as SQLite is crash-resistant.

### Barcode images are not showing
Barcode previews require the `python-barcode` package to be present. If running from source (not the installer), run `pip install python-barcode Pillow` and restart the app.

### Charts are not showing on the Reports page
Analytics charts require `matplotlib`. If running from source, run `pip install matplotlib` and restart.

### I get a DeprecationWarning in the console
This is a known harmless warning from PyQt5's internal `sip` layer. It does not affect functionality and is suppressed automatically when running the installed `.exe`.

---

## Dependencies

These are bundled inside the installer and do not need to be installed separately by end users. Listed here for transparency:

| Package | Version | Purpose |
|---|---|---|
| PyQt5 | 5.15.x | GUI framework |
| cryptography | Latest | AES database file encryption |
| python-barcode | Latest | Code128 SKU barcode generation |
| matplotlib | Latest | Analytics charts |
| Pillow | Latest | Image handling & icon conversion |
| reportlab / fpdf | Latest | PDF report export |

---

## Contact & Support

SmartStock is an independently developed application. For bug reports, feature requests, or support, contact the developer directly.

---

*SmartStock Inventory System v1.0.0 — All rights reserved.*
*Built with Python & PyQt5.*
