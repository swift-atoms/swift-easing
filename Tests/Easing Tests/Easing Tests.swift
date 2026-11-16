public import Easing
import Foundation
import Testing

extension Double: @retroactive Exponential.`Protocol` {
    public static func exp(_ x: Double) -> Double { Foundation.exp(x) }
    public static func expm1(_ x: Double) -> Double { Foundation.expm1(x) }
    public static func exp2(_ x: Double) -> Double { Foundation.exp2(x) }
    public static func log(_ x: Double) -> Double { Foundation.log(x) }
    public static func log1p(_ x: Double) -> Double { Foundation.log1p(x) }
    public static func log2(_ x: Double) -> Double { Foundation.log2(x) }
    public static func log10(_ x: Double) -> Double { Foundation.log10(x) }
}

extension Double: @retroactive Trigonometry.Circular {
    public static func sin(_ x: Double) -> Double { Foundation.sin(x) }
    public static func cos(_ x: Double) -> Double { Foundation.cos(x) }
    public static func tan(_ x: Double) -> Double { Foundation.tan(x) }
    public static func asin(_ x: Double) -> Double { Foundation.asin(x) }
    public static func acos(_ x: Double) -> Double { Foundation.acos(x) }
    public static func atan(_ x: Double) -> Double { Foundation.atan(x) }
    public static func atan2(_ y: Double, _ x: Double) -> Double { Foundation.atan2(y, x) }
}

enum `Easing Tests` {}

extension `Easing Tests` {
    fileprivate static func mix(_ from: Double, _ to: Double, _ progress: Double) -> Double {
        from + (to - from) * progress
    }

    fileprivate static func timing(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Bezier<Point<2, Double>> {
        Bezier(start: Point(x: 0, y: 0), control1: Point(x: x1, y: y1), control2: Point(x: x2, y: y2), end: Point(x: 1, y: 1))
    }
}

extension `Easing Tests` {
    @Suite
    struct Curves {
        @Test
        func `An easing turns elapsed time and segment duration into progress`() {
            let late = Easing<Double> { elapsed, duration in elapsed - duration }
            #expect(late.progress(3, 5) == -2)
            #expect(Easing<Double>.linear.progress(1, 4) == 0.25)
            #expect(Easing<Double>.hold.progress(3.9, 4) == 0)
            let square = Easing<Double>(fraction: { $0 * $0 })
            #expect(square.progress(1, 4) == 0.0625)
            #expect(square.progress(2, 8) == 0.0625)
        }

        @Test
        func `A Bezier easing maps the curve's x to its y`() throws {
            let curves = [(0.25, 0.1, 0.25, 1.0), (0.42, 0.0, 0.58, 1.0), (0.0, 0.0, 1.0, 1.0), (0.9, -0.4, 0.1, 1.6), (1.0, 0.2, 0.3, 1.0)]
            for (x1, y1, x2, y2) in curves {
                let curve = `Easing Tests`.timing(x1, y1, x2, y2)
                let easing = try Easing<Double>.bezier(curve)
                let points = (1..<64).map { step in
                    curve.value(at: Double(step) / 64) { from, to, parameter in
                        Point(x: `Easing Tests`.mix(from.x, to.x, parameter), y: `Easing Tests`.mix(from.y, to.y, parameter))
                    }
                }
                #expect(points.allSatisfy { abs(easing.progress($0.x, 1) - $0.y) < 1e-9 })
            }
        }

        @Test
        func `A Bezier easing starts at zero, ends at one and holds both beyond its ends`() throws {
            let ease = try Easing<Double>.bezier(`Easing Tests`.timing(0.25, 0.1, 0.25, 1))
            #expect(ease.progress(0, 2) == 0)
            #expect(ease.progress(2, 2) == 1)
            #expect(ease.progress(-1, 2) == 0)
            #expect(ease.progress(3, 2) == 1)
            #expect(abs(ease.progress(1, 2) - 0.8024033877) < 1e-9)
            let diagonal = try Easing<Double>.bezier(`Easing Tests`.timing(1.0 / 3, 1.0 / 3, 2.0 / 3, 2.0 / 3))
            #expect((1..<32).allSatisfy { abs(diagonal.progress(Double($0), 32) - Double($0) / 32) < 1e-15 })
            let symmetric = try Easing<Double>.bezier(`Easing Tests`.timing(0.42, 0, 0.58, 1))
            #expect((1..<32).allSatisfy { abs(symmetric.progress(Double($0), 32) + symmetric.progress(Double(32 - $0), 32) - 1) < 1e-12 })
            #expect(abs(symmetric.progress(1, 2) - 0.5) < 1e-15)
        }

        @Test
        func `A Bezier easing is a cubic from the origin to one, one whose x never turns back`() {
            let point = Point<2, Double>(x: 0.5, y: 0.5)
            #expect(throws: Easing<Double>.Error.degree) {
                try Easing<Double>.bezier(Bezier(start: Point(x: 0, y: 0), control: point, end: Point(x: 1, y: 1)))
            }
            #expect(throws: Easing<Double>.Error.endpoints) {
                try Easing<Double>.bezier(Bezier(start: Point(x: 0, y: 0.1), control1: point, control2: point, end: Point(x: 1, y: 1)))
            }
            #expect(throws: Easing<Double>.Error.endpoints) {
                try Easing<Double>.bezier(Bezier(start: Point(x: 0, y: 0), control1: point, control2: point, end: Point(x: 2, y: 1)))
            }
            #expect(throws: Easing<Double>.Error.endpoints) {
                try Easing<Double>.bezier(`Easing Tests`.timing(0.5, .infinity, 0.5, 1))
            }
            #expect(throws: Easing<Double>.Error.monotone) {
                try Easing<Double>.bezier(`Easing Tests`.timing(1.2, 0, 0.5, 1))
            }
            #expect(throws: Easing<Double>.Error.monotone) {
                try Easing<Double>.bezier(`Easing Tests`.timing(0.5, 0, -0.1, 1))
            }
            #expect(throws: Easing<Double>.Error.monotone) {
                try Easing<Double>.bezier(`Easing Tests`.timing(.nan, 0, 0.5, 1))
            }
        }

        @Test
        func `A spring easing follows elapsed time alone, from zero toward one`() throws {
            let spring = try Spring(frequency: 12.0, ratio: 0.4)
            let easing = Easing<Double>.spring(spring)
            #expect(easing.progress(0, 1) == 0)
            #expect(easing.progress(0.3, 1) == easing.progress(0.3, 100))
            #expect(easing.progress(0.3, 1) == 1 - spring.displacement(at: 0.3))
            #expect((1...60).contains { easing.progress(Double($0) / 60, 1) > 1 })
            #expect(abs(easing.progress(5, 1) - 1) < 1e-9)
            let thrown = Easing<Double>.spring(spring, velocity: 6)
            let step = 1e-6
            #expect(abs(thrown.progress(step, 1) / step - 6) < 1e-3)
        }

        @Test
        func `A spring easing from frequency and ratio is the easing of that spring`() throws {
            let spring = try Spring(frequency: 12.0, ratio: 0.4)
            let short = Easing<Double>.spring(frequency: 12, ratio: 0.4, velocity: 3)
            let long = Easing<Double>.spring(spring, velocity: 3)
            #expect([0, 0.05, 0.3, 2].allSatisfy { short.progress($0, 1) == long.progress($0, 1) })
        }
    }
}

extension `Easing Tests` {
    @Suite
    struct Shorthand {
        @Test
        func `Four numbers make the Bezier easing the curve through them would`() throws {
            let numbers = Easing<Double>.bezier(0.16, 1, 0.3, 1)
            let curve = try Easing<Double>.bezier(`Easing Tests`.timing(0.16, 1, 0.3, 1))
            #expect((0...40).allSatisfy { numbers.progress(Double($0), 40) == curve.progress(Double($0), 40) })
        }

        @Test
        func `Named easings run from zero to one, hold beyond their ends, and have their shapes`() {
            let easings: [Easing<Double>] = [.smooth, .power(1), .power(2), .power(2).reversed, .power(2).symmetric, .power(3), .power(4).reversed, .power(3).symmetric]
            for easing in easings {
                #expect(easing.progress(0, 1) == 0 && easing.progress(1, 1) == 1)
                #expect(easing.progress(-1, 1) == 0 && easing.progress(2, 1) == 1)
                #expect((0..<32).allSatisfy { easing.progress(Double($0), 32) <= easing.progress(Double($0 + 1), 32) })
            }
            #expect(Easing<Double>.smooth.progress(1, 4) == 0.15625)
            #expect(Easing<Double>.smooth.progress(1, 2) == 0.5)
            #expect(Easing<Double>.power(3).progress(1, 2) == 0.125)
            #expect(Easing<Double>.power(4).reversed.progress(1, 2) == 0.9375)
            #expect(Easing<Double>.power(2).symmetric.progress(1, 4) == 0.125)
            #expect(Easing<Double>.power(2).symmetric.progress(3, 4) == 0.875)
            #expect(Easing<Double>.power(3).symmetric.progress(1, 2) == 0.5)
            #expect((0...32).allSatisfy { Easing<Double>.power(1).progress(Double($0), 32) == Double($0) / 32 })
        }

        @Test
        func `An easing reversed is one minus its progress at the time left, and reversing twice is the easing up to rounding`() throws {
            let curve = try Easing<Double>.bezier(`Easing Tests`.timing(0.7, 0, 0.84, 0))
            for easing in [curve, .smooth, .power(3)] {
                (0...16).forEach { step in
                    let elapsed = Double(step) / 4
                    #expect(easing.reversed.progress(elapsed, 4) == 1 - easing.progress(4 - elapsed, 4))
                    #expect(abs(easing.reversed.reversed.progress(elapsed, 4) - easing.progress(elapsed, 4)) < 1e-15)
                }
            }
        }

        @Test
        func `A symmetric easing is the easing over the first half and its reverse over the second`() {
            let easing = Easing<Double>.power(3)
            let symmetric = easing.symmetric
            #expect(symmetric.progress(2, 4) == 0.5)
            (0...8).forEach { step in
                let elapsed = Double(step) / 4
                #expect(symmetric.progress(elapsed, 4) == easing.progress(2 * elapsed, 4) / 2)
                #expect(abs(symmetric.progress(4 - elapsed, 4) - (1 - symmetric.progress(elapsed, 4))) < 1e-15)
            }
        }
    }
}
