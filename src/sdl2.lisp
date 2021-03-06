;;;; sdl2.lisp

(in-package #:sdl2)

;;; "sdl2" goes here. Hacks and glory await!

(define-condition sdl-error (error) ())

(define-condition sdl-rc-error (sdl-error)
  ((code :initarg :rc :initform nil :accessor sdl-error-code)
   (string :initarg :string :initform nil :accessor sdl-error-string))
  (:report (lambda (c s)
             (with-slots (code string) c
               (format s "SDL Error (~A): ~A" code string)))))

(defun sdl-collect (wrapped-ptr &optional (free-fun #'foreign-free))
  (let ((ptr (autowrap:ptr wrapped-ptr)))
    (tg:finalize wrapped-ptr (lambda () (funcall free-fun ptr)))
    wrapped-ptr))

(defun sdl-cancel-collect (wrapped-ptr)
  (tg:cancel-finalization wrapped-ptr)
  wrapped-ptr)

(defun sdl-true-p (integer-bool)
  "Use this function to convert truth from a low level wrapped SDL function
returning an SDL_true into CL's boolean type system."
  (= (autowrap:enum-value 'sdl2-ffi:sdl-bool :true) integer-bool))

(autowrap:define-bitmask-from-constants (sdl-init-flags)
  sdl2-ffi:+sdl-init-timer+
  sdl2-ffi:+sdl-init-audio+
  sdl2-ffi:+sdl-init-video+
  sdl2-ffi:+sdl-init-joystick+
  sdl2-ffi:+sdl-init-haptic+
  sdl2-ffi:+sdl-init-gamecontroller+
  sdl2-ffi:+sdl-init-noparachute+
  '(:everything . #x0000FFFF))

(defmacro check-rc (form)
  (with-gensyms (rc)
    `(let ((,rc ,form))
       (when (< ,rc 0)
         (error 'sdl-rc-error :rc ,rc :string (sdl-get-error)))
       ,rc)))

(defmacro check-non-zero (form)
  (with-gensyms (rc)
    `(let ((,rc ,form))
       (unless (> ,rc 0)
         (error 'sdl-rc-error :rc ,rc :string (sdl-get-error)))
       ,rc)))

(defmacro check-true (form)
  (with-gensyms (rc)
    `(let ((,rc ,form))
       (unless (sdl-true-p ,rc)
         (error 'sdl-rc-error :rc ,rc :string (sdl-get-error)))
       ,rc)))

(defmacro check-null (form)
  (with-gensyms (wrapper)
    `(let ((,wrapper ,form))
       (if (null-pointer-p (autowrap:ptr ,wrapper))
           (error 'sdl-rc-error :rc ,wrapper :string (sdl-get-error))
           ,wrapper))))

(defmacro without-fp-traps (&body body)
  #+:sbcl
  `(sb-int:with-float-traps-masked (:underflow
                                    :overflow
                                    :inexact
                                    :invalid
                                    :divide-by-zero) ,@body)
  #-:sbcl
  `(progn ,@body))

(defmacro in-main-thread (&body b)
  #+ (and ccl darwin)
  `(let ((thread (find 0 (ccl:all-processes) :key #'ccl:process-serial-number)))
     (ccl:process-interrupt thread (lambda () (without-fp-traps ,@b))))
  #+ (and sbcl darwin)
  `(let ((thread (first (last (sb-thread:list-all-threads)))))
     (sb-thread:interrupt-thread thread (lambda () (without-fp-traps ,@b))))
  #-darwin
  `(without-fp-traps ,@b))

(defun init (&rest sdl-init-flags)
  "Initialize SDL2 with the specified subsystems. Initializes everything by default."
  ;; HACK! glutInit on OSX uses some magic undocumented API to
  ;; correctly make the calling thread the primary thread. This
  ;; allows cl-sdl2 to actually work. Nothing else seemed to
  ;; work at all to be honest.
  #+:darwin
  (cl-glut:init)
  #-:gamekit
  (let ((init-flags (autowrap:mask-apply 'sdl-init-flags sdl-init-flags)))
    (check-rc (sdl-init init-flags))))

(defun quit ()
  "Shuts down SDL2."
  #-:gamekit
  (sdl-quit))

(defmacro with-init ((&rest sdl-init-flags) &body body)
  `(in-main-thread
     (init ,@sdl-init-flags)
     (unwind-protect
          (progn ,@body)
       (quit))))

(defun niy (message)
  (error "SDL2 Error: Construct Not Implemented Yet: ~A" message))
