import Foundation
import Darwin

/// Sends local Rich Presence updates to the Discord desktop client over its
/// documented IPC socket. The client ID is supplied by the user; NEXARC never
/// logs in to Discord or sends activity through a remote service.
final class DiscordPresence: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.nexarc.discord-presence")
    private let lock = NSLock()
    private var descriptor: Int32 = -1

    func start(clientID: String, title: String, system: String, started: Date) {
        let cleanID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanID.isEmpty else { return }
        queue.async { [weak self] in
            guard let self else { return }
            self.closeSocket()
            guard let fd = Self.connectDiscord() else { return }
            self.lock.lock(); self.descriptor = fd; self.lock.unlock()
            guard self.sendFrame(opcode: 0, json: ["v": 1, "client_id": cleanID]),
                  let response = self.readFrame(fd: fd), response.opcode == 1 else {
                self.closeSocket(expected: fd); return
            }
            let activity: [String: Any] = [
                "details": "Playing \(String(title.prefix(128)))",
                "state": "\(system) · NEXARC",
                "timestamps": ["start": Int(started.timeIntervalSince1970)],
                "instance": false
            ]
            guard self.sendFrame(opcode: 1, json: ["cmd": "SET_ACTIVITY", "args": ["pid": getpid(), "activity": activity], "nonce": UUID().uuidString]) else {
                self.closeSocket(expected: fd); return
            }
            while let frame = self.readFrame(fd: fd) {
                if frame.opcode == 3 { _ = self.sendRaw(opcode: 4, payload: frame.payload) }
                if frame.opcode == 2 { break }
            }
            self.closeSocket(expected: fd)
        }
    }

    func clear() {
        DispatchQueue.global(qos: .utility).async { [weak self] in self?.closeSocket() }
    }

    private static func connectDiscord() -> Int32? {
        for index in 0...9 {
            let path = "/tmp/discord-ipc-\(index)"
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { continue }
            var noSigPipe: Int32 = 1
            _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
            var address = sockaddr_un()
            address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
            address.sun_family = sa_family_t(AF_UNIX)
            let copied = withUnsafeMutableBytes(of: &address.sun_path) { target -> Bool in
                guard path.utf8.count < target.count else { return false }
                target.initializeMemory(as: UInt8.self, repeating: 0)
                guard let base = target.baseAddress?.assumingMemoryBound(to: CChar.self) else { return false }
                path.withCString { _ = strlcpy(base, $0, target.count) }
                return true
            }
            guard copied else { close(fd); continue }
            let result = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if result == 0 { return fd }
            close(fd)
        }
        return nil
    }

    private func sendFrame(opcode: UInt32, json: [String: Any]) -> Bool {
        guard let payload = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]) else { return false }
        return sendRaw(opcode: opcode, payload: payload)
    }

    private func sendRaw(opcode: UInt32, payload: Data) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard descriptor >= 0 else { return false }
        var packet = Data()
        var op = opcode.littleEndian
        var length = UInt32(payload.count).littleEndian
        withUnsafeBytes(of: &op) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: &length) { packet.append(contentsOf: $0) }
        packet.append(payload)
        return packet.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return false }
            var sent = 0
            while sent < bytes.count {
                let count = Darwin.send(descriptor, base.advanced(by: sent), bytes.count - sent, 0)
                if count <= 0 { return false }
                sent += count
            }
            return true
        }
    }

    private func readFrame(fd: Int32) -> (opcode: UInt32, payload: Data)? {
        guard let header = Self.readExactly(fd: fd, count: 8) else { return nil }
        let opcode = header[0..<4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
        let length = header[4..<8].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
        guard length <= 1_048_576, let payload = Self.readExactly(fd: fd, count: Int(length)) else { return nil }
        return (opcode, payload)
    }

    private static func readExactly(fd: Int32, count: Int) -> Data? {
        var data = Data(count: count)
        let success = data.withUnsafeMutableBytes { bytes -> Bool in
            guard let base = bytes.baseAddress else { return count == 0 }
            var received = 0
            while received < count {
                let n = Darwin.recv(fd, base.advanced(by: received), count - received, 0)
                if n <= 0 { return false }
                received += n
            }
            return true
        }
        return success ? data : nil
    }

    private func closeSocket(expected: Int32? = nil) {
        lock.lock()
        if let expected, descriptor != expected { lock.unlock(); return }
        let fd = descriptor; descriptor = -1; lock.unlock()
        if fd >= 0 { shutdown(fd, SHUT_RDWR); close(fd) }
    }
}
