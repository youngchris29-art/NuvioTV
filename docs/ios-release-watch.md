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

## 0.6.7-beta — 2026-11-04

https://github.com/NuvioMedia/NuvioMobile/releases/tag/0.6.7-beta

Assets: androidApp-full-arm64-v8a-release.apk, androidApp-full-armeabi-v7a-release.apk, androidApp-full-x86-release.apk, androidApp-full-x86_64-release.apk, nuvio-0.6.7-full-release.ipa

> - 9f18bfee feat(player): resize video beside watch party panel @tapframe  
> - [Fix addon ASS subtitles not rendering with libass on Android (#2507)](https://github.com/NuvioMedia/NuvioMobile/pull/2507) @skoruppa  
> - [fix(ios): declare long-form video audio so playback is not shown as music (#2419)](https://github.com/NuvioMedia/NuvioMobile/pull/2419) @WhiteGiso  
> - [locales: add and update Arabic settings translations (#2498)](https://github.com/NuvioMedia/NuvioMobile/pull/2498) @aliabdoxd14  
> - [Add missing Polish translations (#2495)](https://github.com/NuvioMedia/NuvioMobile/pull/2495) @skoruppa  
> - [Keep stream info and current stream marker with reused links (#2494)](https://github.com/NuvioMedia/NuvioMobile/pull/2494) @skoruppa  
> - [i18n: harmonize French terminology with Nuvio TV (#2481)](https://github.com/NuvioMedia/NuvioMobile/pull/2481) @SK-Gits  
> - [l10n: complete missing Italian translations (#2482)](https://github.com/NuvioMedia/NuvioMobile/pull/2482) @WhiteGiso  
> - [Add mark as watched to continue watching menu (#2493)](https://github.com/NuvioMedia/NuvioMobile/pull/2493) @skoruppa  
> - [fix(player): prevent auto failover loop and fix anime engine selection (#2467)](https://github.com/NuvioMedia/NuvioMobile/pull/2467) @guuilp  
> - [feat(i18n): complete and update Turkish (tr) localization (#2472)](https://github.com/NuvioMedia/NuvioMobile/pull/2472) @stuntsnakee  
> - [Fix line breaks in the Spanish P2P consent text (#2470)](https://github.com/NuvioMedia/NuvioMobile/pull/2470) @IberianSoldierPC  
> - [Update Spanish mobile translations (#2468)](https://github.com/NuvioMedia/NuvioMobile/pull/2468) @IberianSoldierPC  
> - [i18n(el): sync the Greek locale with 0.6.6 (settings realignment, chapters, subtitle appearance) (#2466)](https://github.com/NuvioMedia/NuvioMobile/pull/2466) @nosvasedis  
> - [Update Bulgarian strings for clarity and accuracy after latest update (#2463)](https://github.com/NuvioMedia/NuvioMobile/pull/2463) @viiktr  
> - [i18n(vi): update latest Vietnamese strings (#2460)](https://github.com/NuvioMedia/NuvioMobile/pull/2460) @blueocean2308  
> - [feat(i18n): refine fr translations and align Nuvio Mobile with Nuvio TV (#2459)](https://github.com/NuvioMedia/NuvioMobile/pull/2459) @SK-Gits  
> - [fix(i18n): pt-BR wording follow-up to #2435 (#2455)](https://github.com/NuvioMedia/NuvioMobile/pull/2455) @jhojhocraazy  
> - [Skip button timer resets when chapters replace API intervals (#2457)](https://github.com/NuvioMedia/NuvioMobile/pull/2457) @skoruppa  
> - [add video hash computation and subtitle extras parity with TV (#2450)](https://github.com/NuvioMedia/NuvioMobile/pull/2450) @skoruppa  
> - [i18n(ar): complete the Arabic mobile translations (#2368)](https://github.com/NuvioMedia/NuvioMobile/pull/2368) @abdulamalik  
> - [fix(ios): publish Now Playing only on playback changes (#2420)](https://github.com/NuvioMedia/NuvioMobile/pull/2420) @WhiteGiso  
> - [fix(i18n): localize Episode N on remaining UI (#2254)](https://github.com/NuvioMedia/NuvioMobile/pull/2254) @blueocean2308  
> 

## 0.6.8-beta — 2026-11-05

https://github.com/NuvioMedia/NuvioMobile/releases/tag/0.6.8-beta

Assets: androidApp-full-arm64-v8a-release.apk, androidApp-full-armeabi-v7a-release.apk, androidApp-full-x86-release.apk, androidApp-full-x86_64-release.apk, nuvio-0.6.8-full-release.ipa

> - 0403e6f6 fix(player): detach mpv surfaces on the playback thread @tapframe  
> - 68c815b2 feat(streams): update blur @tapframe  
> - b90454d7 feat(details): update blur @tapframe  
> - [fix(ios): keep an add-on subtitle selected before mpv loads the file (#2517)](https://github.com/NuvioMedia/NuvioMobile/pull/2517) @skoruppa  
> - [sync ASS/SSA add-on subtitles drawn by libass (#2515)](https://github.com/NuvioMedia/NuvioMobile/pull/2515) @skoruppa  
> - [fix(i18n): drop trailing period from two pt-BR descriptions (#2506)](https://github.com/NuvioMedia/NuvioMobile/pull/2506) @jhojhocraazy  
> - [fix(player): stop Exo/libmpv auto-switch ping-pong on the same source (#2485)](https://github.com/NuvioMedia/NuvioMobile/pull/2485) @halibiram  
> - [fix(player): resume a closed torrent stream at the stalled frame (#2479)](https://github.com/NuvioMedia/NuvioMobile/pull/2479) @halibiram  
> - [feat(player): audio downmix and center mix on Android (#2456)](https://github.com/NuvioMedia/NuvioMobile/pull/2456) @kernexshadow  
> 

## 0.6.9-beta — 2026-11-06

https://github.com/NuvioMedia/NuvioMobile/releases/tag/0.6.9-beta

Assets: androidApp-full-arm64-v8a-release.apk, androidApp-full-armeabi-v7a-release.apk, androidApp-full-x86-release.apk, androidApp-full-x86_64-release.apk, nuvio-0.6.9-full-release.ipa

> - ff522ec9 fix(i18n): add Tamil to iOS @tapframe  
> - [fix(skip-intro): drop open-ended Anime-Skip segments and prefer AniSkip (#2539)](https://github.com/NuvioMedia/NuvioMobile/pull/2539) @skoruppa  
> - [fix(player): leave edge swipes to the back gesture and lock tablets to landscape (#2542)](https://github.com/NuvioMedia/NuvioMobile/pull/2542) @skoruppa  
> - 2f9f4ae6 feat(settings): add ratings source picker @tapframe  
> - 9c26a7cf feat(details): add star ratings for titles and episodes @tapframe  
> - 1255999d feat(mdblist): sync and save ratings @tapframe  
> - 6982ec7d feat(simkl): save and read title ratings @tapframe  
> - 32298713 feat(tracking): add rating source setting @tapframe  
> - d816059e feat(streams): make chips see-through over backdrops @tapframe  
> - 9877adfc feat(details): fade tablet artwork into the cinematic backdrop @tapframe  
> - 5cf73ccc feat(details): show the cinematic backdrop behind the floating header @tapframe  
> - f6ac2840 feat(details): make buttons and chips see-through over backdrops @tapframe  
> - [i18n: add French strings for audio downmix, amplification and delay (#2532)](https://github.com/NuvioMedia/NuvioMobile/pull/2532) @SK-Gits  
> - [fix(player): allow playback during calls with ExoPlayer (#2531)](https://github.com/NuvioMedia/NuvioMobile/pull/2531) @sap6  
> - [i18n(vi): update translations for strings.xml and autosync_toast_strings.xml (#2530)](https://github.com/NuvioMedia/NuvioMobile/pull/2530) @blueocean2308  
> - [fix(i18n): update Bengali (বাংলা) localization and sync missing strings (#2529)](https://github.com/NuvioMedia/NuvioMobile/pull/2529) @TanvirSdq  
> - [feat(i18n): add Tamil language support and UI localization (#2528)](https://github.com/NuvioMedia/NuvioMobile/pull/2528) @vijay3695  
> - [Fix Arabic page-title wrapping in shared screen header (#2063)](https://github.com/NuvioMedia/NuvioMobile/pull/2063) @i7xre  
> 

## 0.6.10-beta — 2026-11-08

https://github.com/NuvioMedia/NuvioMobile/releases/tag/0.6.10-beta

Assets: androidApp-full-arm64-v8a-release.apk, androidApp-full-armeabi-v7a-release.apk, androidApp-full-x86-release.apk, androidApp-full-x86_64-release.apk, nuvio-0.6.10-full-release.ipa

> - c1dfd989 fix(player): start playback service as a normal service first (NUVIO-MOBILE-D9 NUVIO-MOBILE-9E NUVIO-MOBILE-9M NUVIO-MOBILE-PC) @tapframe  
> - 6ad2d9ba fix(player): cap buffer start times at the min buffer (NUVIO-MOBILE-1VH) @tapframe  
> - 81dc761e fix(player): guard caption setting reads (NUVIO-MOBILE-25M) @tapframe  
> - d534d14e fix(network): treat SSL setup errors as failed requests (NUVIO-MOBILE-254 NUVIO-MOBILE-3N) @tapframe  
> - 8172e682 fix(watched): copy unsynced keys before saving (NUVIO-MOBILE-260) @tapframe  
> - [i18n: add French translation for ratings strings (#2562)](https://github.com/NuvioMedia/NuvioMobile/pull/2562) @SK-Gits  
> - [i18n(el): sync the Greek locale with 0.6.9 (playback audio, downmix, ratings) (#2561)](https://github.com/NuvioMedia/NuvioMobile/pull/2561) @nosvasedis  
> - [i18n(he): translate party strings into Hebrew (#2557)](https://github.com/NuvioMedia/NuvioMobile/pull/2557) @haveAnIssue  
> - [i18n(he): translate servers strings into Hebrew (#2556)](https://github.com/NuvioMedia/NuvioMobile/pull/2556) @haveAnIssue  
> - [i18n(he): translate pip strings into Hebrew (#2555)](https://github.com/NuvioMedia/NuvioMobile/pull/2555) @haveAnIssue  
> - [i18n(he): translate autosync strings into Hebrew (#2553)](https://github.com/NuvioMedia/NuvioMobile/pull/2553) @haveAnIssue  
> - [i18n(he): translate mdblist strings into Hebrew (#2552)](https://github.com/NuvioMedia/NuvioMobile/pull/2552) @haveAnIssue  
> - [i18n(he): translate ratings strings into Hebrew (#2551)](https://github.com/NuvioMedia/NuvioMobile/pull/2551) @haveAnIssue  
> - [Update Japanese translation (#2559)](https://github.com/NuvioMedia/NuvioMobile/pull/2559) @Joe00011  
> - [i18n(vi): translate ratings strings into Vietnamese (#2550)](https://github.com/NuvioMedia/NuvioMobile/pull/2550) @blueocean2308  
> - 82ca7d11 fix(player): reset addon subtitles only when the source changes @tapframe  
> - [feat(autosync): shared engine, enable on iOS (#2535)](https://github.com/NuvioMedia/NuvioMobile/pull/2535) @skoruppa  
> - [fix(mdblist): remap anime episodes between addon and TMDB numbering (TV parity) (#2516)](https://github.com/NuvioMedia/NuvioMobile/pull/2516) @kernexshadow  
> 

## 0.6.11-beta — 2026-11-10

https://github.com/NuvioMedia/NuvioMobile/releases/tag/0.6.11-beta

Assets: androidApp-full-arm64-v8a-release.apk, androidApp-full-armeabi-v7a-release.apk, androidApp-full-x86-release.apk, androidApp-full-x86_64-release.apk, nuvio-0.6.11-full-release.ipa

> - 9c2d0902 fix(mdblist): reuse progress and watched lists until a remap changes them @tapframe  
> - daa966d3 fix(auth): stay signed in when session refresh fails @tapframe  
> - [fix(player): center opening overlay backdrop on tall screens (#2585)](https://github.com/NuvioMedia/NuvioMobile/pull/2585) @yvngjoon  
> - f004557c fix(player): show mpv error details on the error screen @tapframe  
> - [fix(autosync): allow AutoSync without a preferred language, enable forced subs and AutoSync by default (#2578)](https://github.com/NuvioMedia/NuvioMobile/pull/2578) @skoruppa  
> - [feat(hero): smart horizontal framing for cropped backdrops (#2538)](https://github.com/NuvioMedia/NuvioMobile/pull/2538) @skoruppa  
> - [Add and update Bulgarian strings in strings.xml (#2576)](https://github.com/NuvioMedia/NuvioMobile/pull/2576) @viiktr  
> - [i18n: harmonize French wording with Nuvio TV (#2575)](https://github.com/NuvioMedia/NuvioMobile/pull/2575) @SK-Gits  
> - [fix(autosync): search further when a restored subtitle does not fit (#2537)](https://github.com/NuvioMedia/NuvioMobile/pull/2537) @skoruppa  
> 
