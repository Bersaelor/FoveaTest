//
//  GameViewController.swift
//  OpenGLTest
//
//  Created by Konrad Feiler on 01/08/16.
//
//

import GLKit
import OpenGLES

func BUFFER_OFFSET(i: Int) -> UnsafePointer<Void> {
    let p: UnsafePointer<Void> = nil
    return p.advancedBy(i)
}

var uResolution: GLint = 0
var uTime: GLint = 0

class GameViewController: GLKViewController {
    
    var program: GLuint = 0
    var rotation: Float = 0.0
    
    var vertexArray: GLuint = 0
    var vertexBuffer: GLuint = 0
    
    var context: EAGLContext? = nil
    
    deinit {
        self.tearDownGL()
        
        if EAGLContext.currentContext() === self.context {
            EAGLContext.setCurrentContext(nil)
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.context = EAGLContext(API: .OpenGLES2)
                
        if self.context == nil {
            print("Failed to create ES context")
        }
        
        let view = self.view as! GLKView
        view.context = self.context!
        view.drawableDepthFormat = .Format24
//        view.drawableMultisample = GLKViewDrawableMultisample.Multisample4X
//        print("drawableMultisample \(view.drawableMultisample.rawValue)")
        
        self.setupGL()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        if self.isViewLoaded() && (self.view.window != nil) {
            self.view = nil
            
            self.tearDownGL()
            
            if EAGLContext.currentContext() === self.context {
                EAGLContext.setCurrentContext(nil)
            }
            self.context = nil
        }
    }
    
    func setupGL() {
        EAGLContext.setCurrentContext(self.context)
        
        self.loadShaders()
        
        glEnable(GLenum(GL_DEPTH_TEST))
        
        glGenVertexArraysOES(1, &vertexArray)
        glBindVertexArrayOES(vertexArray)
        
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(sizeof(GLfloat) * gCubeVertexData.count), &gCubeVertexData, GLenum(GL_STATIC_DRAW))
        
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue))
        glVertexAttribPointer(GLuint(GLKVertexAttrib.Position.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, BUFFER_OFFSET(0))
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Normal.rawValue))
        glVertexAttribPointer(GLuint(GLKVertexAttrib.Normal.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, BUFFER_OFFSET(12))
        
        glBindVertexArrayOES(0)
    }
    
    func tearDownGL() {
        EAGLContext.setCurrentContext(self.context)
        
        glDeleteBuffers(1, &vertexBuffer)
        glDeleteVertexArraysOES(1, &vertexArray)
        
        if program != 0 {
            glDeleteProgram(program)
            program = 0
        }
    }
    
    // MARK: - GLKView and GLKViewController delegate methods
    
    func update() {
        rotation += Float(self.timeSinceLastUpdate * 1.0)
    }
    
    override func glkView(view: GLKView, drawInRect rect: CGRect) {
        glClearColor(0.65, 0.65, 0.65, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        
        glBindVertexArrayOES(vertexArray)
        
        // Render the object again with ES2
        glUseProgram(program)
        
        // Uniforms
        glUniform2f(uResolution, GLfloat(rect.width * 2.0), GLfloat(rect.height * 2.0));
        glUniform1f(uTime, GLfloat(self.timeSinceFirstResume))
        
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 36)
    }
    
    // MARK: -  OpenGL ES 2 shader compilation
    
    func loadShaders() -> Bool {
        var vertShader: GLuint = 0
        var fragShader: GLuint = 0
        var vertShaderPathname: String
        var fragShaderPathname: String
        
        // Create shader program.
        program = glCreateProgram()
        
        // Create and compile vertex shader.
        vertShaderPathname = NSBundle.mainBundle().pathForResource("Shader", ofType: "vsh")!
        if self.compileShader(&vertShader, type: GLenum(GL_VERTEX_SHADER), file: vertShaderPathname) == false {
            print("Failed to compile vertex shader")
            return false
        }
        
        // Create and compile fragment shader.
        fragShaderPathname = NSBundle.mainBundle().pathForResource("Shader", ofType: "fsh")!
        if !self.compileShader(&fragShader, type: GLenum(GL_FRAGMENT_SHADER), file: fragShaderPathname) {
            print("Failed to compile fragment shader")
            return false
        }
        
        // Attach vertex shader to program.
        glAttachShader(program, vertShader)
        
        // Attach fragment shader to program.
        glAttachShader(program, fragShader)
        
        // Bind attribute locations.
        // This needs to be done prior to linking.
        glBindAttribLocation(program, GLuint(GLKVertexAttrib.Position.rawValue), "position")
        glBindAttribLocation(program, GLuint(GLKVertexAttrib.Normal.rawValue), "normal")
        
        // Link program.
        if !self.linkProgram(program) {
            print("Failed to link program: \(program)")
            
            if vertShader != 0 {
                glDeleteShader(vertShader)
                vertShader = 0
            }
            if fragShader != 0 {
                glDeleteShader(fragShader)
                fragShader = 0
            }
            if program != 0 {
                glDeleteProgram(program)
                program = 0
            }
            
            return false
        }
        
        // Get uniform locations.
        uResolution = glGetUniformLocation(program, "uResolution")
        uTime = glGetUniformLocation(program, "uTime")
        
        // Release vertex and fragment shaders.
        if vertShader != 0 {
            glDetachShader(program, vertShader)
            glDeleteShader(vertShader)
        }
        if fragShader != 0 {
            glDetachShader(program, fragShader)
            glDeleteShader(fragShader)
        }
        
        return true
    }
    
    
    func compileShader(inout shader: GLuint, type: GLenum, file: String) -> Bool {
        var status: GLint = 0
        var source: UnsafePointer<Int8>
        do {
            source = try NSString(contentsOfFile: file, encoding: NSUTF8StringEncoding).UTF8String
        } catch {
            print("Failed to load vertex shader")
            return false
        }
        var castSource = UnsafePointer<GLchar>(source)
        
        shader = glCreateShader(type)
        glShaderSource(shader, 1, &castSource, nil)
        glCompileShader(shader)
        
        #if DEBUG
                var logLength: GLint = 0
                glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
                if logLength > 0 {
                    var log = UnsafeMutablePointer<GLchar>(malloc(Int(logLength)))
                    glGetShaderInfoLog(shader, logLength, &logLength, log)
                    NSLog("Shader compile log: \n%s", log)
                    free(log)
                }
        #endif
        
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
        if status == 0 {
            glDeleteShader(shader)
            return false
        }
        return true
    }
    
    func linkProgram(prog: GLuint) -> Bool {
        var status: GLint = 0
        glLinkProgram(prog)
        
        //#if defined(DEBUG)
        //        var logLength: GLint = 0
        //        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        //        if logLength > 0 {
        //            var log = UnsafeMutablePointer<GLchar>(malloc(Int(logLength)))
        //            glGetShaderInfoLog(shader, logLength, &logLength, log)
        //            NSLog("Shader compile log: \n%s", log)
        //            free(log)
        //        }
        //#endif
        
        glGetProgramiv(prog, GLenum(GL_LINK_STATUS), &status)
        if status == 0 {
            return false
        }
        
        return true
    }
    
    func validateProgram(prog: GLuint) -> Bool {
        var logLength: GLsizei = 0
        var status: GLint = 0
        
        glValidateProgram(prog)
        glGetProgramiv(prog, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        if logLength > 0 {
            var log: [GLchar] = [GLchar](count: Int(logLength), repeatedValue: 0)
            glGetProgramInfoLog(prog, logLength, &logLength, &log)
            print("Program validate log: \n\(log)")
        }
        
        glGetProgramiv(prog, GLenum(GL_VALIDATE_STATUS), &status)
        var returnVal = true
        if status == 0 {
            returnVal = false
        }
        return returnVal
    }
}

var gCubeVertexData: [GLfloat] = [
    // Data layout for each line below is:
    // positionX, positionY, positionZ,     normalX, normalY, normalZ,
    1.0, -1.0, -1.0,        1.0, 0.0, 0.0,
    1.0, 1.0, -1.0,         1.0, 0.0, 0.0,
    1.0, -1.0, 1.0,         1.0, 0.0, 0.0,
    1.0, -1.0, 1.0,         1.0, 0.0, 0.0,
    1.0, 1.0, -1.0,         1.0, 0.0, 0.0,
    1.0, 1.0, 1.0,          1.0, 0.0, 0.0,
    
    1.0, 1.0, -1.0,         0.0, 1.0, 0.0,
    -1.0, 1.0, -1.0,        0.0, 1.0, 0.0,
    1.0, 1.0, 1.0,          0.0, 1.0, 0.0,
    1.0, 1.0, 1.0,          0.0, 1.0, 0.0,
    -1.0, 1.0, -1.0,        0.0, 1.0, 0.0,
    -1.0, 1.0, 1.0,         0.0, 1.0, 0.0,
    
    -1.0, 1.0, -1.0,        -1.0, 0.0, 0.0,
    -1.0, -1.0, -1.0,      -1.0, 0.0, 0.0,
    -1.0, 1.0, 1.0,         -1.0, 0.0, 0.0,
    -1.0, 1.0, 1.0,         -1.0, 0.0, 0.0,
    -1.0, -1.0, -1.0,      -1.0, 0.0, 0.0,
    -1.0, -1.0, 1.0,        -1.0, 0.0, 0.0,
    
    -1.0, -1.0, -1.0,      0.0, -1.0, 0.0,
    1.0, -1.0, -1.0,        0.0, -1.0, 0.0,
    -1.0, -1.0, 1.0,        0.0, -1.0, 0.0,
    -1.0, -1.0, 1.0,        0.0, -1.0, 0.0,
    1.0, -1.0, -1.0,        0.0, -1.0, 0.0,
    1.0, -1.0, 1.0,         0.0, -1.0, 0.0,
    
    1.0, 1.0, 1.0,          0.0, 0.0, 1.0,
    -1.0, 1.0, 1.0,         0.0, 0.0, 1.0,
    1.0, -1.0, 1.0,         0.0, 0.0, 1.0,
    1.0, -1.0, 1.0,         0.0, 0.0, 1.0,
    -1.0, 1.0, 1.0,         0.0, 0.0, 1.0,
    -1.0, -1.0, 1.0,        0.0, 0.0, 1.0,
    
    1.0, -1.0, -1.0,        0.0, 0.0, -1.0,
    -1.0, -1.0, -1.0,      0.0, 0.0, -1.0,
    1.0, 1.0, -1.0,         0.0, 0.0, -1.0,
    1.0, 1.0, -1.0,         0.0, 0.0, -1.0,
    -1.0, -1.0, -1.0,      0.0, 0.0, -1.0,
    -1.0, 1.0, -1.0,        0.0, 0.0, -1.0
]
