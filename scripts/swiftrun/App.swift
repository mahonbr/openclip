// Entry file for `scripts/dev_swift_run.sh`.
//
// `swift` interprets a single file, so this file is the whole program the
// interpreter sees. It reaches the app through a C symbol exported by the
// `OpenClip` dynamic library, which avoids importing that module (and with it
// the Clang module maps of SDWebImage, Sparkle, and cmark-gfm).
@_silgen_name("openclip_dev_run_main")
func openclipDevRunMain()

openclipDevRunMain()
