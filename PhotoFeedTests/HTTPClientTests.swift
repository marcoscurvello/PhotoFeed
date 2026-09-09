//
//  HTTPClientTests.swift
//  PhotoFeedTests
//
//  Created by Marcos Curvello on 09/09/2026.
//

import Foundation
import Testing
@testable import PhotoFeed

@Suite("HTTP client", .serialized)
struct HTTPClientTests {

    @Test("Successful response builds the request and decodes its body")
    func decodesSuccessfulResponse() async throws {
        let responseData = try JSONEncoder().encode(TestResponse(value: "success"))

        URLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

            #expect(components.scheme == "https")
            #expect(components.host == "api.unsplash.com")
            #expect(components.path == "/photos")
            #expect(components.queryItems?.first { $0.name == "page" }?.value == "2")
            #expect(components.queryItems?.first { $0.name == "per_page" }?.value == "10")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Client-ID test-key")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )

            return (response, responseData)
        }

        defer {
            URLProtocolStub.handler = nil
        }

        let client = makeClient()
        let request = HTTPRequest(
            path: "photos",
            queryItems: [
                URLQueryItem(name: "page", value: "2"),
                URLQueryItem(name: "per_page", value: "10")
            ],
            headers: [
                "Authorization": "Client-ID test-key"
            ]
        )

        let response: TestResponse = try await client.send(request)

        #expect(response == TestResponse(value: "success"))
    }

    @Test("Non-successful HTTP status throws the status code and response body")
    func rejectsUnacceptableStatusCode() async throws {
        let responseData = Data("rate limited".utf8)

        URLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)
            )

            return (response, responseData)
        }

        defer {
            URLProtocolStub.handler = nil
        }

        let client = makeClient()
        let request = HTTPRequest(path: "photos")

        do {
            _ = try await client.data(for: request)
            Issue.record("Expected the request to fail")
        } catch let error as HTTPClientError {
            switch error {
            case .unacceptableStatusCode(let statusCode, let data):
                #expect(statusCode == 429)
                #expect(data == responseData)

            default:
                Issue.record("Expected unacceptableStatusCode, received \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Non-HTTP response is rejected")
    func rejectsNonHTTPResponse() async throws {
        URLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = URLResponse(
                url: url,
                mimeType: "application/json",
                expectedContentLength: 0,
                textEncodingName: nil
            )

            return (response, Data())
        }

        defer {
            URLProtocolStub.handler = nil
        }

        let client = makeClient()
        let request = HTTPRequest(path: "photos")

        do {
            _ = try await client.data(for: request)
            Issue.record("Expected the request to fail")
        } catch let error as HTTPClientError {
            switch error {
            case .invalidResponse:
                break

            default:
                Issue.record("Expected invalidResponse, received \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Malformed response body propagates its decoding error")
    func propagatesDecodingError() async throws {
        URLProtocolStub.handler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )

            return (response, Data(#"{"unexpected":true}"#.utf8))
        }

        defer {
            URLProtocolStub.handler = nil
        }

        let client = makeClient()
        let request = HTTPRequest(path: "photos")

        do {
            let _: TestResponse = try await client.send(request)
            Issue.record("Expected decoding to fail")
        } catch is DecodingError {
            // Expected.
        } catch {
            Issue.record("Expected DecodingError, received \(error)")
        }
    }

    private func makeClient() -> HTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]

        return HTTPClient(
            baseURL: URL(string: "https://api.unsplash.com")!,
            session: URLSession(configuration: configuration)
        )
    }
}

// MARK: - Test types

private struct TestResponse: Codable, Equatable, Sendable {
    let value: String
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (URLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: StubError.missingHandler)
            return
        }

        do {
            let (response, data) = try handler(request)

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private enum StubError: Error {
        case missingHandler
    }
}
