(in-package :sdl2)

#-:gamekit
(cffi:define-foreign-library libsdl2
    (:darwin (:default "libSDL2"))
  (:unix (:or "libSDL2-2.0.so.0" "libSDL2"))
  (:windows "SDL2.dll")
  (t (:default "libSDL2")))

#-:gamekit
(cffi:use-foreign-library libsdl2)

