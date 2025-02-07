import Foundation
import Combine
import os.log

public typealias HeaderKey = String
public typealias HeaderValue = String
public typealias ParamKey = String
public typealias ParamValue = String
public typealias ResponseHeaders = [AnyHashable: Any]
public typealias ResponseCode = Int
public extension ResponseCode {
    var statusOK: Bool { self == 200 }
}


public extension os.Logger {
    static let api = os.Logger(subsystem: Bundle.main.bundleIdentifier!, category: "↕️ API")
}

public struct ApiResponse {
    public let data: Data?
    public let headers: ResponseHeaders
    public let code: ResponseCode

    public func headerValue(forKey: String) -> String? {
        headers.first { "\($0.key)".lowercased() == forKey.lowercased()}?.value as? String
    }
}

public protocol IRestClient {

    func get(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            onSuccess: @escaping (ApiResponse) -> Void,
            onFail: @escaping (ApiError) -> Void
    )

    func post(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data,
            onSuccess: @escaping (ApiResponse) -> Void,
            onFail: @escaping (ApiError) -> Void
    )

    func get(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue]
    ) -> Result<ApiResponse, ApiError>

    func post(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data
    ) -> Result<ApiResponse, ApiError>

    func put(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data
    ) -> Result<ApiResponse, ApiError>

    func delete(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data?
    ) -> Result<ApiResponse, ApiError>

    func head(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue]
    ) -> Result<ApiResponse, ApiError>

    func get(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue]
    ) -> AnyPublisher<ApiResponse, ApiError>

    func post(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data?
    ) -> AnyPublisher<ApiResponse, ApiError>

    func put(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data?
    ) -> AnyPublisher<ApiResponse, ApiError>

    func delete(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data?
    ) -> AnyPublisher<ApiResponse, ApiError>

    func head(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue]
    ) -> AnyPublisher<ApiResponse, ApiError>

    func perform(
            endpoint: ApiEndpoint,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data?
    ) -> AnyPublisher<ApiResponse, ApiError>

}

public class RestClient: IRestClient {
    private let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    public init(
            sessionConfig: URLSessionConfiguration = ApiSessionConfigBuilder.buildConfig(
                    timeoutForResponse: 20,
                    timeoutResourceInterval: 120
            )
    ) {
        self.session = URLSession(configuration: sessionConfig)
    }

    public func get(
            path: String,
            headers: [HeaderKey: HeaderValue] = [:],
            queryParams: [ParamKey: ParamValue] = [:]
    ) -> Result<ApiResponse, ApiError> {
        request(
                type: .get,
                path: path,
                headers: headers,
                queryParams: queryParams
        )
    }

    public func get(
            path: String,
            headers: [HeaderKey: HeaderValue] = [:],
            queryParams: [ParamKey: ParamValue] = [:],
            onSuccess: @escaping (ApiResponse) -> Void,
            onFail: @escaping (ApiError) -> Void
    ) {
        request(
                type: .get,
                path: path,
                headers: headers,
                queryParams: queryParams,
                onSuccess: onSuccess,
                onFail: onFail
        )
    }

    public func post(
            path: String,
            headers: [HeaderKey: HeaderValue] = [:],
            queryParams: [ParamKey: ParamValue] = [:],
            bodyData: Data
    ) -> Result<ApiResponse, ApiError> {
        request(
                type: .post,
                path: path,
                headers: headers,
                queryParams: queryParams,
                bodyData: bodyData
        )
    }

    public func post(
            path: String,
            headers: [HeaderKey: HeaderValue] = [:],
            queryParams: [ParamKey: ParamValue] = [:],
            bodyData: Data,
            onSuccess: @escaping (ApiResponse) -> Void,
            onFail: @escaping (ApiError) -> Void
    ) {
        request(type: .post, path: path,headers: headers, queryParams: queryParams, bodyData: bodyData, onSuccess: onSuccess, onFail: onFail)
    }

    public func delete(
            path: String,
            headers: [HeaderKey: HeaderValue] = [:],
            queryParams: [ParamKey: ParamValue] = [:],
            bodyData: Data?
    ) -> Result<ApiResponse, ApiError> {
        request(
                type: .delete,
                path: path,
                headers: headers,
                queryParams: queryParams,
                bodyData: bodyData
        )
    }

    public func put(
            path: String,
            headers: [HeaderKey: HeaderValue] = [:],
            queryParams: [ParamKey: ParamValue] = [:],
            bodyData: Data
    ) -> Result<ApiResponse, ApiError> {
        request(
                type: .put,
                path: path,
                headers: headers,
                queryParams: queryParams,
                bodyData: bodyData
        )
    }

    public func head(
            path: String,
            headers: [HeaderKey: HeaderValue] = [:],
            queryParams: [ParamKey: ParamValue] = [:]
    ) -> Result<ApiResponse, ApiError> {
        request(
                type: .head,
                path: path,
                headers: headers,
                queryParams: queryParams
        )
    }

    private func request(
            type: ApiRequestType,
            path: String,
            headers: [HeaderKey: HeaderValue] = [:],
            queryParams: [ParamKey: ParamValue] = [:],
            bodyData: Data? = nil
    ) -> Result<ApiResponse, ApiError> {
        guard let url = buildRequestUrl(path: path, queryParams: queryParams) else {
            return .failure(ApiError(
                    sender: self,
                    url: path,
                    responseCode: 0,
                    message: "incorrect url",
                    requestType: type,
                    headers: headers,
                    params: queryParams
            ))
        }

        var request = URLRequest(url: url)

        headers.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        request.httpMethod = type.rawValue

        switch type {
        case .post, .put, .delete:
            request.httpBody = bodyData
        default:
            break
        }

        var result: Result<ApiResponse, ApiError>!

        let semaphore = DispatchSemaphore(value: 0)

        let cURL = create_cURL(requestType: type, path: url, headers: headers, bodyData: bodyData)
        log("\("🟡 beginning   \(type) \(path)")\n\(cURL)", category: .api)

        let task = session.dataTask(with: request) {[weak self] data, response, error in
            if let _ = error {
                result = .failure(
                        ApiError(
                                sender: self as Any,
                                url: path,
                                responseCode: 0,
                                message: "error occurred: \(self?.stringifyData(data: data) ?? "") ",
                                error: error,
                                requestType: type,
                                headers: headers,
                                params: queryParams
                        )
                )
                semaphore.signal()
            }

            guard let response = response as? HTTPURLResponse else {
                result = .failure(
                        ApiError(
                                sender: self as Any,
                                url: path,
                                responseCode: 0,
                                message: "no response: \(self?.stringifyData(data: data) ?? "")",
                                requestType: type,
                                headers: headers,
                                params: queryParams
                        )
                )
                semaphore.signal()
                return
            }

            if response.statusCode < 200 || response.statusCode >= 300 {
                result = .failure(
                        ApiError(
                                sender: self as Any,
                                url: path,
                                responseCode: response.statusCode,
                                message: "bad response: \(self?.stringifyData(data: data) ?? "")",
                                data: data,
                                requestType: type,
                                headers: headers,
                                params: queryParams
                        )
                )
                semaphore.signal()
                return
            } else if response.statusCode == 204 {
                result = .success(ApiResponse(data: nil, headers: response.allHeaderFields, code: response.statusCode))
                semaphore.signal()
                return
            }

            result = .success(ApiResponse(data: data, headers: response.allHeaderFields, code: response.statusCode))
            semaphore.signal()
        }

        task.resume()

        _ = semaphore.wait(wallTimeout: .distantFuture)

        switch result {
        case .success(let response):
            log("🟢 successful   \(type) \(path) \nresponse data: \(response.data?.utf8 ?? "") \nheaders: \(response.headers)\n", category: .api)

        case .failure(let error):
            log("🔴 unsuccessful \(type) \(path) \nerror: \(error.toString())", category: .api)
        case .none:
            break
        }

        return result
    }

    func upload(
            path: String,
            headers: [HeaderKey: HeaderValue] = [:],
            body: Data,
            then handler: @escaping (Result<Data, ApiError>) -> Void
    ) {
        guard let url = buildRequestUrl(path: path, queryParams: [:]) else {
            handler(.failure(
                    ApiError(sender: self, url: path, responseCode: 0, requestType: .post, headers: headers, params: [:]))
            )
            return
        }
        var request = URLRequest(url: url)
        headers.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        request.httpMethod = ApiRequestType.post.rawValue
        request.httpBody = body

        let task = session.uploadTask(
                with: request,
                from: body,
                completionHandler: { data, response, error in
                    if let response = response as? HTTPURLResponse {
                        print("response: \(response.statusCode)")
                    }
                    if let data = data {
                        print(String(data: data, encoding: .utf8) ?? "")
                    }
                    if let error = error {
                        print(error.localizedDescription)
                    }
                }
        )
        task.resume()
    }

    private func request(
            type: ApiRequestType,
            path: String,
            headers: [HeaderKey: HeaderValue] = [:],
            queryParams: [ParamKey: ParamValue] = [:],
            bodyData: Data? = nil,
            onSuccess: @escaping (ApiResponse) -> Void,
            onFail: @escaping (ApiError) -> Void
    ) {
        guard let url = buildRequestUrl(path: path, queryParams: queryParams) else {
            onFail(
                    ApiError(
                            sender: self,
                            url: path,
                            responseCode: 0,
                            message: "response: nil",
                            requestType: type,
                            headers: headers,
                            params: queryParams
                    )
            )
            return
        }

        let request = buildRequest(url: url, type: type, headers: headers, bodyData: bodyData)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                onFail(
                        ApiError(
                                sender: self,
                                url: path,
                                responseCode: 0,
                                message: "\(self) error",
                                error: error,
                                requestType: type,
                                headers: headers,
                                params: queryParams
                        )
                )
            }

            guard let response = response as? HTTPURLResponse else {
                onFail(
                        ApiError(
                                sender: self,
                                url: path,
                                responseCode: 0,
                                message: "response: nil",
                                requestType: type,
                                headers: headers,
                                params: queryParams
                        )
                )
                return
            }

            guard response.statusCode == 200 else {
                onFail(
                        ApiError(
                                sender: self,
                                url: path,
                                responseCode: response.statusCode,
                                message: "incorrect request",
                                requestType: type,
                                headers: headers,
                                params: queryParams
                        )
                )
                return
            }

            guard let data = data else {
                onFail(
                        ApiError(
                                sender: self,
                                url: path,
                                responseCode: response.statusCode,
                                message: "data: nil",
                                requestType: type,
                                headers: headers,
                                params: queryParams
                        )
                )
                return
            }

            onSuccess(ApiResponse(data: data, headers: response.allHeaderFields, code: response.statusCode))
        }

        task.resume()
    }

    public func get(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue]
    ) -> AnyPublisher<ApiResponse, ApiError> {
        request(type: .get, path: path, headers: headers, queryParams: queryParams)
    }

    public func post(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data?
    ) -> AnyPublisher<ApiResponse, ApiError> {
        request(type: .post, path: path, headers: headers, queryParams: queryParams, bodyData: bodyData)
    }

    public func put(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data?
    ) -> AnyPublisher<ApiResponse, ApiError> {
        request(type: .put, path: path, headers: headers, queryParams: queryParams, bodyData: bodyData)
    }

    public func delete(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data?
    ) -> AnyPublisher<ApiResponse, ApiError> {
        request(type: .delete, path: path, headers: headers, queryParams: queryParams, bodyData: bodyData)
    }

    public func head(
            path: String,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue]
    ) -> AnyPublisher<ApiResponse, ApiError> {
        request(type: .delete, path: path, headers: headers, queryParams: queryParams)
    }

    public func perform(
            endpoint: ApiEndpoint,
            headers: [HeaderKey: HeaderValue],
            queryParams: [ParamKey: ParamValue],
            bodyData: Data?
    ) -> AnyPublisher<ApiResponse, ApiError> {
        switch endpoint.type {
        case .get:
            return get(path: endpoint.path, headers: headers, queryParams: queryParams)
        case .post:
            return post(path: endpoint.path, headers: headers, queryParams: queryParams, bodyData: bodyData)
        case .put:
            return put(path: endpoint.path, headers: headers, queryParams: queryParams, bodyData: bodyData)
        case .delete:
            return delete(path: endpoint.path, headers: headers, queryParams: queryParams, bodyData: bodyData)
        case .head:
            return head(path: endpoint.path, headers: headers, queryParams: queryParams)
        }
    }

    private func request(
            type: ApiRequestType,
            path: String,
            headers: [String: String],
            queryParams: [String: String],
            bodyData: Data? = nil
    ) -> AnyPublisher<ApiResponse, ApiError> {
        guard let url = buildRequestUrl(path: path, queryParams: queryParams) else {
            return Fail(
                    error: ApiError(
                            sender: self,
                            url: path,
                            responseCode: 0,
                            message: "Unable to build url",
                            requestType: type,
                            headers: headers,
                            params: queryParams
                    )
            )
                    .eraseToAnyPublisher()
        }

        let request = buildRequest(url: url, type: type, headers: headers, bodyData: bodyData)

        let cURL = create_cURL(requestType: type, path: url, headers: headers, bodyData: bodyData)
        log("\("🟡 beginning   \(type) \(path)")\n\(cURL)", category: .api)

        return session.dataTaskPublisher(for: request)
                .tryMap { data, response in
                    guard let response = response as? HTTPURLResponse else {
                        throw ApiError(
                                sender: self,
                                url: url.absoluteString,
                                responseCode: 0,
                                message: "no response: \(self.stringifyData(data: data))",
                                data: data,
                                requestType: type,
                                headers: headers,
                                params: queryParams
                        )
                    }

                    if response.statusCode < 200 || response.statusCode >= 300 {
                        throw ApiError(
                                sender: self,
                                url: url.absoluteString,
                                responseCode: response.statusCode,
                                message: "bad response: \(self.stringifyData(data: data))",
                                data: data,
                                requestType: type,
                                headers: headers,
                                params: queryParams
                        )
                    } else if response.statusCode == 204 {
                        let apiResponse =  ApiResponse(data: nil, headers: response.allHeaderFields, code: response.statusCode)
                        log("🟢 successful   \(type) \(path) \nresponse data: nil \nheaders: \(apiResponse.headers)\n", category: .api)
                        return apiResponse
                    }

                    let apiResponse = ApiResponse(data: data, headers: response.allHeaderFields, code: response.statusCode)
                    log("🟢 successful   \(type) \(path) \nresponse data: \(data.utf8 ?? "") \nheaders: \(apiResponse.headers)\n", category: .api)

                    return apiResponse
                }
                .mapError { error in
                    // handle specific errors

                    if let error = error as? ApiError {
                        log("🔴 unsuccessful \(type) \(path) \nerror: \(error.toString())", category: .api)
                        return error
                    } else {
                        log("🔴 unsuccessful \(type) \(path) \nerror: \(error.localizedDescription)", category: .api)
                        return ApiError(
                                sender: self,
                                url: url.absoluteString,
                                responseCode: 0,
                                message: "Unknown error occurred \(error.localizedDescription)",
                                requestType: type,
                                headers: headers,
                                params: queryParams
                        )
                    }
                }
                .eraseToAnyPublisher()
    }

    private func buildRequestUrl(path: String, queryParams: [ParamKey: ParamValue]) -> URL? {
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved) else {
            return nil
        }
        guard var urlComponents = URLComponents(string: encodedPath) else {
            return nil
        }

        if !queryParams.isEmpty {
            urlComponents.percentEncodedQuery = urlComponents.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            urlComponents.queryItems = queryParams
                    .sorted { $0.key < $1.key }
                    .map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        return urlComponents.url
    }

    private func buildRequest(url: URL, type: ApiRequestType, headers: [HeaderKey: HeaderValue], bodyData: Data?) -> URLRequest {
        var request = URLRequest(url: url)

        request.httpMethod = type.rawValue

        headers.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        switch type {
        case .post, .put, .delete:
            request.httpBody = bodyData
        default:
            break
        }

        return request
    }

    private func stringifyData(data: Data?) -> String {
        let htmlPrefix = "<!doctype html>"
        guard let data = data else {
            return ""
        }

        guard let str = String(data: data, encoding: .utf8) else {
            return ""
        }

        return str.replacingOccurrences(of: htmlPrefix, with: "")
    }

}

extension RestClient {
    private func create_cURL(requestType: ApiRequestType, path: URL, headers: [HeaderKey: HeaderValue], bodyData: Data?) -> String {
        let string = """
                     curl -vX "\(requestType.rawValue)" "\(path.description)" \\
                          \(headers.map {"-H '\($0.key): \($0.value)'"}.joined(separator: "\\\n     "))\\
                          -d $'\(bodyData?.utf8 ?? "")'
                     """
        return string
    }
}
