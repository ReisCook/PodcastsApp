import Foundation
import SwiftUI
import Combine
import AVFoundation
import MediaPlayer
import XMLCoder
import Network

// MARK: - Network Monitoring
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Podcast Service
class PodcastService: ObservableObject {
    @Published var searchResults: [Podcast] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let persistenceController = PersistenceController.shared
    private let itunesSearchBaseURL = "https://itunes.apple.com/search"
    
    func searchPodcasts(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Format query for URL
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(itunesSearchBaseURL)?term=\(encodedQuery)&entity=podcast&limit=20"
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    // Parse iTunes Search API response
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(ITunesSearchResponse.self, from: data)
                    
                    // Convert to our Podcast model
                    self?.searchResults = response.results.map { result in
                        Podcast(
                            id: result.collectionId,
                            title: result.collectionName,
                            author: result.artistName,
                            description: result.description ?? "",
                            imageUrl: result.artworkUrl600 ?? result.artworkUrl100,
                            feedUrl: result.feedUrl ?? ""
                        )
                    }
                } catch {
                    self?.errorMessage = "Failed to parse data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func subscribeToPodcast(_ podcast: Podcast, completion: @escaping (Result<Podcast, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // Make sure we have a valid feed URL
        guard !podcast.feedUrl.isEmpty, let feedURL = URL(string: podcast.feedUrl) else {
            isLoading = false
            errorMessage = "Invalid feed URL"
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid feed URL"])))
            return
        }
        
        // Fetch the podcast RSS feed
        URLSession.shared.dataTask(with: feedURL) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    // Parse the RSS feed
                    let decoder = XMLDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let feed = try decoder.decode(RSSFeed.self, from: data)
                    
                    // Create updated podcast with data from feed
                    var updatedPodcast = podcast
                    updatedPodcast.title = feed.channel.title
                    updatedPodcast.author = feed.channel.author ?? podcast.author
                    updatedPodcast.description = feed.channel.description
                    if let imageUrl = feed.channel.image?.url {
                        updatedPodcast.imageUrl = imageUrl
                    }
                    updatedPodcast.isSubscribed = true
                    
                    // Save the podcast to Core Data
                    self?.persistenceController.savePodcast(updatedPodcast)
                    
                    // Process episodes
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                    
                    // Parse and save episodes
                    for item in feed.channel.items {
                        guard let audioUrl = item.enclosure?.url else { continue }
                        
                        // Create unique ID for episode
                        let episodeId = item.guid.value
                        
                        // Parse date
                        var publishDate = Date()
                        if let pubDateString = item.pubDate {
                            publishDate = dateFormatter.date(from: pubDateString) ?? Date()
                        }
                        
                        // Parse duration
                        var duration: TimeInterval = 0
                        if let durationString = item.duration {
                            // Handle various duration formats (seconds, MM:SS, HH:MM:SS)
                            let components = durationString.components(separatedBy: ":")
                            if components.count == 1, let seconds = TimeInterval(durationString) {
                                duration = seconds
                            } else if components.count == 2, let minutes = TimeInterval(components[0]), let seconds = TimeInterval(components[1]) {
                                duration = minutes * 60 + seconds
                            } else if components.count == 3, let hours = TimeInterval(components[0]), let minutes = TimeInterval(components[1]), let seconds = TimeInterval(components[2]) {
                                duration = hours * 3600 + minutes * 60 + seconds
                            }
                        }
                        
                        // Create episode
                        let episode = Episode(
                            id: episodeId,
                            podcastId: podcast.id,
                            title: item.title,
                            description: item.description ?? "",
                            audioUrl: audioUrl,
                            publishDate: publishDate,
                            duration: duration,
                            fileSize: Int64(item.enclosure?.length ?? "0") ?? 0
                        )
                        
                        // Save episode to Core Data
                        self?.persistenceController.saveEpisode(episode)
                    }
                    
                    completion(.success(updatedPodcast))
                } catch {
                    self?.errorMessage = "Failed to parse feed: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func getSubscribedPodcasts() -> [Podcast] {
        return persistenceController.fetchPodcasts(subscribed: true)
    }
    
    func getEpisodesForPodcast(podcastId: String) -> [Episode] {
        return persistenceController.fetchEpisodes(forPodcastId: podcastId)
    }
    
    func getDownloadedEpisodes() -> [Episode] {
        return persistenceController.fetchEpisodes(downloaded: true)
    }
    
    func unsubscribeFromPodcast(id: String) {
        persistenceController.unsubscribeFromPodcast(id: id)
    }
    
    func getRecentlyPlayedEpisodes(limit: Int = 10) -> [Episode] {
        return persistenceController.getRecentlyPlayedEpisodes(limit: limit)
    }
    
    func getInProgressEpisodes() -> [Episode] {
        return persistenceController.getInProgressEpisodes()
    }
}

// MARK: - Download Service
class DownloadService: ObservableObject {
    @Published var activeDownloads: [String: DownloadInfo] = [:]
    
    private let persistenceController = PersistenceController.shared
    
    struct DownloadInfo {
        var progress: Float
        var task: URLSessionDownloadTask
    }
    
    private var urlSession: URLSession!
    
    init() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.podcastapp.download")
        config.sessionSendsLaunchEvents = true
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func downloadEpisode(episode: Episode) {
        guard !episode.audioUrl.isEmpty, let url = URL(string: episode.audioUrl), !episode.isDownloaded else { return }
        
        // Create download task
        let task = urlSession.downloadTask(with: url)
        
        // Start download
        task.resume()
        
        // Add task to active downloads
        activeDownloads[episode.id] = DownloadInfo(progress: 0, task: task)
    }
    
    func cancelDownload(episodeId: String) {
        if let downloadInfo = activeDownloads[episodeId] {
            downloadInfo.task.cancel()
            activeDownloads.removeValue(forKey: episodeId)
        }
    }
    
    func deleteDownload(episodeId: String) {
        persistenceController.deleteDownloadedEpisode(id: episodeId)
    }
    
    func deleteAllDownloads() {
        persistenceController.deleteAllDownloads()
    }
    
    func getDownloadStatus(episodeId: String) -> Float? {
        return activeDownloads[episodeId]?.progress
    }
    
    // Get total size of all downloaded episodes
    func getTotalDownloadsSize() -> Int64 {
        let downloads = persistenceController.fetchEpisodes(downloaded: true)
        return downloads.reduce(0) { $0 + $1.fileSize }
    }
}

// URLSession download delegate
extension DownloadService: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Get the URL for the audio file
        guard let sourceURL = downloadTask.originalRequest?.url?.absoluteString else { return }
        
        // Find the episode by audio URL
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDEpisode")
        fetchRequest.predicate = NSPredicate(format: "audioUrl == %@", sourceURL)
        
        do {
            let results = try context.fetch(fetchRequest)
            guard let episodeObject = results.first as? NSManagedObject,
                  let episodeId = episodeObject.value(forKey: "id") as? String else { return }
            
            // Get the FileManager and document directory
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            // Create a unique filename based on episode ID
            let destinationURL = documentsURL.appendingPathComponent("\(episodeId).mp3")
            
            do {
                // Remove existing file if needed
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                
                // Move downloaded file to permanent location
                try fileManager.moveItem(at: location, to: destinationURL)
                
                // Update episode in Core Data
                DispatchQueue.main.async {
                    episodeObject.setValue(true, forKey: "isDownloaded")
                    episodeObject.setValue(destinationURL.absoluteString, forKey: "downloadPath")
                    
                    try? context.save()
                    
                    // Remove from active downloads
                    self.activeDownloads.removeValue(forKey: episodeId)
                }
            } catch {
                print("Download file error: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to find episode: \(error.localizedDescription)")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Calculate progress
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        
        // Find the episode ID for this download task
        guard let sourceURL = downloadTask.originalRequest?.url?.absoluteString else { return }
        
        // Find the episode by audio URL
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDEpisode")
        fetchRequest.predicate = NSPredicate(format: "audioUrl == %@", sourceURL)
        
        do {
            let results = try context.fetch(fetchRequest)
            guard let episodeObject = results.first as? NSManagedObject,
                  let episodeId = episodeObject.value(forKey: "id") as? String else { return }
            
            // Update the progress
            DispatchQueue.main.async {
                if var info = self.activeDownloads[episodeId] {
                    info.progress = progress
                    self.activeDownloads[episodeId] = info
                } else {
                    // If not in activeDownloads, add it
                    self.activeDownloads[episodeId] = DownloadInfo(progress: progress, task: downloadTask)
                }
            }
        } catch {
            print("Failed to find episode for progress update: \(error.localizedDescription)")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Handle errors
        if let error = error {
            print("Download error: \(error.localizedDescription)")
            
            // Find the episode ID for this task
            guard let sourceURL = task.originalRequest?.url?.absoluteString else { return }
            
            // Find the episode by audio URL
            let context = PersistenceController.shared.container.viewContext
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDEpisode")
            fetchRequest.predicate = NSPredicate(format: "audioUrl == %@", sourceURL)
            
            do {
                let results = try context.fetch(fetchRequest)
                guard let episodeObject = results.first as? NSManagedObject,
                      let episodeId = episodeObject.value(forKey: "id") as? String else { return }
                
                // Remove from active downloads
                DispatchQueue.main.async {
                    self.activeDownloads.removeValue(forKey: episodeId)
                }
            } catch {
                print("Failed to find episode for error handling: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Audio Player Service
class AudioPlayerService: ObservableObject {
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var itemEndObserver: NSObjectProtocol?
    private let persistenceController = PersistenceController.shared
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    @Published var currentEpisode: Episode?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var error: Error?
    @Published var playbackRate: Float = 1.0
    
    // Media Remote Controls and background audio
    private var nowPlayingInfo = [String: Any]()
    private var artworkImage: UIImage?
    
    init() {
        setupAudioSession()
        setupRemoteTransportControls()
    }
    
    deinit {
        // Clean up
        if let timeObserver = timeObserver {
            audioPlayer?.removeTimeObserver(timeObserver)
        }
        statusObserver?.invalidate()
        
        if let itemEndObserver = itemEndObserver {
            NotificationCenter.default.removeObserver(itemEndObserver)
        }
        
        // End background task if active
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // Add interruption notification observer
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: audioSession
            )
            
            // Add route change notification observer
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: audioSession
            )
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Remote Control Setup
    private func setupRemoteTransportControls() {
        // Get command center
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Add handler for play command
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            
            if self.audioPlayer?.rate == 0.0 {
                self.resume()
                return .success
            }
            return .commandFailed
        }
        
        // Add handler for pause command
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            
            if self.audioPlayer?.rate != 0.0 {
                self.pause()
                return .success
            }
            return .commandFailed
        }
        
        // Add handler for skip forward command (30 seconds)
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 30)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            
            self.skipForward()
            return .success
        }
        
        // Add handler for skip backward command (15 seconds)
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            
            self.skipBackward()
            return .success
        }
        
        // Add handler for seek command
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }
    
    // MARK: - Playback Control Methods
    func play(episode: Episode) {
        // Begin background task to ensure playback starts even if app is backgrounded
        beginBackgroundTask()
        
        // Clear any previous state
        stop()
        
        // Set the current episode
        currentEpisode = episode
        isLoading = true
        
        // Determine the audio URL (local or remote)
        var url: URL?
        if episode.isDownloaded, let downloadPath = episode.downloadPath {
            url = URL(string: downloadPath)
        } else {
            url = URL(string: episode.audioUrl)
        }
        
        guard let audioURL = url else {
            isLoading = false
            error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid audio URL"])
            endBackgroundTask()
            return
        }
        
        // Create player item and player
        playerItem = AVPlayerItem(url: audioURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        // Set the initial values
        duration = episode.duration
        currentTime = episode.playProgress
        
        // Seek to the last play position if needed
        if episode.playProgress > 0 {
            let cmTime = CMTime(seconds: episode.playProgress, preferredTimescale: 1000)
            audioPlayer?.seek(to: cmTime)
        }
        
        // Observe status changes
        statusObserver = playerItem?.observe(\.status, options: [.new, .old], changeHandler: { [weak self] item, change in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch item.status {
                case .readyToPlay:
                    self.isLoading = false
                    self.duration = item.duration.seconds > 0 ? item.duration.seconds : episode.duration
                    self.audioPlayer?.play()
                    self.isPlaying = true
                    
                    // Update Now Playing info once we have duration
                    self.updateNowPlayingInfo()
                    
                    // End background task now that playback has started
                    self.endBackgroundTask()
                    
                case .failed:
                    self.isLoading = false
                    self.error = item.error
                    self.endBackgroundTask()
                    
                default:
                    break
                }
            }
        })
        
        // Add periodic time observer
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 1000), queue: .main) { [weak self] time in
            guard let self = self, let episode = self.currentEpisode else { return }
            
            let currentTime = time.seconds
            self.currentTime = currentTime
            
            // Update now playing info with current time periodically
            self.updateNowPlayingInfoWithPlaybackInfo()
            
            // Save progress every 5 seconds
            if Int(currentTime) % 5 == 0 {
                self.persistenceController.updateEpisodeProgress(id: episode.id, progress: currentTime)
            }
        }
        
        // Register for playback completed notification
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main) { [weak self] _ in
                self?.handlePlaybackCompletion()
            }
        
        // Load podcast and artwork for Now Playing info
        loadMetadataForNowPlaying(episode: episode)
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        
        // Update Now Playing info
        updateNowPlayingInfoWithPlaybackInfo()
        
        // Save progress
        if let episode = currentEpisode {
            persistenceController.updateEpisodeProgress(id: episode.id, progress: currentTime)
        }
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
        
        // Update Now Playing info
        updateNowPlayingInfoWithPlaybackInfo()
    }
    
    func stop() {
        // Save progress
        if let episode = currentEpisode {
            persistenceController.updateEpisodeProgress(id: episode.id, progress: currentTime)
        }
        
        // Remove observers
        if let timeObserver = timeObserver {
            audioPlayer?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        statusObserver?.invalidate()
        statusObserver = nil
        
        if let itemEndObserver = itemEndObserver {
            NotificationCenter.default.removeObserver(itemEndObserver)
            self.itemEndObserver = nil
        }
        
        // Clear player
        audioPlayer?.pause()
        audioPlayer = nil
        playerItem = nil
        
        // Reset state
        isPlaying = false
        isLoading = false
        
        // Clear Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        audioPlayer?.seek(to: cmTime)
        
        // Update Now Playing info
        updateNowPlayingInfoWithPlaybackInfo()
        
        if let episode = currentEpisode {
            persistenceController.updateEpisodeProgress(id: episode.id, progress: time)
        }
    }
    
    func skipForward() {
        let newTime = min(currentTime + 30, duration)
        seek(to: newTime)
    }
    
    func skipBackward() {
        let newTime = max(currentTime - 15, 0)
        seek(to: newTime)
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        audioPlayer?.rate = rate
        
        // Update Now Playing info with the new rate
        updateNowPlayingInfoWithPlaybackInfo()
    }
    
    // MARK: - Background Task Management
    private func beginBackgroundTask() {
        // End previous task if it exists
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
        
        // Start a new background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // MARK: - Now Playing Info
    private func loadMetadataForNowPlaying(episode: Episode) {
        // Try to get podcast details for the episode
        if let podcast = persistenceController.getPodcast(id: episode.podcastId) {
            // Load artwork image asynchronously
            if let imageUrl = URL(string: podcast.imageUrl) {
                URLSession.shared.dataTask(with: imageUrl) { [weak self] data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self?.artworkImage = image
                            self?.updateNowPlayingInfo()
                        }
                    }
                }.resume()
            }
            
            // Set Now Playing info with podcast details
            nowPlayingInfo[MPMediaItemPropertyTitle] = episode.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = podcast.author
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = podcast.title
            
            updateNowPlayingInfo()
        } else {
            // Just use episode details if no podcast found
            nowPlayingInfo[MPMediaItemPropertyTitle] = episode.title
            updateNowPlayingInfo()
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let episode = currentEpisode else { return }
        
        // Set duration and playback info
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        
        // Add artwork if available
        if let artwork = artworkImage {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                return artwork
            }
        }
        
        // Update the system's Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingInfoWithPlaybackInfo() {
        // Only update the timing and playback rate, not the entire info
        if var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        } else {
            // If no current info, update the full info
            updateNowPlayingInfo()
        }
    }
    
    // MARK: - Event Handlers
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began (e.g., phone call)
            pause()
            
        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                  AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) else {
                return
            }
            resume()
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Pause playback if headphones were unplugged
        if reason == .oldDeviceUnavailable {
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
               !previousRoute.outputs.filter({ $0.portType == .headphones }).isEmpty {
                pause()
            }
        }
    }
    
    @objc private func handlePlaybackCompletion() {
        isPlaying = false
        
        // Mark episode as played and reset progress
        if let episode = currentEpisode {
            persistenceController.markEpisodeAsPlayed(id: episode.id, played: true)
            persistenceController.updateEpisodeProgress(id: episode.id, progress: 0)
        }
        
        // Reset position to beginning
        currentTime = 0
        seek(to: 0)
        
        // Update Now Playing info
        updateNowPlayingInfoWithPlaybackInfo()
    }
}
