import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.modelStatus != "Ready" {
                    VStack(spacing: 8) {
                        Text(viewModel.modelStatus)
                            .padding(.top)
                            .foregroundColor(.secondary)
                        
                        if viewModel.isDownloading {
                            ProgressView()
                                .padding()
                        } else {
                            Button("モデルをロード") {
                                Task {
                                    await viewModel.setupModel()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                    }
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.messages) { message in
                            HStack {
                                if message.isUser {
                                    Spacer()
                                    Text(message.text)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                } else {
                                    Text(message.text)
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(16)
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                HStack {
                    TextField("Message...", text: $viewModel.inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(viewModel.modelStatus != "Ready")
                    
                    Button("Send") {
                        viewModel.sendMessage()
                    }
                    .disabled(viewModel.modelStatus != "Ready" || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Astro iOS LLM")
            .toolbar {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    Form {
                        Section(header: Text("Model Configuration")) {
                            TextField("HF Model ID", text: $viewModel.hfModelID)
                            TextField("HF Filename", text: $viewModel.hfFilename)
                        }
                        
                        Button("適用して再読込み") {
                            showSettings = false
                            Task {
                                await viewModel.setupModel()
                            }
                        }
                    }
                    .navigationTitle("Settings")
                    .toolbar {
                        Button("Close") {
                            showSettings = false
                        }
                    }
                }
            }
        }
    }
}
