//
//  Math.swift
//  BSpline
//
//  Created by Edward Janne on 11/2/23.
//

import Foundation
import SwiftUI
import simd

extension CGColor {
	static func blend(c0: CGColor, c1: CGColor, f: CGFloat)->CGColor? {
		if c0.colorSpace != c1.colorSpace || c0.numberOfComponents != c1.numberOfComponents { return (f < 0.5) ? c0 : c1 }
		var cr: [CGFloat] = []
		if let a0 = c0.components, let a1 = c1.components {
			for i in 0 ..< c0.numberOfComponents {
				cr.append(a0[i] * (1.0 - f) + a1[i] * f)
			}
		}
		return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: &cr)
	}
}


private let sigMin = 1.0 / (1.0 + exp(-12.0 * -0.5))
private let sigRange = 1.0 / (1.0 + exp(-12.0 * 0.5)) - sigMin

func sigmoid<Scalar>(_ x: Scalar)->Scalar where Scalar: BinaryFloatingPoint {
    return Scalar(((1.0 / (1.0 + (exp((Double(x) - 0.5) * -12.0)))) - sigMin) / sigRange)
}

func inverseSigmoid<Scalar>(_ y: Scalar)->Scalar where Scalar: BinaryFloatingPoint {
    // log() is the natural log
    if y <= 0.0 { return 0.0 }
    if y >= 1.0 { return 1.0 }
    return Scalar(log(1.0 / (Double(y) * sigRange + sigMin) - 1.0) / -12.0 + 0.5)
}

func bell<Scalar>(_ x: Scalar)->Scalar where Scalar: BinaryFloatingPoint {
	let dx = Double(x - 0.5)
	return Scalar(exp(-dx * dx / 0.045) / sqrt(0.045 * .pi) / 2.6594)
}

// Extensions to the SIMD protocol

infix operator •

extension SIMD where Self.Scalar: BinaryFloatingPoint {
    // Dot product
    public static func • (_ a: Self, _ b: Self)->Self.Scalar {
        let lenA = a.scalarCount
        if lenA != b.scalarCount {
            return 0.0
        }
        var dot = Self.Scalar.zero
        for i in 0 ..< lenA {
            dot += a[i] * b[i]
        }
        return dot
    }
    
    // Length of a vector
    public var magnitude: Scalar {
        let prod = self * self
        return sqrt(prod.sum())
    }
    
    // Vector normalized to a unit vector
    public var normalized: Self {
        return self / magnitude
    }
}

// Extensions to specific implementations of the SIMD protocol

extension simd_float2 {
    // Cross product (results in a simd_3)
    public static func * (_ a: simd_float2, _ b: simd_float2)->simd_float3 {
        let a3 = simd_float3(a, 0.0)
        let b3 = simd_float3(b, 0.0)
        return simd_cross(a3, b3)
    }
    
    public static let i: simd_float2 = simd_float2(x: 1.0, y: 0.0)
    public static let j: simd_float2 = simd_float2(x: 0.0, y: 1.0)
}

extension simd_float3 {
    // Cross product
    public static func * (_ a: simd_float3, _ b: simd_float3)->simd_float3 {
        return simd_cross(a, b)
    }
    
    public static let i: simd_float3 = simd_float3(x: 1.0, y: 0.0, z: 0.0)
    public static let j: simd_float3 = simd_float3(x: 0.0, y: 1.0, z: 0.0)
    public static let k: simd_float3 = simd_float3(x: 0.0, y: 0.0, z: 1.0)
}

extension simd_float4 {
    // Cross product (only the first three elements are used, and the 4th is ignored)
    public static func * (_ a: simd_float4, _ b: simd_float4)->simd_float4 {
        let a3 = simd_float3(a.x, a.y, a.z)
        let b3 = simd_float3(b.x, b.y, b.z)
        return simd_float4(simd_cross(a3, b3), 0.0)
    }
    
    public static let i: simd_float4 = simd_float4(x: 1.0, y: 0.0, z: 0.0, w: 0.0)
    public static let j: simd_float4 = simd_float4(x: 0.0, y: 1.0, z: 0.0, w: 0.0)
    public static let k: simd_float4 = simd_float4(x: 0.0, y: 0.0, z: 1.0, w: 0.0)
}

// SIMD matrix extensions

extension simd_float3x3 {
    static let identity = simd_float3x3(diagonal: simd_float3(x: 1.0, y: 1.0, z: 1.0))
    
    init(rotationAxis axis: simd_float3, angle: Float) {
        let s = Float(sin(angle))
        let c = Float(cos(angle))
        let cc = 1.0 - c
        self.init(
            simd_float3(
                x: cc * axis.x * axis.x + c,
                y: cc * axis.x * axis.y + axis.z * s,
                z: cc * axis.x * axis.z - axis.y * s
            ),
            simd_float3(
                x: cc * axis.x * axis.y - axis.z * s,
                y: cc * axis.y * axis.y + c,
                z: cc * axis.y * axis.z + axis.x * s
            ),
            simd_float3(
                x: cc * axis.x * axis.z + axis.y * s,
                y: cc * axis.y * axis.z - axis.x * s,
                z: cc * axis.z * axis.z + c
            )
        )
    }
    
    init(translation t: simd_float3) {
        self.init(translation: simd_make_float2(t))
    }
    
    init(translation t: simd_float2) {
        self.init(
            simd_float3(x: 1.0, y: 0.0, z: 0.0),
            simd_float3(x: 0.0, y: 1.0, z: 0.0),
            simd_float3(x: t.x, y: t.y, z: 1.0))
    }
}

extension simd_double3x3 {
    static let identity = simd_double3x3(diagonal: simd_double3(x: 1.0, y: 1.0, z: 1.0))
    
    init(rotationAxis axis: simd_double3, angle: Double) {
        let s = sin(angle)
        let c = cos(angle)
        let cc = 1.0 - c
        self.init(
            simd_double3(
                x: cc * axis.x * axis.x + c,
                y: cc * axis.x * axis.y + axis.z * s,
                z: cc * axis.x * axis.z - axis.y * s
            ),
            simd_double3(
                x: cc * axis.x * axis.y - axis.z * s,
                y: cc * axis.y * axis.y + c,
                z: cc * axis.y * axis.z + axis.x * s
            ),
            simd_double3(
                x: cc * axis.x * axis.z + axis.y * s,
                y: cc * axis.y * axis.z - axis.x * s,
                z: cc * axis.z * axis.z + c
            )
        )
    }
    
    init(translation t: simd_double3) {
        self.init(translation: simd_make_double2(t))
    }
    
    init(translation t: simd_double2) {
        self.init(
            simd_double3(x: 1.0, y: 0.0, z: 0.0),
            simd_double3(x: 0.0, y: 1.0, z: 0.0),
            simd_double3(x: t.x, y: t.y, z: 1.0))
    }
}

extension simd_float4x4 {
    static let identity = simd_float4x4(diagonal: simd_float4(x: 1.0, y: 1.0, z: 1.0, w: 1.0))
    
    init(rotationAxis axis: simd_float4, angle: Float) {
        let s = Float(sin(angle))
        let c = Float(cos(angle))
        let cc = Float(1.0 - c)
        self.init(
            simd_float4(
                x: cc * axis.x * axis.x + c,
                y: cc * axis.x * axis.y + axis.z * s,
                z: cc * axis.x * axis.z - axis.y * s,
                w: 0.0
            ),
            simd_float4(
                x: cc * axis.x * axis.y - axis.z * s,
                y: cc * axis.y * axis.y + c,
                z: cc * axis.y * axis.z + axis.x * s,
                w: 0.0
            ),
            simd_float4(
                x: cc * axis.x * axis.z + axis.y * s,
                y: cc * axis.y * axis.z - axis.x * s,
                z: cc * axis.z * axis.z + c,
                w: 0.0
            ),
            simd_float4(
                x: 0.0,
                y: 0.0,
                z: 0.0,
                w: 1.0
            )
        )
    }
    
    init(translation t: simd_float4) {
        self.init(translation: simd_make_float3(t))
    }

    init(translation t: simd_float3) {
        self.init(
            simd_float4(x: 1.0, y: 0.0, z: 0.0, w: 0.0),
            simd_float4(x: 0.0, y: 1.0, z: 0.0, w: 0.0),
            simd_float4(x: 0.0, y: 0.0, z: 1.0, w: 0.0),
            simd_float4(x: t.x, y: t.y, z: t.z, w: 1.0))
    }
}

extension simd_double4x4 {
    static let identity = simd_double4x4(diagonal: simd_double4(x: 1.0, y: 1.0, z: 1.0, w: 1.0))
    
    init(rotationAxis axis: simd_double4, angle: Double) {
        let s = sin(angle)
        let c = cos(angle)
        let cc = 1.0 - c
        self.init(
            simd_double4(
                x: cc * axis.x * axis.x + c,
                y: cc * axis.x * axis.y + axis.z * s,
                z: cc * axis.x * axis.z - axis.y * s,
                w: 0.0
            ),
            simd_double4(
                x: cc * axis.x * axis.y - axis.z * s,
                y: cc * axis.y * axis.y + c,
                z: cc * axis.y * axis.z + axis.x * s,
                w: 0.0
            ),
            simd_double4(
                x: cc * axis.x * axis.z + axis.y * s,
                y: cc * axis.y * axis.z - axis.x * s,
                z: cc * axis.z * axis.z + c,
                w: 0.0
            ),
            simd_double4(
                x: 0.0,
                y: 0.0,
                z: 0.0,
                w: 1.0
            )
        )
    }
    
    init(translation t: simd_double4) {
        self.init(translation: simd_make_double3(t))
    }
    
    init(translation t: simd_double3) {
        self.init(
            simd_double4(x: 1.0, y: 0.0, z: 0.0, w: 0.0),
            simd_double4(x: 0.0, y: 1.0, z: 0.0, w: 0.0),
            simd_double4(x: 0.0, y: 0.0, z: 1.0, w: 0.0),
            simd_double4(x: t.x, y: t.y, z: t.z, w: 1.0))
    }
}


// Coeffients and weights for numericl integration by Gauss-Legendre quadrature

private let absc: [Float] = [
                                    0,
                                    -0.2011940939974345223006283033945962078128364544626376796159497246099482390030201876018362580675210590896790225738650942118942792830254885727862468296762689520472323105296106261124651357614417997418035121035408247749648194561179315250580457969565227012849978769073832577847806340363795749473,
                                    0.2011940939974345223006283033945962078128364544626376796159497246099482390030201876018362580675210590896790225738650942118942792830254885727862468296762689520472323105296106261124651357614417997418035121035408247749648194561179315250580457969565227012849978769073832577847806340363795749473,
                                    -0.3941513470775633698972073709810454683627527761586982550311653439516089577869614179754971141616597620258935216963564800247584781260358233957151493455553007521886914392606583742154248479579749842360261132809797979651499137490065468199685647693609935982616317942701783226669048753533254183119,
                                    0.3941513470775633698972073709810454683627527761586982550311653439516089577869614179754971141616597620258935216963564800247584781260358233957151493455553007521886914392606583742154248479579749842360261132809797979651499137490065468199685647693609935982616317942701783226669048753533254183119,
                                    -0.5709721726085388475372267372539106412383863962827496048532654170541953798697585794834146285698261447791264649702625704035115501912776443761340450804516463781076364549656886694892446365920390093401556752553531482547154572126630162234082965371353094862024333370955907936013838701919590803412,
                                    0.5709721726085388475372267372539106412383863962827496048532654170541953798697585794834146285698261447791264649702625704035115501912776443761340450804516463781076364549656886694892446365920390093401556752553531482547154572126630162234082965371353094862024333370955907936013838701919590803412,
                                    -0.724417731360170047416186054613938009630899294584102563551423420704123781677925218996101097603134326269235985493819251120386564200897315435713528175170608440951083020460016262974562085876362569423407165760886935238050225109674832830079599365377790413466864301655149204169505796163086343748,
                                    0.724417731360170047416186054613938009630899294584102563551423420704123781677925218996101097603134326269235985493819251120386564200897315435713528175170608440951083020460016262974562085876362569423407165760886935238050225109674832830079599365377790413466864301655149204169505796163086343748,
                                    -0.8482065834104272162006483207742168513662561747369926340957275587606750751741454851976077197508214808509037383571333991774655863067112478024741155233378528783931705752141398941910147200136987021229009687468623820809560831359261245028073597202508315345765272897870964489632790463532026206005,
                                    0.8482065834104272162006483207742168513662561747369926340957275587606750751741454851976077197508214808509037383571333991774655863067112478024741155233378528783931705752141398941910147200136987021229009687468623820809560831359261245028073597202508315345765272897870964489632790463532026206005,
                                    -0.9372733924007059043077589477102094712439962735153044579013630763502029737970455279505475861742680865974682404460315684492009513352834390536949245590430527861757465810011883749183601162731625066190523359799844459286625508280580877744877723444752122837802536842521085722280263813016978301407,
                                    0.9372733924007059043077589477102094712439962735153044579013630763502029737970455279505475861742680865974682404460315684492009513352834390536949245590430527861757465810011883749183601162731625066190523359799844459286625508280580877744877723444752122837802536842521085722280263813016978301407,
                                    -0.9879925180204854284895657185866125811469728171237614899999975155873884373690194247127220503683191449766751684399007925019395823670692057806992758567920785969340702791275630120497337228079229330198922312006979937161784084500767102113415768221050653691522462833296858362238239685728519647054,
                                    0.9879925180204854284895657185866125811469728171237614899999975155873884373690194247127220503683191449766751684399007925019395823670692057806992758567920785969340702791275630120497337228079229330198922312006979937161784084500767102113415768221050653691522462833296858362238239685728519647054
                                ]
                                
private let wgts: [Float] = [
                                    0.2025782419255612728806201999675193148386621580094773567967041160514353987547460740933934407127880321353514826708299901773095246288719482192675665869139062612256085449558643031836505029978223451416924610397803870997344190817384290577763771236964710158183351656545129738602932076125549319023,
                                    0.1984314853271115764561183264438393248186925599575419934847379279291247975334342681333149991648178232076602085488930991764791477591610421132086613599988857531192702426415927231327044667892816045834098228729517385124172569721507734356429605231973280268604684028301488322765670316796303356288,
                                    0.1984314853271115764561183264438393248186925599575419934847379279291247975334342681333149991648178232076602085488930991764791477591610421132086613599988857531192702426415927231327044667892816045834098228729517385124172569721507734356429605231973280268604684028301488322765670316796303356288,
                                    0.1861610000155622110268005618664228245062260122779284028154957273100132555026991606189497688860993236053997770900138443530672702173881822218913650817524402394454633498455254983854987704558698346743823005532094467225041792102166969649720014347260039240685291809910280840226841347980521837134,
                                    0.1861610000155622110268005618664228245062260122779284028154957273100132555026991606189497688860993236053997770900138443530672702173881822218913650817524402394454633498455254983854987704558698346743823005532094467225041792102166969649720014347260039240685291809910280840226841347980521837134,
                                    0.1662692058169939335532008604812088111309001800984129073218651905635535632122785177107051742924155362148446154065718522274181714630170967754925174671836098206991229223858649637789999954737644311199247756973750854153289068732761392073165357013373138619425638694563391801926576061195937788699,
                                    0.1662692058169939335532008604812088111309001800984129073218651905635535632122785177107051742924155362148446154065718522274181714630170967754925174671836098206991229223858649637789999954737644311199247756973750854153289068732761392073165357013373138619425638694563391801926576061195937788699,
                                    0.1395706779261543144478047945110283225208502753155112432023911286310884445419078116807682573635713336381490888932766399041110917245491409628233342406440126372784794505759941197273360771302835643088631984018181469133646430155458101237375718557827299435854832981132499961239407405172041096534,
                                    0.1395706779261543144478047945110283225208502753155112432023911286310884445419078116807682573635713336381490888932766399041110917245491409628233342406440126372784794505759941197273360771302835643088631984018181469133646430155458101237375718557827299435854832981132499961239407405172041096534,
                                    0.1071592204671719350118695466858693034155437157581019806870223891218779948523157997256858571376086240443980876783750555812718104988405678239974708278615361621323837150901155489565006064488581094283683146572762126337955710255509976788374176850005859153689529410495091691306303339254292612609,
                                    0.1071592204671719350118695466858693034155437157581019806870223891218779948523157997256858571376086240443980876783750555812718104988405678239974708278615361621323837150901155489565006064488581094283683146572762126337955710255509976788374176850005859153689529410495091691306303339254292612609,
                                    0.0703660474881081247092674164506673384667080327543307198259072929143870555128742370448404520666939392193554898585950405388046148432772910792956556041537582479070968902376133780797668535183637426522389065978826221602778581837148625124153563760247327246091136423557230784075321996037169475438,
                                    0.0703660474881081247092674164506673384667080327543307198259072929143870555128742370448404520666939392193554898585950405388046148432772910792956556041537582479070968902376133780797668535183637426522389065978826221602778581837148625124153563760247327246091136423557230784075321996037169475438,
                                    0.0307532419961172683546283935772044177217481448334340742642282855042371894671171680390387707323994040025169911888594731301931311793307049136572121249488040088053791567453616163473679786846675406619664506995965540924443751786755055481899678620830700956557210823767451729158413495735272185295,
                                    0.0307532419961172683546283935772044177217481448334340742642282855042371894671171680390387707323994040025169911888594731301931311793307049136572121249488040088053791567453616163473679786846675406619664506995965540924443751786755055481899678620830700956557210823767451729158413495735272185295
                                ]

// Numerical integration using Guass-Legendre quadrature
public func legendreIntegrate<Scalar>(u0: Scalar, u1: Scalar, f: @escaping (Scalar)->Scalar)->Scalar where Scalar: BinaryFloatingPoint {
    var r: Scalar = 0.0
    
    // Must transform interval to the range -1 ... 1
    let halfLen = (u1 - u0) * 0.5
    let midPt = (u0 + u1) * 0.5
    
    let grp = DispatchGroup()
    let que = DispatchQueue(label: "ad hoc serial")
    // Loop over Legendre Quadrature points
    for i in 0 ..< absc.count {
		DispatchQueue.global(qos: .default).async(group: grp) {
			let xi = halfLen * Scalar(absc[i]) + midPt
			let r1 = Scalar(wgts[i]) * f(xi).magnitude
			que.async(group: grp) {
				r += r1
			}
		}
    }
    grp.wait()
    
    // Final result after integration
    return r * halfLen
}

// Newton Raphson numerical method to solve x for y = f(x) given y
public func newtonSolve<Scalar>(_ target: Scalar, hint: Scalar, f: (Scalar)->Scalar, d: (Scalar)->Scalar, maxSteps: Int = 100, tolerance: Scalar = 0.0001, epsilon: Scalar = 0.0001)->Scalar where Scalar: BinaryFloatingPoint {
    var x0: Scalar = hint
    var x1: Scalar = hint
    var deltaCount = 0
    var lastDelta: Scalar = 0.0
    for _ in 0 ..< maxSteps {
        if x0 < 0.0 {
            x0 = 0.0
        }
        if x0 > 1.0 {
            x0 = 1.0
        }
        let yp = d(x0)
        if abs(yp) < epsilon { return x1 }
        let newTry = f(x0)
        x1 = x0 - (newTry - target) / yp
        if abs(x1-x0) / abs(x1) < tolerance { return x1 }
        let delta = abs(x0 - x1)
        if delta == lastDelta {
            if deltaCount > 10 { return (x0 + x1) * 0.5 }
            deltaCount += 1
        }
        lastDelta = delta
        x0 = x1
    }
    // print("Failed to converge")
    return x1
}

func largerOf<T: FloatingPoint>(v0: T, v1: T)->T {
    return v0 > v1 ? v0 : v1
}
