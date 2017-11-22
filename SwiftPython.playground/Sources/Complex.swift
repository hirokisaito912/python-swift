
// Generated from module complex by bridgegen.py

public let complexModule = PythonModule(loading: "complex")

public let ComplexClass = PythonClass(module: complexModule, named: "Complex", type: Complex.self)

public class Complex: PythonObject {

    public required init(any: Any) {
        super.init(any: any)
    }

    public class var classvar: String {
        get {
            return ComplexClass.getAttr(named: "classvar").asString
        }
        set(newValue) {
            ComplexClass.setAttr(named: "classvar", value: newValue)
        }
    }

    public var array: [Double] {
        get {
            return getAttr(named: "array").asArray(of: Double.self)
        }
        set(newValue) {
            setAttr(named: "array", value: newValue)
        }
    }

    public var r: Double {
        get {
            return getAttr(named: "r").asDouble
        }
        set(newValue) {
            setAttr(named: "r", value: newValue)
        }
    }

    public var i: Double {
        get {
            return getAttr(named: "i").asDouble
        }
        set(newValue) {
            setAttr(named: "i", value: newValue)
        }
    }

    public init(realpart: Any = 0, imagpart: Any = 0, _ _kw: [String: Any]? = nil) {
        super.init(any: ComplexClass.call(args: [realpart, imagpart], kw: _kw))
    }

    public convenience init(_ _realpart: Any = 0, _ _imagpart: Any = 0) {
        self.init(realpart: _realpart, imagpart: _imagpart)
    }

    private static let addMethod = ComplexClass.function(named: "add")

    public func add(c: Any, _ _kw: [String: Any]? = nil) -> Void {
        return Complex.addMethod.call(args: [self, c], kw: _kw).asVoid
    }

    public func add(_ _c: Any) -> Void {
        return add(c: _c)
    }

    private static let callmeMethod = ComplexClass.function(named: "callme")

    public func callme(closure: Any, str: Any, _ _kw: [String: Any]? = nil) -> [String: Double] {
        return Complex.callmeMethod.call(args: [self, closure, str], kw: _kw).asDictionary(of: Double.self)
    }

    public func callme(_ _closure: Any, _ _str: Any) -> [String: Double] {
        return callme(closure: _closure, str: _str)
    }

    private static let echoArrayMethod = ComplexClass.function(named: "echoArray")

    public func echoArray(value: Any, _ _kw: [String: Any]? = nil) -> PythonList<Int> {
        return Complex.echoArrayMethod.call(args: [self, value], kw: _kw).asPythonObject(of: PythonList<Int>.self)
    }

    public func echoArray(_ _value: Any) -> PythonList<Int> {
        return echoArray(value: _value)
    }

    private static let toArrayMethod = ComplexClass.function(named: "toArray")

    public func toArray(_ _kw: [String: Any]? = nil) -> [Double] {
        return Complex.toArrayMethod.call(args: [self], kw: _kw).asArray(of: Double.self)
    }

    private static let toDictionaryMethod = ComplexClass.function(named: "toDictionary")

    public func toDictionary(_ _kw: [String: Any]? = nil) -> [String: Double] {
        return Complex.toDictionaryMethod.call(args: [self], kw: _kw).asDictionary(of: Double.self)
    }

    private static let toStringMethod = ComplexClass.function(named: "toString")

    public func toString(extra: Any = "STRING", _ _kw: [String: Any]? = nil) -> String {
        return Complex.toStringMethod.call(args: [self, extra], kw: _kw).asString
    }

    public func toString(_ _extra: Any = "STRING") -> String {
        return toString(extra: _extra)
    }
}

private let mandelbrotFunction = complexModule.function(named: "mandelbrot")

public func mandelbrot(h: Any, w: Any, maxit: Any = 20, _ _kw: [String: Any]? = nil) -> PythonObject {
    return mandelbrotFunction.call(args: [h, w, maxit], kw: _kw)
}

public func mandelbrot(_ _h: Any, _ _w: Any, _ _maxit: Any = 20) -> PythonObject {
    return mandelbrot(h: _h, w: _w, maxit: _maxit)
}

private let newComplexFunction = complexModule.function(named: "newComplex")

public func newComplex(real: Any, imag: Any, _ _kw: [String: Any]? = nil) -> Complex {
    return newComplexFunction.call(args: [real, imag], kw: _kw).asPythonObject(of: Complex.self)
}

public func newComplex(_ _real: Any, _ _imag: Any) -> Complex {
    return newComplex(real: _real, imag: _imag)
}
