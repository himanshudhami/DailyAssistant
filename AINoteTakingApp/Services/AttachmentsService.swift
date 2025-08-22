//
//  AttachmentsService.swift
//  AINoteTakingApp
//
//  Service for managing file attachments via backend API
//

import Foundation
import Combine
import UIKit

// MARK: - File Upload Models

struct FileUploadResult: Codable {
    let id: UUID
    let fileName: String
    let originalName: String
    let localPath: String
    let url: String
    let fileSize: Int64
    let mimeType: String
    let extension: String
    let checksum: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case fileName = "file_name"
        case originalName = "original_name"
        case localPath = "local_path"
        case url
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case extension
        case checksum
    }
}

class AttachmentsService {
    static let shared = AttachmentsService()
    
    private let client: NetworkClient
    private let session: URLSession
    
    private init(client: NetworkClient = .shared) {
        self.client = client
        
        // Configure session for file uploads
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Upload Operations
    
    func uploadAttachment(
        for noteId: UUID,
        fileURL: URL,
        mimeType: String
    ) -> AnyPublisher<Attachment, NetworkError> {
        
        // Step 1: Upload file first (get server URL)
        return uploadFileToServer(fileURL: fileURL, mimeType: mimeType)
            .flatMap { uploadResult in
                // Step 2: Create attachment record with server URL
                self.createAttachmentRecord(noteId: noteId, uploadResult: uploadResult)
            }
            .eraseToAnyPublisher()
    }
    
    private func uploadFileToServer(
        fileURL: URL,
        mimeType: String
    ) -> AnyPublisher<FileUploadResult, NetworkError> {
        
        guard let baseURL = URL(string: "http://192.168.86.26:8080/api/v1") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let url = baseURL.appendingPathComponent("/attachments/upload")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add auth header
        if let token = client.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent
            
            var body = Data()
            
            // Add file data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Close boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            struct FileUploadResponse: Codable {
                let attachment: APIAttachment
                let uploadResult: FileUploadResult
            }
            
            return session.dataTaskPublisher(for: request)
                .tryMap { data, response in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NetworkError.networkFailed
                    }
                    
                    print("📁 File upload status: \(httpResponse.statusCode)")
                    
                    if !(200...299).contains(httpResponse.statusCode) {
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("❌ Upload error: \(responseString)")
                        }
                        throw NetworkError.networkFailed
                    }
                    
                    return data
                }
                .decode(type: FileUploadResponse.self, decoder: JSONDecoder())
                .map { response in
                    print("✅ File uploaded: \(response.uploadResult.fileName) -> \(response.uploadResult.url)")
                    return response.uploadResult
                }
                .mapError { error in
                    print("❌ File upload failed: \(error)")
                    return NetworkError.networkFailed
                }
                .eraseToAnyPublisher()
            
        } catch {
            return Fail(error: NetworkError.networkFailed)
                .eraseToAnyPublisher()
        }
    }
    
    private func createAttachmentRecord(
        noteId: UUID,
        uploadResult: FileUploadResult
    ) -> AnyPublisher<Attachment, NetworkError> {
        
        struct AttachToNoteRequest: Codable {
            let attachmentId: UUID
            let noteId: UUID
            
            enum CodingKeys: String, CodingKey {
                case attachmentId = "attachment_id"
                case noteId = "note_id"
            }
        }
        
        let request = AttachToNoteRequest(
            attachmentId: uploadResult.id,
            noteId: noteId
        )
        
        struct AttachmentResponse: Codable {
            let attachment: APIAttachment
        }
        
        return client.request(
            "/notes/\(noteId)/attachments",
            method: .POST,
            body: request,
            responseType: AttachmentResponse.self
        )
        .compactMap { response in
            print("✅ Attachment linked to note: \(response.attachment.fileName)")
            return Attachment.from(response.attachment)
        }
        .eraseToAnyPublisher()
    }
    
    func uploadImage(
        for noteId: UUID,
        image: UIImage,
        compressionQuality: CGFloat = 0.8
    ) -> AnyPublisher<Attachment, NetworkError> {
        
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            return Fail(error: NetworkError.encodingFailed)
                .eraseToAnyPublisher()
        }
        
        // Save to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        do {
            try imageData.write(to: tempURL)
            return uploadAttachment(for: noteId, fileURL: tempURL, mimeType: "image/jpeg")
                .handleEvents(receiveCompletion: { _ in
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)
                })
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: NetworkError.networkFailed)
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Download Operations
    
    func downloadAttachment(_ attachment: Attachment) -> AnyPublisher<URL, NetworkError> {
        guard let baseURL = URL(string: "http://192.168.86.26:8080/api/v1") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let url = baseURL.appendingPathComponent("/attachments/\(attachment.id)/download")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add auth header
        if let token = client.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return session.downloadTaskPublisher(for: request)
            .tryMap { url, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.networkFailed
                }
                
                // Move file to Documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                            in: .userDomainMask)[0]
                let destinationURL = documentsPath
                    .appendingPathComponent("attachments")
                    .appendingPathComponent(attachment.fileName)
                
                // Create directory if needed
                try? FileManager.default.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                
                // Move file
                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: url, to: destinationURL)
                
                return destinationURL
            }
            .mapError { _ in NetworkError.networkFailed }
            .eraseToAnyPublisher()
    }
    
    // MARK: - CRUD Operations
    
    func getAttachments(for noteId: UUID) -> AnyPublisher<[Attachment], NetworkError> {
        struct AttachmentsResponse: Codable {
            let attachments: [APIAttachment]
        }
        
        return client.request(
            "/notes/\(noteId)/attachments",
            method: .GET,
            responseType: AttachmentsResponse.self
        )
        .map { response in
            response.attachments.compactMap { Attachment.from($0) }
        }
        .eraseToAnyPublisher()
    }
    
    func deleteAttachment(_ id: UUID) -> AnyPublisher<Void, NetworkError> {
        return client.request(
            "/attachments/\(id)",
            method: .DELETE
        )
    }
    
    // MARK: - Batch Operations
    
    func batchUploadAttachments(
        for noteId: UUID,
        fileURLs: [URL]
    ) -> AnyPublisher<[Attachment], NetworkError> {
        
        let uploads = fileURLs.map { url -> AnyPublisher<Attachment, NetworkError> in
            let mimeType = mimeType(for: url)
            return uploadAttachment(for: noteId, fileURL: url, mimeType: mimeType)
        }
        
        return Publishers.MergeMany(uploads)
            .collect()
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func mimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "pdf":
            return "application/pdf"
        case "mp3":
            return "audio/mpeg"
        case "mp4":
            return "video/mp4"
        case "txt":
            return "text/plain"
        case "doc", "docx":
            return "application/msword"
        default:
            return "application/octet-stream"
        }
    }
}

// MARK: - URLSession Extension for Download Tasks
extension URLSession {
    func downloadTaskPublisher(for request: URLRequest) -> AnyPublisher<(URL, URLResponse), URLError> {
        Future<(URL, URLResponse), URLError> { promise in
            let task = self.downloadTask(with: request) { url, response, error in
                if let error = error as? URLError {
                    promise(.failure(error))
                } else if let url = url, let response = response {
                    promise(.success((url, response)))
                } else {
                    promise(.failure(URLError(.unknown)))
                }
            }
            task.resume()
        }
        .eraseToAnyPublisher()
    }
}