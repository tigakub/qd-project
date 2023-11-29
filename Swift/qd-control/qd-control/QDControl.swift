//
//  QDControl.swift
//  qd-control
//
//  Created by Edward Janne on 11/15/23.
//

import Foundation
import SwiftUI
import simd

@Observable class QDControl {
	struct Stance: CustomStringConvertible {
		var targets: [simd_float4]
		var centroid: simd_float4
		var tangent: simd_float4
		var orthogonal: simd_float4
		var progress: Float
		var stepSize: Float
		
		init(_ targets: [simd_float4] = [.zero, .zero, .zero, .zero], centroid: simd_float4 = .zero, tangent: simd_float4 = .zero, orthogonal: simd_float4 = .zero, progress: Float = 0.0, stepSize: Float = 0.0) {
			self.targets = targets
			self.centroid = centroid
			self.tangent = tangent
			self.orthogonal = orthogonal
			self.progress = progress
			self.stepSize = stepSize
		}
		
		init(_ other: Stance) {
			self.targets = other.targets
			self.centroid = other.centroid
			self.tangent = other.tangent
			self.orthogonal = other.orthogonal
			self.progress = other.progress
			self.stepSize = other.stepSize
		}
		
		var description: String {
			get {
				return "{ \(targets[0]), \(targets[1]), \(targets[2]), \(targets[3]), centroid: \(centroid), tangent: \(tangent), progress: \(progress), step size: \(stepSize) }"
			}
		}

		func tricentroid(_ limb: QDRobot.Limb.Configuration)->simd_float4 {
			var p0: simd_float4 = .zero
			var p1: simd_float4 = .zero
			var p2: simd_float4 = .zero
			
			switch limb {
				case .frontRight:
					p0 = targets[1]
					p1 = targets[2]
					p2 = targets[3]
				case .frontLeft:
					p0 = targets[0]
					p1 = targets[2]
					p2 = targets[3]
				case .backRight:
					p0 = targets[0]
					p1 = targets[1]
					p2 = targets[3]
				case .backLeft:
					p0 = targets[0]
					p1 = targets[1]
					p2 = targets[2]
			}
			
			let m0 = (p0 + p1) * 0.5
			let m1 = (p1 + p2) * 0.5
			
			let x1 = m0.x
			let z1 = m0.z
			let x2 = p2.x
			let z2 = p2.z
			
			let x3 = m1.x
			let z3 = m1.z
			let x4 = p0.x
			let z4 = p0.z
			
			let d = (x1 - x2) * (z3 - z4) - (z1 - z2) * (x3 - x4)
			
			let x = ((x1 * z2 - z1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * z4 - z3 * x4)) / d
			let z = ((x1 * z2 - z1 * x2) * (z3 - z4) - (z1 - z2) * (x3 * z4 - z3 * x4)) / d
			
			return simd_float4(x, 0.0, z, 0.0)
		}
		
		func localizedTargets(position: simd_float4, rotation: Float)->[simd_float4] {
			let matrix = simd_float4x4(rotationAxis: .j, angle: rotation)
			let p0 = matrix * (targets[0] - position)
			let p1 = matrix * (targets[1] - position)
			let p2 = matrix * (targets[2] - position)
			let p3 = matrix * (targets[3] - position)
			// print("r(\(-rotation)) p0(\(p0.x), \(p0.y)) p1(\(p1.x), \(p1.y)) p2(\(p2.x), \(p2.y)) p3(\(p3.x), \(p3.y))")
			return [p0, p1, p2, p3]
		}
	}
	
	var qdRobot: QDRobot
	var qdClient: QDClient

	var spline: BSpline<simd_float4>
	var highResParametizer: BSpline<simd_float4>.Reparameterizer
	
	/*
	var highResParametizer: BSpline<simd_float4>.Parametizer? = nil
	var highResTimes: [Float] = []
	*/

	let fps: Float = 15.0
	let speed: Float = 50.0
	var maxTimeS: Float = 0.0
	
	var cgPath = Path()
	var rightPath = Path()
	var leftPath = Path()

	var firstPoint: CGPoint = .zero
	var lastPoint: CGPoint = .zero
	var firstPointOffset: CGPoint = .zero
	var lastPointOffset: CGPoint = .zero

	var params: (simd_float4, simd_float4, Float, Float) = (.zero, .zero, .zero, .zero)
	var point: simd_float4 = .zero
	var tangent: simd_float4 = .zero
	var heading: Float = 0.0

	var stanceTimes: [Float] = []
	var stances: [Stance] = []
	var firstStance = Path()
	var stancePaths: [Path] = []
	var stanceIndex: Int = 0
	var stanceProgress: Float = 0.0
	var currentStance = Stance()
	var currentStancePath = Path()
	var localFootPositions: [simd_float4] = [.zero, .zero, .zero, .zero]
	var updateCount: UInt64 = 0
	var stepSize: Float = 70.0
	var stepHeight: Float = 40.0
	
	var firstBell: Float = 0.0
	var secondBell: Float = 0.0

	let maxCurvature: Float = sqrt(1000.0)
	let minCurvature: Float = 0.0

	var centroids: [simd_float4] = []
	var centerOfMass: simd_float4 = .zero
	var centerOfMassPath = Path()
	var swayScale: Float = 10.0

	// var startTime: UInt64 = 0
	var currentTime: UInt64 = 0
	var lastTime: UInt64 = 0

	var currentTimeS: Float = 0.0
	var lastTimeS: Float = 0.0
	var tickTimeS: Float = 0.0
	var mappedTimeS: Float = 0.0
	
	var pathPosition: Float = 0.0
    var pathProgression: Float = 0.0 {
		didSet {
			update()
		}
    }
    var updatePathSlider = false
    var pathSlider: Float = 0.0 {
		didSet {
			if updatePathSlider {
				paused = true
				pathPosition = pathProgression * spline.length
				pathProgression = pathSlider
			}
			updatePathSlider = true
		}
    }
	var curveSpeed: Float = 0.0
	var radiusOfCurvature: Float = 0.0
    
	var drawCentroidPath = false
	var drawStances = true
	var drawAllStances = false
	
	var renderScale: Float = 0.5
	
	var paused = true {
        didSet {
            if !paused {
                // startTime = DispatchTime.now().uptimeNanoseconds - currentTime
                lastTime = DispatchTime.now().uptimeNanoseconds
                tick()
            }
			lastTime = DispatchTime.now().uptimeNanoseconds
			currentTime = lastTime
        }
    }
    
	init(robot: QDRobot, client: QDClient, controlPoints: [simd_float4]) {
		qdRobot = robot
		qdClient = client
		
		let controlSpline = BSpline(controlPoints: controlPoints)
		self.spline = controlSpline
		self.highResParametizer = BSpline.Reparameterizer(controlSpline, resolution: 100)
		self.maxTimeS = spline.length / speed
		
		stances = generateStances(segmentLength: stepSize)
		currentStance = stances[0]
		
		let times = spline.parameterizeLinear(resolution: 500)
		var i: Int = 0
		for u in times {
			let params = spline.parameters(u: u)
			// print("\(u) --> \(highResParametizer.mappedTime(u))")
			let point = params.0
			// print("\(u) \(params)")
			let tangent = params.1
			let orthogonal = (tangent * simd_float4.j) * 10.0
			let right = point + orthogonal
			let left = point - orthogonal
			let rightPoint = CGPoint(x: CGFloat(right.x), y: CGFloat(right.z))
			let leftPoint = CGPoint(x: CGFloat(left.x), y: CGFloat(left.z))
			lastPoint = CGPoint(x: CGFloat(point.x), y: CGFloat(point.z))
			if i == 0 {
				firstPoint = lastPoint
				let offset = params.1 * -20.0
				firstPointOffset = CGPoint(x: CGFloat(offset.x), y: CGFloat(offset.z))
				cgPath.move(to: lastPoint)
				rightPath.move(to: rightPoint)
				leftPath.move(to: leftPoint)
			} else {
				let offset = params.1 * 20.0
				lastPointOffset = CGPoint(x: CGFloat(offset.x), y: CGFloat(offset.z))
				cgPath.addLine(to: lastPoint)
				rightPath.addLine(to: rightPoint)
				leftPath.addLine(to: leftPoint)
			}
			i += 1
		}
		
		lastTime = DispatchTime.now().uptimeNanoseconds
		currentTime = lastTime
		currentTimeS = 0.0
		
		pathPosition = 0.0
		pathProgression = 0.0
		update()
	}
    
    func generateStances(segmentLength: Float)->[Stance] {
		
		var pathLength: Float = segmentLength * 0.5
		var profile: [Float] = [0.0]
		var stepSizes: [Float] = [segmentLength]
		
		while pathLength < spline.length - segmentLength {
			let t = spline.timeToArcLength(pathLength + segmentLength)
			let p = spline.parameters(u: t)
			let r = sqrt(p.3)
			let f = 0.9 * ((((r > maxCurvature) ? maxCurvature : ((r < minCurvature) ? minCurvature : r)) - minCurvature) / (maxCurvature - minCurvature)) + 0.1
			
			profile.append(pathLength)
			
			pathLength += segmentLength * f
			
			stepSizes.append(segmentLength * f)
		}
		
		profile.append(profile.last! + segmentLength)
		stepSizes.append(segmentLength)
		
        stanceTimes = spline.parameterizeCustom(profile: profile)
        
		// print("profile: \(profile)")
		// print("stanceTimes: \(stanceTimes)")
		
        var stances: [Stance] = []
        var lastStance = Stance()
        for i in 0 ..< stanceTimes.count {
            let t = stanceTimes[i]
            let params = spline.parameters(u: t)
            
            let position = params.0
            let tangent = params.1
            let orthogonal = (simd_float4.j * tangent)
			let offset = orthogonal * swayScale
            
            let scaledStepSize = stepSizes[i]
            
            let currentProgress = profile[i] / spline.length
            // print(currentProgress)
            
            if i == 0 {
				// First stance
				let forePosition = position + tangent * 75.0
				let aftPosition = position - tangent * 75.0
				
				lastStance = Stance(
					[   forePosition + orthogonal * 71.0,
						forePosition - orthogonal * 71.0,
						aftPosition  + orthogonal * 71.0,
						aftPosition  - orthogonal * 71.0],
					centroid: position,
					tangent: tangent,
					orthogonal: orthogonal,
					progress: 0.0
				)
				
				stances.append(lastStance)
				
				centroids.append(lastStance.tricentroid(.frontLeft) + offset)
			} else if i == stanceTimes.count - 1 {
				// Last stance
				// print("Last stance added at stance index: \(i)")
				let forePosition = position + tangent * 75.0
				let aftPosition = position - tangent * 75.0
				
				lastStance = Stance(
					[   forePosition + orthogonal * 71.0,
						forePosition - orthogonal * 71.0,
						aftPosition  + orthogonal * 71.0,
						aftPosition  - orthogonal * 71.0],
					centroid: position,
					tangent: tangent,
					orthogonal: orthogonal,
					progress: currentProgress
				)
				
				stances.append(lastStance)
				
				if i % 2 == 0 {
					let p0 = lastStance.tricentroid(.backLeft) + offset
					//let p1 = lastStance.tricentroid(.frontLeft)
					centroids.append(p0)
				} else {
					let p0 = lastStance.tricentroid(.backRight) - offset
					// let p1 = lastStance.tricentroid(.frontRight)
					centroids.append(p0)
				}
			} else {
				let forePosition = position + tangent * (75.0 + scaledStepSize)
				let aftPosition = position - tangent * (75.0 - scaledStepSize)
				
				lastStance = Stance(lastStance)
				
				if i % 2 == 0 {
					lastStance.targets[0] = forePosition + orthogonal * 71.0
					lastStance.targets[3] = aftPosition  - orthogonal * 71.0
					
					let p0 = lastStance.tricentroid(.backLeft)
					let p1 = lastStance.tricentroid(.frontLeft)
					centroids.append((p0 + p1) * 0.5 + offset)
				} else {
					lastStance.targets[1] = forePosition - orthogonal * 71.0
					lastStance.targets[2] = aftPosition  + orthogonal * 71.0
					
					let p0 = lastStance.tricentroid(.backRight)
					let p1 = lastStance.tricentroid(.frontRight)
					centroids.append((p0 + p1) * 0.5 - offset)
				}
				
				lastStance.centroid = position
				lastStance.tangent = tangent
				lastStance.orthogonal = orthogonal
				lastStance.progress = currentProgress
				
				stances.append(lastStance)
			}
        }
        
        for i in 0 ..< stances.count {
            let stance = stances[i]
            var stancePath = Path()
            stancePath.move(to: CGPoint(x: CGFloat(stance.targets[0].x), y: CGFloat(stance.targets[0].z)))
            stancePath.addLine(to: CGPoint(x: CGFloat(stance.targets[1].x), y: CGFloat(stance.targets[1].z)))
            stancePath.addLine(to: CGPoint(x: CGFloat(stance.targets[3].x), y: CGFloat(stance.targets[3].z)))
            stancePath.addLine(to: CGPoint(x: CGFloat(stance.targets[2].x), y: CGFloat(stance.targets[2].z)))
            stancePath.closeSubpath()
            stancePaths.append(stancePath)
        }
        
        return stances
    }
    
    func interpolateStances(step: Int, first: Stance, second: Stance, progression: Float)->Stance {
		let firstLinear = (progression - 0.0) / 0.5
		var firstFactor = sigmoid(firstLinear)
		firstBell = 0.0
		if firstFactor <= 0.0 {
			firstFactor = 0.0
		} else if firstFactor >= 1.0 {
			firstFactor = 1.0
		} else {
			firstBell = bell(firstLinear) * stepHeight
		}
		
		let secondLinear = (progression - 0.5) / 0.5
		var secondFactor = sigmoid(secondLinear)
		secondBell = 0.0
		if secondFactor <= 0.0 {
			secondFactor = 0.0
		} else if secondFactor >= 1.0 {
			secondFactor = 1.0
		} else {
			secondBell = bell(secondLinear) * stepHeight
		}
		
		var newStance = Stance(first)
		
		if step % 2 == 1 {
			let frontTarget = first.targets[0] * (1.0 - firstFactor) + second.targets[0] * firstFactor + simd_float4(x: 0.0, y: firstBell, z: 0.0, w: 0.0)
			newStance.targets[0] = frontTarget
			let backTarget = first.targets[3] * (1.0 - secondFactor) + second.targets[3] * secondFactor + simd_float4(x: 0.0, y: secondBell, z: 0.0, w: 0.0)
			newStance.targets[3] = backTarget
		} else {
			let frontTarget = first.targets[1] * (1.0 - firstFactor) + second.targets[1] * firstFactor + simd_float4(x: 0.0, y: firstBell, z: 0.0, w: 0.0)
			newStance.targets[1] = frontTarget
			let backTarget = first.targets[2] * (1.0 - secondFactor) + second.targets[2] * secondFactor + simd_float4(x: 0.0, y: secondBell, z: 0.0, w: 0.0)
			newStance.targets[2] = backTarget
		}
		
		return newStance
    }
    
    func restart() {
		lastTime = DispatchTime.now().uptimeNanoseconds
		pathPosition = 0.0
		pathProgression = 0.0
    }
    
    func update() {
		stanceIndex = 0
		stanceProgress = 0.0
		if 1 < stances.count {
			while (stanceIndex < stances.count-1) && (pathProgression > stances[stanceIndex + 1].progress) {
				stanceIndex += 1
			}
			if stanceIndex < stances.count - 1 {
				stanceProgress = (pathProgression - stances[stanceIndex].progress) / (stances[stanceIndex+1].progress - stances[stanceIndex].progress)
			} else {
				stanceProgress = 0.0
			}
		}
		
		updatePathSlider = false
		pathSlider = pathProgression
		
		params = highResParametizer.parameters(pathProgression)
		point = params.0
		tangent = params.1
		curveSpeed = params.2
		radiusOfCurvature = params.3
		var direction = (tangent * simd_float4.k).y
		if direction != 0.0 {
			direction /= abs(direction)
		}
		heading = acos(tangent • simd_float4.k) * direction
		
		if !stanceTimes.isEmpty {
			if drawCentroidPath {
				centerOfMassPath = Path()
				
				centerOfMassPath.move(to: CGPoint(x: CGFloat(centroids[0].x), y: CGFloat(centroids[0].z)))
				
				if stanceIndex > 0 {
					for i in 1 ... stanceIndex {
						let c = centroids[i]
						centerOfMassPath.addLine(to: CGPoint(x: CGFloat(c.x), y: CGFloat(c.z)))
					}
				}
			}
			
			if stanceIndex < centroids.count - 1 {
				let c = centroids[stanceIndex]
				let nc = centroids[stanceIndex + 1]
				let f = sigmoid(stanceProgress)
				// print("Interpolating centroid at stance index: \(stanceIndex) stance progress: \(stanceProgress)")
				centerOfMass = c * (1.0 - f) + nc * f
				if drawCentroidPath {
					centerOfMassPath.addLine(to: CGPoint(x: CGFloat(centerOfMass.x), y: CGFloat(centerOfMass.z)))
				}
			} else {
				// print("Last centroid at: \(stanceIndex)")
				centerOfMass = centroids[stanceIndex]
			}
			
			if stanceIndex < stances.count - 1 {
				let prevStance = stances[stanceIndex]
				let thisStance = stances[stanceIndex + 1]
				let tweenStance = interpolateStances(step: stanceIndex, first: prevStance, second: thisStance, progression: stanceProgress)
				let p0 = tweenStance.targets[0]
				let p1 = tweenStance.targets[1]
				let p2 = tweenStance.targets[3]
				let p3 = tweenStance.targets[2]
				currentStancePath = Path()
				currentStancePath.move(to: CGPoint(x: CGFloat(p0.x), y: CGFloat(p0.z)))
				currentStancePath.addLine(to: CGPoint(x: CGFloat(p1.x), y: CGFloat(p1.z)))
				currentStancePath.addLine(to: CGPoint(x: CGFloat(p2.x), y: CGFloat(p2.z)))
				currentStancePath.addLine(to: CGPoint(x: CGFloat(p3.x), y: CGFloat(p3.z)))
				currentStancePath.closeSubpath()
				localFootPositions = tweenStance.localizedTargets(position: centerOfMass + simd_float4(0.0, qdRobot.bodyHeight, 0.0, 0.0), rotation: heading)
				updateCount += 1
				emit()
				currentStance = tweenStance
			} else {
				currentStance = stances[stances.count - 1]
				localFootPositions = currentStance.localizedTargets(position: centerOfMass + simd_float4(0.0, qdRobot.bodyHeight, 0.0, 0.0), rotation: heading)
				updateCount += 1
				emit()
				currentStancePath = stancePaths[stancePaths.count - 1]
			}
		}
    }
    
    func render(context: inout GraphicsContext, size: CGSize) {
		context.scaleBy(x: 1.0, y: -1.0)
		context.translateBy(x: 0.0, y: -size.height)
        context.fill(Path(CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)), with: .color(.white))
        
        if spline.controlPoints.count > 0 {
            context.translateBy(x: size.width * 0.5, y: size.height * 0.5)
            context.scaleBy(x: CGFloat(renderScale), y: CGFloat(renderScale))
            context.stroke(cgPath, with: .color(.black), style: StrokeStyle(lineWidth: 1))
            context.stroke(rightPath, with: .color(.black), style: StrokeStyle(lineWidth: 1))
            context.stroke(leftPath, with: .color(.black), style: StrokeStyle(lineWidth: 1))
            
            if !stanceTimes.isEmpty {
				if drawCentroidPath {
					context.stroke(centerOfMassPath, with: .color(.purple), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                
				if stancePaths.count > 0 {
					if drawStances {
						if drawAllStances {
							for i in 0 ... stanceIndex {
								var firstColor = CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
								var secondColor = CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
								if i % 2 == 1 {
									firstColor = CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
									secondColor = CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
								}
								
								let strokeColor = GraphicsContext.Shading.color(Color(cgColor: firstColor))
								let stancePath = stancePaths[i]
								context.stroke(stancePath, with: strokeColor, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
								
								if i == stanceIndex {
									let blendedColor = Color(cgColor: CGColor.blend(c0: firstColor, c1: secondColor, f: CGFloat(sigmoid(stanceProgress)))!)
									let strokeColor = GraphicsContext.Shading.color(blendedColor)
									context.stroke(currentStancePath, with: strokeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
									
									context.drawLayer {
										context in
										var localFootPath = Path()
										localFootPath.move(to: CGPoint(x: CGFloat(localFootPositions[0].x), y: CGFloat(localFootPositions[0].z)))
										localFootPath.addLine(to: CGPoint(x: CGFloat(localFootPositions[1].x), y: CGFloat(localFootPositions[1].z)))
										localFootPath.addLine(to: CGPoint(x: CGFloat(localFootPositions[3].x), y: CGFloat(localFootPositions[3].z)))
										localFootPath.addLine(to: CGPoint(x: CGFloat(localFootPositions[2].x), y: CGFloat(localFootPositions[2].z)))
										localFootPath.closeSubpath()
										// context.rotate(by: Angle.radians(.pi))
										context.stroke(localFootPath, with: strokeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
										var circlePath = Path()
										circlePath.addEllipse(in: CGRect(origin: CGPoint(x: CGFloat(-0.5), y: CGFloat(-0.5)), size: CGSize(width: 10.0, height: 10.0)))
										context.stroke(circlePath, with: .color(.red), style: StrokeStyle(lineWidth: 3))
									}
								}
								
								let stanceCentroid = stances[i].centroid
								var stanceCentroidCircle = Path()
								stanceCentroidCircle.addEllipse(in: CGRect(origin: CGPoint(x: CGFloat(stanceCentroid.x - 5.0), y: CGFloat(stanceCentroid.z - 5.0)), size: CGSize(width: 10.0, height: 10.0)))
								context.stroke(stanceCentroidCircle, with: .color((i % 2 == 1) ? Color.red : Color.cyan), style: StrokeStyle(lineWidth: 1))
								
								let stanceHeading = stances[i].tangent * 100.0
								let fromPt = stances[i].centroid
								let toPt = stances[i].centroid + stanceHeading
								var stanceHeadingVector = Path()
								stanceHeadingVector.move(to: CGPoint(x: CGFloat(fromPt.x), y: CGFloat(fromPt.z)))
								stanceHeadingVector.addLine(to: CGPoint(x: CGFloat(toPt.x), y: CGFloat(toPt.z)))
								context.stroke(stanceHeadingVector, with: .color((i % 2 == 1) ? Color.red : Color.cyan), style: StrokeStyle(lineWidth: 1))
							}
						} else {
							for i in 0 ... 4 {
								if stanceIndex - i >= 0 {
									// let stance = stances[stanceIndex - i]
									let strokeColor = GraphicsContext.Shading.color((((stanceIndex - i) % 2 == 1) ? Color.red : Color.cyan).opacity((5.0 - CGFloat(stanceProgress) - CGFloat(i)) / 5.0))
									let stancePath = stancePaths[stanceIndex - i]
									context.stroke(stancePath, with: strokeColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
								}
							}
						}
					}
					var firstColor = CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
					var secondColor = CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
					if stanceIndex % 2 == 1 {
						firstColor = CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
						secondColor = CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
					}
					let blendedColor = Color(cgColor: CGColor.blend(c0: firstColor, c1: secondColor, f: CGFloat(sigmoid(stanceProgress)))!)
					let strokeColor = GraphicsContext.Shading.color(blendedColor)
					context.stroke(currentStancePath, with: strokeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
					context.drawLayer {
						context in
						var localFootPath = Path()
						localFootPath.move(to: CGPoint(x: CGFloat(localFootPositions[0].x), y: CGFloat(localFootPositions[0].z)))
						localFootPath.addLine(to: CGPoint(x: CGFloat(localFootPositions[1].x), y: CGFloat(localFootPositions[1].z)))
						localFootPath.addLine(to: CGPoint(x: CGFloat(localFootPositions[3].x), y: CGFloat(localFootPositions[3].z)))
						localFootPath.addLine(to: CGPoint(x: CGFloat(localFootPositions[2].x), y: CGFloat(localFootPositions[2].z)))
						localFootPath.closeSubpath()
						// context.rotate(by: Angle.radians(.pi))
						context.stroke(localFootPath, with: strokeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
						var circlePath = Path()
						circlePath.addEllipse(in: CGRect(origin: CGPoint(x: CGFloat(-0.5), y: CGFloat(-0.5)), size: CGSize(width: 10.0, height: 10.0)))
						context.stroke(circlePath, with: .color(.red), style: StrokeStyle(lineWidth: 3))
					}
				}
            }
            
            var circlePath = Path()
            circlePath.addEllipse(in: CGRect(origin: CGPoint(x: CGFloat(centerOfMass.x - 5.0), y: CGFloat(centerOfMass.z - 5.0)), size: CGSize(width: 10.0, height: 10.0)))
            context.stroke(circlePath, with: .color(.red), style: StrokeStyle(lineWidth: 3))
            
            var progressPath = Path()
            progressPath.addEllipse(in: CGRect(origin: CGPoint(x: CGFloat(point.x - 5.0), y: CGFloat(point.z - 5.0)), size: CGSize(width: 10.0, height: 10.0)))
            context.stroke(progressPath, with: .color(.green), style: StrokeStyle(lineWidth: 3))
            
            var tangentPath = Path()
            tangentPath.move(to: CGPoint(x: CGFloat(point.x), y: CGFloat(point.z)))
            tangentPath.addLine(to: CGPoint(x: CGFloat(point.x + tangent.x * 100.0), y: CGFloat(point.z + tangent.z * 100.0)))
            context.stroke(tangentPath, with: .color(.green), style: StrokeStyle(lineWidth: 3))
            
            context.drawLayer {
                context in
                context.translateBy(x: firstPoint.x + firstPointOffset.x, y: firstPoint.y + firstPointOffset.y)
                context.scaleBy(x: -2.0, y: 2.0)
                context.rotate(by: .radians(.pi))
                context.draw(Text("Start").foregroundColor(.black), at: .zero, anchor: .center)
            }
            context.drawLayer {
                context in
                context.translateBy(x: lastPoint.x + lastPointOffset.x, y: lastPoint.y + lastPointOffset.y)
                context.scaleBy(x: -2.0, y: 2.0)
                context.rotate(by: .radians(.pi))
                context.draw(Text("Stop").foregroundColor(.black), at: .zero, anchor: .center)
            }
        }
    }
    
    func tick() {
		DispatchQueue.main.async {
			[unowned self] in
			currentTime = DispatchTime.now().uptimeNanoseconds
			currentTimeS = Float(currentTime) * 0.000000001
			lastTimeS = Float(lastTime) * 0.000000001
			tickTimeS = currentTimeS - lastTimeS
			lastTime = currentTime
			
			let t = spline.timeToArcLength(pathPosition + stepSize)
			let p = spline.parameters(u: t)
			let r = p.3
			let f = (((r > maxCurvature) ? maxCurvature : ((r < minCurvature) ? minCurvature : r)) - minCurvature) / (maxCurvature - minCurvature)
			
			pathPosition = pathPosition + tickTimeS * speed * f
			pathProgression = pathPosition / spline.length // currentTimeS / maxTimeS
			if pathProgression > 1.0 {
				pathProgression = 1.0
			}
			
			if pathPosition > spline.length {
				let excess = pathPosition - spline.length
				if excess / speed > 3.0 {
					restart()
				}
			}
		}
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0 / Double(fps)) {
            [unowned self] in
            var isPaused = false
            DispatchQueue.main.sync {
                isPaused = self.paused
            }
            if !isPaused {
                tick()
            }
        }
    }
    
    func emit() {
		qdRobot.setIKTargets(frontRight: localFootPositions[0], frontLeft: localFootPositions[1], backRight: localFootPositions[2], backLeft: localFootPositions[3])
		for i in 0 ..< 4 {
			if qdRobot.limbs[i].unreachableGoal {
				print("limb[\(i)] -- unreachable goal: \(localFootPositions[i])")
			// } else {
			// 	print("limb[\(i)] -- reachable goal: \(localFootPositions[i])")
			}
		}
		let currentTimeMS = UInt32(currentTime / 1000000)
		let pose = QDPose(with: qdRobot, timestamp: currentTimeMS)
		let encoder = QDEncoder()
		encoder.encode(pose)
		var data = encoder.data
		if data.count < 80 {
			data.append([UInt8](repeating: 0, count: 80 - data.count), count: 80 - data.count)
		}
		qdClient.send(message: data)
    }
}
