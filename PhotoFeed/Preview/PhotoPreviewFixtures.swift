//
//  PhotoPreviewFixtures.swift
//  PhotoFeed
//
//  Created by Marcos Curvello on 16/09/2026.
//

#if DEBUG
import Foundation

@MainActor
enum PhotoPreviewFixtures {

    static let imagePipeline = RemoteImagePipeline()

    static let photo = Photo(
        id: .init(rawValue: "ScZ_EMuC_lY"),
        width: 6063,
        height: 4042,
        colorHex: "#f3f3f3",
        description: "Modern building with hexagonal facade pattern",
        imageURLs: .init(
            full: URL(string: "https://images.unsplash.com/photo-1777913357532-a551d758ca5d?crop=entropy&cs=srgb&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=85")!,
            regular: URL(string: "https://images.unsplash.com/photo-1777913357532-a551d758ca5d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=80&w=1080")!,
            small: URL(string: "https://images.unsplash.com/photo-1777913357532-a551d758ca5d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=80&w=400")!,
            thumbnail: URL(string: "https://images.unsplash.com/photo-1777913357532-a551d758ca5d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=80&w=200")!
        ),
        user: User(
            id: .init(rawValue: "1lxvg0k3BXQ"),
            username: "echogolf",
            name: "Eduard Galitsky",
            avatarURL: URL(string: "https://images.unsplash.com/placeholder-avatars/extra-large.jpg?ixlib=rb-4.1.0&crop=faces&fit=crop&w=64&h=64")!,
            webpageURL: URL(string: "https://unsplash.com/@echogolf")!
        ),
        webpageURL: URL(string: "https://unsplash.com/photos/modern-building-with-hexagonal-grid-facade-ScZ_EMuC_lY")!
    )

    static let photos = [
        photo,
        Photo(
            id: .init(rawValue: "b1FrQVPyIhQ"),
            width: 2688,
            height: 4032,
            colorHex: "#0c7373",
            description: "A young woman with dark hair illuminated by blue light",
            imageURLs: .init(
                full: URL(string: "https://images.unsplash.com/photo-1777927515662-a460bce161eb?crop=entropy&cs=srgb&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=85")!,
                regular: URL(string: "https://images.unsplash.com/photo-1777927515662-a460bce161eb?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=80&w=1080")!,
                small: URL(string: "https://images.unsplash.com/photo-1777927515662-a460bce161eb?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=80&w=400")!,
                thumbnail: URL(string: "https://images.unsplash.com/photo-1777927515662-a460bce161eb?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=80&w=200")!
            ),
            user: User(
                id: .init(rawValue: "HsGAIBLglV8"),
                username: "lhonkarwanhamasalih",
                name: "lhon karwan",
                avatarURL: URL(string: "https://images.unsplash.com/profile-1741377110539-e2116eae66faimage?ixlib=rb-4.1.0&crop=faces&fit=crop&w=64&h=64")!,
                webpageURL: URL(string: "https://unsplash.com/@lhonkarwanhamasalih")!
            ),
            webpageURL: URL(string: "https://unsplash.com/photos/woman-in-dark-jacket-under-light-b1FrQVPyIhQ")!
        ),
        Photo(
            id: .init(rawValue: "Xd8ctkMatn8"),
            width: 2880,
            height: 3840,
            colorHex: "#f3f3f3",
            description: "Sunbath",
            imageURLs: .init(
                full: URL(string: "https://images.unsplash.com/photo-1778244305115-4dd2bf7c8e86?crop=entropy&cs=srgb&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=85")!,
                regular: URL(string: "https://images.unsplash.com/photo-1778244305115-4dd2bf7c8e86?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=80&w=1080")!,
                small: URL(string: "https://images.unsplash.com/photo-1778244305115-4dd2bf7c8e86?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=80&w=400")!,
                thumbnail: URL(string: "https://images.unsplash.com/photo-1778244305115-4dd2bf7c8e86?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxyYW5kb218fHx8fHx8fHwxNzg4ODg3MDY0fA&ixlib=rb-4.1.0&q=80&w=200")!
            ),
            user: User(
                id: .init(rawValue: "9x-z_YzoFEk"),
                username: "jjemanuel",
                name: "João Emanuel",
                avatarURL: URL(string: "https://images.unsplash.com/profile-1786388531451-d6b2c6406a6fimage?ixlib=rb-4.1.0&crop=faces&fit=crop&w=64&h=64")!,
                webpageURL: URL(string: "https://unsplash.com/@jjemanuel")!
            ),
            webpageURL: URL(string: "https://unsplash.com/photos/black-cat-in-white-wall-opening-Xd8ctkMatn8")!
        )
    ]

    static let detailPhoto = photos[1]

    static let detailUserPhotos = [
        detailPhoto,
        Photo(
            id: .init(rawValue: "llB9FwAbMCs"),
            width: 4000,
            height: 6000,
            colorHex: "#260c0c",
            description: "Woman in a red and black jacket crouching at night",
            imageURLs: .init(
                full: URL(string: "https://images.unsplash.com/photo-1773170698495-5fc99eb39010?crop=entropy&cs=srgb&fm=jpg&q=85")!,
                regular: URL(string: "https://images.unsplash.com/photo-1773170698495-5fc99eb39010?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080")!,
                small: URL(string: "https://images.unsplash.com/photo-1773170698495-5fc99eb39010?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400")!,
                thumbnail: URL(string: "https://images.unsplash.com/photo-1773170698495-5fc99eb39010?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=200")!
            ),
            user: detailPhoto.user,
            webpageURL: URL(string: "https://unsplash.com/photos/woman-in-a-red-and-black-jacket-crouching-at-night-llB9FwAbMCs")!
        ),
        Photo(
            id: .init(rawValue: "PRgxRPx0H84"),
            width: 4000,
            height: 6000,
            colorHex: "#262626",
            description: "Woman standing on a street at night",
            imageURLs: .init(
                full: URL(string: "https://images.unsplash.com/photo-1773008752582-287d6c1ca8ca?crop=entropy&cs=srgb&fm=jpg&q=85")!,
                regular: URL(string: "https://images.unsplash.com/photo-1773008752582-287d6c1ca8ca?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080")!,
                small: URL(string: "https://images.unsplash.com/photo-1773008752582-287d6c1ca8ca?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400")!,
                thumbnail: URL(string: "https://images.unsplash.com/photo-1773008752582-287d6c1ca8ca?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=200")!
            ),
            user: detailPhoto.user,
            webpageURL: URL(string: "https://unsplash.com/photos/woman-standing-on-a-street-at-night-PRgxRPx0H84")!
        ),
        Photo(
            id: .init(rawValue: "exc-fdjfivY"),
            width: 4000,
            height: 6000,
            colorHex: "#262626",
            description: "Woman with dramatic makeup at night with city lights",
            imageURLs: .init(
                full: URL(string: "https://images.unsplash.com/photo-1773579616514-28fd4bd552b8?crop=entropy&cs=srgb&fm=jpg&q=85")!,
                regular: URL(string: "https://images.unsplash.com/photo-1773579616514-28fd4bd552b8?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080")!,
                small: URL(string: "https://images.unsplash.com/photo-1773579616514-28fd4bd552b8?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400")!,
                thumbnail: URL(string: "https://images.unsplash.com/photo-1773579616514-28fd4bd552b8?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=200")!
            ),
            user: detailPhoto.user,
            webpageURL: URL(string: "https://unsplash.com/photos/woman-with-dramatic-makeup-at-night-with-city-lights-exc-fdjfivY")!
        ),
        Photo(
            id: .init(rawValue: "FcbgSqFD1lQ"),
            width: 4000,
            height: 6000,
            colorHex: "#260c0c",
            description: "Woman illuminated by red light at night",
            imageURLs: .init(
                full: URL(string: "https://images.unsplash.com/photo-1774217396090-1e4faf7bbb67?crop=entropy&cs=srgb&fm=jpg&q=85")!,
                regular: URL(string: "https://images.unsplash.com/photo-1774217396090-1e4faf7bbb67?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080")!,
                small: URL(string: "https://images.unsplash.com/photo-1774217396090-1e4faf7bbb67?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400")!,
                thumbnail: URL(string: "https://images.unsplash.com/photo-1774217396090-1e4faf7bbb67?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=200")!
            ),
            user: detailPhoto.user,
            webpageURL: URL(string: "https://unsplash.com/photos/woman-illuminated-by-red-light-at-night-FcbgSqFD1lQ")!
        )
    ]

    static let sponsoredPhotos = [
        Photo(
            id: .init(rawValue: "-oFU4FKenNI"),
            width: 4000,
            height: 2668,
            colorHex: "#262626",
            description: "Portable ssd, coffee, and stationery on a grid mat",
            imageURLs: .init(
                full: URL(string: "https://images.unsplash.com/photo-1779896412352-dd950bd9ce71?crop=entropy&cs=srgb&fm=jpg&ixid=M3wxMDU5MzU4fDF8MXxhbGx8MXx8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=85")!,
                regular: URL(string: "https://images.unsplash.com/photo-1779896412352-dd950bd9ce71?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDF8MXxhbGx8MXx8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=80&w=1080")!,
                small: URL(string: "https://images.unsplash.com/photo-1779896412352-dd950bd9ce71?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDF8MXxhbGx8MXx8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=80&w=400")!,
                thumbnail: URL(string: "https://images.unsplash.com/photo-1779896412352-dd950bd9ce71?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDF8MXxhbGx8MXx8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=80&w=200")!
            ),
            user: User(
                id: .init(rawValue: "ggdcMCR6zfY"),
                username: "sandisk",
                name: "Sandisk",
                avatarURL: URL(string: "https://images.unsplash.com/profile-1782233340631-712991c1814aimage?ixlib=rb-4.1.0&crop=faces&fit=crop&w=64&h=64")!,
                webpageURL: URL(string: "https://unsplash.com/@sandisk")!
            ),
            webpageURL: URL(string: "https://unsplash.com/photos/portable-ssd-coffee-and-stationery-on-a-grid-mat--oFU4FKenNI")!
        ),
        Photo(
            id: .init(rawValue: "8Ug4F8iM8NQ"),
            width: 3639,
            height: 5459,
            colorHex: "#598c8c",
            description: "A metal lifeguard chair on a sandy beach by the ocean",
            imageURLs: .init(
                full: URL(string: "https://images.unsplash.com/photo-1789283170426-1d1305571e26?crop=entropy&cs=srgb&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxhbGx8Mnx8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=85")!,
                regular: URL(string: "https://images.unsplash.com/photo-1789283170426-1d1305571e26?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxhbGx8Mnx8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=80&w=1080")!,
                small: URL(string: "https://images.unsplash.com/photo-1789283170426-1d1305571e26?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxhbGx8Mnx8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=80&w=400")!,
                thumbnail: URL(string: "https://images.unsplash.com/photo-1789283170426-1d1305571e26?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxhbGx8Mnx8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=80&w=200")!
            ),
            user: User(
                id: .init(rawValue: "yw477yGgGm8"),
                username: "gsebastian",
                name: "Sebastian",
                avatarURL: URL(string: "https://images.unsplash.com/profile-1787653923487-85d697bc1dbeimage?ixlib=rb-4.1.0&crop=faces&fit=crop&w=64&h=64")!,
                webpageURL: URL(string: "https://unsplash.com/@gsebastian")!
            ),
            webpageURL: URL(string: "https://unsplash.com/photos/lifeguard-chair-on-sandy-beach-8Ug4F8iM8NQ")!
        ),
        Photo(
            id: .init(rawValue: "zVkeONx-3So"),
            width: 6960,
            height: 4640,
            colorHex: "#0c2640",
            description: "An ocean wave breaking at sunset with vibrant sky colors",
            imageURLs: .init(
                full: URL(string: "https://images.unsplash.com/photo-1785677535400-725b852ff2e1?crop=entropy&cs=srgb&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxhbGx8M3x8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=85")!,
                regular: URL(string: "https://images.unsplash.com/photo-1785677535400-725b852ff2e1?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxhbGx8M3x8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=80&w=1080")!,
                small: URL(string: "https://images.unsplash.com/photo-1785677535400-725b852ff2e1?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxhbGx8M3x8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=80&w=400")!,
                thumbnail: URL(string: "https://images.unsplash.com/photo-1785677535400-725b852ff2e1?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3wxMDU5MzU4fDB8MXxhbGx8M3x8fHx8fHx8MTc4OTUwMzM3MHw&ixlib=rb-4.1.0&q=80&w=200")!
            ),
            user: User(
                id: .init(rawValue: "2o12C7OktGI"),
                username: "willv78",
                name: "William Veitch",
                avatarURL: URL(string: "https://images.unsplash.com/profile-1785067824720-2a85c2753f4aimage?ixlib=rb-4.1.0&crop=faces&fit=crop&w=64&h=64")!,
                webpageURL: URL(string: "https://unsplash.com/@willv78")!
            ),
            webpageURL: URL(string: "https://unsplash.com/photos/ocean-wave-under-orange-sky-zVkeONx-3So")!
        )
    ]
}
#endif
