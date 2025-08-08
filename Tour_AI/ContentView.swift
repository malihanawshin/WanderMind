import SwiftUI

struct ContentView: View {
    @State private var userInput: String = ""
    @State private var isLoading = false
    @State private var messages: [(role: String, content: String)] = []
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        VStack {
            Text("Plan your trip with TourAI !").font(.title3)
                .fontWeight(.bold).fontDesign(.rounded)
            //.font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary) // adapts to light/dark mode
                .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(messages, id: \.content) { message in
                        HStack {
                            if message.role == "user" {
                                Spacer()
                                Text(message.content)
                                    .padding(10)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(10)
                                    .foregroundColor(.primary) // Adapts to light/dark mode
                                    .frame(maxWidth: 300, alignment: .trailing)
                            } else {
                                Text(message.content)
                                    .padding(10)
                                    .background(Color.secondary.opacity(0.2)) // Secondary for assistant messages
                                    .cornerRadius(10)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: 300, alignment: .leading)
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground)) // Adapts background to light/dark mode
            
            HStack {
                TextEditor(text: $userInput)
                    .frame(height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary, lineWidth: 1)) // Secondary for border
                    .focused($isTextEditorFocused)
                    .background(Color(UIColor.systemBackground)) // Ensure input background adapts
                
                Button(action: {
                    isTextEditorFocused = false
                    sendToAI()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                    } else {
                        Text("Send")
                            .padding(10)
                            .background(userInput.isEmpty ? Color.secondary : Color.accentColor) // Use accentColor for button
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(userInput.isEmpty || isLoading)
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground)) // Ensure entire view background adapts
    }
    
    func sendToAI() {
        guard let url = URL(string: "https://5haapyl219.execute-api.eu-central-1.amazonaws.com/prod/ask") else {
            messages.append((role: "system", content: "Invalid URL"))
            return
        }
        
        isLoading = true
        let currentInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        messages.append((role: "user", content: currentInput))
        userInput = ""
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: [[String: String]]] = ["messages": messages.map { ["role": $0.role, "content": $0.content] }]
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            print("Request payload:", String(data: request.httpBody!, encoding: .utf8) ?? "N/A")
        } catch {
            print("Failed to encode payload:", error.localizedDescription)
            messages.append((role: "system", content: "Failed to encode payload: \(error.localizedDescription)"))
            isLoading = false
            return
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)
        
        session.dataTask(with: request) { data, response, error in
            defer { DispatchQueue.main.async { isLoading = false } }
            
            if let error = error {
                print("Network error:", error.localizedDescription)
                DispatchQueue.main.async {
                    messages.append((role: "system", content: "Network error: \(error.localizedDescription)"))
                }
                return
            }
            
            if let response = response as? HTTPURLResponse {
                print("Status code:", response.statusCode)
                print("Response headers:", response.allHeaderFields)
            }
            
            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async {
                    messages.append((role: "system", content: "No data received from server."))
                }
                return
            }
            
            print("Raw response data:", String(data: data, encoding: .utf8) ?? "N/A")
            
            do {
                if let decoded = try? JSONDecoder().decode(AIResponse.self, from: data) {
                    DispatchQueue.main.async {
                        messages.append((role: "assistant", content: decoded.response))
                    }
                } else {
                    struct ErrorResponse: Decodable {
                        let error: String
                        let details: String?
                    }
                    if let errorDecoded = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        DispatchQueue.main.async {
                            messages.append((role: "system", content: "Error: \(errorDecoded.error)\(errorDecoded.details != nil ? " - \(errorDecoded.details!)" : "")"))
                        }
                    } else {
                        DispatchQueue.main.async {
                            messages.append((role: "system", content: "Failed to parse response: \(String(data: data, encoding: .utf8) ?? "N/A")"))
                        }
                    }
                }
            }
        }.resume()
    }
}

struct AIResponse: Decodable {
    let response: String
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark) // Preview in dark mode
    }
}
