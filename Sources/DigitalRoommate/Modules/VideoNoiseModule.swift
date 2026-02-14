import Foundation

// Plays YouTube videos from fake interest personas in a hidden WKWebView.
// Simulates watching behavior: plays video muted, watches for a variable
// duration (30-90% of video length), skips ads, and moves on.
class VideoNoiseModule: BrowsingModule {

    let id = "video"
    let displayName = "Video Noise"
    var isEnabled = false
    private(set) var isActive = false
    private(set) var statusText = "Idle"
    private(set) var actionsCompleted = 0
    private var shouldStop = false

    // Track watched videos to avoid immediate rewatching
    private var recentlyWatched: Set<String> = []
    private let maxRecentHistory = 50

    func execute(webView: WebViewInstance) async {
        isActive = true
        shouldStop = false
        actionsCompleted = 0

        let persona = Persona.loadDefault()
        guard !persona.videoInterests.isEmpty else {
            isActive = false
            return
        }

        // Pick a random video interest for this session
        let interest = persona.videoInterests.randomElement()!

        // Decide: search YouTube or go to a direct URL?
        if !interest.videoUrls.isEmpty && Double.random(in: 0...1) < 0.5 {
            // Direct video URL
            let url = pickUnwatchedVideo(from: interest.videoUrls)
            await watchVideo(webView: webView, url: url)
        } else if !interest.searchQueries.isEmpty {
            // Search YouTube and watch a result
            await searchAndWatch(webView: webView, interest: interest)
        } else if !interest.channelUrls.isEmpty {
            // Browse a channel page
            await browseChannel(webView: webView, url: interest.channelUrls.randomElement()!)
        }

        statusText = "Idle"
        isActive = false
    }

    func stop() {
        shouldStop = true
    }

    // MARK: - Video Behaviors

    /// Search YouTube and watch a video from results
    private func searchAndWatch(webView: WebViewInstance, interest: Persona.VideoInterest) async {
        let query = interest.searchQueries.randomElement()!
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = "https://www.youtube.com/results?search_query=\(encoded)"

        statusText = "Searching: \(query)"
        ActivityLog.shared.log(module: id, action: "YouTube search: \(query)")

        let loaded = await webView.loadURL(url)
        guard loaded, !shouldStop else { return }

        await webView.wait(seconds: Double.random(in: 2...4))

        // Scroll through results
        for _ in 0..<Int.random(in: 1...3) {
            guard !shouldStop else { return }
            await webView.runJS("window.scrollBy(0, \(Int.random(in: 200...400)))")
            await webView.wait(seconds: Double.random(in: 1...2))
        }

        // Click on a video from search results
        let clickJS = """
        (function() {
            var links = document.querySelectorAll('a#video-title, ytd-video-renderer a#thumbnail');
            var valid = Array.from(links).filter(function(a) {
                return a.href && a.href.includes('/watch?v=');
            });
            if (valid.length > 0) {
                var idx = Math.floor(Math.random() * Math.min(valid.length, 5));
                var href = valid[idx].href;
                valid[idx].click();
                return href;
            }
            return 'none';
        })()
        """

        let result = await webView.executeJS(clickJS)
        if let videoUrl = result, videoUrl != "none" {
            await webView.wait(seconds: Double.random(in: 2...4))
            await playAndWatchVideo(webView: webView)
            actionsCompleted += 1

            // Mark as watched
            if let videoId = extractVideoId(from: videoUrl) {
                markWatched(videoId)
            }
        }
    }

    /// Watch a video at a specific URL
    private func watchVideo(webView: WebViewInstance, url: String) async {
        statusText = "Loading video"
        ActivityLog.shared.log(module: id, action: "Playing: \(url)")

        let loaded = await webView.loadURL(url)
        guard loaded, !shouldStop else { return }

        await webView.wait(seconds: Double.random(in: 2...4))
        await playAndWatchVideo(webView: webView)
        actionsCompleted += 1

        if let videoId = extractVideoId(from: url) {
            markWatched(videoId)
        }
    }

    /// Browse a YouTube channel page
    private func browseChannel(webView: WebViewInstance, url: String) async {
        statusText = "Browsing channel"
        ActivityLog.shared.log(module: id, action: "Channel: \(url)")

        let loaded = await webView.loadURL(url)
        guard loaded, !shouldStop else { return }

        await webView.wait(seconds: Double.random(in: 2...4))

        // Scroll through channel videos
        for _ in 0..<Int.random(in: 2...4) {
            guard !shouldStop else { return }
            await webView.runJS("window.scrollBy(0, \(Int.random(in: 300...500)))")
            await webView.wait(seconds: Double.random(in: 1...2))
        }

        // Click on a video
        let clickJS = """
        (function() {
            var links = document.querySelectorAll('a#video-title-link, ytd-grid-video-renderer a#thumbnail, ytd-rich-item-renderer a#thumbnail');
            if (links.length > 0) {
                var idx = Math.floor(Math.random() * Math.min(links.length, 8));
                links[idx].click();
                return 'clicked';
            }
            return 'none';
        })()
        """

        let result = await webView.executeJS(clickJS)
        if result == "clicked" {
            await webView.wait(seconds: Double.random(in: 2...4))
            await playAndWatchVideo(webView: webView)
            actionsCompleted += 1
        }
    }

    /// Core video watching behavior: play muted, skip ads, watch for variable duration
    private func playAndWatchVideo(webView: WebViewInstance) async {
        let title = await webView.pageTitle()
        statusText = "Watching: \(String(title.prefix(40)))"

        // Mute the video (we don't want audio from background browsing)
        await webView.runJS("""
            var video = document.querySelector('video');
            if (video) { video.muted = true; video.volume = 0; }
        """)

        // Try to play the video
        await webView.runJS("""
            var video = document.querySelector('video');
            if (video && video.paused) {
                video.play().catch(function(){});
            }
            // Also try YouTube's play button
            var playBtn = document.querySelector('.ytp-play-button');
            if (playBtn) {
                var ariaLabel = playBtn.getAttribute('aria-label') || '';
                if (ariaLabel.toLowerCase().includes('play')) playBtn.click();
            }
        """)

        // Wait a moment, then handle any ads
        await webView.wait(seconds: 3)
        await skipAds(webView: webView)

        // Determine watch duration (30-90% of video length)
        let durationStr = await webView.executeJS("""
            var video = document.querySelector('video');
            video ? String(video.duration || 0) : '0'
        """)

        let videoDuration = Double(durationStr ?? "0") ?? 0
        let watchDuration: Double

        if videoDuration > 0 {
            let watchPercent = Double.random(in: 0.3...0.9)
            watchDuration = min(videoDuration * watchPercent, 600) // Cap at 10 minutes
        } else {
            watchDuration = Double.random(in: 60...300) // Default 1-5 minutes
        }

        ActivityLog.shared.log(module: id, action: "Watching \(Int(watchDuration))s of \(Int(videoDuration))s: \(title)")

        // Watch the video, periodically checking for ads
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < watchDuration && !shouldStop {
            await webView.wait(seconds: Double.random(in: 10...20))
            await skipAds(webView: webView)

            // Occasionally scroll down a bit (looking at description/comments)
            if Double.random(in: 0...1) < 0.2 {
                await webView.runJS("window.scrollBy(0, \(Int.random(in: 100...300)))")
            }
        }
    }

    /// Detect and skip YouTube ads
    private func skipAds(webView: WebViewInstance) async {
        await webView.runJS("""
            // Click "Skip Ad" button if present
            var skipBtn = document.querySelector('.ytp-skip-ad-button, .ytp-ad-skip-button, .ytp-ad-skip-button-modern, [id^="skip-button"]');
            if (skipBtn) skipBtn.click();

            // Click "Skip" text link if present
            var skipText = document.querySelector('.ytp-ad-skip-button-text');
            if (skipText) skipText.click();

            // Ensure video is muted even after ad plays
            var video = document.querySelector('video');
            if (video) { video.muted = true; video.volume = 0; }
        """)
    }

    // MARK: - Watch History

    private func pickUnwatchedVideo(from urls: [String]) -> String {
        // Try to find one we haven't watched recently
        let unwatched = urls.filter { url in
            guard let videoId = extractVideoId(from: url) else { return true }
            return !recentlyWatched.contains(videoId)
        }
        return unwatched.randomElement() ?? urls.randomElement()!
    }

    private func markWatched(_ videoId: String) {
        recentlyWatched.insert(videoId)
        // Trim history to prevent unbounded growth
        if recentlyWatched.count > maxRecentHistory {
            recentlyWatched.removeFirst()
        }
    }

    private func extractVideoId(from url: String) -> String? {
        // Extract video ID from youtube.com/watch?v=XXXXX
        guard let components = URLComponents(string: url),
              let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value else {
            return nil
        }
        return videoId
    }
}
