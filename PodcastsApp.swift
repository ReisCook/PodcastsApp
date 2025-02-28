import SwiftUI
import AVFoundation
import Combine

// MARK: - Models
struct Podcast: Identifiable, Codable {
    var id: String
    var title: String
    var author: String
    var description: String
    var imageUrl: String
    var feedUrl: String
    var episodes: [Episode]?
}

struct Episode: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var audioUrl: String
    var publishDate: Date
    var duration: TimeInterval
    var isDownloaded: Bool = false
    var downloadProgress: Float = 0.0
}

// MARK: - Services
class PodcastService: ObservableObject {
    @Published var featuredPodcasts: [Podcast] = []
    @Published var searchResults: [Podcast] = []
    @Published var isLoading: Bool = false
    
    func fetchFeaturedPodcasts() {
        isLoading = true
        // This would normally be an API call to fetch podcasts
        // For demo purposes, we'll create some mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.featuredPodcasts = self.getMockPodcasts()
            self.isLoading = false
        }
    }
    
    func searchPodcasts(query: String) {
        isLoading = true
        // This would normally be an API call to search podcasts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Filter mock podcasts based on query
            self.searchResults = self.getMockPodcasts().filter { 
                $0.title.lowercased().contains(query.lowercased()) || 
                $0.author.lowercased().contains(query.lowercased())
            }
            self.isLoading = false
        }
    }
    
    func getPodcastDetails(podcast: Podcast, completion: @escaping (Podcast) -> Void) {
        // This would normally fetch the podcast episodes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            var updatedPodcast = podcast
            updatedPodcast.episodes = self.getMockEpisodes(for: podcast.id)
            completion(updatedPodcast)
        }
    }
    
    private func getMockPodcasts() -> [Podcast] {
        return [
            Podcast(id: "1", title: "Tech Talk", author: "John Doe", description: "The latest in technology news and discussions.", imageUrl: "https://example.com/techtalk.jpg", feedUrl: "https://example.com/techtalk.xml"),
            Podcast(id: "2", title: "Science Hour", author: "Jane Smith", description: "Exploring the wonders of science.", imageUrl: "https://example.com/sciencehour.jpg", feedUrl: "https://example.com/sciencehour.xml"),
            Podcast(id: "3", title: "History Revisited", author: "Mark Johnson", description: "Exploring historical events and their impact.", imageUrl: "https://example.com/history.jpg", feedUrl: "https://example.com/history.xml"),
            Podcast(id: "4", title: "Coding Adventures", author: "Sarah Williams", description: "Programming tips and tricks for developers.", imageUrl: "https://example.com/coding.jpg", feedUrl: "https://example.com/coding.xml"),
            Podcast(id: "5", title: "Business Insights", author: "Robert Brown", description: "Business strategies and success stories.", imageUrl: "https://example.com/business.jpg", feedUrl: "https://example.com/business.xml")
        ]
    }
    
    private func getMockEpisodes(for podcastId: String) -> [Episode] {
        let currentDate = Date()
        let calendar = Calendar.current
        
        return [
            Episode(id: "\(podcastId)-1", title: "Episode 1", description: "This is the first episode.", audioUrl: "https://example.com/episode1.mp3", publishDate: calendar.date(byAdding: .day, value: -1, to: currentDate)!, duration: 1800),
            Episode(id: "\(podcastId)-2", title: "Episode 2", description: "This is the second episode.", audioUrl: "https://example.com/episode2.mp3", publishDate: calendar.date(byAdding: .day, value: -8, to: currentDate)!, duration: 2400),
            Episode(id: "\(podcastId)-3", title: "Episode 3", description: "This is the third episode.", audioUrl: "https://example.com/episode3.mp3", publishDate: calendar.date(byAdding: .day, value: -15, to: currentDate)!, duration: 3000),
            Episode(id: "\(podcastId)-4", title: "Episode 4", description: "This is the fourth episode.", audioUrl: "https://example.com/episode4.mp3", publishDate: calendar.date(byAdding: .day, value: -22, to: currentDate)!, duration: 1500),
            Episode(id: "\(podcastId)-5", title: "Episode 5", description: "This is the fifth episode.", audioUrl: "https://example.com/episode5.mp3", publishDate: calendar.date(byAdding: .day, value: -29, to: currentDate)!, duration: 2700)
        ]
    }
}

class AudioPlayerService: ObservableObject {
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    @Published var currentEpisode: Episode?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    func play(episode: Episode) {
        guard let url = URL(string: episode.audioUrl) else { return }
        
        // Stop current playback if any
        stop()
        
        // Create new player
        playerItem = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        // Set current episode
        currentEpisode = episode
        duration = episode.duration
        
        // Add time observer
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
        // Start playback
        audioPlayer?.play()
        isPlaying = true
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    func stop() {
        audioPlayer?.pause()
        isPlaying = false
        
        if let timeObserver = timeObserver {
            audioPlayer?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        audioPlayer = nil
        playerItem = nil
        currentEpisode = nil
        currentTime = 0
        duration = 0
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1)
        audioPlayer?.seek(to: cmTime)
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
}

class DownloadService: ObservableObject {
    @Published var downloads: [String: Float] = [:]
    
    func downloadEpisode(episode: Episode, progressHandler: @escaping (Float) -> Void, completion: @escaping (Bool) -> Void) {
        // In a real app, this would initiate a download session
        // For demo purposes, we'll simulate a download
        
        let episodeId = episode.id
        downloads[episodeId] = 0.0
        
        // Simulate download progress
        var progress: Float = 0.0
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            progress += 0.1
            self?.downloads[episodeId] = progress
            progressHandler(progress)
            
            if progress >= 1.0 {
                timer.invalidate()
                self?.downloads.removeValue(forKey: episodeId)
                completion(true)
            }
        }
    }
    
    func cancelDownload(episodeId: String) {
        downloads.removeValue(forKey: episodeId)
    }
}

// MARK: - View Models
class PodcastViewModel: ObservableObject {
    @Published var podcast: Podcast
    @Published var isLoading: Bool = false
    
    private let podcastService = PodcastService()
    
    init(podcast: Podcast) {
        self.podcast = podcast
        fetchEpisodes()
    }
    
    func fetchEpisodes() {
        isLoading = true
        podcastService.getPodcastDetails(podcast: podcast) { [weak self] updatedPodcast in
            DispatchQueue.main.async {
                self?.podcast = updatedPodcast
                self?.isLoading = false
            }
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var podcastService = PodcastService()
    @StateObject private var audioPlayerService = AudioPlayerService()
    @StateObject private var downloadService = DownloadService()
    
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    
    var body: some View {
        ZStack {
            TabView {
                DiscoverView(podcastService: podcastService, audioPlayerService: audioPlayerService)
                    .tabItem {
                        Label("Discover", systemImage: "magnifyingglass")
                    }
                
                LibraryView(audioPlayerService: audioPlayerService)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                
                DownloadsView(audioPlayerService: audioPlayerService)
                    .tabItem {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            
            if audioPlayerService.currentEpisode != nil {
                VStack {
                    Spacer()
                    MiniPlayerView(audioPlayerService: audioPlayerService)
                        .background(Color(.systemBackground))
                        .shadow(radius: 2)
                }
            }
        }
        .environmentObject(podcastService)
        .environmentObject(audioPlayerService)
        .environmentObject(downloadService)
    }
}

struct DiscoverView: View {
    @ObservedObject var podcastService: PodcastService
    @ObservedObject var audioPlayerService: AudioPlayerService
    
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, isSearching: $isSearching, onCommit: {
                    if !searchText.isEmpty {
                        podcastService.searchPodcasts(query: searchText)
                    }
                })
                .padding(.horizontal)
                
                if isSearching && !searchText.isEmpty {
                    // Search results
                    if podcastService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else {
                        PodcastListView(
                            title: "Search Results",
                            podcasts: podcastService.searchResults,
                            audioPlayerService: audioPlayerService
                        )
                    }
                } else {
                    // Featured podcasts
                    ScrollView {
                        VStack(alignment: .leading) {
                            if podcastService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding()
                            } else {
                                PodcastListView(
                                    title: "Featured Podcasts",
                                    podcasts: podcastService.featuredPodcasts,
                                    audioPlayerService: audioPlayerService
                                )
                                
                                PodcastGridView(
                                    title: "Popular Podcasts",
                                    podcasts: Array(podcastService.featuredPodcasts.prefix(4)),
                                    audioPlayerService: audioPlayerService
                                )
                                
                                PodcastListView(
                                    title: "Recommended For You",
                                    podcasts: Array(podcastService.featuredPodcasts.suffix(3)),
                                    audioPlayerService: audioPlayerService
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Discover")
            .onAppear {
                if podcastService.featuredPodcasts.isEmpty {
                    podcastService.fetchFeaturedPodcasts()
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    var onCommit: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search podcasts", text: $text, onCommit: onCommit)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.trailing, 8)
                .onTapGesture {
                    isSearching = true
                }
            
            if isSearching {
                Button("Cancel") {
                    text = ""
                    isSearching = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .foregroundColor(.blue)
            }
        }
    }
}

struct PodcastListView: View {
    var title: String
    var podcasts: [Podcast]
    @ObservedObject var audioPlayerService: AudioPlayerService
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.vertical, 8)
            
            ForEach(podcasts) { podcast in
                NavigationLink(destination: PodcastDetailView(podcast: podcast, audioPlayerService: audioPlayerService)) {
                    PodcastRowView(podcast: podcast)
                }
            }
        }
    }
}

struct PodcastGridView: View {
    var title: String
    var podcasts: [Podcast]
    @ObservedObject var audioPlayerService: AudioPlayerService
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.vertical, 8)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(podcasts) { podcast in
                    NavigationLink(destination: PodcastDetailView(podcast: podcast, audioPlayerService: audioPlayerService)) {
                        PodcastGridItemView(podcast: podcast)
                    }
                }
            }
        }
    }
}

struct PodcastRowView: View {
    var podcast: Podcast
    
    var body: some View {
        HStack {
            // In a real app, you would use AsyncImage for iOS 15+ or a custom image loader
            Color.gray
                .frame(width: 60, height: 60)
                .cornerRadius(4)
                .overlay(
                    Text(podcast.title.prefix(1))
                        .foregroundColor(.white)
                        .font(.title)
                )
            
            VStack(alignment: .leading) {
                Text(podcast.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(podcast.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PodcastGridItemView: View {
    var podcast: Podcast
    
    var body: some View {
        VStack {
            // In a real app, you would use AsyncImage for iOS 15+ or a custom image loader
            Color.gray
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(8)
                .overlay(
                    Text(podcast.title.prefix(1))
                        .foregroundColor(.white)
                        .font(.largeTitle)
                )
            
            Text(podcast.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }
}

struct PodcastDetailView: View {
    @StateObject private var viewModel: PodcastViewModel
    @ObservedObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var downloadService: DownloadService
    
    init(podcast: Podcast, audioPlayerService: AudioPlayerService) {
        _viewModel = StateObject(wrappedValue: PodcastViewModel(podcast: podcast))
        self.audioPlayerService = audioPlayerService
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Podcast header
                HStack(alignment: .top) {
                    // In a real app, you would use AsyncImage for iOS 15+ or a custom image loader
                    Color.gray
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                        .overlay(
                            Text(viewModel.podcast.title.prefix(1))
                                .foregroundColor(.white)
                                .font(.largeTitle)
                        )
                    
                    VStack(alignment: .leading) {
                        Text(viewModel.podcast.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(2)
                        
                        Text(viewModel.podcast.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button(action: {
                                // Subscribe action
                            }) {
                                Label("Subscribe", systemImage: "plus.circle")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    .padding(.leading, 8)
                }
                .padding(.bottom, 16)
                
                // Description
                Text("About")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Text(viewModel.podcast.description)
                    .font(.body)
                    .lineLimit(nil)
                    .padding(.bottom, 16)
                
                // Episodes
                HStack {
                    Text("Episodes")
                        .font(.headline)
                    
                    Spacer()
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .padding(.bottom, 8)
                
                if let episodes = viewModel.podcast.episodes {
                    ForEach(episodes) { episode in
                        EpisodeRowView(
                            episode: episode,
                            audioPlayerService: audioPlayerService,
                            downloadService: downloadService
                        )
                        .padding(.vertical, 4)
                        
                        Divider()
                    }
                } else {
                    Text("No episodes available")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Podcast")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EpisodeRowView: View {
    var episode: Episode
    @ObservedObject var audioPlayerService: AudioPlayerService
    @ObservedObject var downloadService: DownloadService
    
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Float = 0.0
    @State private var showingOptions: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(episode.title)
                .font(.headline)
                .lineLimit(1)
            
            HStack {
                Text(formattedDate(episode.publishDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formattedDuration(episode.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if episode.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                } else if let progress = downloadService.downloads[episode.id], progress < 1.0 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 40)
                }
            }
            
            Text(episode.description)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundColor(.secondary)
                .padding(.top, 2)
            
            HStack {
                Button(action: {
                    if episode.id == audioPlayerService.currentEpisode?.id {
                        audioPlayerService.togglePlayback()
                    } else {
                        audioPlayerService.play(episode: episode)
                    }
                }) {
                    HStack {
                        Image(systemName: (episode.id == audioPlayerService.currentEpisode?.id && audioPlayerService.isPlaying) ? "pause.fill" : "play.fill")
                        
                        Text((episode.id == audioPlayerService.currentEpisode?.id && audioPlayerService.isPlaying) ? "Pause" : "Play")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(20)
                }
                
                Spacer()
                
                Button(action: {
                    showingOptions = true
                }) {
                    Image(systemName: "ellipsis")
                        .padding(8)
                }
                .actionSheet(isPresented: $showingOptions) {
                    ActionSheet(
                        title: Text(episode.title),
                        buttons: [
                            .default(Text(episode.isDownloaded ? "Delete Download" : "Download Episode")) {
                                if episode.isDownloaded {
                                    // Delete download logic
                                } else {
                                    isDownloading = true
                                    downloadService.downloadEpisode(
                                        episode: episode,
                                        progressHandler: { progress in
                                            self.downloadProgress = progress
                                        },
                                        completion: { success in
                                            isDownloading = false
                                            // In a real app, you would update the episode's isDownloaded status
                                        }
                                    )
                                }
                            },
                            .default(Text("Share Episode")) {
                                // Share logic
                            },
                            .cancel()
                        ]
                    )
                }
            }
            .padding(.top, 8)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct MiniPlayerView: View {
    @ObservedObject var audioPlayerService: AudioPlayerService
    @State private var showFullPlayer: Bool = false
    
    var body: some View {
        if let episode = audioPlayerService.currentEpisode {
            VStack {
                HStack {
                    // Episode image
                    Color.gray
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                    
                    // Title and author
                    VStack(alignment: .leading) {
                        Text(episode.title)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Play/Pause button
                    Button(action: {
                        audioPlayerService.togglePlayback()
                    }) {
                        Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .padding(8)
                    }
                    
                    // Next button (disabled in this simplified version)
                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .padding(8)
                    }
                }
                .padding(.horizontal)
                
                // Progress bar
                ProgressView(value: audioPlayerService.currentTime, total: audioPlayerService.duration)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .onTapGesture {
                showFullPlayer = true
            }
            .sheet(isPresented: $showFullPlayer) {
                FullPlayerView(audioPlayerService: audioPlayerService)
            }
        } else {
            EmptyView()
        }
    }
}

struct FullPlayerView: View {
    @ObservedObject var audioPlayerService: AudioPlayerService
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            // Navigation bar
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.down")
                        .padding()
                }
                
                Spacer()
                
                Text("Now Playing")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    // Show options
                }) {
                    Image(systemName: "ellipsis")
                        .padding()
                }
            }
            
            Spacer()
            
            // Podcast artwork
            Color.gray
                .frame(width: 300, height: 300)
                .cornerRadius(8)
                .overlay(
                    Text(audioPlayerService.currentEpisode?.title.prefix(1) ?? "")
                        .foregroundColor(.white)
                        .font(.system(size: 100))
                )
                .padding(.bottom, 40)
            
            // Episode info
            VStack(spacing: 4) {
                Text(audioPlayerService.currentEpisode?.title ?? "")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal)
            }
            .padding(.bottom, 40)
            
            // Playback controls
            VStack {
                // Time slider
                HStack {
                    Text(formatTime(audioPlayerService.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { audioPlayerService.currentTime },
                            set: { audioPlayerService.seek(to: $0) }
                        ),
                        in: 0...max(audioPlayerService.duration, 1)
                    )
                    
                    Text(formatTime(audioPlayerService.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Playback buttons
                HStack(spacing: 40) {
                    Button(action: {
                        // Skip backward
                        let newTime = max(audioPlayerService.currentTime - 15, 0)
                        audioPlayerService.seek(to: newTime)
                    }) {
                        Image(systemName: "gobackward.15")
                            .font(.title)
                    }
                    
                    Button(action: {
                        audioPlayerService.togglePlayback()
                    }) {
                        Image(systemName: audioPlayerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 70))
                    }
                    
                    Button(action: {
                        // Skip forward
                        let newTime = min(audioPlayerService.currentTime + 30, audioPlayerService.duration)
                        audioPlayerService.seek(to: newTime)
                    }) {
                        Image(systemName: "goforward.30")
                            .font(.title)
                    }
                }
                .padding()
                
                // Playback speed
                HStack {
                    Spacer()
                    
                    Button(action: {
                        // Toggle playback speed
                    }) {
                        Text("1.0x")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Sleep timer
                    }) {
                        Image(systemName: "timer")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct LibraryView: View {
    @ObservedObject var audioPlayerService: AudioPlayerService
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Your subscriptions will appear here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Library")
        }
    }
}

struct DownloadsView: View {
    @ObservedObject var audioPlayerService: AudioPlayerService
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Your downloaded episodes will appear here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Downloads")
        }
    }
}

struct SettingsView: View {
    @AppStorage("autoDownload") private var autoDownload: Bool = false
    @AppStorage("streamingQuality") private var streamingQuality: String = "High"
    @AppStorage("downloadQuality") private var downloadQuality: String = "Normal"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Playback")) {
                    Toggle("Continuous Playback", isOn: .constant(true))
                    
                    Picker("Streaming Quality", selection: $streamingQuality) {
                        Text("High").tag("High")
                        Text("Normal").tag("Normal")
                        Text("Low").tag("Low")
                    }
                }
                
                Section(header: Text("Downloads")) {
                    Toggle("Auto Download New Episodes", isOn: $autoDownload)
                    
                    Picker("Download Quality", selection: $downloadQuality) {
                        Text("High").tag("High")
                        Text("Normal").tag("Normal")
                        Text("Low").tag("Low")
                    }
                    
                    HStack {
                        Text("Storage Used")
                        Spacer()
                        Text("0 MB")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        // Clear downloads
                    }) {
                        Text("Clear All Downloads")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        // Rate app
                    }) {
                        Text("Rate the App")
                    }
                    
                    Button(action: {
                        // Contact support
                    }) {
                        Text("Contact Support")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

@main
struct PodcastsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
