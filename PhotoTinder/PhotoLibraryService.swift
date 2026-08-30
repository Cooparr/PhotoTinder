import Photos
import SwiftUI
import UIKit

enum PhotoAuthState: Equatable {
    case unknown
    case authorized
    case limited
    case denied
}

enum SwipeSort: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst

    var id: Self { self }

    var label: String {
        switch self {
        case .newestFirst: return "Newest first"
        case .oldestFirst: return "Oldest first"
        }
    }

    var symbol: String {
        switch self {
        case .newestFirst: return "arrow.down.to.line"
        case .oldestFirst: return "arrow.up.to.line"
        }
    }
}

enum MediaFilter: String, CaseIterable, Identifiable {
    case all
    case photos
    case videos
    case screenshots
    case livePhotos

    var id: Self { self }

    var label: String {
        switch self {
        case .all: return "All"
        case .photos: return "Photos"
        case .videos: return "Videos"
        case .screenshots: return "Screenshots"
        case .livePhotos: return "Live Photos"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "photo.stack"
        case .photos: return "photo"
        case .videos: return "video"
        case .screenshots: return "camera.viewfinder"
        case .livePhotos: return "livephoto"
        }
    }
}

@Observable
final class PhotoLibraryService: NSObject, PHPhotoLibraryChangeObserver {
    private(set) var authState: PhotoAuthState
    private(set) var libraryVersion: Int = 0

    @ObservationIgnored
    private let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 400 * 1024 * 1024
        return cache
    }()

    override init() {
        authState = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            libraryVersion &+= 1
        }
    }

    func cachedImage(for identifier: String) -> UIImage? {
        imageCache.object(forKey: identifier as NSString)
    }

    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authState = Self.map(status)
    }

    func refreshAuthState() {
        authState = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func fetchAssets(sort: SwipeSort = .newestFirst, filter: MediaFilter = .all) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: sort == .oldestFirst)
        ]
        options.predicate = predicate(for: filter)
        return PHAsset.fetchAssets(with: options)
    }

    private func predicate(for filter: MediaFilter) -> NSPredicate {
        switch filter {
        case .all:
            return NSPredicate(
                format: "mediaType == %d || mediaType == %d",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaType.video.rawValue
            )
        case .photos:
            return NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        case .videos:
            return NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        case .screenshots:
            return NSPredicate(
                format: "mediaType == %d && (mediaSubtypes & %d) != 0",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
        case .livePhotos:
            return NSPredicate(
                format: "mediaType == %d && (mediaSubtypes & %d) != 0",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaSubtype.photoLive.rawValue
            )
        }
    }

    func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        let key = asset.localIdentifier as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }

        let gate = ResumeGate()
        let image: UIImage? = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                if gate.take() {
                    continuation.resume(returning: image)
                }
            }
        }

        if let image {
            let scale = image.scale
            let cost = Int(image.size.width * scale * image.size.height * scale * 4)
            imageCache.setObject(image, forKey: key, cost: cost)
        }
        return image
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoAuthState {
        switch status {
        case .notDetermined: return .unknown
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }
}

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var taken = false

    func take() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if taken { return false }
        taken = true
        return true
    }
}
