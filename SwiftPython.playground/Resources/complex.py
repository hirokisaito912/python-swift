
# example underlying class implemented in python
# triple quoted doc strings are typing hints for
# Swift code generator script

import sys

# Dance necessary to call back to Swift
class SwiftClosure:

    def __init__(self, closure):
        self.callback = sys.modules["swift"].callback
        self.closure = closure
        pass

    def call(self, args):
        # callback expects closure and argument list
        return self.callback(self.closure, args)

    def deallocate(self):
        """ Swift returns Void """
        # Callback with args as None to deallocate
        self.call(None)

    def __del__(self):
        self.deallocate()

# Our test class
class Complex:
    """ Swift var classvar: String Swift var array: [Double]
        Swift var r: Double Swift var i: Double """

    """ Swift returns String """
    classvar = "Complex"

    def __init__(self, realpart, imagpart):
        self.r = realpart
        self.i = imagpart

    def add(self, c):
        """ Swift returns Void """
        self.r += c.r
        self.i += c.i

    def toString(self, extra):
        """ Swift returns String """
        return "(%f %f %s)" % (self.r, self.i, str(extra))

    def toArray(self):
        """ Swift returns [Double] """
        return [self.r, self.i]

    def toDictionary(self):
        """ Swift returns [String: Double] """
        return {'real': self.r, 'imag': self.i}

    def echoArray(self, value):
        """ Swift returns PythonList<Int> """
        return value

    def callme(self, closure, str):
        """ Swift returns [String: Double] """
        return SwiftClosure(closure).call([str]).toDictionary()

def newComplex(real, imag):
    """ Swift returns Complex """
    return Complex(real, imag)

# For plot example
import numpy as np

def mandelbrot( h,w, maxit=20):
    """Returns an image of the Mandelbrot fractal of size (h,w)."""
    y,x = np.ogrid[ -1.4:1.4:h*1j, -2:0.8:w*1j ]
    c = x+y*1j
    z = c
    divtime = maxit + np.zeros(z.shape, dtype=int)
    for i in range(maxit):
        z = z**2 + c
        diverge = z*np.conj(z) > 2**2            # who is diverging
        div_now = diverge & (divtime==maxit)  # who is diverging now
        divtime[div_now] = i                  # note when
        z[diverge] = 2                        # avoid diverging too much
    return divtime
