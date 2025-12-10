# WiiMart DLC Patcher

<img src="https://wiimart.org/media/branding-bag-no-bg.png" width="100" height="100" align="right" />

WiiMart DLC Patcher helps you patch your disc games **(WBFS)** to make them compatible with **DLC content** and **Wiimmfi**.  


---

## Usage

Replace `XX` with either `64` or `86`.

### Linux

1. **Download** the **static build** of WiiMart DLC Patcher and make it executable.
   ```bash
   chmod +x WiiMartPatcher-static_xXX
   ```

2. **Initialize the project structure**:
   ```bash
   ./WiiMartPatcher-static_xXX --init
   ```
   This creates all required folders (e.g. `wit/`, `wbfs/`, etc.).

3. **Download the latest version of [WIT (Wiimms ISO Tools)](https://wit.wiimm.de/download.html)** and unzip it but do **NOT** run the installer.  
   You have three options to make use of WIT:
   - **Option A:** Drop the extracted WIT files into the folder created by WiiMart DLC Patcher.  
     Ensure the executable exists at:
     ```
     ./wit/bin/wit
     ```
   - **Option B:** Use a custom path with the `--wit-path` flag:
     ```bash
     ./WiiMartPatcher-static_xXX --wit-path /path/to/wit
     ```
     Make sure `/path/to/wit/bin/wit` exists.
   - **Option C:** Add WIT to your system’s PATH:  
     Add `/path/to/wit/bin` to your PATH variable and verify that `wit` runs from anywhere.

4. **Place your `.wbfs` file(s)** inside the `wbfs/` folder created by WiiMart DLC Patcher.

5. **Start patching!**  
   Simply run:
   ```bash
   ./WiiMartPatcher-static_xXX
   ```

---

### Windows

1. **Download** the **static build** of WiiMart DLC Patcher.  

2. **Initialize the project structure**:
   ```
   WiiMartPatcher_xXX.exe --init
   ```
   This creates all required folders (e.g. `wit\`, `wbfs\`, etc.).

3. **Download the latest version of [WIT (Wiimms ISO Tools)](https://wit.wiimm.de/download.html)** and unzip it but do **NOT** run the installer.  
   You have three options to make use of WIT:
   - **Option A:** Drop the extracted WIT files into the folder created by WiiMart DLC Patcher.  
     Ensure the executable exists at:
     ```
     .\wit\bin\wit.exe
     ```
   - **Option B:** Use a custom path with the `--wit-path` flag:
     ```
     WiiMartPatcher_xXX.exe --wit-path C:\path\to\wit
     ```
     Make sure `C:\path\to\wit\bin\wit.exe` exists.
   - **Option C:** Add WIT to your system’s PATH:  
     Add `C:\path\to\wit\bin` to your PATH variable and verify that `wit` runs from anywhere.

4. **Place your `.wbfs` files** inside the `wbfs\` folder created by WiiMart DLC Patcher.

5. **Start patching!**  
   Simply run:
   ```
   WiiMartPatcher_xXX.exe
   ```

---

### macOS

Unfortunately, **macOS is not supported** at this time.

---

*The WiiMart Team is not affiliated with Nintendo or any related parties. For inquiries, contact us at **support@wiimart.org**.*