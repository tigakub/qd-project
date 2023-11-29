//
//  QDClient.swift
//  qd-control
//
//  Created by Edward Janne on 10/25/23.
//

import Foundation
import Network
import SwiftUI

@Observable
class QDClient {
    var cnx: NWConnection
    var listener: NWListener? = nil
    
    init(localPort: UInt16, remoteEndpoint: NWEndpoint) {
        do {
            listener = try NWListener(using: .udp, on: NWEndpoint.Port(integerLiteral: localPort))
        } catch(let e) {
			print("Unable to start UDP listener: \(e.localizedDescription)")
            // throw Exception(file: #file, function: #function, line: #line, message: e.localizedDescription)
        }
        cnx = NWConnection(to: remoteEndpoint, using: .udp)
        cnx.stateUpdateHandler = {
            newState in
            switch newState {
                case .cancelled:
                    print("Cancelled")
                case .ready:
                    print("Ready")
                case .preparing:
                    print("Preparing")
                case .setup:
                    print("Setting up")
                default:
                    print("Connection failed")
            }
        }
    }
    
    func start(recvHandler: @escaping (NWConnection)->()) {
        if let listener = listener {
			listener.newConnectionHandler = recvHandler
		}
        cnx.start(queue: .global())
    }
    
    func stop() {
		cnx.cancel()
    }
    
    func send(message: Data) {
        cnx.send(
            content: message,
            completion: .contentProcessed {
                error in
                if let error = error {
                    print(error.localizedDescription)
                }
            }
        )
    }
}
