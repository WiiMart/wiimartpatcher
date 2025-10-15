# WiiMart Patcher

<img src="https://wiimart.org/media/branding-bag-no-bg.png" width="100" height="100" align="right" />

WiiMart Patcher helps you patch your **WBFS (disc) games** to make them compatible with **DLC content** and **Wiimmfi**.  


---

## 🧩 Usage

### 🐧 Linux

1. **Download** the **static build** of WiiMart Patcher.  

2. **Initialize the project structure**:
   ```bash
   ./WiiMartPatcher --init
   ```
   This creates all required folders (e.g. `wit/`, `wbfs/`, etc.).

3. **Download the latest version of [WIT (Wiimms ISO Tools)](https://wit.wiimm.de/download.html)** and unzip it.  
   You have three options to make WIT available:
   - **Option A:** Drop the extracted WIT files into the folder created by WiiMart Patcher.  
     Ensure the executable exists at:
     ```
     ./wit/bin/wit
     ```
   - **Option B:** Use a custom path with the `--wit-path` flag:
     ```bash
     ./WiiMartPatcher --wit-path /path/to/wit
     ```
     Make sure `/path/to/wit/bin/wit` exists.
   - **Option C:** Add WIT to your system’s PATH:  
     Add `/path/to/wit/bin` to your PATH variable and verify that `wit` runs from anywhere.

4. **Place your `.wbfs` files** inside the `wbfs/` folder created by WiiMart Patcher.

5. **Start patching!**  
   Simply run:
   ```bash
   ./WiiMartPatcher
   ```

---

### 🪟 Windows

Support is **coming soon** — some fixes are still in progress.

---

### 🍎 macOS

Unfortunately, **macOS is not supported** at this time.

---

*The WiiMart Team is not affiliated with Nintendo or any related parties. For inquiries, contact us at **support@wiimart.org**.*