# Nuvio iOS release watch

Appended by `scripts/ios/check-release.sh` (daily via the nuvio-ipad launch agent). Newest at the bottom. Notes are upstream's own text.

## 0.6.4-beta — 2026-10-23

https://github.com/NuvioMedia/NuvioMobile/releases/tag/0.6.4-beta

Assets: androidApp-full-arm64-v8a-release.apk, androidApp-full-armeabi-v7a-release.apk, androidApp-full-x86-release.apk, androidApp-full-x86_64-release.apk, nuvio-0.6.4-full-release.ipa

> - 8683505d fix(details): animate ratings on tablet @tapframe  
> - e6a05d1d feat(ios): support duo layout @tapframe  
> - b6287380 fix(deps): update haze to 1.7.3 @tapframe  
> - [fix(trakt): keep continue watching when a progress request fails (#2366)](https://github.com/NuvioMedia/NuvioMobile/pull/2366) @kernexshadow  
> - [perf(streams): compile badge rules once per change (#2365)](https://github.com/NuvioMedia/NuvioMobile/pull/2365) @kernexshadow  
> - [perf(debrid): cache stream filter regexes and reuse stream facts (#2362)](https://github.com/NuvioMedia/NuvioMobile/pull/2362) @kernexshadow  
> - [i18n(el): sync the Greek locale with 0.6.3 (player badges, Simkl statuses, engine switch, party chat) (#2359)](https://github.com/NuvioMedia/NuvioMobile/pull/2359) @nosvasedis  
> - [feat(i18n): complete pt-BR player badges and watch party strings (#2338)](https://github.com/NuvioMedia/NuvioMobile/pull/2338) @jhojhocraazy  
> - [Replace libass renderer with atlas pipeline from Plezy (#2346)](https://github.com/NuvioMedia/NuvioMobile/pull/2346) @skoruppa  
> - [Update Hungarian translations (#2341)](https://github.com/NuvioMedia/NuvioMobile/pull/2341) @emgeje  
> - [i18n(vi): update strings.xml and strings_party.xml (#2339)](https://github.com/NuvioMedia/NuvioMobile/pull/2339) @blueocean2308  
> - 90ab7f95 fix(ratings): use real imdb logo and grey label @tapframe  
> - d9046775 feat(home): show ratings and age rating on hero @tapframe  
> - b9fbc09c fix(player): keep side panels clear of the navigation bar @tapframe  
> - 83e528f0 feat(player): choose a badge pack for the player @tapframe  
> - [Complete Spanish mobile translations (#2344)](https://github.com/NuvioMedia/NuvioMobile/pull/2344) @IberianSoldierPC  
> - [fix(ios): keep hardware decoding when PiP is interrupted by Notification Center (#2306)](https://github.com/NuvioMedia/NuvioMobile/pull/2306) @WhiteGiso  
> - [fix(android): scale ExoPlayer subtitles with the PiP window size (#2314)](https://github.com/NuvioMedia/NuvioMobile/pull/2314) @sap6  
> - [feat(player): auto-sync add-on subtitles on the libmpv engine (#2275)](https://github.com/NuvioMedia/NuvioMobile/pull/2275) @kernexshadow  
> 
> 

## 0.6.5-beta — 2026-10-27

https://github.com/NuvioMedia/NuvioMobile/releases/tag/0.6.5-beta

Assets: androidApp-full-arm64-v8a-release.apk, androidApp-full-armeabi-v7a-release.apk, androidApp-full-x86-release.apk, androidApp-full-x86_64-release.apk, nuvio-0.6.5-full-release.ipa

> - [feat(i18n): translate subtitle render scale and hero ratings settings (#2402)](https://github.com/NuvioMedia/NuvioMobile/pull/2402) @jhojhocraazy  
> - 2c69902b fix(servers): keep title lookups working between episodes @tapframe  
> - [Updated Bulgarian translations - fixes, party file, new strings (#2397)](https://github.com/NuvioMedia/NuvioMobile/pull/2397) @viiktr  
> - 88c9b4ce feat(player): split video and controls at the duo fold @tapframe  
> - [fix(debrid): recognize language words in release names (#2364)](https://github.com/NuvioMedia/NuvioMobile/pull/2364) @kernexshadow  
> - [i18n(vi): update latest Vietnamese strings (#2370)](https://github.com/NuvioMedia/NuvioMobile/pull/2370) @blueocean2308  
> - c85dc721 feat(player): remove source name from paused player @tapframe  
> - [l10n: complete missing Italian translations (#2371)](https://github.com/NuvioMedia/NuvioMobile/pull/2371) @WhiteGiso  
> - [Player chapters: progress bar marks, chapter name and a chapters panel (#2174)](https://github.com/NuvioMedia/NuvioMobile/pull/2174) @kernexshadow  
> 

## 0.6.6-beta — 2026-10-31

https://github.com/NuvioMedia/NuvioMobile/releases/tag/0.6.6-beta

Assets: androidApp-full-arm64-v8a-release.apk, androidApp-full-armeabi-v7a-release.apk, androidApp-full-x86-release.apk, androidApp-full-x86_64-release.apk, nuvio-0.6.6-full-release.ipa

> - [Translation improvements and adjustments for Slovak language + added translated new strings files (#2448)](https://github.com/NuvioMedia/NuvioMobile/pull/2448) @mmsw91
> - [improve player badge codec detection and add filename matching (#2414)](https://github.com/NuvioMedia/NuvioMobile/pull/2414) @skoruppa
> - [Add intro, outro and recap skipping from MKV chapter titles (#2446)](https://github.com/NuvioMedia/NuvioMobile/pull/2446) @skoruppa 
> - [feat(i18n): translate settings groups, subtitle appearance and ASS render modes (#2435)](https://github.com/NuvioMedia/NuvioMobile/pull/2435) @jhojhocraazy
> - Update Vietnamese translations ([#2441](https://github.com/NuvioMedia/NuvioMobile/pull/2441), [#2411](https://github.com/NuvioMedia/NuvioMobile/pull/2411)) @blueocean2308
> - Add subtitle customization with saved styles, custom font imports, appearance controls and a live preview, including fixes for font rendering, subtitle loading, track changes and style updates while paused. @tapframe
> - [Updated Bulgarian translations (#2424)](https://github.com/NuvioMedia/NuvioMobile/pull/2424) @viiktr
> - [fix(ios): resume PiP right after Notification Center (#2418)](https://github.com/NuvioMedia/NuvioMobile/pull/2418) @WhiteGiso
> - c7ff35f0 feat(settings): group settings and split playback pages @tapframe
> - 96061025 fix(ratings): show IMDb ratings with one decimal @tapframe
> - 2f0185ce feat(details): label unreleased episodes as unavailable @tapframe
> - 87795e97 fix(settings): save and restore the selected app icon @tapframe
> - [Draw ASS subtitles onto video frames via setVideoEffects + ASS Render Mode setting (#2394)](https://github.com/NuvioMedia/NuvioMobile/pull/2394) @skoruppa
> - 45af99c4 fix(player): skip drag handling while controls are locked @tapframe
> - [fix(player): offline playback performance and reliability (#2383)](https://github.com/NuvioMedia/NuvioMobile/pull/2383) @guuilp
> - [feat(player): Auto engine selection and engine failover (#2192)](https://github.com/NuvioMedia/NuvioMobile/pull/2192) @guuilp
> 
