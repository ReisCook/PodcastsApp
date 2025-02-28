import SwiftUI
import AVFoundation
import Combine
import CoreData
import XMLCoder
import Network

// MARK: - Models
struct Podcast: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var author: String
    var description: String
    var imageUrl: String
    var feedUrl: String
    var isSubscribed: Bool = false
    
    static func == (lhs: Podcast, rhs: Podcast) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Episode: Identifiable, Hashable, Codable {
    var id: String
    var podcastId: String
    var title: String
    var description: String
    var audioUrl: String
    var publishDate: Date
    var duration: TimeInterval
    var fileSize: Int64
    var isDownloaded: Bool = false
    var downloadPath: String? = nil
    var playProgress: TimeInterval = 0
    
    static func == (lhs: Episode, rhs: Episode) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - RSS Feed Models
struct RSSFeed: Codable {
    let channel: Channel
}

struct Channel: Codable {
    let title: String
    let description: String
    let link: String
    let image: RSSImage?
    let author: String?
    let items: [Item]
    
    enum CodingKeys: String, CodingKey {
        case title, description, link, image, author = "itunes:author", items = "item"
    }
}

struct RSSImage: Codable {
    let url: String
    let title: String?
    let link: String?
}

struct Item: Codable {
    let title: String
    let description: String?
    let pubDate: String?
    let enclosure: Enclosure?
    let guid: GUID
    let duration: String?
    
    enum CodingKeys: String, CodingKey {
        case title, description, pubDate, enclosure, guid
        case duration = "itunes:duration"
    }
}

struct Enclosure: Codable {
    let url: String
    let length: String?
    let type: String?
}

struct GUID: Codable {
    let value: String
    
    enum CodingKeys: String, CodingKey {
        case value = ""
    }
}

// MARK: - Core Data Model
class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "PodcastModel")
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error loading Core Data: \(error.localizedDescription)")
            }
        }
        
        // Create model if it doesn't exist
        let modelURL = Bundle.main.url(forResource: "PodcastModel", withExtension: "momd")
        if modelURL == nil {
            createCoreDataModel()
        }
    }
    
    private func createCoreDataModel() {
        let managedObjectModel = NSManagedObjectModel()
        
        // Podcast Entity
        let podcastEntity = NSEntityDescription()
        podcastEntity.name = "CDPodcast"
        podcastEntity.managedObjectClassName = "CDPodcast"
        
        let podcastId = NSAttributeDescription()
        podcastId.name = "id"
        podcastId.attributeType = .stringAttributeType
        podcastId.isOptional = false
        
        let podcastTitle = NSAttributeDescription()
        podcastTitle.name = "title"
        podcastTitle.attributeType = .stringAttributeType
        podcastTitle.isOptional = false
        
        let podcastAuthor = NSAttributeDescription()
        podcastAuthor.name = "author"
        podcastAuthor.attributeType = .stringAttributeType
        podcastAuthor.isOptional = true
        
        let podcastDesc = NSAttributeDescription()
        podcastDesc.name = "podcastDescription"
        podcastDesc.attributeType = .stringAttributeType
        podcastDesc.isOptional = true
        
        let podcastImageUrl = NSAttributeDescription()
        podcastImageUrl.name = "imageUrl"
        podcastImageUrl.attributeType = .stringAttributeType
        podcastImageUrl.isOptional = true
        
        let podcastFeedUrl = NSAttributeDescription()
        podcastFeedUrl.name = "feedUrl"
        podcastFeedUrl.attributeType = .stringAttributeType
        podcastFeedUrl.isOptional = false
        
        let podcastIsSubscribed = NSAttributeDescription()
        podcastIsSubscribed.name = "isSubscribed"
        podcastIsSubscribed.attributeType = .booleanAttributeType
        podcastIsSubscribed.defaultValue = false
        
        podcastEntity.properties = [podcastId, podcastTitle, podcastAuthor, podcastDesc, podcastImageUrl, podcastFeedUrl, podcastIsSubscribed]
        
        // Episode Entity
        let episodeEntity = NSEntityDescription()
        episodeEntity.name = "CDEpisode"
        episodeEntity.managedObjectClassName = "CDEpisode"
        
        let episodeId = NSAttributeDescription()
        episodeId.name = "id"
        episodeId.attributeType = .stringAttributeType
        episodeId.isOptional = false
        
        let episodePodcastId = NSAttributeDescription()
        episodePodcastId.name = "podcastId"
        episodePodcastId.attributeType = .stringAttributeType
        episodePodcastId.isOptional = false
        
        let episodeTitle = NSAttributeDescription()
        episodeTitle.name = "title"
        episodeTitle.attributeType = .stringAttributeType
        episodeTitle.isOptional = false
        
        let episodeDesc = NSAttributeDescription()
        episodeDesc.name = "episodeDescription"
        episodeDesc.attributeType = .stringAttributeType
        episodeDesc.isOptional = true
        
        let episodeAudioUrl = NSAttributeDescription()
        episodeAudioUrl.name = "audioUrl"
        episodeAudioUrl.attributeType = .stringAttributeType
        episodeAudioUrl.isOptional = false
        
        let episodePublishDate = NSAttributeDescription()
        episodePublishDate.name = "publishDate"
        episodePublishDate.attributeType = .dateAttributeType
        episodePublishDate.isOptional = true
        
        let episodeDuration = NSAttributeDescription()
        episodeDuration.name = "duration"
        episodeDuration.attributeType = .doubleAttributeType
        episodeDuration.defaultValue = 0.0
        
        let episodeFileSize = NSAttributeDescription()
        episodeFileSize.name = "fileSize"
        episodeFileSize.attributeType = .integer64AttributeType
        episodeFileSize.defaultValue = 0
        
        let episodeIsDownloaded = NSAttributeDescription()
        episodeIsDownloaded.name = "isDownloaded"
        episodeIsDownloaded.attributeType = .booleanAttributeType
        episodeIsDownloaded.defaultValue = false
        
        let episodeDownloadPath = NSAttributeDescription()
        episodeDownloadPath.name = "downloadPath"
        episodeDownloadPath.attributeType = .stringAttributeType
        episodeDownloadPath.isOptional = true
        
        let episodePlayProgress = NSAttributeDescription()
        episodePlayProgress.name = "playProgress"
        episodePlayProgress.attributeType = .doubleAttributeType
        episodePlayProgress.defaultValue = 0.0
        
        // Relationship: Podcast to Episodes
        let podcastToEpisodes = NSRelationshipDescription()
        podcastToEpisodes.name = "episodes"
        podcastToEpisodes.destinationEntity = episodeEntity
        podcastToEpisodes.deleteRule = .cascadeDeleteRule
        podcastToEpisodes.minCount = 0
        podcastToEpisodes.maxCount = 0 // To-many relationship
        
        // Relationship: Episode to Podcast
        let episodeToPodcast = NSRelationshipDescription()
        episodeToPodcast.name = "podcast"
        episodeToPodcast.destinationEntity = podcastEntity
        episodeToPodcast.deleteRule = .nullifyDeleteRule
        episodeToPodcast.minCount = 1
        episodeToPodcast.maxCount = 1 // To-one relationship
        
        // Set inverses
        podcastToEpisodes.inverseRelationship = episodeToPodcast
        episodeToPodcast.inverseRelationship = podcastToEpisodes
        
        episodeEntity.properties = [episodeId, episodePodcastId, episodeTitle, episodeDesc, episodeAudioUrl, episodePublishDate, episodeDuration, episodeFileSize, episodeIsDownloaded, episodeDownloadPath, episodePlayProgress, episodeToPodcast]
        
        // Add entities to model
        managedObjectModel.entities = [podcastEntity, episodeEntity]
        
        // Set model to container
        container.managedObjectModel = managedObjectModel
    }
    
    // Convenience methods
    func savePodcast(_ podcast: Podcast) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDPodcast")
        fetchRequest.predicate = NSPredicate(format: "id == %@", podcast.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingPodcast = results.first as? NSManagedObject {
                // Update existing podcast
                existingPodcast.setValue(podcast.title, forKey: "title")
                existingPodcast.setValue(podcast.author, forKey: "author")
                existingPodcast.setValue(podcast.description, forKey: "podcastDescription")
                existingPodcast.setValue(podcast.imageUrl, forKey: "imageUrl")
                existingPodcast.setValue(podcast.feedUrl, forKey: "feedUrl")
                existingPodcast.setValue(podcast.isSubscribed, forKey: "isSubscribed")
            } else {
                // Create new podcast
                let newPodcast = NSEntityDescription.insertNewObject(forEntityName: "CDPodcast", into: context)
                newPodcast.setValue(podcast.id, forKey: "id")
                newPodcast.setValue(podcast.title, forKey: "title")
                newPodcast.setValue(podcast.author, forKey: "author")
                newPodcast.setValue(podcast.description, forKey: "podcastDescription")
                newPodcast.setValue(podcast.imageUrl, forKey: "imageUrl")
                newPodcast.setValue(podcast.feedUrl, forKey: "feedUrl")
                newPodcast.setValue(podcast.isSubscribed, forKey: "isSubscribed")
            }
            
            try context.save()
        } catch {
            print("Failed to save podcast: \(error.localizedDescription)")
        }
    }
    
    func saveEpisode(_ episode: Episode) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDEpisode")
        fetchRequest.predicate = NSPredicate(format: "id == %@", episode.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingEpisode = results.first as? NSManagedObject {
                // Update existing episode
                existingEpisode.setValue(episode.title, forKey: "title")
                existingEpisode.setValue(episode.description, forKey: "episodeDescription")
                existingEpisode.setValue(episode.audioUrl, forKey: "audioUrl")
                existingEpisode.setValue(episode.publishDate, forKey: "publishDate")
                existingEpisode.setValue(episode.duration, forKey: "duration")
                existingEpisode.setValue(episode.fileSize, forKey: "fileSize")
                existingEpisode.setValue(episode.isDownloaded, forKey: "isDownloaded")
                existingEpisode.setValue(episode.downloadPath, forKey: "downloadPath")
                existingEpisode.setValue(episode.playProgress, forKey: "playProgress")
            } else {
                // Create new episode
                let newEpisode = NSEntityDescription.insertNewObject(forEntityName: "CDEpisode", into: context)
                newEpisode.setValue(episode.id, forKey: "id")
                newEpisode.setValue(episode.podcastId, forKey: "podcastId")
                newEpisode.setValue(episode.title, forKey: "title")
                newEpisode.setValue(episode.description, forKey: "episodeDescription")
                newEpisode.setValue(episode.audioUrl, forKey: "audioUrl")
                newEpisode.setValue(episode.publishDate, forKey: "publishDate")
                newEpisode.setValue(episode.duration, forKey: "duration")
                newEpisode.setValue(episode.fileSize, forKey: "fileSize")
                newEpisode.setValue(episode.isDownloaded, forKey: "isDownloaded")
                newEpisode.setValue(episode.downloadPath, forKey: "downloadPath")
                newEpisode.setValue(episode.playProgress, forKey: "playProgress")
                
                // Connect to podcast
                let podcastFetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDPodcast")
                podcastFetchRequest.predicate = NSPredicate(format: "id == %@", episode.podcastId)
                if let podcastResults = try? context.fetch(podcastFetchRequest), let podcastObject = podcastResults.first as? NSManagedObject {
                    newEpisode.setValue(podcastObject, forKey: "podcast")
                }
            }
            
            try context.save()
        } catch {
            print("Failed to save episode: \(error.localizedDescription)")
        }
    }
    
    func fetchPodcasts(subscribed: Bool? = nil) -> [Podcast] {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDPodcast")
        
        if let isSubscribed = subscribed {
            fetchRequest.predicate = NSPredicate(format: "isSubscribed == %@", NSNumber(value: isSubscribed))
        }
        
        do {
            let results = try context.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            return results.map { object in
                Podcast(
                    id: object.value(forKey: "id") as? String ?? "",
                    title: object.value(forKey: "title") as? String ?? "",
                    author: object.value(forKey: "author") as? String ?? "",
                    description: object.value(forKey: "podcastDescription") as? String ?? "",
                    imageUrl: object.value(forKey: "imageUrl") as? String ?? "",
                    feedUrl: object.value(forKey: "feedUrl") as? String ?? "",
                    isSubscribed: object.value(forKey: "isSubscribed") as? Bool ?? false
                )
            }
        } catch {
            print("Failed to fetch podcasts: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchEpisodes(forPodcastId podcastId: String? = nil, downloaded: Bool? = nil) -> [Episode] {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDEpisode")
        
        var predicates: [NSPredicate] = []
        
        if let podcastId = podcastId {
            predicates.append(NSPredicate(format: "podcastId == %@", podcastId))
        }
        
        if let isDownloaded = downloaded {
            predicates.append(NSPredicate(format: "isDownloaded == %@", NSNumber(value: isDownloaded)))
        }
        
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Sort by publish date
        let sortDescriptor = NSSortDescriptor(key: "publishDate", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            let results = try context.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            return results.map { object in
                Episode(
                    id: object.value(forKey: "id") as? String ?? "",
                    podcastId: object.value(forKey: "podcastId") as? String ?? "",
                    title: object.value(forKey: "title") as? String ?? "",
                    description: object.value(forKey: "episodeDescription") as? String ?? "",
                    audioUrl: object.value(forKey: "audioUrl") as? String ?? "",
                    publishDate: object.value(forKey: "publishDate") as? Date ?? Date(),
                    duration: object.value(forKey: "duration") as? TimeInterval ?? 0,
                    fileSize: object.value(forKey: "fileSize") as? Int64 ?? 0,
                    isDownloaded: object.value(forKey: "isDownloaded") as? Bool ?? false,
                    downloadPath: object.value(forKey: "downloadPath") as? String,
                    playProgress: object.value(forKey: "playProgress") as? TimeInterval ?? 0
                )
            }
        } catch {
            print("Failed to fetch episodes: \(error.localizedDescription)")
            return []
        }
    }
    
    func updateEpisodeProgress(id: String, progress: TimeInterval) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDEpisode")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            if let episode = try context.fetch(fetchRequest).first as? NSManagedObject {
                episode.setValue(progress, forKey: "playProgress")
                try context.save()
            }
        } catch {
            print("Failed to update episode progress: \(error.localizedDescription)")
        }
    }
    
    func deleteDownloadedEpisode(id: String) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDEpisode")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            if let episode = try context.fetch(fetchRequest).first as? NSManagedObject {
                // Delete the file if it exists
                if let downloadPath = episode.value(forKey: "downloadPath") as? String,
                   let fileURL = URL(string: downloadPath) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                
                // Update the episode
                episode.setValue(false, forKey: "isDownloaded")
                episode.setValue(nil, forKey: "downloadPath")
                try context.save()
            }
        } catch {
            print("Failed to delete download: \(error.localizedDescription)")
        }
    }
    
    func deleteAllDownloads() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDEpisode")
        fetchRequest.predicate = NSPredicate(format: "isDownloaded == %@", NSNumber(value: true))
        
        do {
            let episodes = try context.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            for episode in episodes {
                // Delete the file if it exists
                if let downloadPath = episode.value(forKey: "downloadPath") as? String,
                   let fileURL = URL(string: downloadPath) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                
                // Update the episode
                episode.setValue(false, forKey: "isDownloaded")
                episode.setValue(nil, forKey: "downloadPath")
            }
            
            try context.save()
        } catch {
            print("Failed to delete all downloads: \(error.localizedDescription)")
        }
    }
    
    func unsubscribeFromPodcast(id: String) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDPodcast")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            if let podcast = try context.fetch(fetchRequest).first as? NSManagedObject {
                podcast.setValue(false, forKey: "isSubscribed")
                try context.save()
                
                // Delete all downloaded episodes
                let episodeFetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CDEpisode")
                episodeFetchRequest.predicate = NSPredicate(format: "podcastId == %@ AND isDownloaded == %@", id, NSNumber(value: true))
                
                if let episodes = try? context.fetch(episodeFetchRequest) as? [NSManagedObject] {
                    for episode in episodes {
                        if let downloadPath = episode.value(forKey: "downloadPath") as? String,
                           let fileURL = URL(string: downloadPath) {
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                        
                        episode.setValue(false, forKey: "isDownloaded")
                        episode.setValue(nil, forKey: "downloadPath")
                    }
                    
                    try context.save()
                }
            }
        } catch {
            print("Failed to unsubscribe: \(error.localizedDescription)")
        }
    }
}

// MARK: - Services
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
}

// iTunes Search API models
struct ITunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [ITunesPodcast]
}

struct ITunesPodcast: Decodable {
    let collectionId: String
    let collectionName: String
    let artistName: String
    let artworkUrl100: String
    let artworkUrl600: String?
    let feedUrl: String?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case collectionId, collectionName, artistName, artworkUrl100, artworkUrl600, feedUrl
        case description = "collectionDescription"
    }
}

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
        urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }
    
    func downloadEpisode(episode: Episode) {
        guard !episode.audioUrl.isEmpty, let url = URL(string: episode.audioUrl), !episode.isDownloaded else { return }
        
        // Create download task
        let task = urlSession.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self, let tempURL = tempURL, error == nil else { return }
            
            // Get the FileManager and document directory
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            // Create a unique filename based on episode ID
            let destinationURL = documentsURL.appendingPathComponent("\(episode.id).mp3")
            
            do {
                // Remove existing file if needed
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                
                // Move downloaded file to permanent location
                try fileManager.moveItem(at: tempURL, to: destinationURL)
                
                // Update episode in Core Data
                DispatchQueue.main.async {
                    var updatedEpisode = episode
                    updatedEpisode.isDownloaded = true
                    updatedEpisode.downloadPath = destinationURL.absoluteString
                    self.persistenceController.saveEpisode(updatedEpisode)
                    
                    // Remove from active downloads
                    self.activeDownloads.removeValue(forKey: episode.id)
                }
            } catch {
                print("Download failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.activeDownloads.removeValue(forKey: episode.id)
                }
            }
        }
        
        // Add task to active downloads
        activeDownloads[episode.id] = DownloadInfo(progress: 0, task: task)
        
        // Start download
        task.resume()
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
}

class AudioPlayerService: ObservableObject {
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private let persistenceController = PersistenceController.shared
    
    @Published var currentEpisode: Episode?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var error: Error?
    
    func play(episode: Episode) {
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
                switch item.status {
                case .readyToPlay:
                    self?.isLoading = false
                    self?.duration = item.duration.seconds
                    self?.audioPlayer?.play()
                    self?.isPlaying = true
                case .failed:
                    self?.isLoading = false
                    self?.error = item.error
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
            
            // Save progress every 5 seconds
            if Int(currentTime) % 5 == 0 {
                self.persistenceController.updateEpisodeProgress(id: episode.id, progress: currentTime)
            }
        }
        
        // Register for notifications
        setupNotifications()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        
        // Save progress
        if let episode = currentEpisode {
            persistenceController.updateEpisodeProgress(id: episode.id, progress: currentTime)
        }
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
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
        
        // Clear player
        audioPlayer?.pause()
        audioPlayer = nil
        playerItem = nil
        
        // Reset state
        isPlaying = false
        isLoading = false
        
        // Don't clear episode or time so mini player can still show info
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
        audioPlayer?.rate = rate
    }
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        
        // Handle playback interruptions (phone calls, etc.)
        center.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        
        // Handle playback completion
        center.addObserver(self, selector: #selector(handlePlaybackCompletion), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                  AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) else {
                return
            }
            resume()
        @unknown default:
            break
        }
    }
    
    @objc private func handlePlaybackCompletion(notification: Notification) {
        isPlaying = false
        
        // Reset play progress to 0
        if let episode = currentEpisode {
            persistenceController.updateEpisodeProgress(id: episode.id, progress: 0)
        }
        
        // Reset position to beginning
        currentTime = 0
        seek(to: 0)
    }
}

// MARK: - Views
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
                
                if episode.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                } else if downloadService.activeDownloads[episode.id] != nil {
                    ProgressView()
                        .scaleEffect(0.7)
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
                
                if !episode.isDownloaded && downloadService.activeDownloads[episode.id] == nil {
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
                } else if downloadService.activeDownloads[episode.id] != nil {
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

struct DownloadsView: View {
    @EnvironmentObject var podcastService: PodcastService
    @EnvironmentObject var downloadService: DownloadService
    @State private var downloadedEpisodes: [Episode] = []
    @State private var showClearAllAlert = false
    
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
                    List {
                        ForEach(downloadedEpisodes) { episode in
                            DownloadedEpisodeRow(episode: episode)
                        }
                    }
                    .listStyle(PlainListStyle())
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
            }
        }
    }
    
    private func loadDownloadedEpisodes() {
        downloadedEpisodes = podcastService.getDownloadedEpisodes()
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
            let podcasts = podcastService.getSubscribedPodcasts()
            podcast = podcasts.first { $0.id == episode.podcastId }
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

struct FullPlayerView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Environment(\.presentationMode) var presentationMode
    @State private var playbackRate: Float = 1.0
    @State private var showRateOptions = false
    
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
                // Episode artwork (represented as a placeholder)
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
                    .padding(.bottom, 40)
                
                // Episode title
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
                            Text("\(String(format: "%.1fx", playbackRate))")
                                .font(.footnote)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                        }
                        .confirmationDialog("Playback Speed", isPresented: $showRateOptions) {
                            Button("0.5x") { setRate(0.5) }
                            Button("0.8x") { setRate(0.8) }
                            Button("1.0x") { setRate(1.0) }
                            Button("1.2x") { setRate(1.2) }
                            Button("1.5x") { setRate(1.5) }
                            Button("2.0x") { setRate(2.0) }
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
    }
    
    private func setRate(_ rate: Float) {
        playbackRate = rate
        audioPlayerService.setPlaybackRate(rate)
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

struct SettingsView: View {
    @AppStorage("autoDownload") private var autoDownload = false
    @AppStorage("deleteCompletedEpisodes") private var deleteCompletedEpisodes = false
    @AppStorage("streamingQuality") private var streamingQuality = "High"
    @AppStorage("downloadQuality") private var downloadQuality = "Standard"
    @State private var storageUsed: String = "0 MB"
    @State private var appVersion: String = "1.0.0"
    @EnvironmentObject var downloadService: DownloadService
    @State private var showDeleteAllAlert = false
    
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
        // In a real app, you would calculate actual storage used
        // For now, we'll use a placeholder
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        
        // Get downloads directory size
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey])
                var totalSize: Int64 = 0
                
                for file in files {
                    if file.pathExtension == "mp3" {
                        let attributes = try file.resourceValues(forKeys: [.fileSizeKey])
                        if let size = attributes.fileSize {
                            totalSize += Int64(size)
                        }
                    }
                }
                
                storageUsed = formatter.string(fromByteCount: totalSize)
            } catch {
                storageUsed = "Unknown"
            }
        }
    }
}

// MARK: - App Entry Point
@main
struct PodcastsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
