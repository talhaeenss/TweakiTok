# TweakiTok <img src="https://img.icons8.com/color/48/tiktok--v1.png" width="28" height="28" valign="middle" /> 47.5.3

An awesome, modern TikTok tweak for iOS. Most TikTok tweaks are paid or outdated; TweakiTok is completely free, open-source, and packed with cutting-edge features.

## GitHub Actions & Prebuilt Releases

Ready-to-install `.deb` packages and modded `.ipa` releases are automatically compiled and published via GitHub Actions on every push. Check out the [Releases](https://github.com/talhaeenss/TweakiTok/releases) tab to grab the latest builds!

## Features

- **No Ads**: Completely removes all in-feed and sponsored ads.
- **Live Stream Recording**: Hardware-accelerated ReplayKit 60fps internal audio & video recording with interactive controls (Pause, Resume, Stop) and automatic gallery export.
- **Circular 3-Dot Action Menu**: Positioned right above the creator avatar for quick downloads, link copies, and clean screen toggling.
- **Watermark-Free Video Downloads**: Save TikTok videos directly to Camera Roll without watermark.
- **Video Cover Image Download**: Download high-resolution video cover images directly to Photos from the download action sheet. Toggleable in settings (enabled by default).
- **HD Video Downloads**: Option to download high-definition copies.
- **Story Downloads**: Download photos & videos from stories directly.
- **Story Progress Bar & Seekbar**: Interactive draggable progress bar on stories for fast-forwarding and rewinding playback, synchronized with the master progress bar setting.
- **Photos & Albums Download**: Download individual photos or batch-download full albums.
- **Download Current Photo (Smart Photo Download)**: In multi-photo slide posts, dynamically reads the active photo index and offers a one-tap option to download only the currently viewed photo without cluttering the menu.
- **Audio / Music Download**: Save music and background audio tracks.
- **Clean Screen Mode**: Hide all UI overlays, buttons, captions, and comments.
- **Smart Auto-Hide**: Hides all tweak buttons during 2x fast-forward long press.
- **Language Support (English & Turkish)**: Automatically adapts to your TikTok app language (defaults to Turkish if TikTok is Turkish, English otherwise). You can switch between English and Turkish anytime from the dedicated Language setting; changes take effect instantly throughout the tweak UI without requiring an app restart.
- **Follow Status Badge**: Profile badge next to username showing whether the user follows you ("Sizi takip ediyor" / "Sizi takip etmiyor"). Automatically hidden on your own profile, toggleable in settings.
- **Copy Actions**: Copy video description, direct video link, and audio track link with a tap.
- **Auto-Play**: Automatically scrolls to the next video when the current one finishes.
- **Seekbar & Progress Bar**: Persistent draggable progress bar on all videos.
- **Action Confirmations**: Confirmation prompts before Liking, Disliking, or Following.
- **Profile Enhancements**: Save HD profile pictures, copy bio information, view total profile video count.
- **Always Show Publish Date**: Displays when the video was published next to the creator's name on all feeds as relative time or exact date/time, matching profile video view. Toggleable in TweakiTok settings (disabled by default).
- **Copy Comment Without Username**: Copies only the clean comment text without the @username: prefix when copying a comment from the comments section. Toggleable in TweakiTok settings (disabled by default).
- **Video Metadata**: Displays video upload date and exact like count.
- **HD Uploads**: Forces uploads in high-definition quality.
- **Extended Text Limits**: Extends bio and comment character limits.
- **External Browser**: Option to open all links directly in Safari.
- **Region Changer**: Built-in region selector to browse TikTok feeds from any country.
- **App Lock**: Biometric Face ID / Touch ID and passcode protection.
- **Privacy & Ghost Mode**: Read DMs without sending seen receipts and type messages without broadcasting typing indicators.
- **Sanitize Sharing Links**: Removes tracking and referral parameters (such as `_t`, `_r`, user IDs, device fingerprints, and UTM parameters) from shared and copied TikTok video and profile links to protect your privacy and prevent account linking. Essential parameters, video IDs, and usernames are fully preserved to keep links functional. Enabled by default; can be toggled off anytime in TweakiTok settings.
- **Disable Screen Capture Detection**: Completely prevents TikTok from detecting screenshots and screen recordings in feeds, live streams, and private chat rooms. Suppresses intrusive "share this screenshot" popups and DM screenshot alerts, while keeping normal iOS screenshot and screen recording quality intact. Enabled by default; can be toggled off in settings.
- **Disable Telemetry**: Blocks background analytics, diagnostic tracking, and telemetry data from being logged and dispatched to ByteDance / TikTok servers (AppLog, BDTracker, AWETracker). Enabled by default; can be toggled off in settings.
- **Security Bypasses**: Bypasses jailbreak detection and environment checks.

## TODO

- [ ] **Remember clear display**: Persist clean screen mode across videos.
- [ ] **Keep the screen's refresh rate**: Prevent dropping 90/120 Hz display rate.
- [ ] **Resume videos after scrolling**: Resume playback from previous position.
- [ ] **Translate comments**: Automatically translate comments on load.
- [ ] **Show commenter handle and region**: Show @handle and country flag in comments.
- [ ] **Show the progress bar thumbnail**: Show preview thumbnail while scrubbing seekbar.
- [ ] **Keep unsent messages**: Keep deleted/unsent messages in chat.
- [ ] **Ghost mode**: Hide view history, online presence, read receipts & typing.
- [ ] **Keep a streak going**: Auto-send scheduled messages to maintain streaks.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0) - see the [LICENSE](LICENSE) file for details.
