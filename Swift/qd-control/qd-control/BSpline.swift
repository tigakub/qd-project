//
//  BSpline.swift
//  BSpline
//
//  Created by Edward Janne on 11/1/23.
//

import Foundation
import simd

public class BSpline<Vector> where Vector: SIMD, Vector.Scalar: BinaryFloatingPoint {
    let controlPoints: [Vector]
    private let knots: [Vector.Scalar]
    private let degree: Int
    private var spanLengths: [Vector.Scalar] = []
    var length: Vector.Scalar = 0
    
    init(controlPoints: [Vector]) {
        assert(controlPoints.count >= 4, "There must be at least 4 control points.")
        // Cache the control points
        self.controlPoints = controlPoints
        
        // Create a knot vector
        self.knots = BSpline.createKnotVector(numPoints: controlPoints.count, degree: 3)
        
        // This is a cubic spline
        self.degree = 3
        
        // Calculate the length of the curve
        self.length = 0.0
        
        cacheSpanLengths()
    }
    
    private func cacheSpanLengths() {
        length = 0.0
        for i in degree ..< knots.count - degree - 1 {
			let u0 = self.knots[i]
			let u1 = self.knots[i+1]
			let len = legendreIntegrate(u0: u0, u1: u1) {
				u in
				return self.evaluate(o: 1, u: u).magnitude
			}
			self.length += len
			self.spanLengths.append(len)
        }
    }
    
    // Utility function to create the knot vector
    private static func createKnotVector(numPoints: Int, degree: Int) -> [Vector.Scalar] {
        // The number of knots must be (number of points - 1) + (degree of the curve) + 1 + 1
        let order = degree + 1
        let numKnots = numPoints + order
        
        // Knot vector before normalization, initialized with (degree + 1) 0.0 values
        // to clamp the start of the curve to the first control point
        var knots = Array(repeating: Vector.Scalar(0.0), count: order)
        
        // The internal knot count is the total knot count minus the number of duplicates at the start and end
        let internalKnotCount = numKnots - order * 2
        
        // Append normalized uniform internal knots
        knots.append(contentsOf: (1 ... internalKnotCount).map { Vector.Scalar($0) / Vector.Scalar(internalKnotCount + 1) })
        
        // Append (degree + 1) 1.0 values to clamp the end of the curve to the last control point
        knots.append(contentsOf: Array(repeating: Vector.Scalar(1.0), count: order))
        
        return knots
    }
    
    private func P(o: Int, i: Int)->Vector {
        if o == 0 {
            return controlPoints[i]
        } else {
            let u0 = knots[i + degree + 1]
            let u1 = knots[i + o]
            let p0 = P(o: o-1, i: i+1)
            let p1 = P(o: o-1, i: i)
            let result = (p0 - p1) * Vector.Scalar(degree - o + 1) / (u0 - u1)
            return result
        }
    }
    
    // The first derivative of the basis functions is evaluated on the knot vector dropping
    // the first and last knots, and the second, on the knot vector dropping the first two
    // and last two knots
    private func U(o: Int, i: Int)->Vector.Scalar {
        return knots[o + i]
    }
    
    private func basis(o: Int, i: Int, k: Int, u: Vector.Scalar) -> Vector.Scalar {
        if k == 0 {
            return (U(o: o, i: i) <= u && u < U(o: o, i: i + 1)) ? 1.0 : 0.0
        } else {
			let denom1 = self.U(o: o, i: i + k) - self.U(o: o, i: i)
			let basis1 = self.basis(o: o, i: i, k: k - 1, u: u)
			let term1 = denom1 > 0 ? (u - self.U(o: o, i: i)) / denom1 * basis1 : 0
			let denom2 = self.U(o: o, i: i + k + 1) - self.U(o: o, i: i + 1)
			let basis2 = self.basis(o: o, i: i + 1, k: k - 1, u: u)
			let term2 = denom2 > 0 ? (self.U(o: o, i: i + k + 1) - u) / denom2 * basis2 : 0
			
            return term1 + term2
        }
    }
    
    // Evaluate the curve or any of its derivatives at an arbitrary parametric position
    public func evaluate(o: Int, u: Vector.Scalar) -> Vector {
        if u == 1.0 {
            return controlPoints.last!
        }
        
        var point = Vector.zero
        
        // With each derivative, the degree is decremented
        let k = 3 - o // Degree of the B-Spline
        
        let grp = DispatchGroup()
        let que = DispatchQueue(label: "ad hoc serial")
        for i in 0 ..< controlPoints.count - o {
			DispatchQueue.global(qos: .default).async(group: grp) {
				let b = self.basis(o: o, i: i, k: k, u: self.clamp(u))
				que.async(group: grp) {
					point += self.P(o: o, i: i) * b
				}
			}
        }
        grp.wait()
        
        return point
    }
    
    // Return the position, tangent, speed, and radius of curvature at any parametric position
    public func parameters(u: Vector.Scalar)->(Vector, Vector, Vector.Scalar, Vector.Scalar) {
        var uClamped = clamp(u)
        let position = evaluate(o: 0, u: uClamped)
        
        if uClamped == 1.0 { uClamped = 0.9999999 }
        let firstDeriv = evaluate(o: 1, u: uClamped)
        let secondDeriv = evaluate(o: 2, u: uClamped)
        let tangent = firstDeriv.normalized
        
        let tanMag = firstDeriv.magnitude
        let radiusOfCurvature = tanMag * tanMag * tanMag / (firstDeriv * secondDeriv).magnitude
        
        return (position, tangent, tanMag, radiusOfCurvature)
    }
    
    public func progress(u: Vector.Scalar)->(Vector.Scalar, Vector.Scalar) {
		let uClamped = clamp(u)
		let len = arcLength(u0: 0.0, u1: u)
		let index = findSpanIndex(forArcLen: len)
		let spanLen = spanLengths[index]
		var localArcLen = len
		for i in 0 ..< index {
			localArcLen -= spanLengths[i]
		}
		return (len / length, localArcLen / spanLen)
    }
    
    // Return the arc length between arbitrary parametric positions
    public func arcLength(u0: Vector.Scalar, u1: Vector.Scalar)->Vector.Scalar {
        return legendreIntegrate(u0: u0, u1: u1) {
            u in
            return self.evaluate(o: 1, u: u).magnitude
        }
    }
    
    private func findSpanIndex(forArcLen len: Vector.Scalar)->Int {
        var sum: Vector.Scalar = 0.0
        for i in 0 ..< spanLengths.count {
            sum += spanLengths[i]
            if len < sum {
                return i
            }
        }
        return spanLengths.count - 1
    }
    
    private func timeInSpan(_ spanIndex: Int, localArcLen len: Vector.Scalar)->Vector.Scalar {
        let u0 = knots[spanIndex + degree]
        let u1 = knots[spanIndex + degree + 1]
        let hintBlender = len / spanLengths[spanIndex]
        let solution = newtonSolve(
            len,
            hint: u0 * (1.0 - hintBlender) + (u1 * hintBlender),
            f: { u in return arcLength(u0: u0, u1: u) },
            d: { u in return evaluate(o: 1, u: u).magnitude })
            
        return solution
    }
    
    // Return the parametric input required to move a given arc length along the curve
    public func timeToArcLength(_ arcLen: Vector.Scalar)->Vector.Scalar {
        if arcLen <= 0.0 {
            return 0.0
        }
        if arcLen >= length {
            return 1.0
        }
        
        let spanIndex = findSpanIndex(forArcLen: arcLen)
        var localArcLen = arcLen
        for i in 0 ..< spanIndex {
            localArcLen -= spanLengths[i]
        }
        
        let time = timeInSpan(spanIndex, localArcLen: localArcLen)
        
        return time
    }
    
    // Utility function to clamp a value in the range 0 ... 1.0 (inclusive)
    private func clamp(_ u: Vector.Scalar)->Vector.Scalar {
        return (u > 1.0) ? 1.0 : ((u < 0.0) ? 0.0 : u)
    }
    
    // Parameterize linearly over the curve
    public func parameterizeLinear(resolution: Int)->[Vector.Scalar] {
        var params: [Vector.Scalar] = []
        
		for i in 0 ... resolution {
			let arcLen = Vector.Scalar(i) / Vector.Scalar(resolution) * self.length
			let timeTo = self.timeToArcLength(arcLen)
			params.append(timeTo)
		}
        
        return params
    }
    
    // Parameterize sigmoidally over the curve
    public func parameterizeSigmoidal(resolution: Int)->[Vector.Scalar] {
        var params: [Vector.Scalar] = []
        
        for i in 0 ... resolution {
			let arcLen = sigmoid(Vector.Scalar(i) / Vector.Scalar(resolution)) * self.length
			params.append(self.timeToArcLength(arcLen))
        }
        
        return params
    }
    
    // Parameterize with a custom profile
    public func parameterizeCustom(profile: [Vector.Scalar])->[Vector.Scalar] {
        var params: [Vector.Scalar] = []
        
        for arcLen in profile {
			let t = self.timeToArcLength(arcLen)
			params.append(t)
        }
        
        return params
    }
    
    public class Reparameterizer {
        var spline: BSpline
        var resolution: Int
        var cached: [Vector.Scalar]
        
        init(_ spline: BSpline, resolution: Int = 100) {
            self.spline = spline
            self.resolution = resolution
            self.cached = spline.parameterizeLinear(resolution: resolution)
            // print(self.cached)
        }
        
        public func mappedTime(_ r: Vector.Scalar)->Vector.Scalar {
            if r >= 1.0 { return 1.0 }
            let scaled = r * Vector.Scalar(resolution)
            let i = Int(floor(scaled))
            let u0 = cached[i]
            let u1 = cached[i+1]
            let k = scaled - Vector.Scalar(i)
            let u = u0 * (1.0 - k) + u1 * k
            // print("r: \(r), u0: \(u0), u1: \(u1), u: \(u)")
            return u
        }
        
        public func parameters(_ r: Vector.Scalar)->(Vector, Vector, Vector.Scalar, Vector.Scalar) {
            if r <= 0.0 { return spline.parameters(u: 0.0) }
            if r >= 1.0 { return spline.parameters(u: 1.0) }
            let u = mappedTime(r)
            return spline.parameters(u: u)
        }
    }
}
