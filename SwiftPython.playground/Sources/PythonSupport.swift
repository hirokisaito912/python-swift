//
//  SwiftEval.swift
//  SwiftPython
//
//  Created by John Holdsworth on 12/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/SwiftPython/SwiftPython.playground/Sources/PythonSupport.swift#85 $
//
//  Support for Python bridge classes
//

import Foundation
import Python

public typealias PyObjectPtr = UnsafeMutablePointer<PyObject>
public typealias PythonCallback = (_: [PythonObject]) -> PythonObject?
public typealias UnownedPyObjectPtr = PyObjectPtr

/// Representing Python's "None"
public let pythonNone = PyObjectPtr(&_Py_NoneStruct)
public let PythonNone = PythonObject(ptr: pythonNone)

/// Used if a sensible value can not be returned for asInt, asDouble etc
public var pythonWasNull = -999

/// Anythhing that looks out of the ordinary will be reported to this closure
/// Can be replaced for custom logging such as reporting a stack trace
public var pythonWarn = {
    (message: String) in
    print(message)
}

/// Wrapper for all Python objects received or created
public class PythonObject: CustomStringConvertible {

    public let pyObject: PyObjectPtr

    /// Take ownership of PyObject * object
    ///
    /// - Parameters:
    ///   - pyObject: pointer to underlying Python object
    ///   - steal: "Steal" the object i.e. don't increment it's referrence count
    fileprivate init(ptr pyObject: PyObjectPtr?, steal: Bool = false) {
        self.pyObject = pyObject ?? pythonNone
        if !steal || pyObject == nil {
            Py_IncRef(self.pyObject)
        }
    }

    /// Required initialiser used for most manual initialisation
    ///
    /// - Parameter any: Almost any Swift structure or another Python object
    public required init(any: Any) {
        self.pyObject = PythonEncode(any)
    }

    /// Check downcasts for the expected type
    ///
    /// - Parameter intended: pointer to Python type structure for type  expected
    public func checkCast(type intended: UnsafeMutablePointer<PyTypeObject>) {
        if pyObject.type != intended {
            pythonWarn("Invalid cast of \(String(cString: pyObject.type.pointee.tp_name)) to \(self)")
        }
    }

    /// Pass on shared ownership by incrementing reference count
    ///
    /// - Returns: PyObject * with +1 reference count
    public func takeReference() -> UnownedPyObjectPtr {
        Py_IncRef(pyObject)
        return pyObject
    }

    /// Get attribute of object
    ///
    /// - Parameter name: name of attribute
    /// - Returns: new PythonObject representing attribute
    public func getAttr(named name: String) -> PythonObject {
        return PythonObject(ptr: PyObject_GetAttrString(pyObject, name), steal: true)
    }
    
    /// Set new value for attribute
    ///
    /// - Parameters:
    ///   - name: attribute name
    ///   - value: Swift value or PythonObject
    public func setAttr(named name: String, value: Any) {
        let value = PythonEncode(value)
        PyObject_SetAttrString(pyObject, name, value)
        Py_DecRef(value)
    }

    /// Used to make sure an object does not get deallocated while you're using it
    ///
    /// - Parameter closure: passed live PyObject pointer
    /// - Returns: whatever the closure returns
    public func withPtr<T>(closure: (_: PyObjectPtr) -> T) -> T {
        return closure(pyObject)
    }
    
    public var type: UnsafeMutablePointer<PyTypeObject> {
        return pyObject.type
    }

    public var isNone: Bool {
        return pyObject.isNone
    }

    public var description: String {
        return pyObject.description
    }

    public var asInt: Int {
        return pyObject.asInt
    }

    public var asDouble: Double {
        return pyObject.asDouble
    }

    public var asString: String {
        return pyObject.asString
    }

    public var asData: Data {
        return pyObject.asData
    }

    public var asVoid: Void {
        return
    }

    public var asType: Any {
        return pyObject.asType
    }

    public func asAny<T>(of type: T.Type) -> Any {
        return pyObject.asAny(of: type)
    }

    public func asArray<T>(of type: T.Type) -> [T] {
        return PythonList<T>(any: self).asArray
    }

    /// For mixed value tyeps
    public var asTypeArray: [Any] {
        return (0 ..< PythonList<Any>(any: self).size).map { PyList_GetItem(pyObject, $0).asType }
    }

    /// For performance
    public var asIntArray: [Int] {
        return (0 ..< PythonList<Int>(any: self).size).map { PyList_GetItem(pyObject, $0).asInt }
    }

    public var asFloatArray: [Float] {
        return (0 ..< PythonList<Float>(any: self).size).map { Float(PyList_GetItem(pyObject, $0).asDouble) }
    }

    public var asDoubleArray: [Double] {
        return (0 ..< PythonList<Double>(any: self).size).map { PyList_GetItem(pyObject, $0).asDouble }
    }

    public func listMap<T>(closure: (PyObjectPtr) -> T) -> [T] {
        return (0 ..< PythonList<T>(any: self).size).map { closure(PyList_GetItem(pyObject, $0)) }
    }

    public func asDictionary<T>(of type: T.Type) -> [String: T] {
        return PythonDict<T>(any: self).asDictionary
    }
    
    public var asTypeDictionary: [String: Any] {
        return PythonDict<Any>(any: self).asTypeDictionary
    }
    
    /// Create an instance of the specified subclass of Python Object
    ///
    /// - Parameter type: class object
    /// - Returns: New instance of that class
    public func asPythonObject<T: PythonObject>(of type: T.Type) -> T {
        return type.init(any: self)
    }

    /// For working with recursive data structures such as JSON
    public var asPythonAny: PythonAny {
        return PythonAny(any: self)
    }

    deinit {
        Py_DecRef(pyObject)
    }
}

/// Wrapper for a Python Module object
public class PythonModule: PythonObject {

    public let name: String

    static var initialize: Void = {
        Py_Initialize()
    }()

    public required init(any: Any) {
        self.name = ""
        super.init(any: any)
        checkCast(type: &PyModule_Type)
    }

    /// Used in playgrounds to find module as auxiliary resources
    ///
    /// - Parameter name: module name
    public convenience init(named name: String) {
        guard let source = Bundle.main.path(forResource: name, ofType: "py") else {
            fatalError("Could not locate module \(name).py")
        }

        self.init(module: name, path: URL(fileURLWithPath: source).deletingLastPathComponent().path)
    }

    /// Start Python, load a module and create an object to represent it
    ///
    /// - Parameters:
    ///   - name: module name
    ///   - path: directory to add to PYTHONPATH
    public init(module name: String, path: String?) {
        if var path = path {
            if let existing = getenv("PYTHONPATH"), !String(cString: existing).contains(path) {
                path = "\(path):\(String(cString: existing))"
            }
            setenv("PYTHONPATH", path, 1)
        }

        /// Boot up Python (Once!)
        _ = PythonModule.initialize

        guard let module = PyImport_Import(PyString_FromString(name)) else {
            PyErr_Print()
            fatalError("Could not module \(name) at \(String(cString: getenv("PYTHONPATH")))")
        }

        self.name = name
        super.init(ptr: module)
    }

    /// Get function defined in this module
    ///
    /// - Parameter name: name of function
    /// - Returns: Object representing function tat can be called
    public func function(named name: String) -> PythonFunction {
        return PythonFunction(any: getAttr(named: name))
    }
}

/// Wrapper for a Python function object
public class PythonFunction: PythonObject {

    /// Call a python function or member function
    ///
    /// - Parameter args: arguments for the function
    /// - Returns: return value from calling the function
    public func call(args: PythonTuple) -> PythonObject {
        let result = args.withPtr { PyObject_Call(pyObject, $0, nil) }
        if let _ = PyErr_Occurred() {
            PyErr_Print()
        }
        return PythonObject(ptr: result, steal: true)
    }
}

/// Wrapper for a Python Class object
public class PythonClass: PythonFunction {

    public let name: String

    public required init(any: Any) {
        self.name = ""
        super.init(any: any)
        checkCast(type: &PyClass_Type)
    }

    /// Create a Python Class object
    ///
    /// - Parameters:
    ///   - module: the module object
    ///   - name: name of the class
    public init(module: PythonModule, named name: String, type: Any.Type) {
        let clazz = module.getAttr(named: name)
        guard !clazz.isNone else {
            fatalError("Unable to find class \(name) in module \(module.name)")
        }

        self.name = name
        super.init(any: clazz)

        let pyType = PyLong_FromVoidPtr(unsafeBitCast(type, to: UnsafeMutableRawPointer.self))
        clazz.setAttr(named: "__swift__type__", value: PythonObject(ptr: pyType, steal: true))
    }

    /// Find a method in the associated class
    ///
    /// - Parameter name: the method name
    /// - Returns: An object wrapping a Python function
    public func method(named name: String) -> PythonFunction {
        let method = getAttr(named: name)
        guard !method.isNone else {
            fatalError("Unable to find method \(name) in class \(self.name)")
        }
        return PythonFunction(any: method)
    }
}

/// Object used mostly to represent arguments to a function call
public class PythonTuple: PythonObject {

    public required init(any: Any) {
        super.init(any: any)
        checkCast(type: &PyTuple_Type)
    }

    public init(count: Int) {
        _ = PythonModule.initialize
        super.init(ptr: PyTuple_New(count), steal: true)
    }

    public convenience init(args: [Any]) {
        self.init(count: args.count)
        for i in 0 ..< args.count {
            PyTuple_SetItem(pyObject, i, PythonEncode(args[i]))
        }
    }

    public var size: Int {
        return PyTuple_Size(pyObject)
    }

    public func set(item: Int, ptr: UnownedPyObjectPtr) {
        PyTuple_SetItem(pyObject, item, ptr)
    }

    public func set(item: Int, arg: Any) {
        set(item: item, ptr: PythonEncode(arg))
    }

    public subscript(index: Int) -> PyObjectPtr {
        get {
            if index > 0 || index >= size {
                pythonWarn("PythonList: Index \(index) out of range [\(size)]")
            }
            return PyTuple_GetItem(pyObject, index)
        }
        set(newValue) {
            PyTuple_SetItem(pyObject, index, newValue)
        }
    }
}

/// Performs the conversion of relevant Swift data types, Collections etc
/// to a newly created Python Object. Will also accept another PythonObject
///
/// - Parameter arg: Swift data type
/// - Returns: Python Object, currently unowned
public func PythonEncode(_ arg: Any) -> UnownedPyObjectPtr {
    if let value = arg as? Int {
        return PyInt_FromLong(value)
    } else if let value = arg as? Double {
        return PyFloat_FromDouble(value)
    } else if let value = arg as? String {
        return PyString_FromString(value)
    } else if let value = arg as? Data {
        return value.withUnsafeBytes { PyByteArray_FromStringAndSize($0, value.count) }
    } else if let value = arg as? PythonObject {
        return value.takeReference()
    } else if let value = arg as? [Int] {
        let list = PyList_New(value.count)!
        for index in 0 ..< value.count {
            PyList_SetItem(list, index, PyInt_FromLong(value[index]))
        }
        return list
    } else if let value = arg as? [Float] {
        let list = PyList_New(value.count)!
        for index in 0 ..< value.count {
            PyList_SetItem(list, index, PyFloat_FromDouble(Double(value[index])))
        }
        return list
    } else if let value = arg as? [Double] {
        let list = PyList_New(value.count)!
        for index in 0 ..< value.count {
            PyList_SetItem(list, index, PyFloat_FromDouble(value[index]))
        }
        return list
    } else if let value = arg as? [Any] {
        let list = PyList_New(value.count)!
        for index in 0 ..< value.count {
            PyList_SetItem(list, index, PythonEncode(value[index]))
        }
        return list
    } else if let value = arg as? [String: Any] {
        let dict = PyDict_New()!
        for (key, item) in value {
            let item = PythonEncode(item)
            PyDict_SetItemString(dict, key, item)
            Py_DecRef(item)
        }
        return dict
    } else if let value = arg as? PythonCallback {
        return PythonClosure(closure: value).closureObject
    }

    pythonWarn("PythonEncode: Could not match type of \(arg), returning PythonNone")
    return PythonNone.takeReference()
}

// Extension to perform most conversions from Python object to basic Swift types
extension UnsafeMutablePointer where Pointee == PyObject {

    public var isNone: Bool {
        return self == pythonNone
    }

    public var description: String {
        return PythonObject(ptr: PyObject_Repr(self), steal: true).asString
    }

    public var asInt: Int {
        if isNone {
            pythonWarn("asInt from empty object, returning \(pythonWasNull)")
            return pythonWasNull
        }
        if type == &PyString_Type {
            let tmpInt = PyInt_FromString(PyString_AsString(self), nil, 0)
            let tmpLong = PyInt_AsLong(tmpInt)
            Py_DecRef(tmpInt)
            return tmpLong != -1 ? tmpLong : Int(asDouble)
        }
        return PyInt_AsLong(self)
    }

    public var asDouble: Double {
        if isNone {
            pythonWarn("asDouble from empty object, returning \(pythonWasNull)")
            return Double(pythonWasNull)
        }
        if type == &PyString_Type {
            let tmpDouble = PyFloat_FromString(self, nil)
            defer { Py_DecRef(tmpDouble) }
            return PyFloat_AsDouble(tmpDouble)
        }
        return PyFloat_AsDouble(self)
    }

    public var asString: String {
        if isNone {
            pythonWarn("asString from empty object, returning \(pythonWasNull)")
            return "\(pythonWasNull)"
        }
        return type == &PyString_Type ?
            String(cString: PyString_AsString(self)) : description
    }

    public var asData: Data {
        if isNone {
            pythonWarn("asData from empty object, returning empty data")
        }
        if let buffer = PyByteArray_AsString(self) {
            return Data(bytes: buffer, count: PyByteArray_Size(self))
        }
        return Data()
    }

    public var asVoid: Void {
        return
    }

    public var type: UnsafeMutablePointer<PyTypeObject> {
        return pointee.ob_type
    }

    /// Although this returns Any it tries to create an appropriate value
    /// for the Python object by checking it's Type structure pointer
    public var asType: Any {
        let type = self.type
        if type == &PyInt_Type {
            return asInt
        } else if type == &PyFloat_Type {
            return asDouble
        } else if type == &PyString_Type {
            return asString
        } else if type == &PyByteArray_Type {
            return asData
        } else if type == &PyModule_Type {
            return PythonModule(any: PythonObject(ptr: self))
        } else if type == &PyFunction_Type {
            return PythonFunction(any: PythonObject(ptr: self))
        } else if type == &PyClass_Type {
            return PythonClass(any: PythonObject(ptr: self))
        } else if type == &PyTuple_Type {
            return PythonTuple(any: PythonObject(ptr: self))
        } else if type == &PyList_Type {
            return PythonObject(ptr: self).asTypeArray
        } else if type == &PyDict_Type {
            return PythonObject(ptr: self).asTypeDictionary
        } else if type == &PyInstance_Type {
            let typeObject = PythonObject(ptr: self).getAttr(named: "__class__").getAttr(named: "__swift__type__")
            if !typeObject.isNone {
                let swiftType = unsafeBitCast(PyLong_AsVoidPtr(typeObject.pyObject), to: PythonObject.Type.self)
                return PythonObject(ptr: self).asPythonObject(of: swiftType)
            }
        }
        return PythonObject(ptr: self)
    }

    /// Set value of required type which can include PythonObject or collections
    ///
    /// - Parameter type: Swift type object
    /// - Returns: Any but of requested type
    public func asAny<T>(of type: T.Type) -> Any {
        if type == Int.self {
            return asInt
        } else if type == Double.self {
            return asDouble
        } else if type == String.self {
            return asString
        } else if type == Data.self {
            return asData
        } else if let subtype = type as? PythonObject.Type {
            return PythonObject(ptr: self).asPythonObject(of: subtype)
        } else if type == [Int].self {
            return PythonObject(ptr: self).asIntArray
        } else if type == [Float].self {
            return PythonObject(ptr: self).asFloatArray
        } else if type == [Double].self {
            return PythonObject(ptr: self).asDoubleArray
        } else if type == [String].self {
            return PythonObject(ptr: self).asArray(of: String.self)
        } else if type == [Data].self {
            return PythonObject(ptr: self).asArray(of: Data.self)
        } else if type == [PythonObject].self {
            return PythonObject(ptr: self).asArray(of: PythonObject.self)
        } else if type == [Any].self {
            return PythonObject(ptr: self).asTypeArray
        } else if type == Any.self {
            return PythonObject(ptr: self).asType
        }
        return PythonObject(ptr: self)
    }
}

public class PythonList<T>: PythonObject, Sequence, Collection {

    public required init(any: Any) {
        super.init(any: any)
        checkCast(type: &PyList_Type)
    }

    public init() {
        super.init(ptr: PyList_New(0), steal: true)
    }

    /// Initialise a list from the keys and values of a dictionary
    ///
    /// - Parameter dictionary: a dictionary
    public convenience init(dictionary: Any) {
        self.init()
        let dict = PythonDict<T>(any: dictionary)
        if dict.type != &PyDict_Type {
            pythonWarn("Initialiser is not Dictionary creating PythonList")
        }
        let keys = PyDict_Keys(dict.pyObject)
        for key in (0 ..< PyList_Size(keys)).map({ PyList_GetItem(keys, $0) }) {
            PyList_Append(pyObject, key)
            PyList_Append(pyObject, PyDict_GetItem(dict.pyObject, key))
        }
        Py_DecRef(keys)
    }

    public var size: Int {
        return PyList_Size(pyObject)
    }

    public var asArray: [T] {
        return map { $0 }
    }

    public func append(_ item: T) {
        let item = PythonEncode(item)
        PyList_Append(pyObject, item)
        Py_DecRef(item)
    }

    public subscript(index: Int) -> Iterator.Element {
        get {
            if index < 0 || index >= size {
                pythonWarn("PythonList: Index \(index) out of range [\(size)]")
            }
            return PyList_GetItem(pyObject, index).asAny(of: T.self) as! T
        }
        set(newValue) {
            PyList_SetItem(pyObject, index, PythonEncode(newValue))
        }
    }

    // Sequence Iterator
    public typealias Iterator = AnyIterator<(T)>

    private struct Listerator<T>: IteratorProtocol {
        public typealias Element = T

        let list: PythonList<T>
        var index = 0

        init(list: PythonList<T>) {
            self.list = list
        }

        public mutating func next() -> Element? {
            defer { index += 1 }
            if index < list.size {
                return list[index]
            }
            return nil
        }
    }

    public func makeIterator() -> Iterator {
        var iterator = Listerator<T>(list: self)
        return AnyIterator {
            return iterator.next()
        }
    }

    // Required for Collection
    public typealias Index = Int

    public var startIndex: Index {
        return 0
    }

    public var endIndex: Index {
        return size
    }

    public func index(after i: Index) -> Index {
        return i + 1
    }
}

public class PythonDict<T>: PythonObject, Sequence {

    public required init(any: Any) {
        super.init(any: any)
        checkCast(type: &PyDict_Type)
    }

    public init() {
        super.init(ptr: PyDict_New(), steal: true)
    }

    /// Initialise dictionary from keys and values in an array
    ///
    /// - Parameter array: key and value pairs in array
    public convenience init(array: Any) {
        self.init()
        let list = PythonEncode(array)
        if list.type != &PyList_Type {
            pythonWarn("Initialiser is not Array creating PythonDict")
        }
        let count = PyList_Size(list)
        if count % 2 != 0 {
            pythonWarn("Odd number of elements in array creating PythonDict")
        }
        for i in stride(from: 0, to: count-1, by: 2) {
            PyDict_SetItem(pyObject, PyList_GetItem(list, i), PyList_GetItem(list, i+1))
        }
        Py_DecRef(list)
    }

    public var keys: [String] {
        return PythonObject(ptr: PyDict_Keys(pyObject), steal: true).asArray(of: String.self)
    }

    public var asDictionary:  [String: T] {
        var out = [String: T]()
        let keys = PyDict_Keys(pyObject)
        for key in (0 ..< PyList_Size(keys)).map({ PyList_GetItem(keys, $0) }) {
            out[String(cString: PyString_AsString(key))]
                = PyDict_GetItem(pyObject, key).asAny(of: T.self) as? T
        }
        Py_DecRef(keys)
        return out
    }

    public override var asTypeDictionary:  [String: Any] {
        var out = [String: Any]()
        let keys = PyDict_Keys(pyObject)
        for key in (0 ..< PyList_Size(keys)).map({ PyList_GetItem(keys, $0) }) {
            out[String(cString: PyString_AsString(key))]
                = PyDict_GetItem(pyObject, key).asType
        }
        Py_DecRef(keys)
        return out
    }

    public subscript(key: String) -> T? {
        get {
            let key = PythonEncode(key)
            defer { Py_DecRef(key) }
            if let ptr = PyDict_GetItem(pyObject, key) {
                return ptr.asAny(of: T.self) as? T
            }
            return nil
        }
        set(newValue) {
            let key = PythonEncode(key)
            if let newValue = newValue {
                let value = PythonEncode(newValue)
                PyDict_SetItem(pyObject, key, value)
                Py_DecRef(value)
            }
            else {
                PyDict_DelItem(pyObject, key)
            }
            Py_DecRef(key)
        }
    }

    // Sequence Iterator
    public typealias Iterator = AnyIterator<(key: String, value: T)>

    private struct Dicterator<T>: IteratorProtocol {
        public typealias Element = (key: String, value: T)

        let dict: PythonDict<T>
        let keys: [String]
        var index = 0

        init(dict: PythonDict<T>) {
            self.dict = dict
            self.keys = dict.keys
        }

        public mutating func next() -> Element? {
            defer { index += 1 }
            if index < keys.count, let value = dict[keys[index]] {
                return (keys[index], value)
            }
            return nil
        }
    }

    public func makeIterator() -> Iterator {
        var iterator = Dicterator<T>(dict: self)
        return AnyIterator {
            return iterator.next()
        }
    }
}

/// Called directly from Python to implemen calls back to Swift
///
/// - Parameters:
///   - self: N/A
///   - args: A PythonTuple containing a closure pointer and a list of arguments
/// - Returns: whatever the Swift closure returns with +1 referrence count
fileprivate func swiftCallback(_ self: PyObjectPtr?, _ args: PyObjectPtr?) -> UnownedPyObjectPtr? {
    if let pointer = PyLong_AsVoidPtr(PyTuple_GetItem(args, 0)) {
        let closure = Unmanaged<PythonClosure>.fromOpaque(pointer).takeUnretainedValue()
        if let args = PyTuple_GetItem(args, 1) {
            if args != pythonNone {
                let args = PythonObject(ptr: args).asArray(of: PythonObject.self)
                if let result = closure.closure(args) {
                    return result.takeReference()
                }
            }
            else {
                Unmanaged.passUnretained(closure).release()
            }
        }
    } else {
        pythonWarn("swiftCallback: nil closure pointer")
    }

    return PythonNone.takeReference()
}

fileprivate var methods: [PyMethodDef] = {
    var methods = [PyMethodDef](repeating: PyMethodDef(), count: 2)
    methods[0].ml_name = UnsafePointer<Int8>(strdup("callback"))
    methods[0].ml_meth = swiftCallback
    methods[0].ml_flags = METH_VARARGS
    methods[0].ml_doc = UnsafePointer<Int8>(strdup("Swift callback"))
    return methods
}()

/// Holder for a closure the pointer to which is passed to python as an
/// integer from which the pointer to an instance of this class is recovered.
fileprivate class PythonClosure {

    private static let initialize: Void = {
        Py_InitModule4_64("swift", &methods, nil, nil, PYTHON_API_VERSION)
    }()

    let closure: PythonCallback

    init(closure: @escaping PythonCallback) {
        _ = PythonClosure.initialize
       self.closure = closure
    }

    var closureObject: UnownedPyObjectPtr {
        return PyLong_FromVoidPtr(Unmanaged.passRetained(self).toOpaque())
    }
}

/// SwiftyJSON like Omi-type to make working with
/// recursive data structures a little bit easier
public class PythonAny: PythonObject {
    public var list: PythonList<Any> {
        return PythonList<Any>(any: self)
    }
    public var dict: PythonDict<Any> {
        return PythonDict<Any>(any: self)
    }
    public var count: Int {
        return list.size
    }
    public var keys: [String] {
        return dict.keys
    }
    public subscript(index: Int) -> PythonAny {
        return PythonAny(any: list[index])
    }
    public subscript(key: String) -> PythonAny? {
        if let next = dict[key] {
            return PythonAny(any: next)
        }
        return nil
    }
}
