//
//  DeviceDiscoveryService.swift
//  TVremote
//
//  mDNS/Bonjour device discovery for Android TV
//

import Foundation
import Network
import Combine

/// Discovers Android TV devices on the local network using mDNS/Bonjour
final class DeviceDiscoveryService: NSObject, DeviceDiscoveryProtocol {
    // MARK: - Properties

    private var browser: NWBrowser?
    private var netServiceBrowser: NetServiceBrowser?
    private var resolving: [NetService] = []

    private var devicesSubject = CurrentValueSubject<[TVDevice], Never>([])
    private var scanningSubject = CurrentValueSubject<Bool, Never>(false)

    private var foundDevices: Set<TVDevice> = []
    private let queue = DispatchQueue(label: "com.tvremote.discovery", qos: .userInitiated)

    // Android TV Remote service type
    private let serviceType = "_androidtvremote2._tcp."
    private let domain = "local."

    // MARK: - DeviceDiscoveryProtocol

    var discoveredDevices: AnyPublisher<[TVDevice], Never> {
        devicesSubject.eraseToAnyPublisher()
    }

    var isScanning: AnyPublisher<Bool, Never> {
        scanningSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    override init() {
        super.init()
    }

    deinit {
        stopScanning()
    }

    // MARK: - Scanning

    func startScanning() {
        guard !scanningSubject.value else { return }

        scanningSubject.send(true)
        foundDevices.removeAll()
        devicesSubject.send([])

        // Use NetServiceBrowser for mDNS discovery
        startNetServiceBrowser()

        // Also try NWBrowser for newer iOS
        startNWBrowser()

        // Stop after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        scanningSubject.send(false)

        browser?.cancel()
        browser = nil

        netServiceBrowser?.stop()
        netServiceBrowser = nil

        resolving.forEach { $0.stop() }
        resolving.removeAll()
    }

    func manualConnect(host: String, port: Int = 6466) async throws -> TVDevice {
        // Validate IP address
        guard isValidIPAddress(host) else {
            throw DiscoveryError.invalidAddress
        }

        // Try to connect to verify device
        let device = TVDevice(
            name: "Android TV (\(host))",
            host: host,
            port: port
        )

        return device
    }

    // MARK: - NetServiceBrowser

    private func startNetServiceBrowser() {
        netServiceBrowser = NetServiceBrowser()
        netServiceBrowser?.delegate = self
        netServiceBrowser?.searchForServices(ofType: serviceType, inDomain: domain)
    }

    // MARK: - NWBrowser

    private func startNWBrowser() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: domain)
        browser = NWBrowser(for: descriptor, using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                break
            case .failed(let error):
                print("Browser failed: \(error)")
                self?.scanningSubject.send(false)
            default:
                break
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResults(results)
        }

        browser?.start(queue: queue)
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                // Resolve the service to get IP address
                resolveService(name: name, type: type, domain: domain)

            case .hostPort(let host, let port):
                if case .ipv4(let addr) = host {
                    let ipString = addr.debugDescription
                    addDevice(name: "Android TV", host: ipString, port: Int(port.rawValue))
                }

            default:
                break
            }
        }
    }

    private func resolveService(name: String, type: String, domain: String) {
        let service = NetService(domain: domain, type: type, name: name)
        service.delegate = self
        resolving.append(service)
        service.resolve(withTimeout: 10.0)
    }

    private func addDevice(name: String, host: String, port: Int) {
        let device = TVDevice(name: name, host: host, port: port)

        if !foundDevices.contains(device) {
            foundDevices.insert(device)
            DispatchQueue.main.async {
                self.devicesSubject.send(Array(self.foundDevices))
            }
        }
    }

    // MARK: - Validation

    private func isValidIPAddress(_ string: String) -> Bool {
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()

        if inet_pton(AF_INET, string, &sin.sin_addr) == 1 {
            return true
        }
        if inet_pton(AF_INET6, string, &sin6.sin6_addr) == 1 {
            return true
        }
        return false
    }
}

// MARK: - NetServiceBrowserDelegate

extension DeviceDiscoveryService: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        resolving.append(service)
        service.resolve(withTimeout: 10.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        resolving.removeAll { $0 == service }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Discovery error: \(errorDict)")
    }
}

// MARK: - NetServiceDelegate

extension DeviceDiscoveryService: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }

        for data in addresses {
            data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                guard let addr = pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return }

                if addr.pointee.sa_family == UInt8(AF_INET) {
                    var addr4 = pointer.load(as: sockaddr_in.self)
                    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &addr4.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                    let ip = String(cString: buffer)

                    addDevice(
                        name: sender.name.isEmpty ? "Android TV" : sender.name,
                        host: ip,
                        port: sender.port > 0 ? sender.port : 6466
                    )
                }
            }
        }

        resolving.removeAll { $0 == sender }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        resolving.removeAll { $0 == sender }
    }
}

// MARK: - Discovery Errors

enum DiscoveryError: Error, LocalizedError {
    case invalidAddress
    case networkUnavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid IP address"
        case .networkUnavailable:
            return "Network unavailable"
        case .timeout:
            return "Discovery timed out"
        }
    }
}
