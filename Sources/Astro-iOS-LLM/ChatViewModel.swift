import Foundation
import LocalLLMClient
import LocalLLMClientLlama

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isDownloading: Bool = false
    @Published var modelStatus: String = "Not loaded"
    
    // Default model specified by user
    @Published var hfModelID: String = "unsloth/gemma-3-1b-it-GGUF"
    @Published var hfFilename: String = "gemma-3-1b-it-Q4_K_S.gguf"
    
    private var client: (any LLMClient)?
    private var chatHistory: [LLMInput.Message] = []
    
    struct Message: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
    }
    
    func setupModel() async {
        isDownloading = true
        modelStatus = "Downloading model..."
        
        do {
            let modelPath = try await downloadModel(id: hfModelID, filename: hfFilename)
            
            modelStatus = "Loading model..."
            
            // Initialize the llama backend
            let llamaClient = try await LocalLLMClient.llama(url: modelPath)
            self.client = llamaClient
            
            // Add initial system prompt if needed
            chatHistory = [
                .system("You are a helpful assistant running locally on an iOS device.")
            ]
            
            modelStatus = "Ready"
        } catch {
            modelStatus = "Error: \(error.localizedDescription)"
            print("Error loading model: \(error)")
        }
        
        isDownloading = false
    }
    
    func downloadModel(id: String, filename: String) async throws -> URL {
        guard let url = URL(string: "https://huggingface.co/\(id)/resolve/main/\(filename)") else {
            throw URLError(.badURL)
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL // Already downloaded
        }
        
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }
    
    func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }
        guard let client = client else {
            modelStatus = "Model not ready"
            return
        }
        
        inputText = ""
        messages.append(Message(text: userMessage, isUser: true))
        chatHistory.append(.user(userMessage))
        
        // Add empty assistant message placeholder
        messages.append(Message(text: "", isUser: false))
        
        Task {
            do {
                let stream = try await client.textStream(from: .chat(chatHistory))
                
                var responseText = ""
                for try await chunk in stream {
                    responseText += chunk
                    
                    // Update the last message in the UI
                    if let lastIndex = self.messages.indices.last {
                        self.messages[lastIndex] = Message(text: responseText, isUser: false)
                    }
                }
                
                chatHistory.append(.assistant(responseText))
                
            } catch {
                if let lastIndex = self.messages.indices.last {
                    self.messages[lastIndex] = Message(text: "Error: \(error.localizedDescription)", isUser: false)
                }
            }
        }
    }
}
