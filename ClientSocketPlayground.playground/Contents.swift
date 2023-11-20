import Foundation

class EchoClient {
    let serverHost: String
    let serverPort: UInt16

    init(serverHost: String, serverPort: UInt16) {
        self.serverHost = serverHost
        self.serverPort = serverPort
    }

    func start() {
        guard let serverAddress = createServerAddress() else { return }
        let clientSocket = createClientSocket(with: serverAddress)

        guard clientSocket != -1 else { return }

        defer {
            close(clientSocket)
        }

        sendData(to: clientSocket)
        receiveAndPrintResponse(from: clientSocket)
    }

    private func createServerAddress() -> sockaddr_in? {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = serverPort.bigEndian
        addr.sin_addr.s_addr = inet_addr(serverHost)

        return addr
    }

    private func createClientSocket(with serverAddress: sockaddr_in) -> Int32 {
        let clientSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard clientSocket != -1 else {
            perror("Error creating socket")
            return -1
        }

        withUnsafePointer(to: serverAddress) { ptrAddr in
            ptrAddr.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptrSockaddr in
                guard connect(clientSocket, ptrSockaddr, socklen_t(MemoryLayout<sockaddr_in>.size)) != -1 else {
                    perror("Error connecting to server")
                    close(clientSocket)
                    return
                }
            }
        }

        return clientSocket
    }

    private func sendData(to clientSocket: Int32) {
        let message = "“Who has not asked himself at some time or other: am I a monster or is this what it means to be a person?”"
        guard let messageData = message.data(using: .utf8) else {
            print("Error encoding message")
            return
        }

        _ = messageData.withUnsafeBytes { bufferPointer in
            send(clientSocket, bufferPointer.baseAddress, messageData.count, 0)
        }
    }

    private func receiveAndPrintResponse(from clientSocket: Int32) {
        var buffer = [UInt8](repeating: 0, count: 1024)

        let bytesRead = recv(clientSocket, &buffer, buffer.count, 0)
        if bytesRead > 0 {
            if let responseString = String(bytes: buffer, encoding: .utf8) {
                print("Server Response: \(responseString)")
            } else {
                print("Error decoding server response")
            }
        } else if bytesRead == 0 {
            print("Server closed the connection")
        } else {
            perror("Error receiving data from server")
        }
    }
}

// Usage
let serverHost = "0.0.0.0"  // Replace with the actual IP address or hostname of your server
let serverPort: UInt16 = 12346 // Replace with the port number used by your server

let echoClient = EchoClient(serverHost: serverHost, serverPort: serverPort)
echoClient.start()

