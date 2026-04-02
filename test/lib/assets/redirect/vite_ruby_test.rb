require "test_helper"

class Assets::Redirect::ViteRubyTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  setup { @app = build_app }
  attr_accessor :app

  DIGEST = "391dafc3c8e0f58faf6677e72efb27c1"

  def build_app(options = {})
    default_app = lambda do |env|
      headers = {"Content-Type" => "text/html"}
      [ 200, headers, [ "OK" ] ]
    end

    manifest = mock("manifest")
    # Default: unknown keys raise MissingEntrypointError
    manifest.stubs(:path_for).raises(ViteRuby::MissingEntrypointError.new("not found"))
    # Non-entrypoint asset (image) — no directory prefix
    manifest.stubs(:path_for).with("snowglobe.png").returns("/vite/assets/snowglobe-#{DIGEST}.png")
    manifest.stubs(:path_for).with("deleted-snowglobe.png").returns("/vite/assets/deleted-snowglobe-#{DIGEST}.png")
    # Entrypoint: TypeScript source (.ts)
    manifest.stubs(:path_for).with("entrypoints/inertia.ts").returns("/vite/assets/inertia-#{DIGEST}.js")
    # Entrypoint: JavaScript source (.js)
    manifest.stubs(:path_for).with("entrypoints/application.js").returns("/vite/assets/application-#{DIGEST}.js")
    # Entrypoint: CSS
    manifest.stubs(:path_for).with("entrypoints/application.css").returns("/vite/assets/application-#{DIGEST}.css")

    vite_instance = stub(manifest: manifest)
    ViteRuby.stubs(:instance).returns(vite_instance)

    Assets::Redirect::ViteRuby.new(default_app, nil, **{ public_path: "test/fixtures", assets_prefix: "/vite/assets" }.merge(options))
  end

  def test_redirect_non_entrypoint_asset
    get "http://example.org/vite/assets/snowglobe-8f05909c25ad578ba8fbb27fb28da779.png"
    assert_equal "http://example.org/vite/assets/snowglobe-#{DIGEST}.png",
      last_response.headers["Location"]

    get "http://example.org/vite/assets/snowglobe.png"
    assert_equal "http://example.org/vite/assets/snowglobe-#{DIGEST}.png",
      last_response.headers["Location"]
  end

  def test_redirect_ts_entrypoint
    get "http://example.org/vite/assets/inertia-oldfingerprint123.js"
    assert_equal "http://example.org/vite/assets/inertia-#{DIGEST}.js",
      last_response.headers["Location"]
  end

  def test_redirect_js_entrypoint
    get "http://example.org/vite/assets/application-oldfingerprint123.js"
    assert_equal "http://example.org/vite/assets/application-#{DIGEST}.js",
      last_response.headers["Location"]
  end

  def test_redirect_css_entrypoint
    get "http://example.org/vite/assets/application-oldfingerprint123.css"
    assert_equal "http://example.org/vite/assets/application-#{DIGEST}.css",
      last_response.headers["Location"]
  end

  def test_no_redirect
    # Current fingerprint exists on disk — no redirect needed
    get "http://example.org/vite/assets/snowglobe-#{DIGEST}.png"
    assert_equal 200, last_response.status

    # Non-asset path — passes through
    get "http://example.org/users"
    assert_equal 200, last_response.status

    # Redirect target doesn't exist on disk — passes through
    get "http://example.org/vite/assets/deleted-snowglobe-391dafc3c840f58faf6677e72efb27c1.png"
    assert_equal 200, last_response.status

    # Disabled — passes through
    Assets::Redirect.enabled = false
    get "http://example.org/vite/assets/snowglobe-391dafc3c840f58faf6677e72efb27c1.png"
    assert_equal 200, last_response.status
    Assets::Redirect.enabled = true
  end

  def test_no_redirect_unknown_asset
    get "http://example.org/vite/assets/unknown-oldfingerprint123.js"
    assert_equal 200, last_response.status
  end
end

module ViteRuby
  class MissingEntrypointError < StandardError; end
end
