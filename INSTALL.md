# Sideloading NuvioTV

This guide walks you through installing NuvioTV on your Apple TV using a free Apple ID. No paid developer account needed — just a computer, your Apple TV, and about 10 minutes.

## What You Need

- An **Apple TV HD or Apple TV 4K** running **tvOS 26+**
- A **Mac or Windows** computer
- A **free Apple ID** (your normal one works; some people prefer a separate one just for sideloading — create one at [account.apple.com](https://account.apple.com))
- **Sideloadly** — the tool that installs the app ([download here](https://sideloadly.io/))
- **NuvioTV.ipa** — download from the [latest release](https://github.com/youngchris29-art/NuvioTV/releases/latest)
- **WiFi** — your computer and Apple TV on the same network

## Quick Start with Sideloadly

### 1. Pair Your Apple TV

On your **Apple TV**, open **Settings → Remotes and Devices → Remote App and Devices**. Note the 4-digit pairing code shown (or confirm the pairing prompt).

### 2. Install Sideloadly

Download and install Sideloadly from [sideloadly.io](https://sideloadly.io/) on your Mac or Windows computer.

### 3. Sideload the App

1. Open **Sideloadly**.
2. Click the **plus icon** to select the NuvioTV.ipa file you downloaded.
3. Select **your Apple TV** from the device list on the right (detects via WiFi automatically).
4. Enter your **free Apple ID email** and password when prompted.
5. Click **Start**.

Sideloadly handles signing and installation — just wait for the green checkmark.

**Don't have your Apple TV in the device list?** Make sure it's on the same WiFi network, and click the refresh button. If you still don't see it, restart Sideloadly and try again.

### 4. Trust the Developer on Apple TV

On your **Apple TV**, go to **Settings → General → Privacy & Security**, scroll to **App Installation**, and verify the developer. This only happens once per app.

Launch NuvioTV. Sign in and add your accounts / addons on first launch.

## Set Up 7-Day Auto Re-Sign

With a **free Apple ID**, the app signature expires every 7 days. You have two ways to handle this:

### Option A: Automatic Re-Signing (Recommended)

1. In **Sideloadly**, open **Advanced Options** (top menu or settings).
2. Enable **"Auto-Refresh in Background"**.
3. Leave Sideloadly running on a computer that stays on the same WiFi as your Apple TV.

Sideloadly will quietly re-sign the app every 5–6 days. You'll see a notification when it completes.

### Option B: Manual Re-Signing

When the app stops launching after 7 days, just repeat the Quick Start steps above (the app and data stay; you're only re-signing the certificate). Takes 2 minutes.

## Apple TV Without USB?

**That's totally normal.** Apple TV 4K has no USB port. Everything here is **wireless** — Sideloadly talks to your Apple TV over WiFi.

If you have an older USB-equipped model, you can still use WiFi; USB is optional and slower anyway.

## Paid Alternatives

### Signulous (~$20/year)

Signs apps with a real distribution certificate — no 7-day refresh needed, and the signature lasts a year.
- [signulous.com](https://signulous.com/)
- Easier for "set it and forget it" users.
- Worth it if you sideload many apps.

### atvloadly (Self-Hosted, Free)

A web-based sideloader running on Docker. Install once, sideload from your browser.
- [github.com/bitxeno/atvloadly](https://github.com/bitxeno/atvloadly)
- Auto-re-signs in the background.
- Great for home-server enthusiasts.

## Troubleshooting

### "App ID Limit" Error

You can only sideload 3 apps per free Apple ID at a time.

**Fix:** In Sideloadly **Advanced Options**, enable **"Remove App Extensions"** before sideload. You'll lose the Top Shelf widget on the Apple TV home screen, but the app installs fine. (Or remove an old sideloaded app first and try again.)

### App Stops Opening After 7 Days

Your signature expired. Just re-sideload (repeat the Quick Start). Your data and accounts stay.

### Developer Certificate Not Trusted

On your **Apple TV**, go to **Settings → General → Privacy & Security**, find **App Installation**, and tap the developer name to verify.

### Sideloadly Can't Find My Apple TV

1. Restart Sideloadly and click **Refresh Devices**.
2. Check that your computer and Apple TV are on the **same WiFi network**.
3. Make sure the Apple TV is awake (not sleeping).
4. Try manually entering the Apple TV's IP address in Sideloadly (find it in Apple TV Settings → Network).

## Free Apple ID Limits

| Limit | Details |
|-------|---------|
| **Sideloaded apps** | Max **3 at a time**. Remove an old one to sideload a new one. |
| **Certificate lifespan** | **7 days**. Re-sideload to refresh; your data stays. |
| **Multiple users** | Each Apple ID gets its own 3-app limit. |

These aren't bugs — they're Apple's free tier. Signulous or Paid Developer ($99/year) bypass them.

## FAQ

**Q: Do I need a paid Apple Developer account?**  
A: No. A free Apple ID works fine for NuvioTV.

**Q: Can I keep the app after 7 days?**  
A: Yes, just re-sign it (re-sideload). Takes 2 minutes.

**Q: Will my accounts and settings survive the re-sign?**  
A: Yes, everything stays. Only the certificate is refreshed.

**Q: Can I use a different computer to re-sign?**  
A: Yes, as long as you have the .ipa file and use the same Apple ID.

**Q: What if I switch Apple IDs?**  
A: The previous ID's apps are deleted, and you get a fresh 3-app limit with the new ID.

**Q: Does Sideloadly work on Windows?**  
A: Yes. WiFi detection and signing work the same way.
