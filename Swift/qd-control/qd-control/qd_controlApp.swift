//
//  qd_controlApp.swift
//  qd-control
//
//  Created by Edward Janne on 10/25/23.
//

import SwiftUI
import simd
import Network

let testPoints = [
			simd_float4(x: -800.0,     y: 0.0,    z: -800.0,     w: 0.0),
			simd_float4(x: -800.0,     y: 0.0,    z:  300.0,     w: 0.0),
			simd_float4(x:  300.0,     y: 0.0,    z:  300.0,     w: 0.0),
			simd_float4(x:  300.0,     y: 0.0,    z: -300.0,     w: 0.0),
			simd_float4(x: -200.0,     y: 0.0,    z: -300.0,     w: 0.0),
			simd_float4(x: -200.0,     y: 0.0,    z: -750.0,     w: 0.0),
			simd_float4(x: -150.0,     y: 0.0,    z: -800.0,     w: 0.0),
			simd_float4(x:  800.0,     y: 0.0,    z: -800.0,     w: 0.0),
			simd_float4(x:  800.0,     y: 0.0,    z:    0.0,     w: 0.0),
			simd_float4(x:  800.0,     y: 0.0,    z:  700.0,     w: 0.0),
			simd_float4(x:  700.0,     y: 0.0,    z:  800.0,     w: 0.0),
			simd_float4(x: -800.0,     y: 0.0,    z:  800.0,     w: 0.0),
			
			/*
			simd_float4(x: 100.0, y: 100.0, z: 0.0, w: 0.0),
			simd_float4(x: 100.0, y: 500.0, z: 0.0, w: 0.0),
			simd_float4(x: 400.0, y: 500.0, z: 0.0, w: 0.0),
			simd_float4(x: 400.0, y: 100.0, z: 0.0, w: 0.0),
			simd_float4(x: 900.0, y: 100.0, z: 0.0, w: 0.0),
			simd_float4(x: 900.0, y: 500.0, z: 0.0, w: 0.0),
			simd_float4(x: 900.0, y: 850.0, z: 0.0, w: 0.0),
			simd_float4(x: 850.0, y: 900.0, z: 0.0, w: 0.0),
			simd_float4(x: 100.0, y: 900.0, z: 0.0, w: 0.0),
			*/
		]


// Circuit Launch
let remoteHost = "192.168.4.1"
// Home

// let remoteHost = "192.168.7.220"
let remoteIP = IPv4Address(remoteHost)!
let remotePort = UInt16(3567)

let bodyHeight: Float = 80.0

let qdRobot = QDRobot(
	bodyHeight: bodyHeight,
    hipToShoulder: 42.0,
    shoulderToElbow: 42.0,
    elbowToToe: 73.0,
    frontRightRoot  : simd_float4( 29.0, 0.0,  75.0, 0.0),
    frontLeftRoot   : simd_float4(-29.0, 0.0,  75.0, 0.0),
    backRightRoot   : simd_float4( 29.0, 0.0, -75.0, 0.0),
    backLeftRoot    : simd_float4(-29.0, 0.0, -75.0, 0.0),
	frontRight  : simd_float4(x:  71.0, y: -bodyHeight, z:  75.0, w: 0.0),
	frontLeft   : simd_float4(x: -71.0, y: -bodyHeight, z:  75.0, w: 0.0),
	backRight   : simd_float4(x:  71.0, y: -bodyHeight, z: -75.0, w: 0.0),
	backLeft    : simd_float4(x: -71.0, y: -bodyHeight, z: -75.0, w: 0.0))

let qdClient = QDClient(localPort: 3567, remoteEndpoint: NWEndpoint.hostPort(host: .ipv4(remoteIP), port: NWEndpoint.Port(integerLiteral: remotePort)))

let qdControl = QDControl(robot: qdRobot, client: qdClient, controlPoints: testPoints)

@main
struct qd_controlApp: App {
    
    var body: some Scene {
        WindowGroup {
            ContentView(qdControl: qdControl, qdRobot: qdRobot, qdClient: qdClient)
        }
    }
}
