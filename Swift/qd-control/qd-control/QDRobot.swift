//
//  QDRobot.swift
//  qd-control
//
//  Created by Edward Janne on 10/26/23.
//

import Foundation
import simd
import SwiftUI

@Observable
class QDRobot {
    class Limb {
        enum Configuration: Int {
            case frontRight = 0
            case frontLeft  = 1
            case backRight  = 2
            case backLeft   = 3
        }
        
        let configuration   : Configuration
        let rootOffset      : simd_float4
        let l0              : Float
        let l0sq            : Float
        let l1              : Float
        let l1sq            : Float
        let l2              : Float
        let l2sq            : Float
        
        var hipAngle        : Float
        var shoulderAngle   : Float
        var elbowAngle      : Float
        
        var unreachableGoal	: Bool = false
        
        init(config: Configuration, root: simd_float4, hipToShoulder: Float, shoulderToElbow: Float, elbowToToe: Float) {
            configuration   = config
            rootOffset      = root
            l0              = hipToShoulder
            l0sq            = l0 * l0
            l1              = shoulderToElbow
            l1sq            = l1 * l1
            l2              = elbowToToe
            l2sq            = l2 * l2
            
            hipAngle        = 0.0
            shoulderAngle   = 0.0
            elbowAngle      = 0.0
        }
        
        func normalizeTarget(_ target: simd_float4)->simd_float4 {
            var normalized = target - rootOffset;
            switch(configuration) {
                case .frontLeft: fallthrough
                case .backLeft:
                    let m = simd_float4x4(rotationAxis: simd_float4.j, angle: Float.pi)
                    normalized = m * normalized
                default:
                    break;
            }
            return normalized
        }
        
        func denormalizeTarget(_ normalized: simd_float4)->simd_float4 {
            var target: simd_float4 = .zero
            switch(configuration) {
                case .frontLeft: fallthrough
                case .backLeft:
                    let m = simd_float4x4(rotationAxis: simd_float4.j, angle: -Float.pi)
                    target = m * normalized
                default:
                    break;
            }
            return target + rootOffset
        }
        
        func calcIKAngles(_ target: simd_float4) {
            var dsq     : Float = target[0] * target[0] + target[1] * target[1]
            var d       : Float = sqrtf(dsq)
            let e       : Float = acosf(l0 / d)
            let n       : Float = 1.0 / d
            let unitp   = simd_float4(target[0] * n, target[1] * n, 0.0, 0.0)
            let mat     = simd_float4x4(rotationAxis: simd_float4.k, angle: e)
            let v       = mat * unitp * l0
            hipAngle    = -atan2f(v[1], v[0])
            let p       = target - v
            dsq         = simd_dot(p, p)
            d           = sqrtf(dsq);
            unreachableGoal = (l1 + l2 < d)
            let at      = asinf(target[2] / d);
            let ae      = unreachableGoal ? Float.pi : acosf(0.5 * (l1sq + l2sq - dsq) / (l1 * l2))
            let a1      = unreachableGoal ? 0.0 : acosf(0.5 * (l1sq + dsq - l2sq) / (l1 * d))
            
            switch(configuration) {
                case .frontLeft: fallthrough
                case .backLeft:
                    shoulderAngle   = at + a1 - Float.pi * 0.5;
                    elbowAngle      = ae - Float.pi;
                default:
                    hipAngle        *= -1.0;
                    shoulderAngle   = Float.pi * 0.5 - (at + a1);
                    elbowAngle      = Float.pi - ae;
            }
            
            hipAngle                += Float.pi;
            shoulderAngle           += Float.pi;
            elbowAngle              += Float.pi;
        }
        
        subscript(_ i: Int)->Float {
            get {
                switch i {
                    case 0:
                        return hipAngle
                    case 1:
                        return shoulderAngle
                    default:
                        return elbowAngle
                }
            }
            set{
                switch i {
                    case 0:
                        hipAngle        = newValue
                    case 1:
                        shoulderAngle   = newValue
                    default:
                        elbowAngle      = newValue
                }
            }
        }
    }
    
    var bodyHeight: Float = 100.0
    var limbs: [Limb]
    var ikTargets: [simd_float4]
    
    init(bodyHeight: Float = 100.0, hipToShoulder: Float, shoulderToElbow: Float, elbowToToe: Float, frontRightRoot: simd_float4, frontLeftRoot: simd_float4, backRightRoot: simd_float4, backLeftRoot: simd_float4, frontRight: simd_float4, frontLeft: simd_float4, backRight: simd_float4, backLeft: simd_float4) {
		self.bodyHeight = bodyHeight
		
		let limb0 = Limb(config: .frontRight, root: frontRightRoot, hipToShoulder: hipToShoulder, shoulderToElbow: shoulderToElbow, elbowToToe: elbowToToe)
		let limb1 = Limb(config: .frontLeft, root: frontLeftRoot, hipToShoulder: hipToShoulder, shoulderToElbow: shoulderToElbow, elbowToToe: elbowToToe)
		let limb2 = Limb(config: .backRight, root: backRightRoot, hipToShoulder: hipToShoulder, shoulderToElbow: shoulderToElbow, elbowToToe: elbowToToe)
		let limb3 = Limb(config: .backLeft, root: backLeftRoot, hipToShoulder: hipToShoulder, shoulderToElbow: shoulderToElbow, elbowToToe: elbowToToe)
        
        limbs = [
			limb0,
			limb1,
			limb2,
			limb3
        ]
        ikTargets = [
        	limb0.normalizeTarget(frontRight),
        	limb1.normalizeTarget(frontLeft),
        	limb2.normalizeTarget(backRight),
        	limb3.normalizeTarget(backLeft)
        ]
    }
    
    func setIKTargets(frontRight: simd_float4, frontLeft: simd_float4, backRight: simd_float4, backLeft: simd_float4) {
        ikTargets[0] = limbs[0].normalizeTarget(frontRight)
        ikTargets[1] = limbs[1].normalizeTarget(frontLeft)
        ikTargets[2] = limbs[2].normalizeTarget(backRight)
        ikTargets[3] = limbs[3].normalizeTarget(backLeft)
        ikTargets[0].z *= -1.0
        ikTargets[2].z *= -1.0
        update()
    }
    
    func setAngles(hipAngles: simd_float4, shoulderAngles: simd_float4, elbowAngles: simd_float4) {
        for i in 0 ..< 4 {
            limbs[i][0] = hipAngles[i]
            limbs[i][1] = shoulderAngles[i]
            limbs[i][2] = elbowAngles[i]
        }
    }
    
    func update() {
        for i in 0 ..< 4 {
            limbs[i].calcIKAngles(ikTargets[i])
        }
    }
    
    var angles: (simd_float4, simd_float4, simd_float4) {
        var hipAngles: simd_float4 = .zero
        var shoulderAngles: simd_float4 = .zero
        var elbowAngles: simd_float4 = .zero
        for i in 0 ..< 4 {
            hipAngles[i] = limbs[i][0]
            shoulderAngles[i] = limbs[i][1]
            elbowAngles[i] = limbs[i][2]
        }
        return (hipAngles, shoulderAngles, elbowAngles)
    }

    func extractAngles(_ pose: QDFeedback) {
        for i in 0 ..< 4 {
            limbs[i][0] = pose.hips[i]
            limbs[i][1] = pose.shoulders[i]
            limbs[i][2] = pose.elbows[i]
        }
    }
    
    func centroid(_ limb: Limb.Configuration)->simd_float4 {
        var p0: simd_float2 = .zero
        var p1: simd_float2 = .zero
        var p2: simd_float2 = .zero
        
        switch limb {
            case .frontRight:
                p0 = simd_float2(ikTargets[1].x, ikTargets[1].z)
                p1 = simd_float2(ikTargets[2].x, ikTargets[2].z)
                p2 = simd_float2(ikTargets[3].x, ikTargets[3].z)
            case .frontLeft:
                p0 = simd_float2(ikTargets[0].x, ikTargets[0].z)
                p1 = simd_float2(ikTargets[2].x, ikTargets[2].z)
                p2 = simd_float2(ikTargets[3].x, ikTargets[3].z)
            case .backRight:
                p0 = simd_float2(ikTargets[0].x, ikTargets[0].z)
                p1 = simd_float2(ikTargets[1].x, ikTargets[1].z)
                p2 = simd_float2(ikTargets[3].x, ikTargets[3].z)
            case .backLeft:
                p0 = simd_float2(ikTargets[0].x, ikTargets[0].z)
                p1 = simd_float2(ikTargets[1].x, ikTargets[1].z)
                p2 = simd_float2(ikTargets[2].x, ikTargets[2].z)
        }
        
        let m0 = (p0 + p1) * 0.5
        let m1 = (p1 + p2) * 0.5
        
        let x1 = m0.x
        let y1 = m0.y
        let x2 = p2.x
        let y2 = p2.y
        
        let x3 = m1.x
        let y3 = m1.y
        let x4 = p0.x
        let y4 = p0.y
        
        let d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        
        let x = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) / d
        let y = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) / d
        
        return simd_float4(x, 0.0, y, 1.0)
    }
}
