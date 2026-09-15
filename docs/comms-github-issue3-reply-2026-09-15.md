# GitHub issue #3 reply draft (2026-09-15) — NOT POSTED

Thanks for the report and the repro steps, they matched what we see.

We did not take the "scroll the shelf when the hero gains focus" approach. We tried that class of fix twice on hardware in beta.17 and both times it wedged Down navigation from the hero and interrupted Menu to top, so the code carries a note banning focus triggered scrolls there. rc13 (build 130) fixes it from the other side: an Up press or swipe from the hero action that the focus engine cannot resolve scrolls the shelf to the top, the native bar re expands, and the next Up reaches it. Focus changes on their own never scroll.

Could you retest on build 130 when it is out? If you want to send code, please open the PR against youngchris29-art/NuvioMobile on the tvos-shared-extraction branch, which is where the app lives. This repo mirrors the releases.
