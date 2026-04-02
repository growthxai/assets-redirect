require_relative "base"

class Assets::Redirect::ViteRuby < Assets::Redirect::Base
  private
    def path_from_manifest
      manifest = ViteRuby.instance.manifest

      manifest_logical_path_candidates.each do |candidate|
        return strip_assets_prefix(manifest.path_for(candidate))
      rescue ViteRuby::MissingEntrypointError
        next
      end

      nil
    end

    # ViteRuby manifest keys use source paths relative to sourceCodeDir, so
    # entrypoints are prefixed (e.g. "entrypoints/inertia.ts"). JS files may
    # be authored as .ts or .js. Try the most likely key first.
    def manifest_logical_path_candidates
      base = logical_path
      ts_variant = base.sub(/\.js$/, ".ts")

      unprefixed = [ts_variant, base].uniq
      prefixed = unprefixed.map { |c| "entrypoints/#{c}" }

      prefixed + unprefixed
    end

    FINGERPRINT_REGEXP = /
      -                              # Hyphen
      [0-9a-zA-Z_-]{3,}               # Rollup or Propshaft digest
      .                              # Dot
      /x

    def logical_path
      strip_assets_prefix(@request.path).sub(FINGERPRINT_REGEXP, ".")
    end
end
