# GitHub issue #3 reply draft (2026-09-15) — NOT POSTED

Thanks for the report and the repro steps in #3. They matched what we see.

We didn't take the "scroll the shelf when the hero gains focus" approach. We tried that class of fix twice on hardware in beta.17. Both attempts wedged Down navigation from the hero and interrupted Menu to top, so the code carries a note banning focus-triggered scrolls there.

rc13 (build 130) fixes it from the other side. When the focus engine can't resolve an Up press or swipe from the hero action, the shelf scrolls to the top and the native bar expands again. The next Up reaches it. Focus changes alone never scroll.

Could you retest on build 130 when it is out? If you want to send code, please open the PR against youngchris29-art/NuvioMobile on the tvos-shared-extraction branch, which is where the app lives. This repo mirrors the releases.

---
- Split the dense explanation into the failed approach and the rc13 behavior.
- Varied sentence length and used contractions.
- Kept the hardware failures, technical claims, and release details intact.
