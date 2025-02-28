import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - App Entry Point
@main
struct PodcastsApp: App {
    // Add key in Info.plist: UIBackgroundModes with values: audio, fetch
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Request notification permissions for playback controls
                    UIApplication.shared.beginReceivingRemoteControlEvents()
                    
                    // Prevent screen from dimming during playback
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                .onDisappear {
                    UIApplication.shared.endReceivingRemoteControlEvents()
                    UIApplication.shared.isIdleTimerDisabled = false
                }
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var podcastService = PodcastService()
    @StateObject private var downloadService = DownloadService()
    @StateObject private var audioPlayerService = AudioPlayerService()
    @StateObject private var networkMonitor = NetworkMonitor()
    
    var body: some View {
        ZStack {
            TabView {
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                
                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock")
                    }
                
                DownloadsView()
                    .tabItem {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }
                
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            
            // Mini player that appears when something is playing
            if audioPlayerService.currentEpisode != nil {
                VStack {
                    Spacer()
                    MiniPlayerView()
                        .background(Color(.systemBackground))
                        .shadow(radius: 2)
                }
            }
            
            // Network warning overlay
            if !networkMonitor.isConnected {
                VStack {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("No internet connection")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    
                    Spacer()
                }
            }
        }
        .environmentObject(podcastService)
        .environmentObject(downloadService)
        .environmentObject(audioPlayerService)
    }
}

// MARK: - Library View
struct LibraryView: View {
    @EnvironmentObject var podcastService: PodcastService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @State private var subscribedPodcasts: [Podcast] = []
    @State private var refreshing = false
    
    var body: some View {
        NavigationView {
            Group {
                if subscribedPodcasts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "mic")
                            .font(.system(size: 72))
                            .foregroundColor(.secondary)
                        
                        Text("No podcasts yet")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Search for podcasts to add to your library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        NavigationLink(destination: SearchView()) {
                            Text("Search Podcasts")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(subscribedPodcasts) { podcast in
                            NavigationLink(destination: PodcastDetailView(podcast: podcast)) {
                                PodcastRowView(podcast: podcast)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        refreshing = true
                        // In a real app, you would refresh podcast feeds here
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        loadSubscribedPodcasts()
                        refreshing = false
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SearchView()) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .onAppear {
                loadSubscribedPodcasts()
            }
        }
    }
    
    private func loadSubscribedPodcasts() {
        subscribedPodcasts = podcastService.getSubscribedPodcasts()
    }
}

// MARK: - History View
struct HistoryView: View {
    @EnvironmentObject var podcastService: PodcastService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @State private var recentlyPlayedEpisodes: [Episode] = []
    @State private var inProgressEpisodes: [Episode] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !inProgressEpisodes.isEmpty {
                        Text("In Progress")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(inProgressEpisodes) { episode in
                                    InProgressEpisodeCard(episode: episode)
                                        .frame(width: 280, height: 150)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    if !recentlyPlayedEpisodes.isEmpty {
                        Text("Recently Played")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .padding(.top, inProgressEpisodes.isEmpty ? 0 : 20)
                        
                        ForEach(recentlyPlayedEpisodes) { episode in
                            HistoryEpisodeRow(episode: episode)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                    }
                    
                    if inProgressEpisodes.isEmpty && recentlyPlayedEpisodes.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "clock")
                                .font(.system(size: 72))
                                .foregroundColor(.secondary)
                            
                            Text("No playback history")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Episodes you've listened to will appear here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("History")
            .onAppear {
                loadPlaybackHistory()
            }
        }
    }
    
    private func loadPlaybackHistory() {
        inProgressEpisodes = podcastService.getInProgressEpisodes()
        recentlyPlayedEpisodes = podcastService.getRecentlyPlayedEpisodes()
    }
}

struct InProgressEpisodeCard: View {
    var episode: Episode
    @EnvironmentObject var podcastService: PodcastService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @State private var podcast: Podcast?
    
    var body: some View {
        Button(action: {
            audioPlayerService.play(episode: episode)
        }) {
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                
                // Progress bar
                VStack(spacing: 0) {
                    Spacer()
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(height: 4)
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: episode.duration > 0 ? CGFloat(episode.playProgress / episode.duration) * geometry.size.width : 0, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    if let podcast = podcast {
                        Text(podcast.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(episode.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack {
                        Text("\(formatTime(episode.playProgress)) / \(formatTime(episode.duration))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(episode.playProgress / episode.duration * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Image(systemName: "play.fill")
                            .foregroundColor(.blue)
                        
                        Text("Continue")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                }
                .padding(12)
            }
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Find the podcast this episode belongs to
            if let podcastId = episode.podcastId.isEmpty ? nil : episode.podcastId {
                podcast = podcastService.persistenceController.getPodcast(id: podcastId)
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct HistoryEpisodeRow: View {
    var episode: Episode
    @EnvironmentObject var podcastService: PodcastService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @State private var podcast: Podcast?
    
    var body: some View {
        Button(action: {
            audioPlayerService.play(episode: episode)
        }) {
            HStack(spacing: 12) {
                // Podcast artwork placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    if let podcast = podcast, let url = URL(string: podcast.imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Color.gray.opacity(0.2)
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            case .failure:
                                Image(systemName: "waveform")
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                    } else {
                        Image(systemName: "waveform")
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 60, height: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let podcast = podcast {
                        Text(podcast.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(episode.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack {
                        if let lastPlayed = episode.lastPlayedDate {
                            Text(formatDate(lastPlayed))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if episode.isPlayed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Find the podcast this episode belongs to
            if let podcastId = episode.podcastId.isEmpty ? nil : episode.podcastId {
                podcast = podcastService.persistenceController.getPodcast(id: podcastId)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Podcast Detail View
struct PodcastDetailView: View {
    @EnvironmentObject var podcastService: PodcastService
    @EnvironmentObject var downloadService: DownloadService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    
    var podcast: Podcast
    @State private var episodes: [Episode] = []
    @State private var showingUnsubscribeAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            PodcastHeaderView(podcast: podcast)
                .padding()
                .background(Color(.systemBackground))
            
            Divider()
            
            // Episodes List
            List {
                ForEach(episodes) { episode in
                    EpisodeRowView(episode: episode)
                        .padding(.vertical, 8)
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle(podcast.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingUnsubscribeAlert = true
                }) {
                    Image(systemName: "ellipsis")
                }
                .alert("Unsubscribe from \(podcast.title)", isPresented: $showingUnsubscribeAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Unsubscribe", role: .destructive) {
                        podcastService.unsubscribeFromPodcast(id: podcast.id)
                    }
                } message: {
                    Text("You will no longer receive new episodes for this podcast.")
                }
            }
        }
        .onAppear {
            loadEpisodes()
        }
    }
    
    private func loadEpisodes() {
        episodes = podcastService.getEpisodesForPodcast(podcastId: podcast.id)
    }
}

// MARK: - Mini Player
struct MiniPlayerView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @State private var showFullPlayer = false
    
    var body: some View {
        if let episode = audioPlayerService.currentEpisode {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: audioPlayerService.duration > 0 ? CGFloat(audioPlayerService.currentTime / audioPlayerService.duration) * geometry.size.width : 0, height: 2)
                    }
                }
                .frame(height: 2)
                
                HStack {
                    // Episode title
                    VStack(alignment: .leading) {
                        Text(episode.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text(formatTime(audioPlayerService.currentTime) + " / " + formatTime(audioPlayerService.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Playback controls
                    HStack(spacing: 20) {
                        Button(action: {
                            audioPlayerService.skipBackward()
                        }) {
                            Image(systemName: "gobackward.15")
                                .font(.title3)
                        }
                        
                        Button(action: {
                            audioPlayerService.togglePlayback()
                        }) {
                            Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        
                        Button(action: {
                            audioPlayerService.skipForward()
                        }) {
                            Image(systemName: "goforward.30")
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            .background(
                Color(.systemBackground)
                    .onTapGesture {
                        showFullPlayer = true
                    }
            )
            .sheet(isPresented: $showFullPlayer) {
                FullPlayerView()
            }
        } else {
            EmptyView()
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

// MARK: - Full Player
struct FullPlayerView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var podcastService: PodcastService
    @Environment(\.presentationMode) var presentationMode
    @State private var showRateOptions = false
    @State private var podcast: Podcast?
    
    var body: some View {
        VStack {
            // Dismiss button
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.title3)
                        .padding()
                }
                
                Spacer()
                
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
            }
            
            Spacer()
            
            if let episode = audioPlayerService.currentEpisode {
                // Episode artwork
                Group {
                    if let podcast = podcast, let url = URL(string: podcast.imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                podcastArtworkPlaceholder
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(12)
                            case .failure:
                                podcastArtworkPlaceholder
                            @unknown default:
                                podcastArtworkPlaceholder
                            }
                        }
                        .frame(width: 300, height: 300)
                    } else {
                        podcastArtworkPlaceholder
                    }
                }
                .padding(.bottom, 40)
                
                // Podcast & Episode info
                if let podcast = podcast {
                    Text(podcast.title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Text(episode.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal)
                
                Spacer()
                
                // Playback controls
                VStack(spacing: 20) {
                    // Playback slider and time
                    VStack(spacing: 8) {
                        Slider(
                            value: Binding<Double>(
                                get: { audioPlayerService.currentTime },
                                set: { audioPlayerService.seek(to: $0) }
                            ),
                            in: 0...max(audioPlayerService.duration, 1)
                        )
                        .padding(.horizontal)
                        
                        HStack {
                            Text(formatTime(audioPlayerService.currentTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(formatTime(audioPlayerService.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Main playback controls
                    HStack(spacing: 50) {
                        Button(action: {
                            audioPlayerService.skipBackward()
                        }) {
                            Image(systemName: "gobackward.15")
                                .font(.largeTitle)
                        }
                        
                        Button(action: {
                            audioPlayerService.togglePlayback()
                        }) {
                            Image(systemName: audioPlayerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 80))
                        }
                        
                        Button(action: {
                            audioPlayerService.skipForward()
                        }) {
                            Image(systemName: "goforward.30")
                                .font(.largeTitle)
                        }
                    }
                    .padding(.vertical)
                    
                    // Speed control
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            showRateOptions = true
                        }) {
                            Text("\(String(format: "%.1fx", audioPlayerService.playbackRate))")
                                .font(.footnote)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                        }
                        .confirmationDialog("Playback Speed", isPresented: $showRateOptions) {
                            Button("0.5x") { audioPlayerService.setPlaybackRate(0.5) }
                            Button("0.8x") { audioPlayerService.setPlaybackRate(0.8) }
                            Button("1.0x") { audioPlayerService.setPlaybackRate(1.0) }
                            Button("1.2x") { audioPlayerService.setPlaybackRate(1.2) }
                            Button("1.5x") { audioPlayerService.setPlaybackRate(1.5) }
                            Button("2.0x") { audioPlayerService.setPlaybackRate(2.0) }
                            Button("Cancel", role: .cancel) { }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                Text("No episode playing")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .onAppear {
            loadPodcastInfo()
        }
    }
    
    private var podcastArtworkPlaceholder: some View {
        Color.gray
            .frame(width: 300, height: 300)
            .cornerRadius(12)
            .overlay(
                Image(systemName: "headphones")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(80)
                    .foregroundColor(.white)
            )
    }
    
    private func loadPodcastInfo() {
        if let episode = audioPlayerService.currentEpisode,
           let podcastId = episode.podcastId.isEmpty ? nil : episode.podcastId {
            podcast = podcastService.persistenceController.getPodcast(id: podcastId)
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

// MARK: - Supporting Views
struct PodcastHeaderView: View {
    var podcast: Podcast
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Podcast image
            AsyncImage(url: URL(string: podcast.imageUrl)) { phase in
                switch phase {
                case .empty:
                    Color.gray
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                case .failure:
                    Color.gray
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 100, height: 100)
            
            // Podcast info
            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(podcast.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
Text(podcast.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.top, 4)
            }
        }
    }
}

struct PodcastRowView: View {
    var podcast: Podcast
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: podcast.imageUrl)) { phase in
                switch phase {
                case .empty:
                    Color.gray
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                case .failure:
                    Color.gray
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(podcast.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EpisodeRowView: View {
    var episode: Episode
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var downloadService: DownloadService
    @State private var showOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(episode.title)
                .font(.headline)
                .lineLimit(2)
            
            // Metadata
            HStack {
                Text(formatDate(episode.publishDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatDuration(episode.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if episode.isPlayed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                if episode.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                } else if let progress = downloadService.getDownloadStatus(episodeId: episode.id) {
                    // Show download progress
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 40)
                }
            }
            
            // Description
            if !episode.description.isEmpty {
                Text(episode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
            
            // Control buttons
            HStack {
                Button(action: {
                    if audioPlayerService.currentEpisode?.id == episode.id {
                        audioPlayerService.togglePlayback()
                    } else {
                        audioPlayerService.play(episode: episode)
                    }
                }) {
                    HStack {
                        Image(systemName: (audioPlayerService.currentEpisode?.id == episode.id && audioPlayerService.isPlaying) ? "pause.fill" : "play.fill")
                        
                        Text((audioPlayerService.currentEpisode?.id == episode.id && audioPlayerService.isPlaying) ? "Pause" : "Play")
                    }
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                
                if !episode.isDownloaded && downloadService.getDownloadStatus(episodeId: episode.id) == nil {
                    Button(action: {
                        downloadService.downloadEpisode(episode: episode)
                    }) {
                        HStack {
                            Image(systemName: "arrow.down")
                            Text("Download")
                        }
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                    }
                } else if downloadService.getDownloadStatus(episodeId: episode.id) != nil {
                    Button(action: {
                        downloadService.cancelDownload(episodeId: episode.id)
                    }) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Cancel")
                        }
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                    }
                } else if episode.isDownloaded {
                    Button(action: {
                        showOptions = true
                    }) {
                        Image(systemName: "ellipsis")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(16)
                    }
                    .confirmationDialog("Episode Options", isPresented: $showOptions) {
                        Button("Delete Download", role: .destructive) {
                            downloadService.deleteDownload(episodeId: episode.id)
                        }
                        
                        Button("Mark as \(episode.isPlayed ? "Unplayed" : "Played")") {
                            let context = PersistenceController.shared.container.viewContext
                            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDEpisode")
                            fetchRequest.predicate = NSPredicate(format: "id == %@", episode.id)
                            
                            do {
                                if let episodeObject = try context.fetch(fetchRequest).first as? NSManagedObject {
                                    episodeObject.setValue(!episode.isPlayed, forKey: "isPlayed")
                                    episodeObject.setValue(episode.isPlayed ? nil : Date(), forKey: "lastPlayedDate")
                                    try context.save()
                                }
                            } catch {
                                print("Failed to mark episode as played: \(error)")
                            }
                        }
                        
                        Button("Cancel", role: .cancel) { }
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Downloads View
struct DownloadsView: View {
    @EnvironmentObject var podcastService: PodcastService
    @EnvironmentObject var downloadService: DownloadService
    @State private var downloadedEpisodes: [Episode] = []
    @State private var showClearAllAlert = false
    @State private var totalStorage: String = "0 MB"
    
    var body: some View {
        NavigationView {
            Group {
                if downloadedEpisodes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 72))
                            .foregroundColor(.secondary)
                        
                        Text("No Downloads")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Episodes you download will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack {
                        // Storage indicator
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                            
                            Text("Storage used:")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(totalStorage)
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding()
                        
                        List {
                            ForEach(downloadedEpisodes) { episode in
                                DownloadedEpisodeRow(episode: episode)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                if !downloadedEpisodes.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showClearAllAlert = true
                        }) {
                            Text("Clear All")
                        }
                        .alert("Delete All Downloads", isPresented: $showClearAllAlert) {
                            Button("Cancel", role: .cancel) { }
                            Button("Delete All", role: .destructive) {
                                downloadService.deleteAllDownloads()
                                loadDownloadedEpisodes()
                            }
                        } message: {
                            Text("This will remove all downloaded episodes. This action cannot be undone.")
                        }
                    }
                }
            }
            .onAppear {
                loadDownloadedEpisodes()
                calculateTotalStorage()
            }
        }
    }
    
    private func loadDownloadedEpisodes() {
        downloadedEpisodes = podcastService.getDownloadedEpisodes()
    }
    
    private func calculateTotalStorage() {
        let totalSize = downloadService.getTotalDownloadsSize()
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        totalStorage = formatter.string(fromByteCount: totalSize)
    }
}

struct DownloadedEpisodeRow: View {
    var episode: Episode
    @State private var podcast: Podcast?
    @EnvironmentObject var podcastService: PodcastService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var downloadService: DownloadService
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let podcast = podcast {
                Text(podcast.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Text(episode.title)
                .font(.headline)
                .lineLimit(2)
            
            HStack {
                Text(formatDate(episode.publishDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatDuration(episode.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatFileSize(episode.fileSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button(action: {
                    if audioPlayerService.currentEpisode?.id == episode.id {
                        audioPlayerService.togglePlayback()
                    } else {
                        audioPlayerService.play(episode: episode)
                    }
                }) {
                    HStack {
                        Image(systemName: (audioPlayerService.currentEpisode?.id == episode.id && audioPlayerService.isPlaying) ? "pause.fill" : "play.fill")
                        
                        Text((audioPlayerService.currentEpisode?.id == episode.id && audioPlayerService.isPlaying) ? "Pause" : "Play")
                    }
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                
                Button(action: {
                    showDeleteAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
                }
                .alert("Delete Download", isPresented: $showDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        downloadService.deleteDownload(episodeId: episode.id)
                    }
                } message: {
                    Text("Are you sure you want to delete this download?")
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            // Find the podcast that this episode belongs to
            if let podcastId = episode.podcastId.isEmpty ? nil : episode.podcastId {
                podcast = podcastService.persistenceController.getPodcast(id: podcastId)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Search View
struct SearchView: View {
    @EnvironmentObject var podcastService: PodcastService
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search podcasts", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            // Cancel previous search task
                            searchTask?.cancel()
                            
                            // Debounce search
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                if !Task.isCancelled {
                                    DispatchQueue.main.async {
                                        debouncedSearchText = newValue
                                        if !newValue.isEmpty {
                                            podcastService.searchPodcasts(query: newValue)
                                        }
                                    }
                                }
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            debouncedSearchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                
                // Search results or suggestions
                Group {
                    if debouncedSearchText.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 64))
                                .foregroundColor(.secondary)
                            
                            Text("Search for podcasts")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Enter a podcast name, topic, or author to find new shows")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                    } else if podcastService.isLoading {
                        ProgressView("Searching...")
                            .progressViewStyle(CircularProgressViewStyle())
                    } else if let errorMessage = podcastService.errorMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 64))
                                .foregroundColor(.orange)
                                .padding()
                            
                            Text("Error")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(errorMessage)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                    } else if podcastService.searchResults.isEmpty {
                        VStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 64))
                                .foregroundColor(.secondary)
                                .padding()
                            
                            Text("No results found")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Try a different search term")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        List {
                            ForEach(podcastService.searchResults) { podcast in
                                Button(action: {
                                    showSubscribeSheet(podcast: podcast)
                                }) {
                                    PodcastRowView(podcast: podcast)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("Search")
        }
    }
    
    @State private var selectedPodcast: Podcast? = nil
    @State private var showingSubscribeSheet = false
    @State private var isSubscribing = false
    @State private var subscribeError: String? = nil
    
    private func showSubscribeSheet(podcast: Podcast) {
        selectedPodcast = podcast
        showingSubscribeSheet = true
    }
    
    var subscribePodcastSheet: some View {
        Group {
            if let podcast = selectedPodcast {
                VStack {
                    // Podcast header
                    PodcastHeaderView(podcast: podcast)
                        .padding()
                    
                    Spacer()
                    
                    if isSubscribing {
                        ProgressView("Subscribing...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else if let error = subscribeError {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(.orange)
                                .padding()
                            
                            Text("Failed to subscribe")
                                .font(.headline)
                            
                            Text(error)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Button("Try Again") {
                                subscribeToPodcast()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    } else {
                        Button(action: {
                            subscribeToPodcast()
                        }) {
                            Text("Subscribe")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding()
                    }
                }
                .sheet(isPresented: $showingSubscribeSheet) {
                    // Reset state when sheet is dismissed
                    isSubscribing = false
                    subscribeError = nil
                }
            }
        }
    }
    
    private func subscribeToPodcast() {
        guard let podcast = selectedPodcast else { return }
        
        isSubscribing = true
        subscribeError = nil
        
        podcastService.subscribeToPodcast(podcast) { result in
            isSubscribing = false
            
            switch result {
            case .success(_):
                showingSubscribeSheet = false
            case .failure(let error):
                subscribeError = error.localizedDescription
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("autoDownload") private var autoDownload = false
    @AppStorage("deleteCompletedEpisodes") private var deleteCompletedEpisodes = false
    @AppStorage("streamingQuality") private var streamingQuality = "High"
    @AppStorage("downloadQuality") private var downloadQuality = "Standard"
    @State private var storageUsed: String = "0 MB"
    @State private var appVersion: String = "1.0.0"
    @EnvironmentObject var downloadService: DownloadService
    @State private var showDeleteAllAlert = false
    @State private var showResetHistoryAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Playback")) {
                    Picker("Streaming Quality", selection: $streamingQuality) {
                        Text("Low").tag("Low")
                        Text("Standard").tag("Standard")
                        Text("High").tag("High")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Toggle("Delete Completed Episodes", isOn: $deleteCompletedEpisodes)
                }
                
                Section(header: Text("Downloads")) {
                    Toggle("Auto-Download New Episodes", isOn: $autoDownload)
                    
                    Picker("Download Quality", selection: $downloadQuality) {
                        Text("Low").tag("Low")
                        Text("Standard").tag("Standard")
                        Text("High").tag("High")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    HStack {
                        Text("Storage Used")
                        Spacer()
                        Text(storageUsed)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        showDeleteAllAlert = true
                    }) {
                        Text("Delete All Downloads")
                            .foregroundColor(.red)
                    }
                    .alert("Delete All Downloads", isPresented: $showDeleteAllAlert) {
                        Button("Cancel", role: .cancel) { }
                        Button("Delete", role: .destructive) {
                            downloadService.deleteAllDownloads()
                            calculateStorageUsed()
                        }
                    } message: {
                        Text("This will remove all downloaded episodes. This action cannot be undone.")
                    }
                }
                
                Section(header: Text("History")) {
                    Button(action: {
                        showResetHistoryAlert = true
                    }) {
                        Text("Reset Playback History")
                            .foregroundColor(.red)
                    }
                    .alert("Reset Playback History", isPresented: $showResetHistoryAlert) {
                        Button("Cancel", role: .cancel) { }
                        Button("Reset", role: .destructive) {
                            PersistenceController.shared.resetPlaybackHistory()
                        }
                    } message: {
                        Text("This will clear all play progress and history. This action cannot be undone.")
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                calculateStorageUsed()
            }
        }
    }
    
    private func calculateStorageUsed() {
        // Get the total size of all downloaded episodes
        let totalSize = downloadService.getTotalDownloadsSize()
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        storageUsed = formatter.string(fromByteCount: totalSize)
    }
}
