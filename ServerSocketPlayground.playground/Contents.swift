import Foundation

class EchoServer {
    private var serverSocket: Int32 = 0
    private let port: UInt16

    init(port: UInt16) {
        self.port = port
    }

    func start() {
        setupServerSocket()
        startListening()
    }

    private func setupServerSocket() {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian

        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket != -1 else {
            perror("Error creating socket")
            return
        }

        withUnsafePointer(to: &addr) { ptrAddr in
            ptrAddr.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptrSockaddr in
                guard bind(serverSocket, ptrSockaddr, socklen_t(MemoryLayout<sockaddr_in>.size)) != -1 else {
                    perror("Error binding socket")
                    close(serverSocket)
                    return
                }
            }
        }

        listen(serverSocket, 5)
        print("Server listening on port \(port)")
    }

    private func startListening() {
        while true {
            let clientSocket = accept(serverSocket, nil, nil)
            guard clientSocket != -1 else {
                perror("Error accepting connection")
                continue
            }

            DispatchQueue.global().async {
                self.handleClient(clientSocket: clientSocket)
            }
        }
    }

    private func handleClient(clientSocket: Int32) {
        defer {
            close(clientSocket)
        }

        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while true {
            let bytesRead = recv(clientSocket, &buffer, bufferSize, 0)

            guard bytesRead > 0 else {
                handleReceiveError(bytesRead)
                return
            }

            handleReceivedData(buffer: buffer, bytesRead: bytesRead, clientSocket: clientSocket)

            // Clear the buffer for the next iteration
            buffer = [UInt8](repeating: 0, count: bufferSize)
        }
    }

    private func handleReceivedData(buffer: [UInt8], bytesRead: Int, clientSocket: Int32) {
        guard let receivedString = String(bytes: buffer, encoding: .utf8) else {
            print("Error decoding received data")
            return
        }

        print("Received: \(receivedString)")

        // Echo back to the client
        send(clientSocket, buffer, bytesRead, 0)
    }

    private func handleReceiveError(_ bytesRead: Int) {
        if bytesRead == 0 {
            print("Client disconnected")
        } else {
            perror("Error receiving data")
        }
    }

    deinit {
        close(serverSocket)
    }
}

// Usage
let port: UInt16 = 12346
let echoServer = EchoServer(port: port)
echoServer.start()

