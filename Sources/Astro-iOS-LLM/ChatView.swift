import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showSettings = false
    @State private var showFileImporter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("チャット")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // MARK: - Status Bar
            if viewModel.modelStatus != "Ready" {
                HStack {
                    Text(viewModel.modelStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if viewModel.isDownloading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button("Reload") {
                            Task { await viewModel.setupModel() }
                        }
                        .font(.caption)
                    }
                }
                .padding(.horizontal)
            }
            
            // MARK: - Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            HStack {
                                if message.isUser {
                                    Spacer()
                                    Text(message.text)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(red: 0.3, green: 0.7, blue: 1.0))
                                        .foregroundColor(.white)
                                        .clipShape(BubbleShape(isUser: true))
                                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                } else {
                                    Text(message.text)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(.systemGray6))
                                        .foregroundColor(.primary)
                                        .clipShape(BubbleShape(isUser: false))
                                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 16)
                            .id(message.id)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            // MARK: - Input Area
            VStack(spacing: 8) {
                if let docName = viewModel.selectedDocumentName {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text(docName)
                        Button(action: {
                            viewModel.selectedDocumentName = nil
                            viewModel.attachedContent = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                HStack(spacing: 12) {
                    // Attach Button
                    Button(action: { showFileImporter = true }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.3, green: 0.7, blue: 1.0))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Text Input Field
                    HStack {
                        TextField("", text: $viewModel.inputText)
                            .placeholder(when: viewModel.inputText.isEmpty) {
                                Text("メッセージを入力")
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            .padding(.leading, 16)
                            .frame(height: 50)
                        
                        // Send Button inside the input bar
                        Button(action: { viewModel.sendMessage() }) {
                            Circle()
                                .fill(Color(red: 0.3, green: 0.7, blue: 1.0))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text("送信")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.black)
                                )
                        }
                        .padding(.trailing, 6)
                        .disabled(viewModel.modelStatus != "Ready" || (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachedContent == nil))
                        .opacity(viewModel.inputText.isEmpty && viewModel.attachedContent == nil ? 0.5 : 1.0)
                    }
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText, .text, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.attachDocument(at: url)
                }
            case .failure(let error):
                print("Error selecting file: \(error)")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel, isPresented: $showSettings)
        }
    }
}

// MARK: - Helper Views

struct BubbleShape: Shape {
    var isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: [
            .topLeft, .topRight, isUser ? .bottomLeft : .bottomRight
        ], cornerRadii: CGSize(width: 16, height: 16))
        return Path(path.cgPath)
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Model Configuration")) {
                    TextField("HF Model ID", text: $viewModel.hfModelID)
                    TextField("HF Filename", text: $viewModel.hfFilename)
                }
                
                Button("適用して再読込み") {
                    isPresented = false
                    Task {
                        await viewModel.setupModel()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Close") {
                    isPresented = false
                }
            }
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
