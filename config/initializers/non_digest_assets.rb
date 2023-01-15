require 'non_stupid_digest_assets'

NonStupidDigestAssets.whitelist = ["404.html", "429.html", "500.html"]
Sprockets::Manifest.send(:prepend, NonStupidDigestAssets::CompileWithNonDigest)
